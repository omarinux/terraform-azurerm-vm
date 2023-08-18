
resource "local_file" "ansible_inventory_linux" {
  depends_on = [
        azurerm_virtual_machine.vm-linux, azurerm_public_ip.vm_linux
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
        azurerm_public_ip.vm_windows
      ]

  content = templatefile("${path.module}/inventory_windows.tmpl",
    {
     #windows_vms_name = azurerm_virtual_machine.vm-windows.*.name,
     windows_vms_ip = azurerm_public_ip.vm_windows.*.ip_address
    }
  )
  filename = "inventory_windows"
}


resource "local_file" "AnsibleInventory" {
 depends_on = [
        azurerm_public_ip.vm_windows
      ]
 
 content = templatefile("${path.module}/inventory.tmpl",
   {
     vm-names                   = [for k, p in azurerm_virtual_machine.vm-windows: p.name],
     public-ip                  = [for k, p in azurerm_public_ip.vm_windows: p.ip_address]
   }
 )
 filename = "inventory_windows_for"
}


resource "null_resource" "ansible_linux" {
  
  count                         = "${var.vm_os_offer != "WindowsServer" ? 1 : 0}"
  
    depends_on = [
      local_file.ansible_inventory_linux, azurerm_virtual_machine.vm-linux
    ]
  provisioner "local-exec" {
    command = "sleep 120"
    }
  
  provisioner "local-exec" {
    
    command = "ansible-playbook -i inventory_linux ${path.module}/setup.yml"
    }

}

# already on custom image
/* resource "null_resource" "terraform_sample"{
  count                        = "${var.vm_os_offer == "WindowsServer"}" ? var.nb_public_ip : 0

  depends_on = [
        azurerm_virtual_machine.vm-windows, azurerm_public_ip.vm_windows,
      ]
  
  /* triggers = {
    last_windows_update = "2020-03-24.008"
  } 

  connection {
    type     = "winrm"
    port = 5986
    user     = "azureuser"
    password = "Pallone2023!!!"
    host     = azurerm_public_ip.vm_windows[count.index].ip_address
    timeout  = "2m"
    https    = true
    use_ntlm = false
    insecure = true
  }

  provisioner "file" {
    source      = "${path.module}/scripts/windows/ConfigureRemotingForAnsible.ps1"
    destination = "c:/windows/temp/ConfigureRemotingForAnsible.ps1"
  }
  provisioner "remote-exec" {
    inline = [
      "powershell.exe winrm quickconfig -q"
    ]
  }
}

 */
resource "null_resource" "ansible_windows" {
  
  #count                         = "${var.vm_os_offer == "WindowsServer" ? 1 : 0}"
  
/*     depends_on = [
      null_resource.terraform_sample
    ] */
  provisioner "local-exec" {
    command = "sleep 180"
    }
  
  provisioner "local-exec" {
    
    command = "ansible-playbook -i inventory_windows_for ${path.module}/setup.yml"
    }

}