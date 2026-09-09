@description('Name of the parent firewall policy')
param firewallPolicyName string

@description('Name of this rule collection group')
param ruleCollectionGroupName string

@description('Priority of the RCG (100-65000)')
@minValue(100)
@maxValue(65000)
param priority int

@description('FQDNs that match Azure logging / monitoring endpoints')
param loggingUrls array = []

@description('FQDNs for Windows Update endpoints')
param windowsUpdateUrls array = []

@description('Business-hours time window object')
param businessHours object = {
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

//------------------------------------------------------------------------------
// Application rule collections: outbound HTTP/HTTPS by FQDN
//------------------------------------------------------------------------------
resource rcg 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = {
  parent: existingPolicy
  name: ruleCollectionGroupName
  properties: {
    priority: priority
    ruleCollections: [
      // ---------- Allow diagnostics & updates to Microsoft telemetry ----------
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'RC-Egress-AzureDiagnostics'
        priority: 100
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'AllowAzureMonitor-BusinessHours'
            description: 'Allow diagnostic traffic to AzureMonitor only during ${businessHours.startTime}-${businessHours.endTime} on ${join(businessHours.days, ', ')}'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            fqdnTags: [
              'AzureDiagnostics'
            ]
            sourceAddresses: [
              '10.10.0.0/16'  // app spoke
              '10.20.0.0/16'  // data spoke
            ]
            targetFqdns: loggingUrls
            webCategories: []
          }
        ]
      }

      // ---------- Windows Update ----------
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'RC-Egress-WindowsUpdate'
        priority: 200
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'AllowWindowsUpdate'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
              {
                protocolType: 'Http'
                port: 80
              }
            ]
            targetFqdns: windowsUpdateUrls != [] ? windowsUpdateUrls : ['*.microsoft.com']
            sourceAddresses: [
              '10.10.0.0/16'
            ]
          }
        ]
      }

      // ---------- Azure portal / PowerShell / CLI ----------
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'RC-Egress-AzureManagement'
        priority: 300
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'AllowAzurePortal'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            fqdnTags: [
              'AzurePortal'
            ]
            sourceAddresses: [
              '10.30.0.0/16' // shared services spoke
            ]
          }
          {
            ruleType: 'ApplicationRule'
            name: 'AllowAzureAPIManagement'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            fqdnTags: [
              'APIManagement'
            ]
            sourceAddresses: [
              '10.10.0.0/16'
            ]
          }
        ]
      }

      // ---------- Time-restricted access to GitHub for build agents ----------
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'RC-Egress-GitHub-Timed'
        priority: 400
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'AllowGitHub-BusinessHours'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            targetFqdns: [
              'github.com'
              '*.github.com'
              'githubusercontent.com'
              '*.githubusercontent.com'
              'pkg.github.com'
            ]
            sourceAddresses: [
              '10.10.0.128/25' // build agents subnet
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
