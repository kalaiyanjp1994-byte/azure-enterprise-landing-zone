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
param firewallSubnetPrefix string = '10.0.2.0/26' // Explicitly defined for clarity


// Spoke VNet configuration
param spokeVnetName string = 'Spoke-Vnet-prod'
param spokeAddressPrefix string = '10.1.0.0/16'
param spokeSubnetPrefix string = '10.1.1.0/24'
param vmSize string = 'Standard_D2s_v7'
@secure()
param adminPassword string

// 1. Deploy Log Analytics Workspace
module logAnalytics 'modules/log-analytics.bicep' = {
  name: 'logAnalyticsDeploy'
  params: {
    location: location
    workspaceName: 'law-hub-prod'
    tags: tags
  }
}

// 2. Deploy Key Vault
module keyVault 'modules/keyvault.bicep' = {
  name: 'keyVaultDeploy'
  params: {
    location: location
    keyVaultName: 'kv-hub-prod-01'
    tags: tags
  }
}

// 3. Deploy NSGs

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
    rules: [
      {
        name: 'AllowBastionSSH'
        priority: 100
        access: 'Allow'
        direction: 'Inbound'
        protocol: 'Tcp'
        source: '10.0.2.0/26' 
        destination: '*'
        port: '22'
      }
      {
        name: 'AllowHTTPInbound'
        priority: 200
        access: 'Allow'
        direction: 'Inbound'
        protocol: 'Tcp'
        source: '*'
        destination: '*'
        port: '80' // This allows the world to see your web server
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
      { name: 'AzureFirewallSubnet', prefix: firewallSubnetPrefix }
      { name: 'AzureBastionSubnet', prefix: '10.0.3.0/26' }
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

// 6. Deploy VM Scale Set
module spokeVmss 'modules/vmss.bicep' = {
  name: 'spokeVmssDeploy'
  dependsOn: [
    spokeVnet
  ]
  params: {
    location: location
    vmssName: 'vmss-app-prod-01'
    vmSize: vmSize
    subnetId: resourceId('Microsoft.Network/virtualNetworks/subnets', spokeVnetName, 'snet-spoke-default')
    adminPassword: adminPassword
    tags: tags
    lbBackendPoolId: lbModule.outputs.lbBackendPoolId 
  }
}


// 7. Deploy the Load Balancer
module lbModule 'modules/lb.bicep' = {
  name: 'lbDeploy'
  params: {
    location: location
    lbName: 'lb-app-prod-01'
    tags: tags
  }
}

// 8. Deploy Firewall Policy and Firewall
module firewallPolicy 'modules/firewall-policy-orchestrator.bicep' = {
  name: 'firewallPolicyDeploy'
  params: {
    location: location
    policyName: 'fp-hub-prod'
    tags: tags
  }
}

module firewall 'modules/firewall.bicep' = {
  name: 'firewallDeploy'
  dependsOn: [
    hubVnet
  ]
  params: {
    location: location
    firewallName: 'afw-hub-prod'
    firewallPolicyId: firewallPolicy.outputs.policyId
    subnetId: resourceId('Microsoft.Network/virtualNetworks/subnets', hubVnetName, 'AzureFirewallSubnet')
    tags: tags
  }
}









