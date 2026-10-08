# main.tf — provider + shared data sources
# Repeatable UniFi deployment. Point it at a client's controller and `terraform apply`
# to build the tagged VLANs, firewall, Wi-Fi, and switch port profiles on top of the
# controller's existing native LAN (which stays the Management / VLAN 1 network).
#
# Remote flow (per client):
#   1. Reach the client's UniFi controller over Tailscale (see README).
#   2. Set per-client values in terraform.tfvars + creds in env (TF_VAR_unifi_password).
#   3. terraform init && terraform plan && terraform apply
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    unifi = {
      source  = "paultyng/unifi"
      version = "~> 0.41"
    }
  }
}

provider "unifi" {
  username       = var.unifi_username
  password       = var.unifi_password       # export TF_VAR_unifi_password=... (never commit)
  api_url        = var.unifi_api_url        # e.g. https://10.10.1.1 (UCG-Max) or https://unifi:8443
  site           = var.unifi_site           # usually "default"
  allow_insecure = var.unifi_allow_insecure # true for self-signed controller certs
}

# Defaults that already exist on every controller — we attach Wi-Fi to these.
data "unifi_user_group" "default" {}
data "unifi_ap_group" "default" {}

# Management = the native VLAN 1 = the controller's pre-existing "Default" LAN.
# Referenced (never managed/destroyed) so the AP trunk's untagged VLAN points at it.
data "unifi_network" "native" {
  name = "Default"
}
