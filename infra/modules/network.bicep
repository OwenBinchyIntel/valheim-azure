param location string
param namePrefix string

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: '${namePrefix}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.10.0.0/16'
      ]
    }
    subnets: [
      {
        name: '${namePrefix}-subnet'
        properties: {
          addressPrefix: '10.10.1.0/24'
        }
      }
    ]
  }
}

output vnetName string = vnet.name
output subnetName string = vnet.properties.subnets[0].name
output subnetId string = vnet.properties.subnets[0].id
