# Azure Virtual Network
# This creates a VNet with a subnet

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "tofu-demo-rg"
}

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
  default     = "tofu-demo-vnet"
}

variable "address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    environment = "demo"
    managed-by  = "tofu-controller"
    demo        = "flux-tofu"
  }
}

# Reference to existing resource group
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

resource "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  address_space       = var.address_space
  tags                = var.tags
}

resource "azurerm_subnet" "main" {
  name                 = "default-subnet"
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "main" {
  name                = "${var.vnet_name}-nsg"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  tags                = var.tags
}

# Associate NSG with subnet
resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

output "vnet_name" {
  value       = azurerm_virtual_network.main.name
  description = "The name of the virtual network"
}

output "vnet_id" {
  value       = azurerm_virtual_network.main.id
  description = "The ID of the virtual network"
}

output "subnet_id" {
  value       = azurerm_subnet.main.id
  description = "The ID of the subnet"
}

output "nsg_id" {
  value       = azurerm_network_security_group.main.id
  description = "The ID of the network security group"
}
