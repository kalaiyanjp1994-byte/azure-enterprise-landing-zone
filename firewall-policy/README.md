# Firewall Policy — Bicep

Manages settings, rule collection groups, and rule collections of an **existing**
Azure Firewall Policy that was created in the hub deployment and attached to
the hub firewall.

## Layout
```
firewall-policy/
├── main.bicep                      # Parent policy settings + 4 RCG modules
├── main.bicepparam                 # Parameter file
├── deploy.sh                       # what-if + apply helper
├── modules/
│   ├── rcg-dnat-platform.bicep     # DNAT inbound (RDP, SSH, HTTPS)
│   ├── rcg-network-platform.bicep  # Network rules (spoke↔spoke, Azure platform)
│   ├── rcg-app-egress.bicep        # Application rules (egress to internet)
│   └── rcg-app-shared.bicep        # Application rules (KeyVault, ACR, Files)
```

## What this template does
1. **References** the existing `Microsoft.Network/firewallPolicies` by name and
   updates its settings (SKU, threat intel, DNS, intrusion detection, etc.).
2. **Declares** four `ruleCollectionGroups`, each with its own
   `ruleCollections` (DNAT, Network, Application).
3. Priorities are spaced (100, 200, 300, 400) — change as needed; lower
   number wins.

## What you must change
- Replace `203.0.113.0/24` / `198.51.100.42/32` with your real admin source
  IPs in `modules/rcg-dnat-platform.bicep`.
- Replace `<firewallPublicIp>` placeholders with the actual public IP of the
  firewall (or use a `dnatFqdn` if you front it differently).
- Edit spoke CIDRs in `main.bicep` `var sharedSpokes` to match your hub
  topology.
- If you want flow/log analytics, fill the `insights` block in `main.bicep`.
- Set `autoLearnPrivateRanges: 'Disabled'` if you want strict RFC1918
  behavior.

## Deploy
```bash
./deploy.sh rg-hub-prod fp-hub-prod-01 westus3
```

## Verify
```bash
az network firewall policy show \
  --resource-group rg-hub-prod \
  --name fp-hub-prod-01 \
  --query "{name:name, sku:sku.tier, threatIntel:threatIntelMode, dns:dnsSettings.enableProxy}"

az network firewall policy rule-collection-group list \
  --resource-group rg-hub-prod \
  --policy-name fp-hub-prod-01 \
  --query "[].{name:name, priority:priority}"
```

## Best practices encoded
- **RULE processing for DNAT happens first.** All RCGs hold their own
  priorities; Azure evaluates them in numeric order.
- **`autoLearnPrivateRanges: Enabled`** for hub-and-spoke top so VNets flow
  to the firewall.
- **`threatIntelMode: Deny`** with the built-in feeds.
- **FQDN tags** (`AzureDiagnostics`, `AzurePortal`) used where possible —
  they’re automatically maintained by the platform.
- **Module split** keeps each RCG < 100 lines so diffs are reviewable.
- **Idempotent** — re-running the deploy adds/updates but never duplicates
  rule IDs (Azure handles identity).

## When to apply
- Setting changes: usually fine, but `sku` can take ~2 min to update.
- Adding new collections: safe to apply any time.
- Removing collections: Bicep will delete them; check for a `Remove` window
  in the pipeline previews.
