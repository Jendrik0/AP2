#region Ressource Group
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = var.location
}

#region Network
# Create a network security group
resource "azurerm_network_security_group" "netsec" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

# > Subnet Virtual Machines
resource "azurerm_subnet" "subnet_vm" {
  name                 = "${var.prefix}-subnet-vm"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# > Subnet for Bastion
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# > Subnet for Managed SQL Instance
resource "azurerm_subnet" "subnet_db" {
  name                 = "${var.prefix}-subnet-db"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.3.0/24"]

  delegation {
    name = "managedinstancedelegation"

    service_delegation {
      name = "Microsoft.Sql/managedInstances"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"
      ]
    }
  }
}

# Associate subnet and the security group
resource "azurerm_subnet_network_security_group_association" "subnet_nsg" {
  subnet_id                 = azurerm_subnet.subnet_db.id
  network_security_group_id = azurerm_network_security_group.netsec.id
}

# Create route table
resource "azurerm_route_table" "rt" {
  name                = "${var.prefix}-route-table"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  bgp_route_propagation_enabled = true
}

# Associate subnet and the route table
resource "azurerm_subnet_route_table_association" "subnet_rt" {
  subnet_id      = azurerm_subnet.subnet_db.id
  route_table_id = azurerm_route_table.rt.id

  depends_on = [azurerm_subnet_network_security_group_association.subnet_nsg]
}

#region Azure Bastion
# Azure Bastion requires a dedicated subnet named "AzureBastionSubnet" with a /27 or larger CIDR block 
resource "azurerm_public_ip" "pubip" {
  name                = "${var.prefix}-pubip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bastion" {
  name                = "${var.prefix}-bastion"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.pubip.id
  }
}

#region Virtual Machines
resource "azurerm_network_interface" "vmnic-lnx" {
  name                = "${var.prefix}-nic-lnx"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "configuration"
    subnet_id                     = azurerm_subnet.subnet_vm.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vmlnx" {
  name                            = "${var.prefix}-lnx"
  resource_group_name             = azurerm_resource_group.rg.name
  computer_name                   = "${var.prefix}-lnx"
  location                        = var.location
  size                            = "Standard_B4as_v2"
  disable_password_authentication = false
  admin_username                  = var.admin_username
  admin_password                  = random_password.password.result
  network_interface_ids           = [azurerm_network_interface.vmnic-lnx.id]

  os_disk {
    name                 = "${var.prefix}-osdisk-lnx"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

resource "azurerm_network_interface" "vmnic-win" {
  name                = "${var.prefix}-nic-win"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "configuration"
    subnet_id                     = azurerm_subnet.subnet_vm.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "vmwin" {
  name                  = "${var.prefix}-win"
  admin_username        = var.admin_username
  admin_password        = random_password.password.result
  location              = var.location
  resource_group_name   = azurerm_resource_group.rg.name
  computer_name         = "${var.prefix}-win"
  network_interface_ids = [azurerm_network_interface.vmnic-win.id]
  size                  = "Standard_B4as_v2"

  os_disk {
    name                 = "${var.prefix}-osdisk-win"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}

#region SQL Instance
resource "azurerm_mssql_managed_instance" "mi" {
  name                         = "${var.prefix}-mi"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = var.location
  administrator_login          = var.admin_username
  administrator_login_password = random_password.password.result
  license_type                 = "BasePrice"
  sku_name                     = "GP_Gen5"
  storage_size_in_gb           = 32
  subnet_id                    = azurerm_subnet.subnet_db.id
  vcores                       = 4

  depends_on = [azurerm_subnet_route_table_association.subnet_rt]
}

resource "azurerm_mssql_managed_database" "db" {
  name                = "${var.prefix}-db"
  managed_instance_id = azurerm_mssql_managed_instance.mi.id
}

resource "azurerm_mssql_managed_database" "db-NEW" {
  name                = "${var.prefix}-db-NEW"
  managed_instance_id = azurerm_mssql_managed_instance.mi.id
}

#region etc
# Generate password for resources
resource "random_password" "password" {
  length      = 32
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  min_special = 1
  special     = true
}
