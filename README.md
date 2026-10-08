# UniFi + Home Assistant VLAN Deployment Kit

Infrastructure-as-code for standing up a segmented home or small-site network on UniFi, ready for a
Home Assistant install: five tagged VLANs (Trusted / IoT / Cameras / Guest / Servers), three SSIDs
mapped to VLANs, inter-VLAN firewall isolation where Home Assistant is the only initiator into IoT
and Cameras, and reusable switch-port profiles. One `terraform apply` per site, driven by a small
`terraform.tfvars`.

Validated end-to-end against a live UniFi Network Application 10.6.x controller: clean apply,
idempotent re-apply, one-knob re-IP, and a full destroy/recreate cycle.

- [`terraform/`](terraform/README.md) — the Terraform configuration and the full deployment runbook
- [`deployment-mock.html`](deployment-mock.html) — a static mock of the resulting topology used for client walkthroughs

No site-specific values, credentials or state files are committed; copy `terraform.tfvars.example`
per site.
