// File share module - references existing storage account
@description('Existing storage account name')
param storageAccountName string

@description('File share name')
param fileShareName string

@description('File share quota in GB')
param shareQuota int = 100

@description('File share access tier')
@allowed([
  'TransactionOptimized'
  'Hot'
  'Cool'
  'Premium'
])
param accessTier string = 'TransactionOptimized'

// Reference existing storage account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

// Create file share in existing storage account
resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  name: '${storageAccountName}/default/${fileShareName}'
  properties: {
    shareQuota: shareQuota
    accessTier: accessTier
  }
  dependsOn: [
    storageAccount
  ]
}

// Outputs
output fileShareName string = fileShare.name
output storageAccountName string = storageAccountName
