#!/usr/bin/env bash

# The environment variables are set at the time of deployment in the init container
CREDENTIALS=$(aws sts assume-role --role-session-name $AWS_ROLE_SESSION_NAME --role-arn $AWS_ROLE_ARN > /dev/null)

ACCESS_KEY_ID=$(echo $CREDENTIALS | jq -r '.Credentials.AccessKeyId' > /dev/null)

SECRET_ACCESS_KEY=$(echo $CREDENTIALS | jq -r '.Credentials.SecretAccessKey' > /dev/null)

SESSION_TOKEN=$(echo $CREDENTIALS | jq -r '.Credentials.SessionToken' > /dev/null)

echo "export AWS_ACCESS_KEY_ID=$ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$SECRET_ACCESS_KEY AWS_SESSION_TOKEN=$SESSION_TOKEN" > /var/mina-delegation-verify-auth/.env
