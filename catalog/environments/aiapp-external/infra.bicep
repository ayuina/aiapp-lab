param region string
param postfix string

var logAnalyticsName = 'laws-${postfix}'
var uamiName = 'uami-${postfix}'
var vnetName = 'vnet-${postfix}'
var acaSubnetName = 'aca-subnet'
var devboxSubnetName = 'devbox-subnet'
var devboxConnettoinName = 'devcon-${postfix}'

var privateEndpointSubnetName = 'private-endpoint-subnet'
var natgwPipName = 'pip-${postfix}'
var natgwName = 'natgw-${postfix}'
/////

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: region
  properties: {
    addressSpace: {
      addressPrefixes: [ '10.0.0.0/16' ]
    }
    subnets: [
      {
        name: devboxSubnetName
        properties: {
          addressPrefix: '10.0.0.0/24' 
        }
      }
      {
        name: acaSubnetName
        properties: {
          addressPrefix: '10.0.1.0/24'
          delegations: [
            {
              name: 'Microsoft.App/environments'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
          natGateway: {
            id: natgateway.id
          }
        }
      }
      {
        name: privateEndpointSubnetName
        properties: {
          addressPrefix: '10.0.2.0/24'
        }
      }
    ]
  }
}

resource devcon 'Microsoft.DevCenter/networkConnections@2024-05-01-preview' = {
  name: devboxConnettoinName
  location: region
  properties: {
    domainJoinType: 'AzureADJoin'
    subnetId: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, devboxSubnetName)
    networkingResourceGroupName: resourceGroup().name
  }
}

resource pip 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: natgwPipName
  location: region
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
  }
}

resource natgateway 'Microsoft.Network/natGateways@2023-11-01' = {
  name: natgwName
  location: region
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes:4
    publicIpAddresses: [
      {id: pip.id}
    ]
  }
}

/////

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: region
  properties:{
    sku:{
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: -1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: uamiName
  location: region
}

output logAnalyticsName string = logAnalytics.name
output uamiName string = uami.name
output vnetName string = vnet.name
output acaSubnetName string = acaSubnetName
output acaNatgwIpAddress string = pip.properties.ipAddress
output devboxSubnetName string = devboxSubnetName
output privateEndpointSubnetName string = privateEndpointSubnetName
