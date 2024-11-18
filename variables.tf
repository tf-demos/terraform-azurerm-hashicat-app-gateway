variable "prefix" {
  description = "This prefix will be included in the name of most resources."
}

variable "location" {
  description = "The region where the virtual network is created."
  default     = "centralus"
}

variable "resource_group_name" {
  description = "Name of the resource group previously created."
}

variable "appgw_subnet_id" {
  description = "ID of the subnet for the VM."
}

variable "vm_ips" {
  type = list(string)
  description = "Private IPs of the backend VMs for this App GW."
}