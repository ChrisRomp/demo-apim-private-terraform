rg_name = "TEST-apim-private-tf"
location = "westus3"

# NETWORKING
vnet_name = "vnet-apim-private-tf1"
vnet_address_space = [ "10.0.0.0/16" ]
snet_common_name = "snet-common"
snet_common_cidr = "10.0.0.0/24"
snet_apim_name = "snet-apim"
snet_apim_cidr = "10.0.1.0/24"

# JUMPBOX VM
vm_jumpbox_name = "vm-jumpbox"
vm_jumpbox_sku = "Standard_DS2_v2"
vm_jumpbox_user = "azureuser"

# KEY VAULT
kv_name = "kv-apim-private-tf1"

# APIM
apim_name = "apim-private-tf1"
apim_sku = "Developer"
apim_capacity = 1
apim_publisher_name = "Contoso"
apim_publisher_email = "ChrisRomp@users.noreply.github.com"
apim_domain = "contoso.com"
apim_gateway_hostname = "apim-gw"
apim_portal_hostname = "apim-portal"
apim_certificate_kv_name = "apim-cert"
apim_certificate_file = "../apim-cert.pfx"
apim_certificate_password = "pass@word1"
