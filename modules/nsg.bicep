param nsgName string
param location string
param tags object
param rules array = [] // This allows us to pass a list of rules from main.bicep

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [for rule in rules: {
      name: rule.name
      properties: {
        priority: rule.priority
        access: rule.access
        direction: rule.direction
        protocol: rule.protocol
        sourceAddressPrefix: rule.source
        sourcePortRange: '*'
        destinationAddressPrefix: rule.destination
        destinationPortRange: rule.port
      }
    }]
  }
}

output nsgId string = nsg.id

