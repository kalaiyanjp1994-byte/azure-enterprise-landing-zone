@description('Name of the parent firewall policy')
param firewallPolicyName string

@description('Name of this rule collection group')
param ruleCollectionGroupName string

@description('Priority of the RCG (100-65000)')
@minValue(100)
@maxValue(65000)
param priority int

@description('Tags')
param tags object = {}

resource rcg 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = {
  parent: existingPolicy
  name: ruleCollectionGroupName
  properties: {
    priority: priority
    ruleCollections: [
      // ---------- Application-aware rules for shared services ----------
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'RC-SharedServices-Outbound'
        priority: 100
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'AllowKeyVault'
            description: 'Workloads fetching secrets from any KV within the tenant'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            targetFqdns: [
              '*.vault.azure.net'
              '*.vault.usgovcloudapi.net'
            ]
            sourceAddresses: [
              '10.10.0.0/16'
              '10.20.0.0/16'
            ]
          }
          {
            ruleType: 'ApplicationRule'
            name: 'AllowContainerRegistry'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            targetFqdns: [
              '*.azurecr.io'
              '*.blob.core.windows.net'
            ]
            sourceAddresses: [
              '10.10.0.0/16'
            ]
          }
          {
            ruleType: 'ApplicationRule'
            name: 'AllowAzureFiles'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            targetFqdns: [
              '*.file.core.windows.net'
              '*.file.core.usgovcloudapi.net'
            ]
            sourceAddresses: [
              '10.10.0.0/16'
              '10.20.0.0/16'
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
