param location string = resourceGroup().location

// ... (keep your Hub/Spoke name and prefix params) ...
param hubVnetName string = 'Hub-Vnet-prod'
param hubAddressPrefix string = '10.0.0.0/16'
param spokeVnetName string = 'Spoke-Vnet-prod'
param spokeAddressPrefix string = '10.1.0.0/16'

// 1. Deploy NSGs
module hubNsg 'modules/nsg.bicep' = {
  name: 'hubNsgDeploy'
  params: { nsgName: 'nsg-hub-prod', location: location }
}
module spokeNsg 'modules/nsg.bicep' = {
  name: 'spokeNsgDeploy'
  params: { nsgName: 'nsg-spoke-prod', location: location }
}

// 2. Deploy Hub VNet (With the required Bastion Subnet)
module hubVnet 'modules/vnet.bicep' = {
  name: 'hubVnetModule'
  params: {
    location: location
    vnetname: hubVnetName
    vnetaddressprefix: hubAddressPrefix
    nsgId: hubNsg.outputs.nsgId
    subnets: [
      { name: 'snet-hub-default', prefix: '10.0.1.0/24' }
      { name: 'AzureBastionSubnet', prefix: '10.0.2.0/26' } // REQUIRED for Bastion
    ]
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
      { name: 'snet-spoke-default', prefix: '10.1.1.0/24' }
    ]
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

module bastion 'bastion.bicep' = {
  name: 'bastionDeploy'
  dependsOn: [
    hubVnet
  ]
  params: {
    location: location
    bastionName: 'bastion-hub-prod'
    hubVnetName: hubVnetName
  }
}

