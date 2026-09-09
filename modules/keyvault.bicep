param location string = resourceGroup().location
param keyVaultName string
param tags object = {}

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    accessPolicies: [] // Start with empty, add as needed
    enabledForDeployment: true
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: false
  }
}

output keyVaultUri string = kv.properties.vaultUri
output keyVaultId string = kv.id
