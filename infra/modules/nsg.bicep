param location string
param namePrefix string
param vnetName string
param subnetName string
param sshSourceCidr string

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: '${namePrefix}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: sshSourceCidr
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'Allow-Valheim-UDP'
        properties: {
          priority: 110
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Udp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRanges: [
            '2456'
            '2457'
            '2458'
          ]
        }
      }
    ]
  }
}

// Associate NSG to the existing subnet created in network.bicep
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: '${namePrefix}-vnet'
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  name: '${vnet.name}/${subnetName}'
  properties: {
    addressPrefix: '10.10.1.0/24'
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

output nsgId string = nsg.id
