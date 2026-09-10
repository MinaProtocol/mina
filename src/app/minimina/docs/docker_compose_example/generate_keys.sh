#!/bin/bash

declare -a bp_array=("mina-bp-1" "mina-bp-2")
declare bp_dir=~/.minimina/default/block_producer_keys
declare libp2p_dir=~/.minimina/default/libp2p_keys

# Create directories holding keys ensuring correct file permissions
mkdir -p $bp_dir $libp2p_dir
chmod 700 $bp_dir $libp2p_dir

for bp in "${bp_array[@]}"; do

    echo "----------------"
    echo "$bp keys: "
    echo
    
    # Generate block producer keys
    docker run \
    --rm \
    --env MINA_PRIVKEY_PASS='naughty blue worm' \
    --entrypoint mina \
    -v $bp_dir:/keys \
    gcr.io/o1labs-192920/mina-daemon:2.0.0rampup3-bfd1009-buster-berkeley \
    advanced generate-keypair -privkey-path /keys/$bp

    echo
    # Generate libp2p keys
    docker run \
    --rm \
    --env MINA_LIBP2P_PASS='naughty blue worm' \
    --entrypoint mina \
    -v $libp2p_dir:/keys \
    gcr.io/o1labs-192920/mina-daemon:2.0.0rampup3-bfd1009-buster-berkeley \
    libp2p generate-keypair -privkey-path /keys/$bp
    echo
done
