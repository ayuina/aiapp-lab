param region string = 'japaneast'
param aoaiRegion string = 'swedencentral'
param allowedClientIp string

var postfix = toLower(uniqueString(subscription().id, resourceGroup().name, region))

module infra 'infra.bicep' = {
  name:'infra'
  params: {
    region: region
    postfix: postfix
  }
}

module backends 'backends.bicep' = {
  name: 'backends'
  params: {
    region: region
    aoaiRegion: aoaiRegion
    postfix: postfix
    allowedClientIps: [ 
      allowedClientIp 
      infra.outputs.acaNatgwIpAddress 
    ]
    logAnalyticsName: infra.outputs.logAnalyticsName
    uamiName: infra.outputs.uamiName
  }
}

module application 'application.bicep' = {
  name: 'application'  
  params: {
    region: region
    postfix: postfix
    allowedClientIps: [
      allowedClientIp
    ]
    logAnalyticsName: infra.outputs.logAnalyticsName
    uamiName: infra.outputs.uamiName
    vnetName: infra.outputs.vnetName
    acaSubnetName: infra.outputs.acaSubnetName
  }
}
