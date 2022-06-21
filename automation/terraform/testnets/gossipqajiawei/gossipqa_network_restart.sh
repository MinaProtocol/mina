#!/bin/bash

whale_producers=1
fish_producers=2
seeds=1
coordinators=1
namespace="gossipqa"

function restart {
   POD_NAME=$1
   CONTAINER=$2
   # $kubectl exec $POD_NAME -c $CONTAINER -n $namespace /sbin/killall5 
}

while read -r line
do 
    t=$[ ( $RANDOM % 20 )  + 1 ]
    echo "waiting $t minutes"
    sleep ${t}m
    arr=(${line/ /})
    echo "${arr[0]}, ${arr[1]}, ${arr[2]}, ${arr[3]}"
    pod_name=${arr[0]}
    role=${arr[3]}
    status=${arr[2]}
    container=${arr[1]}
    if [[ $role == "block-producer" && $status == "Running" && $container == "mina" ]]; then
        if [[ $whale_producers -gt 0 ]]; then
            whale_producers=$((whale_producers - 1))
            echo "restarting $pod_name; remaining ${whale_producers}"
            restart $pod_name $container
        else
            echo "Not restarting"
        fi
    elif [[ $role == "snark-coordinator" && $status == "Running" && $container == "coordinator" ]]; then
        if [[ $coordinators -gt 0 ]]; then
            coordinators=$((coordinators - 1))
            echo "restarting $pod_name; remaining ${coordinators}"
            restart $pod_name $container
        else
            echo "Not restarting"
        fi
    elif [[ $role == "seed" && $status == "Running" && $container == "mina" && ${pod_name} = *"seed"*  ]]; then
        if [[ $seeds -gt 0 ]]; then
            seeds=$((seeds - 1))
            echo "restarting $pod_name; remaining ${seeds}"
            restart $pod_name $container
        else
            echo "Not restarting"
        fi
    elif [[ $role == "block-producer" && $status == "Running" && ${pod_name} = *"fish"*  ]]; then
        if [[ $fish_producers -gt 0 ]]; then
            fish_producers=$((fish_producers - 1))
            echo "restarting $pod_name; remaining ${fish_producers}"
            restart $pod_name "mina"
        else
            echo "Not restarting"
        fi
    else
        echo "Ignoring"
    fi

done <<<  $(sudo kubectl get pods -n $namespace -o custom-columns=NAME:.metadata.name,CONTAINER:.spec.containers[0].name,META:.status.phase,ROLE:.metadata.labels.role)
