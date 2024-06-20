param region string
param postfix string
param allowedClientIps array
param logAnalyticsName string
param uamiName string
param vnetName string
param acaSubnetName string

var acrName = 'acr${postfix}'
var acaenvName = 'acaenv-${postfix}'
var acaName = 'app01'
var acaContainerImage = 'mcr.microsoft.com/k8se/quickstart:latest'

////
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logAnalyticsName
}

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: uamiName
}


resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: vnetName

  resource acaSubnet 'subnets' existing =  {
    name: acaSubnetName
  }
}

/////

resource acr 'Microsoft.ContainerRegistry/registries@2022-12-01' = {
  name: acrName
  location: region
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
    publicNetworkAccess: 'Enabled'
    zoneRedundancy: 'Disabled'
  }
}

resource acrPull 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
}

resource acrPullAssign 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: acr
  name: guid(acr.id, acrPull.id, uami.id)
  properties: {
    roleDefinitionId: acrPull.id
    principalType: 'ServicePrincipal'
    principalId: uami.properties.principalId
  }
}

resource acrdiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: acr
  name: '${acrName}-diag'
  properties: {
    workspaceId: logAnalytics.id
    logs :[
      {
        category: null
        categoryGroup: 'audit'
        enabled: true
        retentionPolicy: {
          days : 0
          enabled: false
        }
      }
      {
        category: null
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          days : 0
          enabled: false
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          days : 0
          enabled: false
        }
      }
    ]

  }
}

/////

resource acaenv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: acaenvName
  location: region
  properties: {
    vnetConfiguration: {
      internal: false
      infrastructureSubnetId: vnet::acaSubnet.id
    }
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
  }
}

/////

resource app01 'Microsoft.App/containerApps@2024-03-01' =  {
  name: acaName
  location: region
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uami.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: acaenv.id
    configuration: {
      activeRevisionsMode: 'Single'
      registries: [
        {
          server: acr.properties.loginServer
          identity: uami.id
        }
      ]
      ingress: {
        external: true
        targetPort: 80
        ipSecurityRestrictions: [for (clientip, index) in allowedClientIps: {
          action: 'Allow'
          name: 'allow-${index}'
          description: 'allow client ip ${clientip}'
          ipAddressRange: clientip
        }]
      }
    }
    template: {
      containers: [
        {
          name: '${acaName}-container'
          image: acaContainerImage
          
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 3
      }
    }
  }
}
