module "os" {
  source       = "./os"
  vm_os_simple = "${var.vm_os_simple}"
}

resource "azurerm_resource_group" "vm" {
  name     = "${var.resource_group_name}"
  location = "${var.location}"
  tags     = "${var.tags}"
}



resource "random_id" "vm-sa" {
  keepers = {
    vm_hostname = "${var.vm_hostname}"
  }

  byte_length = 6
}

resource "azurerm_storage_account" "vm-sa" {
  count                    = "${var.boot_diagnostics == "true" ? 1 : 0}"
  name                     = "bootdiag${lower(random_id.vm-sa.hex)}"
  resource_group_name      = "${azurerm_resource_group.vm.name}"
  location                 = "${var.location}"
  account_tier             = "${element(split("_", var.boot_diagnostics_sa_type),0)}"
  account_replication_type = "${element(split("_", var.boot_diagnostics_sa_type),1)}"
  tags                     = "${var.tags}"
}


/* resource "azurerm_availability_set" "vm" {
  name                         = "${var.vm_hostname}-avset"
  location                     = "${azurerm_resource_group.vm.location}"
  resource_group_name          = "${azurerm_resource_group.vm.name}"
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true
} */

resource "azurerm_public_ip" "vm_linux" {
  count                        = "${var.vm_os_offer != "WindowsServer"}" ? var.nb_public_ip : 0
  name                         = "${var.vm_hostname}-${count.index}-publicIP"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.vm.name}"
  allocation_method            = "${var.public_ip_address_allocation}"
  domain_name_label            = "${element(var.public_ip_dns, count.index)}"
}

resource "azurerm_public_ip" "vm_windows" {
  count                        = "${var.vm_os_offer == "WindowsServer"}" ? var.nb_public_ip : 0
  name                         = "${var.vm_hostname}-${count.index}-publicIP"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.vm.name}"
  allocation_method            = "${var.public_ip_address_allocation}"
  domain_name_label            = "${element(var.public_ip_dns, count.index)}"
}

resource "azurerm_network_interface" "vm_linux" {
  count                     = "${var.vm_os_offer != "WindowsServer"}" ? var.nb_instances : 0
  name                      = "nic-${var.vm_hostname}-${count.index}"
  location                  = "${azurerm_resource_group.vm.location}"
  resource_group_name       = "${azurerm_resource_group.vm.name}"
  #etwork_security_group_id = "${var.nsg_id}"

  ip_configuration {
    name                          = "ipconfig${count.index}"
    subnet_id                     = "${var.vnet_subnet_id}"
    private_ip_address_allocation = "Dynamic"
    #public_ip_address_id          = "${element(azurerm_public_ip.vm_linux.*.id, count.index)}"
    public_ip_address_id          = azurerm_public_ip.vm_linux[count.index].id
  }
}

resource "azurerm_network_interface" "vm_windows" {
  count                     = "${var.vm_os_offer == "WindowsServer"}" ? var.nb_instances : 0
  name                      = "nic-${var.vm_hostname}-${count.index}"
  location                  = "${azurerm_resource_group.vm.location}"
  resource_group_name       = "${azurerm_resource_group.vm.name}"
  #etwork_security_group_id = "${var.nsg_id}"

  ip_configuration {
    name                          = "ipconfig${count.index}"
    subnet_id                     = "${var.vnet_subnet_id}"
    private_ip_address_allocation = "Dynamic"
    #public_ip_address_id          = "${element(azurerm_public_ip.vm_windows.*.id, count.index)}"
    public_ip_address_id          = azurerm_public_ip.vm_windows[count.index].id
  }
}

resource "azurerm_network_security_group" "nsg" {
  location            = "${var.location}"
  name                = "nsg01"
  resource_group_name = "${azurerm_resource_group.vm.name}"

  security_rule {
    name                       = "SSHWEBRDP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80,22,3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "test_linux" {
  count = "${var.vm_os_offer != "WindowsServer"}" ? var.nb_instances : 0

  network_interface_id      = azurerm_network_interface.vm_linux[count.index].id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_network_interface_security_group_association" "test_windows" {
  count = "${var.vm_os_offer == "WindowsServer"}" ? var.nb_instances : 0

  network_interface_id      = azurerm_network_interface.vm_windows[count.index].id
  network_security_group_id = azurerm_network_security_group.nsg.id
}


resource "azurerm_virtual_machine" "vm-linux" {
  #count                         = "${!contains(list("${var.vm_os_simple}","${var.vm_os_offer}"), "WindowsServer") && var.is_windows_image != "true" && var.data_disk == "false" ? var.nb_instances : 0}"
  count                         = "${var.vm_os_offer != "WindowsServer" && var.is_windows_image != "true" && var.data_disk == "false" ? var.nb_instances : 0}"
  name                          = "${var.vm_hostname}${count.index}"
  location                      = "${var.location}"
  resource_group_name           = "${azurerm_resource_group.vm.name}"
  #availability_set_id           = "${azurerm_availability_set.vm.id}"
  vm_size                       = "${var.vm_size}"
  network_interface_ids         = ["${element(azurerm_network_interface.vm_linux.*.id, count.index)}"]
  #network_interface_ids = [azurerm_network_interface.master[count.index].id]
  delete_os_disk_on_termination = "${var.delete_os_disk_on_termination}"

  storage_image_reference {
    id        = "${var.vm_os_id}"
    publisher = "${var.vm_os_id == "" ? coalesce(var.vm_os_publisher, module.os.calculated_value_os_publisher) : ""}"
    offer     = "${var.vm_os_id == "" ? coalesce(var.vm_os_offer, module.os.calculated_value_os_offer) : ""}"
    sku       = "${var.vm_os_id == "" ? coalesce(var.vm_os_sku, module.os.calculated_value_os_sku) : ""}"
    version   = "${var.vm_os_id == "" ? var.vm_os_version : ""}"
  }

  storage_os_disk {
    name              = "osdisk-${var.vm_hostname}-${count.index}"
    create_option     = "FromImage"
    caching           = "ReadWrite"
    managed_disk_type = "${var.storage_account_type}"
  }

  os_profile {
    computer_name  = "${var.vm_hostname}${count.index}"
    admin_username = "${var.admin_username}"
    admin_password = "${var.admin_password}"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = "${file("${var.ssh_key}")}"
    }
  }

  tags = "${var.tags}"

  boot_diagnostics {
    enabled     = "${var.boot_diagnostics}"
    storage_uri = "${var.boot_diagnostics == "true" ? join(",", azurerm_storage_account.vm-sa.*.primary_blob_endpoint) : "" }"
  }
}

resource "azurerm_virtual_machine" "vm-linux-with-datadisk" {
  count                         = "${var.vm_os_offer != "WindowsServer"  && var.is_windows_image != "true"  && var.data_disk == "true" ? var.nb_instances : 0}"
  name                          = "${var.vm_hostname}${count.index}"
  location                      = "${var.location}"
  resource_group_name           = "${azurerm_resource_group.vm.name}"
  #availability_set_id           = "${azurerm_availability_set.vm.id}"
  vm_size                       = "${var.vm_size}"
  network_interface_ids         = ["${element(azurerm_network_interface.vm_linux.*.id, count.index)}"]
  delete_os_disk_on_termination = "${var.delete_os_disk_on_termination}"

  storage_image_reference {
    id        = "${var.vm_os_id}"
    publisher = "${var.vm_os_id == "" ? coalesce(var.vm_os_publisher, module.os.calculated_value_os_publisher) : ""}"
    offer     = "${var.vm_os_id == "" ? coalesce(var.vm_os_offer, module.os.calculated_value_os_offer) : ""}"
    sku       = "${var.vm_os_id == "" ? coalesce(var.vm_os_sku, module.os.calculated_value_os_sku) : ""}"
    version   = "${var.vm_os_id == "" ? var.vm_os_version : ""}"
  }

  storage_os_disk {
    name              = "osdisk-${var.vm_hostname}-${count.index}"
    create_option     = "FromImage"
    caching           = "ReadWrite"
    managed_disk_type = "${var.storage_account_type}"
  }

  storage_data_disk {
    name              = "datadisk-${var.vm_hostname}-${count.index}"
    create_option     = "Empty"
    lun               = 0
    disk_size_gb      = "${var.data_disk_size_gb}"
    managed_disk_type = "${var.data_sa_type}"
  }

  os_profile {
    computer_name  = "${var.vm_hostname}${count.index}"
    admin_username = "${var.admin_username}"
    admin_password = "${var.admin_password}"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = "${file("${var.ssh_key}")}"
    }
  }

  tags = "${var.tags}"

  boot_diagnostics {
    enabled     = "${var.boot_diagnostics}"
    storage_uri = "${var.boot_diagnostics == "true" ? join(",", azurerm_storage_account.vm-sa.*.primary_blob_endpoint) : "" }"
  }
}

resource "azurerm_virtual_machine" "vm-windows" {
  count                         = "${var.vm_os_offer == "WindowsServer"  && var.is_windows_image != "true"  && var.data_disk == "false" ? var.nb_instances : 0}"
  name                          = "${var.vm_hostname}${count.index}"
  location                      = "${var.location}"
  resource_group_name           = "${azurerm_resource_group.vm.name}"
  #availability_set_id           = "${azurerm_availability_set.vm.id}"
  vm_size                       = "${var.vm_size}"
  network_interface_ids         = ["${element(azurerm_network_interface.vm_windows.*.id, count.index)}"]
  delete_os_disk_on_termination = "${var.delete_os_disk_on_termination}"

  storage_image_reference {
    id        = "${var.vm_os_id}"
    publisher = "${var.vm_os_id == "" ? coalesce(var.vm_os_publisher, module.os.calculated_value_os_publisher) : ""}"
    offer     = "${var.vm_os_id == "" ? coalesce(var.vm_os_offer, module.os.calculated_value_os_offer) : ""}"
    sku       = "${var.vm_os_id == "" ? coalesce(var.vm_os_sku, module.os.calculated_value_os_sku) : ""}"
    version   = "${var.vm_os_id == "" ? var.vm_os_version : ""}"
  }

  storage_os_disk {
    name              = "osdisk-${var.vm_hostname}-${count.index}"
    create_option     = "FromImage"
    caching           = "ReadWrite"
    managed_disk_type = "${var.storage_account_type}"
  }

  os_profile {
    computer_name  = "${var.vm_hostname}${count.index}"
    admin_username = "${var.admin_username}"
    admin_password = "${var.admin_password}"
  }

  tags = "${var.tags}"

  os_profile_windows_config {}

  boot_diagnostics {
    enabled     = "${var.boot_diagnostics}"
    storage_uri = "${var.boot_diagnostics == "true" ? join(",", azurerm_storage_account.vm-sa.*.primary_blob_endpoint) : "" }"
  }
}

resource "azurerm_virtual_machine" "vm-windows-with-datadisk" {
  count                         = "${((var.vm_os_id != "" && var.is_windows_image == "true") || "${var.vm_os_simple}" == "WindowsServer") && var.data_disk == "true" ? var.nb_instances : 0}"
  name                          = "${var.vm_hostname}${count.index}"
  location                      = "${var.location}"
  resource_group_name           = "${azurerm_resource_group.vm.name}"
  #availability_set_id           = "${azurerm_availability_set.vm.id}"
  vm_size                       = "${var.vm_size}"
  network_interface_ids         = ["${element(azurerm_network_interface.vm_windows.*.id, count.index)}"]
  delete_os_disk_on_termination = "${var.delete_os_disk_on_termination}"

  storage_image_reference {
    id        = "${var.vm_os_id}"
    publisher = "${var.vm_os_id == "" ? coalesce(var.vm_os_publisher, module.os.calculated_value_os_publisher) : ""}"
    offer     = "${var.vm_os_id == "" ? coalesce(var.vm_os_offer, module.os.calculated_value_os_offer) : ""}"
    sku       = "${var.vm_os_id == "" ? coalesce(var.vm_os_sku, module.os.calculated_value_os_sku) : ""}"
    version   = "${var.vm_os_id == "" ? var.vm_os_version : ""}"
  }

  storage_os_disk {
    name              = "osdisk-${var.vm_hostname}-${count.index}"
    create_option     = "FromImage"
    caching           = "ReadWrite"
    managed_disk_type = "${var.storage_account_type}"
  }

  storage_data_disk {
    name              = "datadisk-${var.vm_hostname}-${count.index}"
    create_option     = "Empty"
    lun               = 0
    disk_size_gb      = "${var.data_disk_size_gb}"
    managed_disk_type = "${var.data_sa_type}"
  }

  os_profile {
    computer_name  = "${var.vm_hostname}${count.index}"
    admin_username = "${var.admin_username}"
    admin_password = "${var.admin_password}"
  }

  tags = "${var.tags}"

  os_profile_windows_config {}

  boot_diagnostics {
    enabled     = "${var.boot_diagnostics}"
    storage_uri = "${var.boot_diagnostics == "true" ? join(",", azurerm_storage_account.vm-sa.*.primary_blob_endpoint) : "" }"
  }
}


resource "local_file" "ansible_inventory_linux" {
  depends_on = [
        azurerm_virtual_machine.vm-linux, azurerm_virtual_machine.vm-windows
      ]
  content = templatefile("${path.module}/inventory_linux.tmpl",
    {
     linux_vms_name = azurerm_virtual_machine.vm-linux.*.name,
     linux_vms_ip = azurerm_public_ip.vm_linux.*.ip_address
    }
  )
  filename = "inventory_linux"
}

resource "local_file" "ansible_inventory_windows" {
  depends_on = [
        azurerm_virtual_machine.vm-linux, azurerm_virtual_machine.vm-windows
      ]
  content = templatefile("${path.module}/inventory_windows.tmpl",
    {
     windows_vms_name = azurerm_virtual_machine.vm-windows.*.name,
     windows_vms_ip = azurerm_public_ip.vm_windows.*.ip_address
    }
  )
  filename = "inventory_windows"
}