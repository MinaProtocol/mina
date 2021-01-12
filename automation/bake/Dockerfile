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
RUN mkdir -p /root/.coda-config && echo "{}" > /root/.coda-config/daemon.json

RUN coda daemon -config-file ${CONFIG_FILE} -generate-genesis-proof true; \
  mv ~/.coda-config/genesis/genesis_* /var/lib/coda/

RUN curl https://raw.githubusercontent.com/MinaProtocol/mina/${COMMIT_HASH}/automation/terraform/testnets/${TESTNET_NAME}/peers.txt -o /root/peers.txt

#RUN curl https://raw.githubusercontent.com/MinaProtocol/mina/develop/dockerfiles/scripts/healthcheck-utilities.sh -o /healthcheck/utilities.sh

RUN echo '#!/bin/bash -x\n\
mkdir -p .coda-config\n\
touch .coda-config/coda-prover.log\n\
touch .coda-config/coda-verifier.log\n\
touch .coda-config/mina-best-tip.log\n\
command=$1 \n\
shift \n\
while true; do\n\
  rm -f /root/.coda-config/.mina-lock\n\
  coda "$command" -config-file "'${CONFIG_FILE}'" "$@" 2>&1 >coda.log &\n\
  coda_pid=$!\n\
  tail -q -f coda.log &\n\
  tail_pid=$!\n\
  wait "$coda_pid"\n\
  echo "Coda process exited with status code $?"\n\
  sleep 10\n\
  kill "$tail_pid"\n\
  if [ ! -f stay_alive ]; then\n\
    exit 0\n\
  fi\n\
done'\
> init_coda_baked.sh

RUN chmod +x init_coda_baked.sh

ENV CODA_TIME_OFFSET 0

ENTRYPOINT ["/usr/bin/dumb-init", "/root/init_coda_baked.sh"]
