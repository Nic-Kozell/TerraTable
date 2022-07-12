provider "azurerm" {
  features {}
}
##TODO Update this stuff to handle the permissions for all the managed identities to do their things once I rock this in prod.
##Also figure out how to export / import the logic app, not the end of the world if I has to be built manually.. but sux
resource "random_string" "random_suffix" {
  length = 3
  special = false
  upper = false
}

variable "location" {
    default = "westus3"
}
variable "name" {
  default = "agencytable"
}

resource "azurerm_resource_group" "rg" {
  name = "rg-${var.name}-${random_string.random_suffix.result}"
  location = "${var.location}"
}

resource "azurerm_storage_account" "sa" {
    name = "sa${var.name}${random_string.random_suffix.result}"
    resource_group_name = azurerm_resource_group.rg.name
    location = "${var.location}"
    account_tier             = "Standard"
    account_replication_type = "LRS"
}
resource "azurerm_storage_container" "container" {
  name                  = "container${var.name}${random_string.random_suffix.result}"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}

resource "azurerm_storage_table" "tbl" {
  name = "${var.name}${random_string.random_suffix.result}"
  storage_account_name = azurerm_storage_account.sa.name
}

resource "azurerm_logic_app_workflow" "logic" {
  name = "logicapp-${var.name}${random_string.random_suffix.result}"
  location = var.location
  resource_group_name = azurerm_resource_group.rg.name
  # app_service_plan_id = azurerm_service_plan.plan.id
  # storage_account_name = azurerm_storage_account.sa.name
  # storage_account_access_key = azurerm_storage_account.sa.primary_access_key
    identity {
    type = "SystemAssigned"
  }
}
resource "azurerm_automation_account" "aa" {
  name =  "aa-${var.name}${random_string.random_suffix.result}"
  location = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name = "Basic"
  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_monitor_diagnostic_setting" "diagnostic_settings" {
    name                       = "Send all to log analytics"
    target_resource_id         = azurerm_automation_account.aa.id
    log_analytics_workspace_id = "/subscriptions/518c9a02-6606-415d-9fb8-28974db3a5b8/resourcegroups/rg-id-dev-001/providers/microsoft.operationalinsights/workspaces/logworkspacename"
    log_analytics_destination_type = "Dedicated"
    
    log {
        category = "JobLogs"
        enabled  = true
        retention_policy {
            enabled = false
        }
    }
    
    # metric {
    #     category = "AllMetrics"
    #     enabled  = true
    #     retention_policy {
    #         enabled = false
    #     }
    # }
}


resource "azurerm_role_assignment" "aaPermissionsAutomation" {
  scope                = azurerm_automation_account.aa.id
  role_definition_name = "Contributor"
  principal_id         = "${azurerm_automation_account.aa.identity[0].principal_id}"
}

resource "azurerm_role_assignment" "saPermisionsAutomation" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Contributor"
  principal_id         = "${azurerm_automation_account.aa.identity[0].principal_id}"
}

resource "azurerm_role_assignment" "aaPermissionsLogic" {
  scope = azurerm_automation_account.aa.id
  role_definition_name = "Contributor"
  principal_id = azurerm_logic_app_workflow.logic.identity[0].principal_id
}

resource "azurerm_role_assignment" "saPermissionsLogic" {
  scope = azurerm_storage_account.sa.id
  role_definition_name = "Contributor"
  principal_id = azurerm_logic_app_workflow.logic.identity[0].principal_id

}
