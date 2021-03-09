ARG BAKE_VERSION

FROM codaprotocol/coda-daemon:${BAKE_VERSION}

RUN apt-get update && apt-get install -y gnupg2

RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -

RUN apt-get update && apt-get install -y google-cloud-sdk

ARG COMMIT_HASH=master
ARG TESTNET_NAME=testworld
ARG CONFIG_FILE="/root/daemon.json"

RUN curl https://raw.githubusercontent.com/MinaProtocol/mina/${COMMIT_HASH}/automation/terraform/testnets/${TESTNET_NAME}/genesis_ledger.json -o "${CONFIG_FILE}"

RUN head ${CONFIG_FILE}

# Create the defautl config dir and an empty config
RUN mkdir -p /root/.mina-config && echo "{}" > /root/.mina-config/daemon.json

RUN mina daemon -config-file ${CONFIG_FILE} -generate-genesis-proof true; \
  mv ~/.mina-config/genesis/genesis_* /var/lib/coda/

RUN curl https://raw.githubusercontent.com/MinaProtocol/mina/${COMMIT_HASH}/automation/terraform/testnets/${TESTNET_NAME}/peers.txt -o /root/peers.txt

#RUN curl https://raw.githubusercontent.com/MinaProtocol/mina/develop/dockerfiles/scripts/healthcheck-utilities.sh -o /healthcheck/utilities.sh

RUN echo '#!/bin/bash\n\
function is_synced {\n\
  local sync_status=$(mina client status | grep "Sync status" | cut -d":" -f2)\n\
  if [ $? -ne 0 ];\n\
  then\n\
    echo Fail to fetch sync status\n\
    return 0\n\
  fi\n\
  if [ $sync_status != "Synced" ];\n\
  then\n\
    echo Nodes not synced\n\
    return 0\n\
  fi\n\
  local max_observed_block=$(mina client status | grep "Max observed block height" | cut -d":" -f2)\n\
  if [ $? -ne 0 ];\n\
  then\n\
    echo Fail to fetch max_observed_block\n\
    return 0\n\
  fi\n\
  local max_unvalidated_block=$(mina client status | grep "Max observed unvalidated block height" | cut -d":" -f2)\n\
  if [ $? -ne 0 ];\n\
  then\n\
    echo Fail to fetch max_unvalidated_block\n\
    return 0\n\
  fi\n\
  local diff=$((max_unvalidated_block-max_observed_block))\n\
  echo Difference between validated and unvalidated block height is $diff\n\
  test $diff -lt 10\n\
  return\n\
}\n\
\n\
not_synced=0\n\
while true\n\
do\n\
  if is_synced;\n\
  then\n\
    echo Nodes has no sync issue\n\
    not_synced=0\n\
  else\n\
    echo Node reports sync but is not synced\n\
    not_synced=$(($not_synced+1))\n\
  fi\n\
  if [ $not_synced -gt 5 ];\n\
  then mina client stop-daemon\n\
  fi\n\
  sleep 60\n\
done'\
> auto-kill-node.sh

RUN chmod +x auto-kill-node.sh

RUN echo '#!/bin/bash -x\n\
mkdir -p .mina-config\n\
touch .mina-config/mina-prover.log\n\
touch .mina-config/mina-verifier.log\n\
touch .mina-config/mina-best-tip.log\n\
command=$1 \n\
shift \n\
while true; do\n\
  rm -f /root/.mina-config/.mina-lock\n\
  mina "$command" -config-file "'${CONFIG_FILE}'" "$@" 2>&1 >mina.log &\n\
  coda_pid=$!\n\
  tail -q -f mina.log &\n\
  tail_pid=$!\n\
  wait "$coda_pid"\n\
  echo "Coda process exited with status code $?"\n\
  sleep 10\n\
  kill "$tail_pid"\n\
  if [ ! -f stay_alive ]; then\n\
    exit 0\n\
  fi\n\
done'\
> init_mina_baked.sh

RUN chmod +x init_mina_baked.sh

ENV CODA_TIME_OFFSET 0

ENTRYPOINT ["/usr/bin/dumb-init", "/root/init_mina_baked.sh"]
