@description('Name of the parent firewall policy')
param firewallPolicyName string

@description('Name of this rule collection group')
param ruleCollectionGroupName string

@description('Priority of the RCG (100-65000)')
@minValue(100)
@maxValue(65000)
param priority int

@description('Internal CIDR ranges for spoke VNETs')
param spokes object

@description('AppGateway infrastructure subnet range')
param appGwInfraRanges array = []

@description('Tags')
param tags object = {}

//------------------------------------------------------------------------------
// Network rule collections: well-known service traffic
//------------------------------------------------------------------------------
resource rcg 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = {
  parent: existingPolicy
  name: ruleCollectionGroupName
  properties: {
    priority: priority
    ruleCollections: [
      // ---------- Allow spokes to talk to each other on common ports ----------
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'RC-SpokeToSpoke'
        priority: 100
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'AllowSpokeToSpoke-HTTPS'
            description: 'Allow HTTPS between landing-zone spokes'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              spokes.hub
              spokes.app
              spokes.data
              spokes.shared
            ]
            destinationAddresses: [
              spokes.app
              spokes.data
              spokes.shared
            ]
            destinationPorts: [
              '443'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'AllowSpokeToSpoke-RDP'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              spokes.shared
            ]
            destinationAddresses: [
              spokes.app
              spokes.data
            ]
            destinationPorts: [
              '3389'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'AllowSpokeToSpoke-SQL'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              spokes.app
            ]
            destinationAddresses: [
              spokes.data
            ]
            destinationPorts: [
              '1433'
              '11000-11999'
            ]
          }
        ]
      }

      // ---------- Spoke → Azure platform services (DNS, KMS, AAD, etc.) ----------
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'RC-SpokeToAzurePlatform'
        priority: 200
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'AllowAzureDNS'
            ipProtocols: [
              'UDP'
              'TCP'
            ]
            sourceAddresses: [
              spokes.hub
              spokes.app
              spokes.data
              spokes.shared
            ]
            destinationAddresses: [
              '168.63.129.16'
              'AzureDNS'
            ]
            destinationPorts: [
              '53'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'AllowAzureKMS'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              spokes.hub
              spokes.app
              spokes.data
              spokes.shared
            ]
            destinationAddresses: [
              '23.102.135.246'
              '40.90.220.85'
              '23.102.135.245'
              'AzureKeyVault'
            ]
            destinationPorts: [
              '1688'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'AllowAzureAD-TLS'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              spokes.hub
              spokes.app
              spokes.data
              spokes.shared
            ]
            destinationAddresses: [
              'AzureActiveDirectory'
            ]
            destinationPorts: [
              '443'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'AllowAzureMonitor'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              spokes.hub
              spokes.app
              spokes.data
              spokes.shared
            ]
            destinationAddresses: [
              'AzureMonitor'
            ]
            destinationPorts: [
              '443'
            ]
          }
        ]
      }

      // ---------- App Gateway tier needs to reach control plane ----------
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'RC-AppGatewayInfrastructure'
        priority: 300
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'AllowAppGwInfrastructure'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: appGwInfraRanges
            destinationAddresses: [
              'GatewayManager'
            ]
            destinationPorts: [
              '443'
            ]
          }
        ]
      }
    ]
  }
}

resource existingPolicy 'Microsoft.Network/firewallPolicies@2024-05-01' existing = {
  name: firewallPolicyName
}

output name string = rcg.name
output resourceId string = rcg.id
