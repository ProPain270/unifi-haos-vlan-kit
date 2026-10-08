# variables.tf — everything a per-client deploy needs to change lives here.
variable "unifi_api_url" {
  type = string
}
variable "unifi_username" {
  type    = string
  default = "deploy"
}
variable "unifi_password" {
  type      = string
  sensitive = true
}
variable "unifi_site" {
  type    = string
  default = "default"
}
variable "unifi_allow_insecure" {
  type    = bool
  default = true
}

# Subnet prefix — one knob to re-IP the whole site (e.g. "10.10" -> VLANs become 10.10.X.0/24)
variable "net_prefix" {
  type    = string
  default = "10.10"
}
variable "site_domain" {
  type    = string
  default = "home.arpa"
}

# Wi-Fi (passphrases via env: TF_VAR_wifi_pass_main etc.)
variable "ssid_main" {
  type    = string
  default = "Client-Home"
}
variable "ssid_iot" {
  type    = string
  default = "Client-IoT"
}
variable "ssid_guest" {
  type    = string
  default = "Client-Guest"
}
variable "wifi_pass_main" {
  type      = string
  sensitive = true
}
variable "wifi_pass_iot" {
  type      = string
  sensitive = true
}
variable "wifi_pass_guest" {
  type      = string
  sensitive = true
}

# HAOS host static IP on the Servers VLAN (used by firewall "HA is the only initiator" rules)
variable "ha_ip" {
  type    = string
  default = "10.10.50.10"
}

# VLAN scheme — the whole thing in one place.
locals {
  # Management lives on the native VLAN (the controller's existing Default LAN, left
  # untouched). These are the tagged VLANs Terraform builds on top of it.
  vlans = {
    trusted = { id = 10, name = "Trusted", third = 10, guest = false }
    iot     = { id = 20, name = "IoT", third = 20, guest = false }
    cameras = { id = 30, name = "Cameras", third = 30, guest = false }
    guest   = { id = 40, name = "Guest", third = 40, guest = true }
    servers = { id = 50, name = "Servers", third = 50, guest = false }
  }
}
