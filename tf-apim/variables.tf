variable "rg_name" {
  type = string
}

variable "location" {
  type = string
  default = "westus3"
}

# NETWORKING
variable "vnet_name" {
  type = string
  description = "Virtual Network name"
}

variable "vnet_address_space" {
  type = list(string)
  description = "Virtual network IP address space"
}

variable "snet_common_name" {
  type = string
  description = "Common subnet name"
}

variable "snet_common_cidr" {
  type = string
  description = "CIDR for Common subnet"
}

variable "snet_apim_name" {
  type = string
  description = "APIM subnet name"
}
  
variable "snet_apim_cidr" {
  type = string
  description = "CIDR for APIM subnet"
}

# JUMPBOX VM
variable "vm_pip_name" {
  type = string
  description = "VM Public IP name"
  default = "pip-vm-jumpbox"
}

variable "vm_jumpbox_name" {
  type = string
  description = "Jump Box VM hostname"
}

variable "vm_jumpbox_sku" {
  type = string
  description = "SKU for Jump Box VM"
  default = "Standard_DS2_v2"
}

variable "vm_jumpbox_user" {
  type = string
  description = "Username for shared admin account (when using ssh key auth)"
}

# KEY VAULT
variable "kv_name" {
    type = string
    description = "Key Vault name"
}

# APIM
variable "apim_name" {
  type = string
  description = "API Management service name"
}

variable "apim_sku" {
    type = string
    description = "APIM SKU"
    default = "Developer"
}

variable "apim_capacity" {
    type = number
    description = "The number of scale units to provision"
    default = 1
}

variable "apim_publisher_name" {
    type = string
    description = "The name of your organization for use in the publisher portal and the developer portal."
}

variable "apim_publisher_email" {
    type = string
    description = "The email address to receive all system notifications."
}

variable "apim_domain" {
    type = string
    description = "The custom domain name associated with this instance of API Management."
}

variable "apim_gateway_hostname" {
    type = string
    description = "The gateway URL of the API Management service instance, prepended to apim_domain."
}

variable "apim_portal_hostname" {
    type = string
    description = "The developer portal URL of the API Management service instance, prepended to apim_domain."
}

variable "apim_certificate_kv_name" {
    type = string
    description = "The name of the certificate stored in Key Vault."
}

variable "apim_certificate_file" {
    type = string
    description = "Path to the certificate file (.pfx) containing a private key and its X.509 certificates."
}

variable "apim_certificate_password" {
    type = string
    description = "The password to the certificate file."
    sensitive = true
}
