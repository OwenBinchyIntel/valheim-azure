// Main deployment file for Valheim Azure infrastructure
targetScope = 'resourceGroup'

// Parameters
@description('Location for all resources')
param location string = resourceGroup().location

@description('Virtual machine name')
param vmName string

@description('Admin username for the virtual machine')
param adminUsername string

@description('Admin password or SSH key for the virtual machine')
@secure()
param adminPasswordOrKey string

@description('Virtual network name')
param vnetName string

@description('Storage account name for file share')
param storageAccountName string

@description('File share name')
param fileShareName string

@description('Authentication type for VM (password or sshPublicKey)')
@allowed([
  'password'
  'sshPublicKey'
])
param authenticationType string = 'sshPublicKey'

@description('VM size')
param vmSize string = 'Standard_D2s_v3'

// Network module
module network 'modules/network.bicep' = {
  name: 'network-deployment'
  params: {
    location: location
    vnetName: vnetName
  }
}

// File share module (references existing storage account)
module fileshare 'modules/fileshare.bicep' = {
  name: 'fileshare-deployment'
  params: {
    storageAccountName: storageAccountName
    fileShareName: fileShareName
  }
}

// VM module
module vm 'modules/vm.bicep' = {
  name: 'vm-deployment'
  params: {
    location: location
    vmName: vmName
    vmSize: vmSize
    adminUsername: adminUsername
    adminPasswordOrKey: adminPasswordOrKey
    authenticationType: authenticationType
    subnetId: network.outputs.subnetId
  }
}

// Outputs
output vmPublicIpAddress string = vm.outputs.publicIpAddress
output vmName string = vm.outputs.vmName
output vnetId string = network.outputs.vnetId
