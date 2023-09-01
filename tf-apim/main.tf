terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.71.0"
    }
  }
}

provider "azurerm" {
  features {}
  # Configuration options
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config.html
data "azurerm_client_config" "current" {}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group
resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.location
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network
resource "azurerm_virtual_network" "vnet" {
  name = var.vnet_name
  location = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space = var.vnet_address_space
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet
resource "azurerm_subnet" "snet_common" {
  name = var.snet_common_name
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes = [var.snet_common_cidr]

  service_endpoints = [
    "Microsoft.KeyVault"
  ]
}

resource "azurerm_subnet" "snet_apim" {
  name = var.snet_apim_name
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes = [var.snet_apim_cidr]

  service_endpoints = [
    "Microsoft.KeyVault"
  ]
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/network_security_group.html
resource "azurerm_network_security_group" "nsg_common" {
  name                = "nsg-common"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}
resource "azurerm_network_security_group" "nsg_apim" {
  name                = "nsg-apim"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_rule
# https://learn.microsoft.com/en-us/azure/api-management/api-management-using-with-internal-vnet?tabs=stv2#configure-nsg-rules
resource "azurerm_network_security_rule" "apim_management_3443" {
  name                        = "Allow-APIM-Management-3443"
  priority                    = 1010
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_address_prefix       = "ApiManagement"
  destination_port_range      = "3443"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg_apim.name
}
resource "azurerm_network_security_rule" "apim_lb_6390" {
  name                        = "Allow-APIM-LB-6390"
  priority                    = 1020
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_port_range      = "6390"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg_apim.name
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association
resource "azurerm_subnet_network_security_group_association" "snet_nsg_common" {
  subnet_id                 = azurerm_subnet.snet_common.id
  network_security_group_id = azurerm_network_security_group.nsg_common.id
}
resource "azurerm_subnet_network_security_group_association" "snet_nsg_apim" {
  subnet_id                 = azurerm_subnet.snet_apim.id
  network_security_group_id = azurerm_network_security_group.nsg_apim.id
}


### VIRTUAL MACHINE (Jump Box) ###
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip
resource "azurerm_public_ip" "pip_vm_jumpbox" {
  name                = var.vm_pip_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface
resource "azurerm_network_interface" "nic_vm_jumpbox" {
  name                = "${var.vm_jumpbox_name}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet_common.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip_vm_jumpbox.id
  }
}

# https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key
resource "tls_private_key" "vm_jumphost_ssh_key" {
    algorithm = "RSA"
    rsa_bits = 4096
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine
resource "azurerm_linux_virtual_machine" "vm_jumpbox" {
  name                = var.vm_jumpbox_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = var.vm_jumpbox_sku
  admin_username      = var.vm_jumpbox_user
  network_interface_ids = [
    azurerm_network_interface.nic_vm_jumpbox.id,
  ]

  identity {
    type = "SystemAssigned"
  }

  admin_ssh_key {
    username   = var.vm_jumpbox_user
    public_key = tls_private_key.vm_jumphost_ssh_key.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "${var.vm_jumpbox_name}-os-disk"
  }

  # az vm image list-offers -l westus3 --publisher Canonical --query "[?contains(name, 'focal')]"
  # az vm image list-skus -l westus3 --publisher Canonical --offer 0001-com-ubuntu-server-focal
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_extension
# Connect with az ssh vm --resource-group myResourceGroup --name myVM
resource "azurerm_virtual_machine_extension" "vm_jumpbox_aadlogin" {
  name                 = "AADSSHLogin"
  virtual_machine_id   = azurerm_linux_virtual_machine.vm_jumpbox.id
  publisher            = "Microsoft.Azure.ActiveDirectory"
  type                 = "AADSSHLoginForLinux"
  type_handler_version = "1.0"
}

# KEY VAULT
# Fetch local IP address for network rules (so we can upload a cert from TF)
data "http" "myip" {
  url = "https://ipv4.icanhazip.com"
}
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault
resource "azurerm_key_vault" "kv" {
  name                        = var.kv_name
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  sku_name                    = "standard"
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  enable_rbac_authorization   = true

  # Restrict networking for KV
  # Could also use private endpoint
  network_acls {
    virtual_network_subnet_ids = [
      azurerm_subnet.snet_common.id,
      azurerm_subnet.snet_apim.id
    ]
    ip_rules = [chomp(data.http.myip.response_body)]
    default_action = "Deny"
    bypass         = "AzureServices"
  }
}

# APIM
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/api_management
resource "azurerm_api_management" "apim" {
  name                = var.apim_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  publisher_name      = var.apim_publisher_name
  publisher_email     = var.apim_publisher_email

  sku_name = "${var.apim_sku}_${var.apim_capacity}" # e.g., Developer_1
  min_api_version = "2021-08-01" #https://learn.microsoft.com/en-us/azure/api-management/breaking-changes/api-version-retirement-sep-2023

  virtual_network_type = "Internal"
  virtual_network_configuration {
    subnet_id = azurerm_subnet.snet_apim.id
  }

  identity {
    type = "SystemAssigned"
  }

  depends_on = [ 
    azurerm_network_security_rule.apim_management_3443,
    azurerm_network_security_rule.apim_lb_6390
  ]

  # APIM Provisioning is S-L-O-W
  timeouts {
    create = "90m"
    update = "90m"
  }
}

# Grant APIM Identity access to KV secrets
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment
resource "azurerm_role_assignment" "rbac_apim_kv_secrets" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_api_management.apim.identity[0].principal_id
}

# We want to have an SSL certificate for APIM, which can be referenced in Terraform
# a few ways (this is not a complete list, just what I'm showing here):
#   1. Generate a self-signed cert for APIM
#   2. Import an existing certificate from PFX to Key Vault
#   3. Reference an existing certificate in Key Vault

# Option 1: Generate a self-signed cert for APIM
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_certificate
# resource "azurerm_key_vault_certificate" "cert_apim" {
#   name         = "apim-certificate"
#   key_vault_id = azurerm_key_vault.kv.id

#   certificate_policy {
#     issuer_parameters {
#       name = "Self"
#     }

#     key_properties {
#       exportable = true
#       key_size   = 2048
#       key_type   = "RSA"
#       reuse_key  = true
#     }

#     lifetime_action {
#       action {
#         action_type = "AutoRenew"
#       }

#       trigger {
#         days_before_expiry = 30
#       }
#     }

#     secret_properties {
#       content_type = "application/x-pkcs12"
#     }

#     x509_certificate_properties {
#       key_usage = [
#         "cRLSign",
#         "dataEncipherment",
#         "digitalSignature",
#         "keyAgreement",
#         "keyCertSign",
#         "keyEncipherment",
#       ]

#       subject            = "CN=apim.${var.apim_domain}"
#       validity_in_months = 12

#       subject_alternative_names {
#         dns_names = [
#           "${var.apim_gateway_hostname}.${var.apim_domain}",
#           "${var.apim_portal_hostname}.${var.apim_domain}"
#         ]
#       }
#     }
#   }
# }

# Option 2: Import an existing certificate from PFX to Key Vault
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_certificate
resource "azurerm_key_vault_certificate" "cert_apim" {
  name         = var.apim_certificate_kv_name
  key_vault_id = azurerm_key_vault.kv.id

  certificate {
    contents = filebase64(var.apim_certificate_file)
    password = var.apim_certificate_password
  }
}

# Option 3: Reference an existing certificate in Key Vault
# You can upload it with CLI or Portal
# E.g.: az keyvault certificate import --vault-name $keyvault_name --name "$certname" --file "$certname.pfx" --password "$certpass"
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_certificate
# data "azurerm_key_vault_certificate" "cert_apim" {
#   name         = var.apim_certificate_kv_name
#   key_vault_id = azurerm_key_vault.kv.id
# }

# APIM Custom domains
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/api_management_custom_domain
resource "azurerm_api_management_custom_domain" "apim" {
  api_management_id = azurerm_api_management.apim.id

  gateway {
    host_name    = "${var.apim_gateway_hostname}.${var.apim_domain}"
    key_vault_id = azurerm_key_vault_certificate.cert_apim.versionless_secret_id
    default_ssl_binding = true
  }

  developer_portal {
    host_name    = "${var.apim_portal_hostname}.${var.apim_domain}"
    key_vault_id = azurerm_key_vault_certificate.cert_apim.versionless_secret_id
  }

  # This takes a while to update APIM
  timeouts {
    create = "30m"
    update = "30m"
  }
}

# Private DNS Zone
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone
resource "azurerm_private_dns_zone" "apim" {
  name                = var.apim_domain
  resource_group_name = azurerm_resource_group.rg.name
}

# Private DNS Zone Link
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone_virtual_network_link
resource "azurerm_private_dns_zone_virtual_network_link" "apim" {
  name                  = "dns-apim"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.apim.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

# Add A Records for APIM Gateway and Portal
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_a_record
resource "azurerm_private_dns_a_record" "apim_gateway" {
  name                = var.apim_gateway_hostname
  zone_name           = azurerm_private_dns_zone.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  records             = [azurerm_api_management.apim.private_ip_addresses[0]]
}
resource "azurerm_private_dns_a_record" "apim_portal" {
  name                = var.apim_portal_hostname
  zone_name           = azurerm_private_dns_zone.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  records             = [azurerm_api_management.apim.private_ip_addresses[0]]
}
