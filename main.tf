terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.9.0"
    }
  }
}

#######################
#      Public IP      #
#######################
resource "azurerm_public_ip" "catapp-pip" {
  name                = "${var.prefix}-ip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  domain_name_label   = "${var.prefix}-meow"
}

#######################
# Application Gateway #
#######################
# since these variables are re-used - a locals block makes this more maintainable
locals {
  backend_address_pool_name      = "${var.prefix}-beap"
  frontend_port_name             = "${var.prefix}-feport"
  frontend_ip_configuration_name = "${var.prefix}-feip"
  http_setting_name              = "${var.prefix}-be-htst"
  listener_name                  = "${var.prefix}-httplstn"
  request_routing_rule_name      = "${var.prefix}-rqrt"
  redirect_configuration_name    = "${var.prefix}-rdrcfg"
}

resource "azurerm_application_gateway" "network" {
  name                = "${var.prefix}-appgateway"
  resource_group_name = var.resource_group_name
  location            = var.location
  #Associate with the WAF defined below
  firewall_policy_id  = azurerm_web_application_firewall_policy.example.id
  depends_on = [ azurerm_web_application_firewall_policy.example ]

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = var.appgw_subnet_id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.catapp-pip.id
  }

  backend_address_pool {
    name            = local.backend_address_pool_name
    ip_addresses    = var.vm_ips
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    # path                  = "/path1/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    priority                   = 9
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  }
}

#########################
#    AppGW WAF policy   #
#########################
resource "azurerm_web_application_firewall_policy" "example" {
  name                = "${var.prefix}-wafpolicy1"
  resource_group_name = var.resource_group_name
  location            = var.location

  custom_rules {
    name      = "BlockRule2"
    priority  = 2
    rule_type = "MatchRule"

    match_conditions {
      match_variables {
        variable_name = "QueryString"
      }

      operator           = "Contains"
      match_values       = ["promo"]
    }
    action = "Block"
  }

  managed_rules {

    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
      rule_group_override {
        rule_group_name = "REQUEST-920-PROTOCOL-ENFORCEMENT"

        rule {
          id      = "920440"
          enabled = true
          action  = "Block"
        }
      }
    }
  }
}

# front door profile
resource "azurerm_cdn_frontdoor_profile" "demo-frontdoor" {
  name                = "${var.prefix}-cdn-profile"
  resource_group_name = var.resource_group_name
  sku_name            = "Standard_AzureFrontDoor"

  tags = {
    environment = "Production"
  }
}

#########################
# Front door WAF policy #
#########################
# This is a module in the public registry
# Check: https://registry.terraform.io/modules/Azure/avm-res-network-frontdoorwebapplicationfirewallpolicy/azurerm/latest

# Instantiate the WAF Policy Module
module "frontdoor_waf_policy" {
  source  = "Azure/avm-res-network-frontdoorwebapplicationfirewallpolicy/azurerm"
  version = "0.1.0"

  name                = "${var.prefix}0mywafpolicy"
  resource_group_name = var.resource_group_name
  mode                = "Prevention"
  sku_name            = "Premium_AzureFrontDoor"

  request_body_check_enabled        = true
  redirect_url                      = "https://www.hashicorp.com/"
  custom_block_response_status_code = 405
  custom_block_response_body        = base64encode("Blocked by WAF")

  custom_rules = [
    #custom rule 1
    {
      name     = "BlockRule1"
      priority = 1
      type     = "MatchRule"
      action   = "Redirect"
      match_conditions  = [{
        match_variable = "QueryString"
        operator       = "Contains"
        match_values   = ["promo"]
        }
      ]
    },
  ]
  managed_rules = [
    #Managed Rule example - Microsoft_BotManagerRuleSet
    {
      action  = "Block"
      type    = "Microsoft_BotManagerRuleSet"
      version = "1.1"
    }
  ]
}
