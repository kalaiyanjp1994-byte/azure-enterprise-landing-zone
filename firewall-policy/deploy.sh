#!/usr/bin/env bash
# Deploy the firewall policy management template.
# Usage: ./deploy.sh <resource-group> <firewall-policy-name> [location]
set -euo pipefail

RG="${1:-rg-hub-prod}"
POLICY="${2:-fp-hub-prod-01}"
LOCATION="${3:-westus3}"

echo "▶ What-if: $RG / $POLICY"
az deployment group what-if \
  --resource-group "$RG" \
  --template-file main.bicep \
  --parameters firewallPolicyName="$POLICY" \
  --parameters location="$LOCATION"

echo
read -rp "Apply? (y/N) " ans
[[ "$ans" == "y" ]] || { echo "Aborted."; exit 0; }

echo "▶ Deploying"
az deployment group create \
  --resource-group "$RG" \
  --template-file main.bicep \
  --parameters firewallPolicyName="$POLICY" \
  --parameters location="$LOCATION"
