#!/usr/bin/env bash

set -x

# The environment variables are set at the time of deployment in the init container
CREDENTIALS=$(aws sts assume-role --role-session-name $DELEGATION_VERIFY_AWS_ROLE_SESSION_NAME --role-arn $DELEGATION_VERIFY_AWS_ROLE_ARN)

ACCESS_KEY_ID=$(echo $CREDENTIALS | jq -r '.Credentials.AccessKeyId')

SECRET_ACCESS_KEY=$(echo $CREDENTIALS | jq -r '.Credentials.SecretAccessKey')

SESSION_TOKEN=$(echo $CREDENTIALS | jq -r '.Credentials.SessionToken')

echo "export AWS_ACCESS_KEY_ID=$ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$SECRET_ACCESS_KEY AWS_SESSION_TOKEN=$SESSION_TOKEN" > /var/mina-delegation-verify-auth/.env
