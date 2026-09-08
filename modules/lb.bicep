param location string
param lbName string
param tags object

// 1. Create a Public IP for the Load Balancer
resource lbPublicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: '${lbName}-pip'
  location: location
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
  tags: tags
}

// 2. Create the Load Balancer
resource lb 'Microsoft.Network/loadBalancers@2023-09-01' = {
  name: lbName
  location: location
  sku: { name: 'Standard' }
  tags: tags
  properties: {
    frontendIPConfigurations: [
      {
        name: 'LoadBalancerFrontEnd'
        properties: {
          publicIPAddress: { id: lbPublicIp.id }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'BackendPool1'
      }
    ]
    probes: [
      {
        name: 'HttpHealthProbe'
        properties: {
          protocol: 'Http'
          port: 80
          requestPath: '/'
          intervalInSeconds: 15
          numberOfProbes: 2
        }
      }
    ]
    loadBalancingRules: [
      {
        name: 'LBRuleHttp'
        properties: {
          frontendIPConfiguration: { id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, 'LoadBalancerFrontEnd') }
          backendAddressPool: { id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, 'BackendPool1') }
          probe: { id: resourceId('Microsoft.Network/loadBalancers/probes', lbName, 'HttpHealthProbe') }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          idleTimeoutInMinutes: 4
          loadDistribution: 'Default'
        }
      }
    ]
  }
}

output lbPublicIp string = lbPublicIp.properties.ipAddress
output lbBackendPoolId string = lb.properties.backendAddressPools[0].id


