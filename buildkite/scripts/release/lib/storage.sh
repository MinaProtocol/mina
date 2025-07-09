#!/usr/bin/env bash

# Storage backend abstraction layer

function storage_list() {
    local backend=$1
    local path=$2

    case $backend in
        local)
            ls $path
            ;;
        gs)
            gsutil list "$path"
            ;;
        hetzner)
            ssh -p23 -i $HETZNER_KEY $HETZNER_USER@$HETZNER_HOST "ls $path"
            ;;
        *)
            echo "❌ Unsupported backend: $backend"
            exit 1
            ;;
    esac
}

function storage_md5() {
    local backend=$1
    local path=$2

    case $backend in
        local)
            md5sum $path | awk '{print $1}'
            ;;
        gs)
            gsutil hash -h -m "$path" | grep "Hash (md5)" | awk '{print $3}'
            ;;
        hetzner)
            ssh -p23 -i $HETZNER_KEY $HETZNER_USER@$HETZNER_HOST  "md5sum $path" | awk '{print $1}'
            ;;
        *)
            echo "❌ Unsupported backend: $backend"
            exit 1
            ;;
    esac
}

function storage_download() {
    local backend=$1
    local remote_path=$2
    local local_path=$3

    case $backend in
        local)
            cp $remote_path $local_path
            ;;
        gs)
            gsutil cp "$remote_path" "$local_path"
            ;;
        hetzner)
           ssh -p 23 -i $HETZNER_KEY $HETZNER_USER@$HETZNER_HOST "ls $remote_path" | xargs -I {} rsync -avz --rsh="ssh -p 23 -i $HETZNER_KEY" $HETZNER_USER@$HETZNER_HOST:{} $local_path
            ;;
        *)
            echo "❌ Unsupported backend: $backend"
            exit 1
            ;;
    esac
}

function storage_upload() {
    local backend=$1
    local local_path=$2
    local remote_path=$3

    case $backend in
        local)
            cp "$local_path" "$remote_path"
            ;;
        gs)
            gsutil cp "$local_path" "$remote_path"
            ;;
        hetzner)
           rsync -avz -e "ssh -p 23 -i $HETZNER_KEY" $local_path "$HETZNER_USER@$HETZNER_HOST:$remote_path"
            ;;
        *)
            echo "❌ Unsupported backend: $backend"
            exit 1
            ;;
    esac
}

function storage_root() {
    local backend=$1

    case $backend in
        local)
            echo "/var/storagebox/"
            ;;
        gs)
            echo "gs://buildkite_k8s/coda/shared"
            ;;
        hetzner)
            echo "/home/o1labs-generic/pvc-4d294645-6466-4260-b933-1b909ff9c3a1"
            ;;
        *)
            echo "❌ Unsupported backend: $backend"
            exit 1
            ;;
    esac
}

function validate_backend() {
    local backend=$1

    case $backend in
        gs|hetzner|local)
            return 0
            ;;
        *)
            echo -e "❌ ${RED} !! Backend (--backend) can be only gs, hetzner or local ${CLEAR}\n"
            return 1
            ;;
    esac
}