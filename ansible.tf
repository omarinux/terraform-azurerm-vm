
resource "local_file" "ansible_inventory_linux" {
  depends_on = [
        azurerm_virtual_machine.vm-linux, azurerm_virtual_machine.vm-windows, azurerm_public_ip.vm_linux,
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
        azurerm_virtual_machine.vm-linux, azurerm_virtual_machine.vm-windows, azurerm_public_ip.vm_windows,
      ]
  content = templatefile("${path.module}/inventory_windows.tmpl",
    {
     #windows_vms_name = azurerm_virtual_machine.vm-windows.*.name,
     windows_vms_ip = azurerm_public_ip.vm_windows.*.ip_address
    }
  )
  filename = "inventory_windows"
}


resource "null_resource" "ansible_linux" {
  
  count                         = "${var.vm_os_offer != "WindowsServer" ? 1 : 0}"
  
    depends_on = [
      local_file.ansible_inventory_linux
    ]
  provisioner "local-exec" {
    command = "sleep 120"
    }
  
  provisioner "local-exec" {
    
    command = "ansible-playbook -i inventory_linux ${path.module}/setup.yml"
    }

}

resource "null_resource" "terraform_sample"{
  count                         = "${var.vm_os_offer == "WindowsServer" ? 1 : 0}"
  
  /* triggers = {
    last_windows_update = "2020-03-24.008"
  } */

  connection {
    type     = "winrm"
    user     = "azureuser"
    password = "Pallone2023!!!"
    host     = element(azurerm_public_ip.vm_windows.*.ip_address, 0)
    timeout  = "20s"
    https    = false
    use_ntlm = true
    insecure = true
  }

  provisioner "file" {
    source      = "${path.module}/scripts/windows"
    destination = "c:/windows/temp"
  }
  provisioner "remote-exec" {
    inline = [
      "powershell.exe -ExecutionPolicy Bypass -File c:/windows/temp/chocolatey.org_install.ps1"
    ]
  }
}