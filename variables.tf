variable "prefix" {
  description = "Prefix for all resources"
  type        = string
  default     = "ap"
}
variable "location" {
  description = "Azure location"
  type        = string
  default     = "westeurope"
}
variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
}
variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
  
}
