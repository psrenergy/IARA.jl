aws ecr get-login-password --region $Env:AWS_REGION | docker login --username AWS --password-stdin $Env:AWS_ACCOUNT_ID + ".dkr.ecr." + $Env:AWS_REGION + ".amazonaws.com"
docker build -t $Env:AWS_ACCOUNT_ID + ".dkr.ecr." + $Env:AWS_REGION + ".amazonaws.com/iara:latest"
docker push $Env:AWS_ACCOUNT_ID + ".dkr.ecr." + $Env:AWS_REGION + ".amazonaws.com/iara:latest"