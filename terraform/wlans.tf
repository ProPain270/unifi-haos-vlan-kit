# wlans.tf — 3 SSIDs mapped to their VLANs, broadcast on all APs (default AP group).
resource "unifi_wlan" "main" {
  name            = var.ssid_main
  security        = "wpapsk"
  wpa3_support    = true
  wpa3_transition = true
  pmf_mode        = "optional" # WPA3 transition mode requires PMF >= optional
  passphrase      = var.wifi_pass_main
  network_id      = unifi_network.vlan["trusted"].id
  user_group_id   = data.unifi_user_group.default.id
  ap_group_ids    = [data.unifi_ap_group.default.id]
  wlan_band       = "both"
}

resource "unifi_wlan" "iot" {
  name          = var.ssid_iot
  security      = "wpapsk" # WPA2 — many IoT devices can't do WPA3
  passphrase    = var.wifi_pass_iot
  network_id    = unifi_network.vlan["iot"].id
  user_group_id = data.unifi_user_group.default.id
  ap_group_ids  = [data.unifi_ap_group.default.id]
  wlan_band     = "both" # keep 2.4 enabled for IoT reach
}

resource "unifi_wlan" "guest" {
  name          = var.ssid_guest
  security      = "wpapsk"
  passphrase    = var.wifi_pass_guest
  network_id    = unifi_network.vlan["guest"].id
  user_group_id = data.unifi_user_group.default.id
  ap_group_ids  = [data.unifi_ap_group.default.id]
  wlan_band     = "both"
  is_guest      = true # applies guest policies/isolation
}
