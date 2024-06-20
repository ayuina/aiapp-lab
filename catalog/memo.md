# deploy with bicep

```powershell
$RG = 'yourRgName'
$REGION = 'japaneast'
$AOAI_REGION = 'swedencentral'
$CLIENT_IP = (curl ifconfig.io/ip)

az group create -n $RG -l $REGION
az deployment group create -g $RG -f .\catalog\aiapp-external\main.bicep `
    -p allowedClientIp=$CLIENT_IP region=$REGION aoaiRegion=$AOAI_REGION
```