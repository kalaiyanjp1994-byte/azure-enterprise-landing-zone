# Hub-and-Spoke Azure Network

This project deploys a small Azure hub-and-spoke network using Bicep.

## What It Deploys

- Hub VNet: `Hub-Vnet-prod` (`10.0.0.0/16`)
- Spoke VNet: `Spoke-Vnet-prod` (`10.1.0.0/16`)
- Hub NSG: `nsg-hub-prod`
- Spoke NSG: `nsg-spoke-prod`
- Bidirectional VNet peering
- Azure Bastion in the hub VNet
- Standard, static public IP for Bastion

## Repository Structure

```text
.
├── main.bicep              # Deployment entry point and module orchestration
├── bastion.bicep           # Azure Bastion and public IP resources
└── modules/
    ├── nsg.bicep           # Network security groups and security rules
    ├── peering.bicep       # Hub-to-spoke and spoke-to-hub peerings
    └── vnet.bicep          # Reusable VNet and subnet module
```

`main.json` is a generated ARM template artifact. Edit `main.bicep`, then rebuild it when an ARM JSON file is required.

## Deployment Workflow

The deployment starts at `main.bicep`:

1. Create the hub and spoke NSGs.
2. Create the hub VNet with:
   - `snet-hub-default` (`10.0.1.0/24`)
   - `AzureBastionSubnet` (`10.0.2.0/26`)
3. Create the spoke VNet with `snet-spoke-default` (`10.1.1.0/24`).
4. Create both directions of VNet peering using the VNet module resource ID outputs.
5. Create Azure Bastion after the hub VNet exists.

The VNet module accepts an array of subnet objects with `name` and `prefix` properties. It attaches the supplied NSG to normal subnets, but deliberately does not attach the standard hub NSG to `AzureBastionSubnet`. Azure Bastion rejects an incompatible NSG on that subnet.

## Prerequisites

- An Azure subscription
- An existing Azure resource group, or permission to create one
- Azure CLI installed
- Bicep support through Azure CLI

Sign in and select the subscription:

```bash
az login
az account set --subscription <subscription-id-or-name>
```

Create the resource group when needed:

```bash
az group create \
  --name rg-devops-journey \
  --location eastus
```

## Validate and Deploy

Run these commands from the repository root:

```bash
az bicep build --file main.bicep
```

Deploy to the resource group:

```bash
az deployment group create \
  --resource-group rg-devops-journey \
  --template-file main.bicep
```

To override the defaults:

```bash
az deployment group create \
  --resource-group rg-devops-journey \
  --template-file main.bicep \
  --parameters location=eastus hubVnetName=Hub-Vnet-dev spokeVnetName=Spoke-Vnet-dev
```

The deployment output and operation status can be inspected with:

```bash
az deployment group show \
  --resource-group rg-devops-journey \
  --name main

az deployment operation group list \
  --resource-group rg-devops-journey \
  --name main \
  --output table
```

## Upgrade Bicep

The Azure CLI may report a newer Bicep release. Upgrade it with:

```bash
az bicep upgrade
```

This is optional for deployment unless the installed version cannot compile the template.

## Troubleshooting

### Bastion subnet NSG error

If Azure reports `NetworkSecurityGroupNotCompliantForAzureBastionSubnet`, make sure the Bastion subnet is named exactly `AzureBastionSubnet` and is not associated with the normal hub NSG. The current `modules/vnet.bicep` handles this automatically.

### Peering resource ID error

Peering requires fully qualified VNet resource IDs. The VNet module exports `vnet.id` as `resourceId`, and `main.bicep` passes these values through `hubVnet.outputs.resourceId` and `spokeVnet.outputs.resourceId`.

### Deployment operation details

The top-level deployment error is often only a summary. Use `az deployment operation group list` from the validation section to find the resource-specific error.

## Cleanup

Remove all resources created in the resource group:

```bash
az group delete \
  --name rg-devops-journey \
  --yes \
  --no-wait
```
