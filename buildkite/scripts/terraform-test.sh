#!/bin/bash

function test_single_terraform_config {

    cd $1 || exit

    terraform init
    terraform plan -var="create_libp2p_files=true"

    RET=$?

    if [ $RET != "0" ]; then
        printf "[ERROR] There is an error when trying to plan terraform network '$1'\n"
        exit 1
    else
        printf "[OK] $1 network deployment\n"
    fi
    
    cd ../
}

cd automation/terraform/testnets || exit
test_single_terraform_config "ci-net"