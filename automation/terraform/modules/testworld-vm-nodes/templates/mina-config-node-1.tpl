cat > /root/startup.sh <<- "SCRIPT"
#!/bin/bash

export MINA_LIBP2P_PASS=${mina_libp2p_pass}
export MINA_PRIVKEY_PASS=${wallet_privkey_pass}
export UPTIME_PRIVKEY_PASS=${wallet_privkey_pass}

# check if mina is installed
function mina_installed() {
    if which mina >/dev/null; then
        return 0
    else
        return 1
    fi
}

function install_mina() {
    sudo rm /etc/apt/sources.list.d/mina*.list
    echo "deb [trusted=yes] http://packages.o1test.net/ buster rampup" | sudo tee /etc/apt/sources.list.d/mina-rampup.list
    sudo apt-get update
    sudo apt-get install -y mina-berkeley=2.0.0rampup7-4a0fff9 tzdata
    sudo curl https://raw.githubusercontent.com/MinaProtocol/mina/rampup/genesis_ledgers/berkeley.json > /root/berkeley.json
}

function generate_libp2p_key() {
    mina libp2p generate-keypair --privkey-path /root/libp2p-keys/key
    chmod -R 0700 /root/libp2p-keys/
}

function install_mina_keygen() {
    echo "deb [trusted=yes] http://packages.o1test.net $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/mina.list
    sudo apt-get update
    sudo apt-get install mina-generate-keypair=1.4.0-c980ba8
}

function generate_block_producer_key() {
    mkdir /root/wallet-keys
    chmod 700 /root/wallet-keys

    # keys are being manually assigned in this case
    # mina-generate-keypair --privkey-path /root/wallet-keys/key

    echo '${wallet_privkey}' >> /root/wallet-keys/key
    echo '${wallet_pubkey}' >> /root/wallet-keys/key.pub

    chmod 600 /root/wallet-keys/key
}

function start_mina() {
    mina daemon \
    --config-file /root/berkeley.json \
    --peer-list-url "https://storage.googleapis.com/seed-lists/testworld-2-0_seeds.txt" \
    --libp2p-keypair "/root/libp2p-keys/key" \
    --log-level "Debug" \
    --log-json \
    --itn-keys "${itn_logger_keys}" \
    --uptime-url "https://block-producers-uptime-itn.minaprotocol.tools/v1/submit" \
    --node-status-url "https://nodestats-itn.minaprotocol.tools/submit/stats" \
    --node-error-url "https://nodestats-itn.minaprotocol.tools/submit/stats" \
    --uptime-submitter-key "/root/wallet-keys/key" \
    --internal-tracing \
    --enable-peer-exchange true \
    --config-directory "/root/.mina-config" \
    --insecure-rest-server \
    --client-port 8301 \
    --rest-port 3085 \
    --itn-graphql-port 3086 \
    --external-port 10501 \
    --metrics-port 10001 \
    --block-producer-key "/root/wallet-keys/key" \
    --upload-blocks-to-gcloud false \
    --generate-genesis-proof true \
    --itn-max-logs 10000
}

# sudo su
if ! mina_installed; then
    install_mina
    generate_libp2p_key
    install_mina_keygen
    generate_block_producer_key
    start_mina
else
    start_mina
fi
SCRIPT