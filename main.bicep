// Testing GitHub Actions Pipeline
param location string = resourceGroup().location

// 1. DEFINE THE MANDATORY TAGS (This satisfies your Azure Policy)
var tags = {
  CostCenter: 'DevOps-Journey-101'
  Environment: 'Dev'
}

// Hub VNet configuration
param hubVnetName string = 'Hub-Vnet-prod'
param hubAddressPrefix string = '10.0.0.0/16'
param hubSubnetPrefix string = '10.0.1.0/24'

// Spoke VNet configuration
param spokeVnetName string = 'Spoke-Vnet-prod'
param spokeAddressPrefix string = '10.1.0.0/16'
param spokeSubnetPrefix string = '10.1.1.0/24'
param vmSize string = 'Standard_D2s_v7'
param deployWebApp bool = true
param appServicePlanSku string = 'B1'
@secure()
param adminPassword string

// 1. Deploy NSGs
module hubNsg 'modules/nsg.bicep' = {
  name: 'hubNsgDeploy'
  params: { 
    nsgName: 'nsg-hub-prod'
    location: location 
    tags: tags 
  }
}

module spokeNsg 'modules/nsg.bicep' = {
  name: 'spokeNsgDeploy'
  params: { 
    nsgName: 'nsg-spoke-prod' 
    location: location 
    tags: tags
    // ADDED: These rules allow you to actually connect to the VM
    rules: [
      {
        name: 'AllowBastionSSH'
        priority: 100
        access: 'Allow'
        direction: 'Inbound'
        protocol: 'Tcp'
        source: '10.0.2.0/26' // The Bastion Subnet
        destination: '*'
        port: '22'
      }
      {
        name: 'AllowHTTPSInbound'
        priority: 200
        access: 'Allow'
        direction: 'Inbound'
        protocol: 'Tcp'
        source: '*'
        destination: '*'
        port: '443'
      }
      {
        name: 'DenyAllInbound'
        priority: 4096
        access: 'Deny'
        direction: 'Inbound'
        protocol: '*'
        source: '*'
        destination: '*'
        port: '*'
      }
    ]
  }
}

// 2. Deploy Hub VNet
module hubVnet 'modules/vnet.bicep' = {
  name: 'hubVnetModule'
  params: {
    location: location
    vnetname: hubVnetName
    vnetaddressprefix: hubAddressPrefix
    nsgId: hubNsg.outputs.nsgId
    subnets: [
      { name: 'snet-hub-default', prefix: hubSubnetPrefix }
      { name: 'AzureBastionSubnet', prefix: '10.0.2.0/26' }
    ]
    tags: tags
  }
}

// 3. Deploy Spoke VNet
module spokeVnet 'modules/vnet.bicep' = {
  name: 'spokeVnetModule'
  params: {
    location: location
    vnetname: spokeVnetName
    vnetaddressprefix: spokeAddressPrefix
    nsgId: spokeNsg.outputs.nsgId
    subnets: [
      { name: 'snet-spoke-default', prefix: spokeSubnetPrefix }
    ]
    tags: tags
  }
}

// 4. Peer them
module vnetPeering 'modules/peering.bicep' = {
  name: 'vnetPeeringModule'
  params: {
    hubVnetName: hubVnetName
    spokeVnetName: spokeVnetName
    hubVnetresourceId: hubVnet.outputs.resourceId
    spokeVnetresourceId: spokeVnet.outputs.resourceId
  }
}

// 5. Deploy Bastion
module bastion 'bastion.bicep' = {
  name: 'bastionDeploy'
  dependsOn: [
    hubVnet
  ]
  params: {
    location: location
    bastionName: 'bastion-hub-prod'
    hubVnetName: hubVnetName
    tags: tags
  }
}

// 6. Deploy VM
module spokeVm 'modules/vm.bicep' = {
  name: 'spokeVmDeploy'
  params: {
    location: location
    vmName: 'vm-app-prod-01'
    vmSize: vmSize
    subnetId: resourceId('Microsoft.Network/virtualNetworks/subnets', spokeVnetName, 'snet-spoke-default')
    adminPassword: adminPassword
    tags: tags
  }
}

// 7. Deploy the Web Tier
module webAppModule 'modules/webapp.bicep' = if (deployWebApp) {
  name: 'webAppDeploy'
  params: {
    location: location
    appServicePlanName: 'asp-app-prod-01'
    appServicePlanSku: appServicePlanSku
    webAppName: 'webapp-devops-journey-${uniqueString(resourceGroup().id)}' // Must be globally unique
    tags: tags
  }
}




