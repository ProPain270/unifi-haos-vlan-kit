# networks.tf — the tagged VLANs. One resource, driven by the locals.vlans map.
# (Management is the native Default LAN, referenced in main.tf, not created here.)
resource "unifi_network" "vlan" {
  for_each = local.vlans

  name    = each.value.name
  purpose = each.value.guest ? "guest" : "corporate"
  site    = var.unifi_site

  vlan_id      = each.value.id
  subnet       = "${var.net_prefix}.${each.value.third}.1/24"
  dhcp_start   = "${var.net_prefix}.${each.value.third}.100"
  dhcp_stop    = "${var.net_prefix}.${each.value.third}.254"
  dhcp_enabled = true
  domain_name  = var.site_domain

  # mDNS is a site-wide toggle on current UniFi (10.x) — it cannot be set per-network, so
  # it is enabled across the board for HA discovery. Cross-VLAN reach stays gated by firewall.tf.
  multicast_dns = true

  igmp_snooping = contains(["iot", "trusted"], each.key)
}

output "vlan_ids" {
  value = { for k, v in unifi_network.vlan : k => v.id }
}
