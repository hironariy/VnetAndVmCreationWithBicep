param location string = resourceGroup().location

@minLength(3)
@maxLength(24)
param vmNamePrefix string = 'BicepVm'

@allowed([
  'General'
  'HPC'
  'HPC2'
])
param vmType string

@minValue(1)
@maxValue(10)
param vmCount int

@description('Username for the Virtual Machine.')
param adminUsername string

@description('Type of authentication to use on the Virtual Machine. SSH key is recommended.')
@allowed([
  'sshPublicKey'
  'password'
])
param authenticationType string

@description('SSH Key or password for the Virtual Machine. SSH key is recommended.')
@secure()
param adminPasswordOrKey string

@description('Unique DNS Name for the Public IP used to access the Virtual Machine.')
param dnsLabelPrefix string = toLower('${vmNamePrefix}-${uniqueString(resourceGroup().id)}')

var osDiskType = 'Premium_LRS'
var dataDiskType = 'Premium_LRS'

var vmSecondNamePrefix = {
  General: 'General'
  HPC: 'HPC'
  HPC2: 'HPC2'
}

var vmSize = {
  General: 'Standard_D2ads_v5'
  HPC: 'Standard_ND40rs_v2'
  HPC2: 'Standard_ND96isr_H100_v5'
}

var imageReference = {
  General: {
    publisher: 'Canonical'
    offer: 'ubuntu-24_04-lts'
    sku: 'server'
    version: 'latest'
  }
  HPC: {
    publisher: 'microsoft-dsvm'
    offer: 'ubuntu-hpc'
    sku: '2204'
    version: '22.04.2024102301'
  }
  HPC2: {
    publisher: 'microsoft-dsvm'
    offer: 'ubuntu-hpc'
    sku: '2204'
    version: '22.04.2024102301'
  }
}


var linuxConfiguration = {
  disablePasswordAuthentication: true
  ssh: {
    publicKeys: [
      {
        path: '/home/${adminUsername}/.ssh/authorized_keys'
        keyData: adminPasswordOrKey
      }
    ]
  }
}

// Reference the existing VNet
resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: 'BicepVNet'
}

resource publicIP 'Microsoft.Network/publicIPAddresses@2024-05-01' = [for i in range(0, vmCount):{
  name: 'publicIP${i + 1}'
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: '${dnsLabelPrefix}-${i + 1}'
    }
  }
}]

// Create an availability set for the first two VMs
resource availabilitySet 'Microsoft.Compute/availabilitySets@2022-08-01' = {
  name: '${vmNamePrefix}-availabilitySet'
  location: location
  sku: {
    name: 'Aligned'
  }
  properties: {
    platformFaultDomainCount: 2
    platformUpdateDomainCount: 2
  }
}

resource dataDisk 'Microsoft.Compute/disks@2024-03-02' = [for i in range(0, vmCount):{
  name: '${vmNamePrefix}-${vmSecondNamePrefix[vmType]}-${i + 1}-dataDisk'
  location: location
  sku: {
    name: dataDiskType
  }
  properties: {
    diskSizeGB: 1024
    diskIOPSReadWrite: 5000
    diskMBpsReadWrite: 200
    creationData: {
      createOption: 'Empty'
    }
  }
}]



resource vm 'Microsoft.Compute/virtualMachines@2022-08-01' = [for i in range(0, vmCount):{
  name: '${vmNamePrefix}-${vmSecondNamePrefix[vmType]}-${i + 1}'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize[vmType]
    }
    storageProfile: {
      imageReference: imageReference[vmType]
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
      }
      dataDisks: [
        {
          lun: 0
          name: '${vmNamePrefix}-${vmSecondNamePrefix[vmType]}-${i + 1}-dataDisk'
          createOption: 'Attach'
          managedDisk: {
            id: dataDisk[i].id
          }
        }
      ]
    }
    osProfile: {
      computerName: '${vmNamePrefix}-${vmSecondNamePrefix[vmType]}-${i + 1}'
      adminUsername: adminUsername
      adminPassword: adminPasswordOrKey
      linuxConfiguration: ((authenticationType == 'password') ? null : linuxConfiguration)
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic[i].id
        }
      ]
    }
    availabilitySet: {
      id: availabilitySet.id
    }
  }
}]

resource nic 'Microsoft.Network/networkInterfaces@2021-02-01' = [for i in range(0, vmCount):{
  name: 'nic${i + 1}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vnet.properties.subnets[i].id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIP[i].id
          }
        }
      }
    ]
  }
}]

output adminUsername string = adminUsername
output hostname string[] = [for i in range(0, vmCount):publicIP[i].properties.dnsSettings.fqdn]
output sshCommand string[] = [for i in range(0, vmCount):'ssh ${adminUsername}@${publicIP[i].properties.dnsSettings.fqdn}']
