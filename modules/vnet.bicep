param location string 
param vnetname string 
param vnetaddressprefix string 
param subnets array //  chnages to array 
param nsgId string = '' // Added this: Optional NSG ID

resource vnet 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: vnetname
  location: location

  properties:{addressSpace:{
      addressPrefixes: [
        vnetaddressprefix
      ]
    }
    subnets: [for subnet in subnets: {
        name: subnet.name
        properties: {
          addressPrefix: subnet.prefix
          networkSecurityGroup: nsgId != '' && subnet.name != 'AzureBastionSubnet' ? {
            id: nsgId
          } : null
        }
      }
    ]
  }
}

output resourceId string = vnet.id
