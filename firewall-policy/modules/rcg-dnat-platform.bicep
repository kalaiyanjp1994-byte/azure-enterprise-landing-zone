@description('Name of the parent firewall policy')
param firewallPolicyName string

@description('Name of this rule collection group')
param ruleCollectionGroupName string

@description('Priority of the RCG within the policy (100-65000)')
@minValue(100)
@maxValue(65000)
param priority int

//------------------------------------------------------------------------------
// Rule Collection: DNAT — inbound shared services
//------------------------------------------------------------------------------
resource rcg 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = {
  parent: existingPolicy
  name: ruleCollectionGroupName
  properties: {
    priority: priority
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyNatRuleCollection'
        name: 'RC-DNAT-SharedServices'
        priority: 100
        action: {
          type: 'Dnat'
        }
        rules: [
          {
            ruleType: 'NatRule'
            name: 'DNAT-RDPJumpbox'
            description: 'Inbound RDP to jumpbox via FW public IP'
            translatedAddress: '10.10.0.4'
            translatedPort: '3389'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              '203.0.113.0/24'  // Replace with corporate egress CIDR
              '198.51.100.42/32' // Replace with admin public IP
            ]
            destinationAddresses: [
              '<firewallPublicIp>'  // Resolved by the firewall itself
            ]
            destinationPorts: [
              '3389'
            ]
          }
          {
            ruleType: 'NatRule'
            name: 'DNAT-HTTPS-AppGw'
            description: 'Inbound 443 to application gateway'
            translatedAddress: '10.10.0.20'
            translatedPort: '443'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              '*'
            ]
            destinationAddresses: [
              '<firewallPublicIp>'
            ]
            destinationPorts: [
              '443'
            ]
          }
          {
            ruleType: 'NatRule'
            name: 'DNAT-SSH-Bastion'
            description: 'Inbound SSH to jumpbox via bastion host'
            translatedAddress: '10.10.0.5'
            translatedPort: '22'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              '203.0.113.0/24'
            ]
            destinationAddresses: [
              '<firewallPublicIp>'
            ]
            destinationPorts: [
              '22'
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
