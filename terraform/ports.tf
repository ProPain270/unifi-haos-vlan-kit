# ports.tf — reusable switch port profiles. Assign these to ports in the UI (or extend with
# unifi_port_override per switch). Current UniFi normalises "forward": an all-VLAN uplink
# becomes "all", a single-VLAN access port becomes "customize" — config matches so re-apply is a no-op.

# AP uplink: native = the native/Management LAN, all tagged VLANs carried (forward = all). PoE on.
resource "unifi_port_profile" "ap_trunk" {
  name                  = "AP-Trunk"
  native_networkconf_id = data.unifi_network.native.id
  forward               = "all"
  poe_mode              = "auto"
  op_mode               = "switch"
}

resource "unifi_port_profile" "cameras" {
  name                  = "Cameras-V30"
  native_networkconf_id = unifi_network.vlan["cameras"].id
  forward               = "customize" # access port, VLAN 30 only
  poe_mode              = "auto"
  op_mode               = "switch"
}

resource "unifi_port_profile" "servers" {
  name                  = "Servers-V50" # HAOS host, NAS
  native_networkconf_id = unifi_network.vlan["servers"].id
  forward               = "customize"
  poe_mode              = "off"
  op_mode               = "switch"
}

resource "unifi_port_profile" "trusted" {
  name                  = "Trusted-V10" # wired PCs
  native_networkconf_id = unifi_network.vlan["trusted"].id
  forward               = "customize"
  poe_mode              = "off"
  op_mode               = "switch"
}
