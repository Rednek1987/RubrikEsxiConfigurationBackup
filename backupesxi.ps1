


############ --- Variable definition --- ###########
# FQDN or IP address of the vCenter
$VCENTER="vcenter.example.org"

# vCetner credential file - If you want to store the credential in a file
$VCENTERCREDFILE="./vCenterCred.xml"

# IP address and path of the Managed Volume on Rubrik device, Please use the following format    UNC Path:\\CDM_FLOATING_IP\VOLUMENAME_CHANNELID
$MANAGEDVOLUMEUNCPATH="\\10.20.2.57\EsxiBackupCIFS_channel0_54eb0484"

# This is the FQDN of customers Rubrik Security Cloud instance - only the FQDN, NOT THE URL!
$CUSTOMERRSCINSTANCE="CUSTOMER_INSTANCE.my.rubrik.com"

# The client id of the generated service user from RSC - it has to start with "client|xyz..."
$CLIENTID="client|ffcc8d74-288c-4db0-b268-6b103c633251"

# The client secret of the generated service user from RSC
$CLIENTSECRET="go5KaaHj6KN-t6q8zWj4YWEIHE7Zleui4nPn0kMkWLxhL6Ch3teryX0V17yPRfHe"

# The ID of the Managed Volume from RSC URL
$MANAGEDVOLUMEID="c354d817-e86d-5f5b-9463-8fe3882f8e61"

# The ID of the SLA domain from RSC URL
$SLADOMAINID="00000000-0000-0000-0000-000000000002"



########### --- Business logic --- ###########
Write-Host "STARTED: Backup task started"

Import-Module VMware.VimAutomation.Core
### Testing UNC path
Write-Host "### --->> Testing UNC path: $MANAGEDVOLUMEUNCPATH"
if (!(Test-Path -Path $MANAGEDVOLUMEUNCPATH)) {
    Write-Error "The Rubrik Managed Volume is not available! Please check the permissions and allowed IPs!"
    Exit 5
}
Write-Host

### Generating authentication token
Write-Host "### --->> Generating authentication token"
$AUTHDATA='{"client_id": "' + $CLIENTID + '", "client_secret": "' + $CLIENTSECRET + '"}'
$TOKEN=((Invoke-WebRequest -Method Post -Uri "https://$CUSTOMERRSCINSTANCE/api/client_token" -ContentType "application/json" -Body $AUTHDATA).Content | ConvertFrom-Json).access_token
Write-Host

### Set Managed Volume in writable mode
Write-Host "### --->> Set Managed Volume in writable mode"
$BODYDATA='{"query":"mutation beginManagedVolumeSnapshot($id:String!){beginManagedVolumeSnapshot(input:{id:$id,config:{isAsync:true}}){snapshotId asyncRequestStatus{id}}}","operationName":"beginManagedVolumeSnapshot","variables":{"id":"' + $MANAGEDVOLUMEID + '"}}'
(Invoke-WebRequest -Method Post -Uri "https://$CUSTOMERRSCINSTANCE/api/graphql" -ContentType "application/json" -Headers @{"Authorization"="Bearer $TOKEN"} -Body $BODYDATA).Content
Sleep -Seconds 5
Write-Host

### Copy data to Rubrik
Write-Host "### --->> Copy data to Rubrik"
$Credential = Import-CliXml -Path $VCENTERCREDFILE
Connect-VIServer -Server $VCENTER -Credential $Credential
Get-VMHost | Get-VMHostFirmware -BackupConfiguration -DestinationPath $MANAGEDVOLUMEUNCPATH
Disconnect-VIServer -Confirm:$false
Write-Host

### Create Managed Volume snapshot
Write-Host "### --->> Creating Managed Volume snapshot"
$BODYDATA='{"query":"mutation endManagedVolumeSnapshot($id:String!,$slaId:String!){endManagedVolumeSnapshot(input:{id:$id,params:{isAsync:true retentionConfig:{slaId:$slaId}}}){asyncRequestStatus{id}}}","operationName":"endManagedVolumeSnapshot","variables":{"id":"' + $MANAGEDVOLUMEID + '","slaId":"' + $SLADOMAINID + '"}}'
(Invoke-WebRequest -Method Post -Uri "https://$CUSTOMERRSCINSTANCE/api/graphql" -ContentType "application/json" -Headers @{"Authorization"="Bearer $TOKEN"} -Body $BODYDATA).Content
Write-Host

Write-Host "COMPLETED: Backup finished"
Exit