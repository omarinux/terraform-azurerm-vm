output "vm_ids" {
  description = "Virtual machine ids created."
  value       = "${concat(azurerm_virtual_machine.vm-windows.*.id, azurerm_virtual_machine.vm-linux.*.id)}"
}

output "network_interface_ids" {
  description = "ids of the vm nics provisoned."
  value       = "${concat(azurerm_network_interface.vm_linux.*.id, azurerm_network_interface.vm_windows.*.id)}"
}

output "network_interface_private_ip" {
  description = "private ip addresses of the vm nics"
  value       = "${concat(azurerm_network_interface.vm_linux.*.private_ip_address, azurerm_network_interface.vm_windows.*.private_ip_address)}"
}

output "public_ip_address_linux" {
  description = "The actual ip address allocated for the resource."
  value       = "${azurerm_public_ip.vm_linux.*.ip_address}"
}

output "public_ip_address_windows" {
  description = "The actual ip address allocated for the resource."
  value       = "${azurerm_public_ip.vm_windows.*.ip_address}"
}

/* output "availability_set_id" {
  description = "id of the availability set where the vms are provisioned."
  value       = "${azurerm_availability_set.vm.id}"
}
 */
/* optionally, retrieve public IP properties
output "public_ip_id" {
  description = "id of the public ip address provisoned."
  value       = "${azurerm_public_ip.vm.*.id}"
}

output "public_ip_address" {
  description = "The actual ip address allocated for the resource."
  value       = "${azurerm_public_ip.vm.*.ip_address}"
}

output "public_ip_dns_name" {
  description = "fqdn to connect to the first vm provisioned."
  value       = "${azurerm_public_ip.vm.*.fqdn}"
}
*/

