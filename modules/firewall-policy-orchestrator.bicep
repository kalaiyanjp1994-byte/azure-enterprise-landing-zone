param location string = resourceGroup().location
param policyName string = 'fp-hub-prod'
param tags object = {}

resource policy 'Microsoft.Network/firewallPolicies@2024-05-01' = {
  name: policyName
  location: location
  tags: tags
  properties: {
    sku: {
      tier: 'Standard'
    }
    threatIntelMode: 'Deny'
  }
}

// Orchestrate the Rule Collection Groups (RCGs) using your existing modular logic
module platformRcg '../firewall-policy/modules/rcg-dnat-platform.bicep' = {
  name: 'deploy-rcg-dnat-platform'
  params: {
    firewallPolicyName: policyName
    ruleCollectionGroupName: 'RCG-Platform-DNAT'
    priority: 100
  }
}

module platformNetworkRcg '../firewall-policy/modules/rcg-network-platform.bicep' = {
  name: 'deploy-rcg-network-platform'
  params: {
    firewallPolicyName: policyName
    ruleCollectionGroupName: 'RCG-Platform-Network'
    priority: 200
    appGwInfraRanges: ['10.0.100.0/24']
    spokes: {
      hub: '10.0.0.0/16'
      app: '10.1.0.0/16' // Matched to your main.bicep spoke prefix
    }
  }
}

module appEgressRcg '../firewall-policy/modules/rcg-app-egress.bicep' = {
  name: 'deploy-rcg-app-egress'
  params: {
    firewallPolicyName: policyName
    ruleCollectionGroupName: 'RCG-Application-Egress'
    priority: 300
  }
}

module appSharedRcg '../firewall-policy/modules/rcg-app-shared.bicep' = {
  name: 'deploy-rcg-app-shared'
  params: {
    firewallPolicyName: policyName
    ruleCollectionGroupName: 'RCG-Application-Shared'
    priority: 400
  }
}

output policyId string = policy.id
output policyName string = policy.name
