param location string
param appServicePlanName string
param webAppName string
param tags object

// 1. The App Service Plan (The computing power)
resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'F1' // Free Tier
  }
  kind: 'app'
  tags: tags
}

// 2. The Web App (The actual application)
resource webApp 'Microsoft.Web/sites@2022-03-01' = {
  name: webAppName
  location: location
  tags: tags
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
  }
}

output webAppUrl string = webApp.properties.defaultHostName

