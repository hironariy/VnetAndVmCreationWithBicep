param location string = resourceGroup().location

@minLength(3)
@maxLength(24)
@description('Provide a name for the storage account. Use only lowercase letters and numbers. The name must be unique across Azure.')
param storageAccountName string = 'store${uniqueString(resourceGroup().id)}'

@minValue(1)
@maxValue(10)
param subnetCount int

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'competitionVNet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/8'
      ]
    }
  }
}

resource createSubnets 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = [for i in range(0, subnetCount): {
  parent: vnet
  name: 'subnet${i + 1}'
  properties: {
    addressPrefix: '10.${i + 1}.0.0/16'
  }
}]

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
  }
}
