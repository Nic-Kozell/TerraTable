terraform {
    backend "azurerm"{
      resource_group_name = "cloudtfstate"
      storage_account_name = "tfstatemgb68"
      container_name = "cloudtfstate"
      key = "TerraTable.tfstate"
    }
}
