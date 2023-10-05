#!/bin/bash

function test_single_terraform_config {

    cd $1

    terraform init
    terraform plan

    RET=$?

    if [ $RET != "0" ]; then
        printf "[ERROR] There is an error when trying to plan terraform network '$1'\n"
        exit 1
    else
        printf "[OK] $1 network deployment\n"
    fi
    
}

cd automation/terraform/testnets

for NETWORK_FOLDER in *; do
    if [ -d "${NETWORK_FOLDER}" ]; then
        printf "testing $1 network deployment...\n"
        test_single_terraform_config ${NETWORK_FOLDER}
        cd ../
    fi
done