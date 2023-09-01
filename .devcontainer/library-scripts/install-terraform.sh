#!/bin/bash
# https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli

# Required apps
apt-get update && apt-get install -y gnupg software-properties-common

# Fetch the GPG key
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg

# Install the GPG key
gpg --no-default-keyring \
    --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    --fingerprint

# Optional: Verify the fingerprint
# gpg --no-default-keyring \
#     --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg \
#     --fingerprint

# Add the HashiCorp Linux repository
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
    https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    tee /etc/apt/sources.list.d/hashicorp.list

# Get package information
apt-get update

# Install Terraform
apt-get install terraform -y
