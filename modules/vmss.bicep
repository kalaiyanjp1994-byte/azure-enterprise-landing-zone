param location string = resourceGroup().location
param vmssName string
param vmSize string = 'Standard_D2s_v3'
param subnetId string
param lbBackendPoolId string
@secure()
param adminPassword string
param tags object = {}

resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2023-09-01' = {
  name: vmssName
  location: location
  tags: tags
  sku: {
    name: vmSize
    tier: 'Standard'
    capacity: 2 // Default to 2 instances for high availability
  }
  properties: {
    overprovision: true
    upgradePolicy: {
      mode: 'Automatic'
    }
    virtualMachineProfile: {
      osProfile: {
        computerNamePrefix: 'vmss-app'
        adminUsername: 'azureuser'
        adminPassword: adminPassword
      }
      storageProfile: {
        imageReference: {
          publisher: 'Canonical'
          offer: '0001-com-ubuntu-server-jammy'
          sku: '22_04-lts-gen2'
          version: 'latest'
        }
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: 'nic-vmss'
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: 'ipconfig-vmss'
                  properties: {
                    subnet: {
                      id: subnetId
                    }
                    loadBalancerBackendAddressPools: [
                      {
                        id: lbBackendPoolId
                      }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }
    }
  }
}

output vmssId string = vmss.id
