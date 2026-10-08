# Remote UniFi + HAOS Deployment Kit

The goal: **connect to a client's site remotely and have the entire network configure itself** —
tagged VLANs, firewall isolation, Wi-Fi, and switch port profiles — then drop in Home Assistant.
This folder is the repeatable, version-controlled config. One `apply` per client.

> **Status: validated end-to-end against a live UniFi Network Application 10.6.106 controller.**
> Clean apply (19 resources, 0 errors), idempotent re-apply (no changes), one-knob re-IP, and a
> full destroy→recreate cycle all pass. See "What's been tested" at the bottom.

```
terraform/
  main.tf        provider + data sources (incl. the native/Management LAN lookup)
  variables.tf   every per-client knob (subnet prefix, SSIDs, HA IP) + the VLAN scheme
  networks.tf    the 5 tagged VLANs (Trusted/IoT/Cameras/Guest/Servers)
  wlans.tf       3 SSIDs -> VLANs, all APs
  firewall.tf    inter-VLAN isolation; HA is the only initiator into IoT/Cameras
  ports.tf       reusable switch port profiles
  terraform.tfvars.example   copy per client
```

## The VLAN scheme (6 segments)

| Segment     | 802.1Q tag | Subnet (net_prefix `10.10`) | Notes                                            |
|-------------|-----------|------------------------------|--------------------------------------------------|
| Management  | **native (VLAN 1)** | the controller's existing Default LAN | **Not created/destroyed by Terraform** — see below |
| Trusted     | 10        | 10.10.10.0/24                | wired + main Wi-Fi                                |
| IoT         | 20        | 10.10.20.0/24                | WPA2, HA reaches in                               |
| Cameras     | 30        | 10.10.30.0/24                | no WAN                                            |
| Guest       | 40        | 10.10.40.0/24                | UniFi guest isolation                            |
| Servers     | 50        | 10.10.50.0/24                | HAOS host (`ha_ip`), NAS                          |

**Why Management is the native VLAN and not a created resource:** in 802.1Q, "management on
VLAN 1" *is* the untagged/native VLAN. UniFi reserves VLAN 1 — you cannot create a second
tagged VID-1 network, and the controller's built-in **Default** LAN is the native network.
The kit therefore **references** that Default LAN (read-only, via `data "unifi_network" "native"`)
so the AP trunk's untagged VLAN points at it, and never tries to create, re-tag, or delete it.
(Managing the protected Default network via Terraform is unreliable — the provider throws
`not found` on update — so we deliberately leave it alone. If a client wants Management re-IP'd
to `10.10.1.0/24`, change the Default LAN's subnet once in the UI during staging.)

## How a remote deploy works (per client)

1. **Get remote reach into the site.** Install Tailscale on one always-on device at the client
   (a mini-PC, the HAOS host, or enable the UniFi/UDM Tailscale integration where available).
   Now the client's UniFi controller (`https://<mgmt-ip>`) is reachable over your tailnet — no
   port-forwarding, no inbound WAN holes. This is the "connect to their PC/desktop" layer.

2. **Stage once on site (or walk the client through it):** adopt the UCG-Max + switch + 7 APs to
   the console, update firmware, and create a dedicated local admin for Terraform (see below).

3. **Configure everything as code — from your Mac:**
   ```bash
   export TF_VAR_unifi_password='…'      # the deploy admin
   export TF_VAR_wifi_pass_main='…'  TF_VAR_wifi_pass_iot='…'  TF_VAR_wifi_pass_guest='…'
   cp terraform.tfvars.example terraform.tfvars    # set api_url, net_prefix, SSIDs, ha_ip
   terraform init
   terraform plan      # review: 5 networks, 3 WLANs, 3 fw groups, 4 fw rules, 4 port profiles
   terraform apply     # the whole network builds itself (19 resources)
   ```
   Re-running against the next client = change `terraform.tfvars`, `apply`. Idempotent.

   **Re-IP the whole site** with one knob: `terraform apply -var 'net_prefix=10.30' -var 'ha_ip=10.30.50.10'`
   (or just edit `terraform.tfvars`). Every subnet, DHCP range, and firewall group follows.

4. **Assign port profiles** (AP-Trunk to the 7 AP ports, Cameras-V30 to the NVR, Servers-V50 to
   the HAOS host, Trusted-V10 to wired PCs). Click in the UI or extend with `unifi_port_override`.

5. **Deploy HAOS** on the Servers VLAN (static `ha_ip`): a HAOS VM/appliance, restore your baseline
   HA backup (HACS, dashboards, Tailscale add-on, UniFi + Protect integrations), done. See
   `../deployment-mock.html` for the architecture and the verification checklist.

## Creating the Terraform admin on a fresh controller (headless)

The provider needs a local super-admin. On a brand-new self-hosted controller you can create one
without the setup wizard:
```bash
curl -sk -c cj -H "Content-Type: application/json" -X POST https://<controller>:8443/api/cmd/sitemgr \
  --data '{"cmd":"add-default-admin","name":"deploy","email":"deploy@site.local","x_password":"<STRONG_PW>"}'
```
On a UCG-Max/UniFi-OS console, create the local admin in the UI (Settings → Admins) instead.

## Provider quirks this kit already handles

Learned by running against a live 10.6 controller — baked into the config so `apply` is a no-op the
second time:
- **WPA3 transition** requires `pmf_mode = "optional"` (WPA3 won't enable with PMF off). Set on the
  main SSID.
- **mDNS is a site-wide toggle** on current UniFi — it can't be set per-network, so `multicast_dns`
  is `true` on all networks. Cross-VLAN reach is still controlled by the firewall rules, not mDNS.
- **Port `forward` is normalised**: an all-VLAN uplink stores as `"all"`; a single-VLAN access port
  stores as `"customize"`. The port profiles declare those exact values so there's no perpetual diff.
- **Firewall address-group members** are literal network CIDRs (`10.10.20.0/24`), derived from the
  variables — not from a network's computed `.subnet` (which the controller normalises and which
  trips a provider set-correlation bug).

## Notes / to refine
- Add later as needed: `unifi_setting_mgmt` (auto-backup, SSH), `unifi_port_forward` (only if a
  service truly needs WAN), VPN (WireGuard on the UCG for your own remote admin), UniFi Protect.
- Keep secrets in env or a vault; commit only `*.tf`, `.terraform.lock.hcl`, and `terraform.tfvars.example`.
- Pinned to provider `paultyng/unifi ~> 0.41`; `.terraform.lock.hcl` locks the exact build.

## What's been tested (sandbox: disposable Debian 12 LXC + UniFi Network 10.6.106)
- `terraform init` + `validate` clean.
- `apply` from scratch: **19 added, 0 changed, 0 destroyed, 0 errors.**
- Idempotency: immediate re-`plan` → **"No changes."**
- Re-IP: `net_prefix 10.10 → 10.20` → **7 changed**, clean, idempotent at the new prefix, reverts clean.
- Full **destroy → recreate**: 19 destroyed → 19 added, clean; the client's Default LAN is untouched.
- Verified on-controller: 5 VLANs with correct subnets/DHCP, 3 SSIDs (WPA3 main / WPA2 IoT / Guest),
  3 firewall groups, 4 firewall rules (established → HA-allow → isolation drop → cameras-no-WAN),
  4 port profiles.
