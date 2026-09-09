@description('Name of the existing Firewall Policy created by the hub deployment')
param firewallPolicyName string

@description('Azure region for the policy (must match the policy region)')
param location string = resourceGroup().location

@description('SKU tier of the parent firewall policy. Determines which features are available.')
@allowed([
  'Standard'
  'Premium'
])
param skuTier string = 'Premium'

@description('Enable threat intelligence to alert/deny traffic from known malicious IPs')
param threatIntelMode string = 'Deny'

@description('Autogenerate a default workarounds path for some IdP signatures (Premium only, recommended true)')
param allowActiveFTP bool = true

@description('Autogenerate SNAT for private ranges (default true)')
param autoLearnPrivateRanges string = 'Enabled'

@description('Whether to enable DNS proxy on the firewall')
param dnsProxyEnabled bool = false

@description('DNS servers used when DNS proxy is enabled. Required if dnsProxyEnabled = true.')
param dnsServers string[] = []

@description('SQL redirect settings (Premium only)')
param sqlRedirectEnabled bool = false

@description('Explicit IDs of the parent firewall policy to inherit from. Use for cross-region/centralised policies.')
param basePolicyResourceIds string[] = []

@description('Tags to apply to all resources')
param tags object = {}

//------------------------------------------------------------------------------
// Reference the existing policy created by the hub deployment
//------------------------------------------------------------------------------
resource existingPolicy 'Microsoft.Network/firewallPolicies@2024-05-01' existing = {
  name: firewallPolicyName
}

//------------------------------------------------------------------------------
// Update parent policy settings (idempotent - settings already on the policy)
//------------------------------------------------------------------------------
resource policySettings 'Microsoft.Network/firewallPolicies@2024-05-01' = {
  name: firewallPolicyName
  location: location
  tags: tags
  identity: empty(existingPolicy.identity) ? null : existingPolicy.identity
  properties: {
    sku: {
      tier: skuTier
    }
    threatIntelMode: threatIntelMode
    threatIntelWhitelist: {
      fqdns: []
      ipAddresses: []
    }
    insights: {
      isEnabled: false
    }
    dnsSettings: {
      servers: dnsServers
      enableProxy: dnsProxyEnabled
      requireProxyForNetworkRules: false
    }
    sqlSetting: sqlRedirectEnabled ? {
      id: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/TODO/providers/Microsoft.Sql/servers/TODO-SQL'
    } : null
    transportSecurity: null
    explicitProxy: {
      enableExplicitProxy: false
    }
    intrusionDetection: skuTier == 'Premium' ? {
      mode: 'Deny'
      configuration: {
        signatureOverrides: []
        bypassTrafficSettings: []
        privateRanges: []
      }
    } : null
    privateRanges: skuTier == 'Premium' ? [] : null
    allowActiveFTP: allowActiveFTP
    autoLearnPrivateRanges: autoLearnPrivateRanges
    basePolicyResourceIds: basePolicyResourceIds
  }
}

//------------------------------------------------------------------------------
// Shared variables for rules (keep rule definitions readable)
//------------------------------------------------------------------------------

var sharedSpokes = {
  hub:    '10.0.0.0/16'
  app:    '10.10.0.0/16'
  data:   '10.20.0.0/16'
  shared: '10.30.0.0/16'
}

var loggingUrls = [
  '*.blob.core.windows.net'
  '*.table.core.windows.net'
  '*.vault.azure.net'
  '*.blob.core.usgovcloudapi.net'
  '*.azureedge.net'
  '*.azurewebsites.net'
  '*.azurehdinsight.net'
  '*.sql.azuresynapse.net'
  '*.azuresynapse.net'
  '*.graph.microsoft.com'
  '*.aadcdn.msftauth.net'
  '*.login.microsoftonline.com'
  '*.login.microsoft.com'
  '*.msftncsi.com'
  '*.office.com'
  '*.office.net'
  '*.office365.com'
  '*.officeapps.live.com'
  '*.onenote.com'
  '*.outlook.com'
  '*.sharepoint.com'
  '*.dynamics.com'
  '*.visualstudio.com'
  '*.lighthouse.msftcloudes.com'
  '*.api.loganalytics.io'
  '*.prod.loganalytics.io'
]

var windowsUpdateUrls = [
  '*.windowsupdate.com'
  '*.update.microsoft.com'
  '*.delivery.mp.microsoft.com'
  '*.windows.net'
  '*.windows.com'
  '*.microsoft.com'
  '*.akamaiedge.net'
  '*.azureedge.net'
  '*.aka.ms'
]

var timeWindows = {
  businessHours: {
    startTime: '08:00'
    endTime: '18:00'
    days: [
      'Monday'
      'Tuesday'
      'Wednesday'
      'Thursday'
      'Friday'
    ]
  }
}

//------------------------------------------------------------------------------
// Rule Collection Group: Platform — DNAT inbound to shared services
//------------------------------------------------------------------------------
module platformRcg 'modules/rcg-dnat-platform.bicep' = {
  name: 'deploy-rcg-dnat-platform'
  params: {
    firewallPolicyName: firewallPolicyName
    ruleCollectionGroupName: 'RCG-Platform-DNAT'
    priority: 100
    tags: tags
  }
}

//------------------------------------------------------------------------------
// Rule Collection Group: Platform — Network rules (allowed traffic)
//------------------------------------------------------------------------------
module platformNetworkRcg 'modules/rcg-network-platform.bicep' = {
  name: 'deploy-rcg-network-platform'
  params: {
    firewallPolicyName: firewallPolicyName
    ruleCollectionGroupName: 'RCG-Platform-Network'
    priority: 200
    appGwInfraRanges: [
      '10.0.100.0/24'
    ]
    spokes: sharedSpokes
    tags: tags
  }
}

//------------------------------------------------------------------------------
// Rule Collection Group: Application — Internet egress rules
//------------------------------------------------------------------------------
module appEgressRcg 'modules/rcg-app-egress.bicep' = {
  name: 'deploy-rcg-app-egress'
  params: {
    firewallPolicyName: firewallPolicyName
    ruleCollectionGroupName: 'RCG-Application-Egress'
    priority: 300
    loggingUrls: loggingUrls
    windowsUpdateUrls: windowsUpdateUrls
    businessHours: timeWindows.businessHours
    tags: tags
  }
}

//------------------------------------------------------------------------------
// Rule Collection Group: App-specific (shared services) — application rules
//------------------------------------------------------------------------------
module appSharedRcg 'modules/rcg-app-shared.bicep' = {
  name: 'deploy-rcg-app-shared'
  params: {
    firewallPolicyName: firewallPolicyName
    ruleCollectionGroupName: 'RCG-Application-Shared'
    priority: 400
    tags: tags
  }
}

//------------------------------------------------------------------------------
// Outputs
//------------------------------------------------------------------------------
output firewallPolicyResourceId string = existingPolicy.id
output firewallPolicyName string = existingPolicy.name
output ruleCollectionGroups array = [
  platformRcg.outputs.name
  platformNetworkRcg.outputs.name
  appEgressRcg.outputs.name
  appSharedRcg.outputs.name
]
