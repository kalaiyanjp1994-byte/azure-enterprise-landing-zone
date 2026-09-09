param location string = resourceGroup().location
param firewallName string = 'afw-hub-prod'
param publicIpName string = 'pip-afw-hub-prod'
param firewallPolicyId string
param subnetId string
param tags object = {}

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: publicIpName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2023-09-01' = {
  name: firewallName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    firewallPolicy: {
      id: firewallPolicyId
    }
    ipConfigurations: [
      {
        name: 'azurefirewall0'
        properties: {
          publicIPAddress: {
            id: publicIp.id
          }
          subnet: {
            id: subnetId
          }
        }
      }
    ]
  }
}

output firewallId string = firewall.id
output firewallPublicIp string = publicIp.properties.ipAddress
