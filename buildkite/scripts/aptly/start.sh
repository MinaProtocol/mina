#!/bin/bash

apt install -y aptly

DISTRIBUTION=$1
DEBS=$2
COMPONENT=unstable
REPO="$DISTRIBUTION-$COMPONENT"

rm -rf ~/.aptly

aptly repo create -component $COMPONENT -distribution $DISTRIBUTION  $REPO

aptly repo add $REPO $DEBS

aptly snapshot create $COMPONENT from repo $REPO

aptly publish snapshot -distribution=$DISTRIBUTION -skip-signing $COMPONENT

nohup aptly serve -listen localhost:8080 &
