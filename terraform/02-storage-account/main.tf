# Azure Storage Account
# This depends on the resource group being created first

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

variable "storage_account_name" {
  description = "Name of the storage account (must be globally unique)"
  type        = string
  default     = "tofudemo"
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

# Random suffix for storage account name to ensure uniqueness
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Reference to existing resource group
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

resource "azurerm_storage_account" "main" {
  name                     = "${var.storage_account_name}${random_string.suffix.result}"
  resource_group_name      = data.azurerm_resource_group.main.name
  location                 = data.azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # Security settings
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false

  tags = var.tags
}

# Create a blob container for demo purposes
resource "azurerm_storage_container" "demo" {
  name                 = "demo-container"
  storage_account_id   = azurerm_storage_account.main.id
  container_access_type = "private"
}

output "storage_account_name" {
  value       = azurerm_storage_account.main.name
  description = "The name of the storage account"
}

output "storage_account_id" {
  value       = azurerm_storage_account.main.id
  description = "The ID of the storage account"
}

output "primary_blob_endpoint" {
  value       = azurerm_storage_account.main.primary_blob_endpoint
  description = "The primary blob endpoint"
}

output "container_name" {
  value       = azurerm_storage_container.demo.name
  description = "The name of the blob container"
}
