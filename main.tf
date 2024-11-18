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

  sku {
    name     = "Basic"
    tier     = "Basic"
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