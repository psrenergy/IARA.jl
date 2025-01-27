aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $Env:AWS_ACCOUNT_ID
docker build -t $Env:AWS_ACCOUNT_ID/iara:latest .
docker push $Env:AWS_ACCOUNT_ID/iara:latest