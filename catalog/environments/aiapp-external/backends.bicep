param region string
param aoaiRegion string
param postfix string
param allowedClientIps array
param logAnalyticsName string
param uamiName string

var aoaiName = 'aoai-${postfix}'
var modelSettings = [
  {  name: 'gpt-4', version: 'turbo-2024-04-09',  deploy: 'chatgpt', capacity: 10 }
  {  name: 'text-embedding-ada-002', version: '2',  deploy: 'embedding', capacity: 10 }
  {  name: 'dall-e-3', version: '3.0',  deploy: 'dalle', capacity: 1 }
]

var storageName = 'str${postfix}'
var containerName = 'data'

var cosmosName = 'cosmos-${postfix}'
var cosmosDatabaseName = 'Database1'
var cosmosContainerName = 'MyItems'

var searchName = 'search-${postfix}'

/////
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logAnalyticsName
}

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: uamiName
}

/////

resource storage 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: storageName
  location: region
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }

  properties: {
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Deny'
      ipRules: [for ip in allowedClientIps :{
          value: ip
          action: 'Allow'
        }
      ]
    }
  }

  resource blobSvc 'blobServices' existing = {
    name: 'default'

    resource container 'containers' = {
      name: containerName
    }
  }
}

resource blobContributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
}

resource blobRoleAssign 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storage
  name: guid(storage.id, blobContributor.id, uami.id)
  properties: {
    roleDefinitionId: blobContributor.id
    principalType: 'ServicePrincipal'
    principalId: uami.properties.principalId
  }
}

////////

resource aoai 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' = {
  name: aoaiName
  location: aoaiRegion
  sku: {
    name: 'S0'
  }
  kind: 'OpenAI'
  properties: {
    customSubDomainName: aoaiName
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Deny'
      ipRules: [ for clientip in allowedClientIps : { 
        value: clientip
      }]
    }
  }
}

@batchSize(1)
resource modelDeployments 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = [for (model, index) in modelSettings : {
  name: model.deploy
  parent: aoai
  sku: {
    name: 'Standard'
    capacity: model.capacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: model.name
      version: model.version
    }
  }
}]

resource aoaiContributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'a001fd3d-188f-4b5d-821b-7da978bf7442'
}

resource aoaiRoleAssign 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: aoai
  name: guid(aoai.id, aoaiContributor.id, uami.id)
  properties: {
    roleDefinitionId: aoaiContributor.id
    principalType: 'ServicePrincipal'
    principalId: uami.properties.principalId
  }
}

resource aoaiDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${aoai.name}-diag'
  scope: aoai
  properties: {
    workspaceId: logAnalytics.id
    logAnalyticsDestinationType: 'Dedicated'
    logs: [
      {
        category: null
        categoryGroup: 'Audit'
        enabled: true
      }
      {
        category: null
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
          category: 'AllMetrics'
          enabled: true
          timeGrain: null
      }
    ]
  }
}

////////

resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2024-02-15-preview' = {
  name: cosmosName
  location: region
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    publicNetworkAccess: 'Enabled'
    networkAclBypass: 'None'
    ipRules: [for clientip in allowedClientIps: { 
      ipAddressOrRange: clientip 
    }]
    locations: [
      {
        locationName: region
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
  }

  resource database 'sqlDatabases' = {
    name: cosmosDatabaseName
    properties: {
      resource: {
        id: cosmosDatabaseName
      }
    }

    resource container 'containers' = {
      name: cosmosContainerName
      properties: {
        resource: {
          id: cosmosContainerName
          partitionKey: {
            paths: [
              '/id'
            ]
            kind: 'Hash'
          }
        }
      }
    }
  }
}

var cosmosContributorId = '00000000-0000-0000-0000-000000000002'
resource cosmosRoleAssign 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2023-11-15' = {
  name: guid(cosmosContributorId, uami.id, cosmos.id)
  parent: cosmos
  properties: {
    roleDefinitionId: '${cosmos.id}/sqlRoleDefinitions/${cosmosContributorId}'
    principalId: uami.properties.principalId
    scope: cosmos.id
  }
}

//////

resource search 'Microsoft.Search/searchServices@2024-03-01-preview' = {
  name: searchName
  location: region
  sku: {
    name: 'basic'
  }
  properties: {
    publicNetworkAccess: 'enabled'
    networkRuleSet: {
      bypass: 'None'
      ipRules: [for clientip in allowedClientIps: { 
        value: clientip
      }]
    }
    disableLocalAuth: false
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
  }
}

resource searchIndexContributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
}

resource searchRoleAssign 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: search
  name: guid(search.id, searchIndexContributor.id, uami.id)
  properties: {
    roleDefinitionId: searchIndexContributor.id
    principalType: 'ServicePrincipal'
    principalId: uami.properties.principalId
  }
}
