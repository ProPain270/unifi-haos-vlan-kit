# firewall.tf — inter-VLAN isolation. Model:
#   * Allow established/related everywhere (so replies work).
#   * Block IoT/Cameras/Guest from initiating into other internal VLANs.
#   * Home Assistant (single /32) is the ONE host allowed to initiate into IoT + Cameras.
# Rules live in LAN_IN (traffic entering the router from a VLAN, routed to another VLAN).

# --- address groups ---
resource "unifi_firewall_group" "rfc1918" {
  name    = "RFC1918"
  type    = "address-group"
  members = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
}

resource "unifi_firewall_group" "ha_host" {
  name    = "HA-Host"
  type    = "address-group"
  members = [var.ha_ip]
}

# IoT + Cameras + Guest network addresses. Built from vars (NOT the networks' computed
# .subnet, which the controller normalises and which breaks set correlation on apply).
resource "unifi_firewall_group" "isolated_src" {
  name = "Isolated-Source-VLANs"
  type = "address-group"
  members = [
    "${var.net_prefix}.${local.vlans["iot"].third}.0/24",
    "${var.net_prefix}.${local.vlans["cameras"].third}.0/24",
    "${var.net_prefix}.${local.vlans["guest"].third}.0/24",
  ]
}

# --- rules (lower rule_index = evaluated first) ---
resource "unifi_firewall_rule" "allow_established" {
  name              = "Allow established/related"
  action            = "accept"
  ruleset           = "LAN_IN"
  rule_index        = 2000
  protocol          = "all"
  state_established = true
  state_related     = true
}

# HA may initiate into IoT + Cameras (control plane).
resource "unifi_firewall_rule" "ha_to_iot_cams" {
  name                   = "Allow HA -> IoT/Cameras"
  action                 = "accept"
  ruleset                = "LAN_IN"
  rule_index             = 2010
  protocol               = "all"
  src_firewall_group_ids = [unifi_firewall_group.ha_host.id]
}

# Block isolated VLANs (IoT/Cameras/Guest) from reaching any private network.
resource "unifi_firewall_rule" "block_isolated_to_private" {
  name                   = "Block IoT/Cam/Guest -> private"
  action                 = "drop"
  ruleset                = "LAN_IN"
  rule_index             = 2050
  protocol               = "all"
  src_firewall_group_ids = [unifi_firewall_group.isolated_src.id]
  dst_firewall_group_ids = [unifi_firewall_group.rfc1918.id]
}

# Cameras: no internet at all (drop WAN out from the cameras subnet).
resource "unifi_firewall_rule" "cameras_no_wan" {
  name           = "Cameras no WAN"
  action         = "drop"
  ruleset        = "WAN_OUT"
  rule_index     = 2060
  protocol       = "all"
  src_network_id = unifi_network.vlan["cameras"].id
}

# NOTE: UniFi's built-in "Guest" network already isolates Guest; the rule above is defense-in-depth.
