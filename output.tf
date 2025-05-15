output "password" {
	value = random_password.password.result
	sensitive = true
}
output "IP" {
  value = azurerm_public_ip.pubip.ip_address
}
