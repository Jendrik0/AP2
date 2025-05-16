[AI]

# Azure Infrastructure Terraform Project

This project provisions an Azure infrastructure using Terraform. It creates multiple resources, including:

- A resource group  
- Virtual network and subnets for virtual machines, Bastion host, and SQL managed instance  
- Network security groups and route tables  
- Bastion host with public IP  
- Linux and Windows virtual machines  
- Azure SQL Managed Instance with associated databases  
- Random password generation for secure credentials

## Prerequisites

- [Terraform](https://www.terraform.io) installed
- Valid Azure subscription credentials  
- The necessary providers defined in [providers.tf](providers.tf)
- Required variables defined in [variables.tf](variables.tf) (e.g., admin username, subscription ID, etc.)

## Project Structure

- **main.tf**: Provisioning of all Azure resources including resource groups, networks, VMs, Bastion host, and SQL managed instance ([main.tf](main.tf)).
- **output.tf**: Outputs important data such as the generated password and public IP ([output.tf](output.tf)).
- **providers.tf**: Defines the required provider (AzureRM) and configuration ([providers.tf](providers.tf)).
- **variables.tf**: Contains variables that customize the deployment such as resource prefix, location, admin username, and subscription ID ([variables.tf](variables.tf)).
- **.gitignore**: Specifies files and directories to be excluded from version control ([.gitignore](.gitignore)).

## Setup and Deployment

1. **Initialize Terraform**

   Run the following command to initialize the project and download the provider plugins:

   ```sh
   terraform init
