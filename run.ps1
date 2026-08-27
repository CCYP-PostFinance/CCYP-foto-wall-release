# docker.env
"GARAGE_RPC_SECRET=$(-join ((1..64) | ForEach-Object { '{0:x}' -f (Get-Random -Maximum 16) }))" |
    Set-Content docker.env

docker compose --env-file .\docker.env up -d

Start-Sleep 5

# Get node id
$NODE_ID = docker exec fotowall-garage /garage status `
    | Select-String '^[0-9a-f]{16}' `
    | Select-Object -First 1 `
    | ForEach-Object { $_.Matches[0].Value }

docker exec fotowall-garage /garage layout assign $NODE_ID -z dc1 -c 10G
docker exec fotowall-garage /garage layout apply --version 1

# Create key
$Response = Invoke-RestMethod `
    -Uri 'http://localhost:3909/api/v2/CreateKey' `
    -Method Post `
    -Body '{"name":"backend"}' `
    -ContentType 'application/json'

$ACCESS_KEY_ID = $Response.accessKeyId
$SECRET_ACCESS_KEY = $Response.secretAccessKey

# Create bucket
$BucketResponse = Invoke-RestMethod `
    -Uri 'http://localhost:3909/api/v2/CreateBucket' `
    -Method Post `
    -Body '{"globalAlias":"fotowall"}' `
    -ContentType 'application/json'

$BUCKET_ID = $BucketResponse.id

# Allow permissions
$PermissionBody = @{
    bucketId   = $BUCKET_ID
    accessKeyId = $ACCESS_KEY_ID
    permissions = @{
        read  = $true
        write = $true
        owner = $false
    }
} | ConvertTo-Json -Depth 3

Invoke-RestMethod `
    -Uri 'http://localhost:3909/api/v2/AllowBucketKey' `
    -Method Post `
    -Body $PermissionBody `
    -ContentType 'application/json' | Out-Null

Invoke-RestMethod `
    -Uri "http://localhost:3909/api/v2/UpdateBucket?id=$BUCKET_ID" `
    -Method Post `
    -Body '{"websiteAccess": {"enabled": true,"indexDocument": "index.html","errorDocument": "error/400.html"}}' `
    -ContentType 'application/json' | Out-Null

# Write spring.env
@"
AWS_ACCESSKEY=$ACCESS_KEY_ID
AWS_SECRETACCESSKEY=$SECRET_ACCESS_KEY
AWS_BUCKET_NAME=fotowall
AWS_ENDPOINT=http://127.0.0.1:3900
"@ | Set-Content spring.env


Start-Sleep 10

docker compose --profile runtime --env-file ./docker.env --env-file ./spring.env up -d