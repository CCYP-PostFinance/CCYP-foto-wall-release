Write-Host "Downloading required files"

Invoke-WebRequest `
    -Uri "https://raw.githubusercontent.com/CCYP-PostFinance/CCYP-foto-wall-release/refs/heads/main/docker-compose.yaml" `
    -OutFile "docker-compose.yaml"

Invoke-WebRequest `
    -Uri "https://raw.githubusercontent.com/CCYP-PostFinance/CCYP-foto-wall-release/refs/heads/main/garage.toml" `
    -OutFile "garage.toml"

Write-Host "Downloading completed"

Start-Sleep -Seconds 2

Write-Host "Setting up environment for Garage"

$GarageSecret = -join ((1..64) | ForEach-Object {
    "{0:x}" -f (Get-Random -Maximum 16)
})

"GARAGE_RPC_SECRET=$GarageSecret" | Out-File `
    -FilePath "docker.env" `
    -Encoding ascii

docker compose --profile dependencies --env-file ./docker.env up -d

Start-Sleep -Seconds 5

Write-Host "Garage setup completed"

Start-Sleep -Seconds 2

Write-Host "Launching S3 and Database"

$NODE_ID = docker exec fotowall-garage /garage status |
    Select-String '^[0-9a-f]{16}' |
    Select-Object -First 1 |
    ForEach-Object { $_.Matches[0].Value }

docker exec fotowall-garage /garage layout assign $NODE_ID -z dc1 -c 10G
docker exec fotowall-garage /garage layout apply --version 1

$response = Invoke-RestMethod `
    -Method Post `
    -Uri "http://localhost:3909/api/v2/CreateKey" `
    -Body '{"name":"backend"}'

$ACCESS_KEY_ID = $response.accessKeyId
$SECRET_ACCESS_KEY = $response.secretAccessKey

$bucketResponse = Invoke-RestMethod `
    -Method Post `
    -Uri "http://localhost:3909/api/v2/CreateBucket" `
    -Body '{"globalAlias":"fotowall"}'

$BUCKET_ID = $bucketResponse.id

Invoke-RestMethod `
    -Method Post `
    -Uri "http://localhost:3909/api/v2/AllowBucketKey" `
    -Body (@{
        bucketId = $BUCKET_ID
        accessKeyId = $ACCESS_KEY_ID
        permissions = @{
            read  = $true
            write = $true
            owner = $false
        }
    } | ConvertTo-Json -Depth 5)

Invoke-RestMethod `
    -Method Post `
    -ContentType "application/json" `
    -Uri "http://localhost:3909/api/v2/UpdateBucket?id=$BUCKET_ID" `
    -Body (@{
        websiteAccess = @{
            enabled = $true
            indexDocument = "index.html"
            errorDocument = "error/400.html"
        }
    } | ConvertTo-Json)

@"
AWS_ACCESSKEY=$ACCESS_KEY_ID
AWS_SECRETACCESSKEY=$SECRET_ACCESS_KEY
AWS_BUCKET_NAME=fotowall
AWS_ENDPOINT=http://127.0.0.1:3900
"@ | Out-File -FilePath "spring.env" -Encoding ascii

Start-Sleep -Seconds 10

Write-Host "Database and S3 is Ready"

Start-Sleep -Seconds 2

Write-Host "Launching Fotowall"

docker compose `
    --profile runtime `
    --env-file ./docker.env `
    --env-file ./spring.env `
    up -d