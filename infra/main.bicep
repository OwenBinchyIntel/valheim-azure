
targetScope = 'resourceGroup'

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Prefix used for naming resources')
param namePrefix string = 'valheim'

@description('Admin username for the VM')
param adminUsername string

@secure()
@description('SSH public key for the admin user')
param adminSshPublicKey string

@description('VM size (B2ms is a good default for 2-6 players)')
param vmSize string = 'Standard_B2ms'

@description('CIDR allowed to SSH (set to your public IP /32). Use "*" only temporarily.')
param sshSourceCidr string = '*'

@description('Resource group that contains the existing storage account')
param storageResourceGroup string = 'rg-valheim-aci'

@description('Existing storage account name that contains the Azure File Share')
param storageAccountName string = 'valheim7463'

@description('Existing Azure File Share name')
param fileShareName string = 'valheim'

@secure()
@description('Storage account key used to mount Azure Files (MVP). Do not commit.')
param storageAccountKey string

@description('Directory within the share where Valheim worlds live')
param worldsDir string = 'worlds_local'

module network './modules/network.bicep' = {
  name: '${namePrefix}-network'
  params: {
    location: location
    namePrefix: namePrefix
  }
}

module nsg './modules/nsg.bicep' = {
  name: '${namePrefix}-nsg'
  params: {
    location: location
    namePrefix: namePrefix
    vnetName: network.outputs.vnetName
    subnetName: network.outputs.subnetName
    sshSourceCidr: sshSourceCidr
  }
}

module vm './modules/vm.bicep' = {
  name: '${namePrefix}-vm'
  params: {
    location: location
    namePrefix: namePrefix
    subnetId: network.outputs.subnetId
    adminUsername: adminUsername
    adminSshPublicKey: adminSshPublicKey
    vmSize: vmSize

    storageAccountName: storageAccountName
    fileShareName: fileShareName
    storageAccountKey: storageAccountKey
    worldsDir: worldsDir

    cloudInit: loadTextContent('./cloud-init/valheim.yaml')
  }
}

output publicIp string = vm.outputs.publicIp
