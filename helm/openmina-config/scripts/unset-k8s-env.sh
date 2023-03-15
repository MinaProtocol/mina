#!/usr/bin/env sh

for VAR in $(printenv | sed -e 's/=.*//' | grep -E -e "(SEED|PROD|SNARK|NODE|FRONTEND).*_(SERVICE|PORT).*"); do
    eval "unset $VAR"
done

echo mina "$@"
exec mina "$@"
