echo "Downloading required files"

curl -fsSL https://raw.githubusercontent.com/CCYP-PostFinance/CCYP-foto-wall-release/refs/heads/main/docker-compose.yaml  -o docker-compose.yaml
curl -fsSL https://raw.githubusercontent.com/CCYP-PostFinance/CCYP-foto-wall-release/refs/heads/main/garage.toml  -o garage.toml

echo "Downloading completed"

sleep 2

echo "Setting up environment for Garage"
printf 'GARAGE_RPC_SECRET=%s\n' "$(openssl rand -hex 32)" > docker.env

docker compose --profile dependencies --env-file ./docker.env up -d

sleep 5

echo "Garage setup completed"

sleep 2

echo "Launching S3 and Database"

NODE_ID=$(docker exec fotowall-garage /garage status | grep -E '^[0-9a-f]{16}' | awk '{print $1}' | head -n 1)

docker exec fotowall-garage /garage layout assign "$NODE_ID" -z dc1 -c 10G

docker exec fotowall-garage /garage layout apply --version 1

RESPONSE=$(curl -s -X POST -d '{"name":"backend"}' http://localhost:3909/api/v2/CreateKey)

ACCESS_KEY_ID=$(echo "$RESPONSE" | jq -r '.accessKeyId')
SECRET_ACCESS_KEY=$(echo "$RESPONSE" | jq -r '.secretAccessKey')

RESPONSE_BUCKET=$(curl -s -X POST -d '{"globalAlias":"fotowall"}' http://localhost:3909/api/v2/CreateBucket)

BUCKET_ID=$(echo "$RESPONSE_BUCKET" | jq -r '.id')

RESPONSE_PERMS=$(curl -s -X POST -d '{"bucketId":"'"$BUCKET_ID"'","accessKeyId":"'"$ACCESS_KEY_ID"'","permissions":{"read":true,"write":true,"owner":false}}' http://localhost:3909/api/v2/AllowBucketKey)

RESPONSE_ENABLE_WEB=$(curl -s -X POST -H "Content-Type: application/json" -d '{"websiteAccess": {"enabled": true,"indexDocument": "index.html","errorDocument": "error/400.html"}}' "http://localhost:3909/api/v2/UpdateBucket?id=$BUCKET_ID")

printf '%s\n' \
  "AWS_ACCESSKEY=$ACCESS_KEY_ID" \
  "AWS_SECRETACCESSKEY=$SECRET_ACCESS_KEY" \
  "AWS_BUCKET_NAME=fotowall" \
  "AWS_ENDPOINT=http://127.0.0.1:3900" \
  > spring.env

sleep 10

echo "Database and S3 is Ready"

sleep 2

echo "Launching Fotowall"

docker compose --profile runtime --env-file ./docker.env --env-file ./spring.env up -d