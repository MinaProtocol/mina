FROM codaprotocol/coda-daemon:0.0.16-beta-hotfix-master-fix-genesis-timestamp-e900fe0

RUN mkdir /tmp/coda_cache_dir
RUN curl -sL https://s3-us-west-2.amazonaws.com/snark-keys.o1test.net/genesis_proof_3ef99b7a1a7a782f6498a9091ba8a370d6f429247984b4ee2f545b2482d3d739 -o /tmp/coda_cache_dir/genesis_proof_3ef99b7a1a7a782f6498a9091ba8a370d6f429247984b4ee2f545b2482d3d739

COPY ./genesis_ledger.json /root/config.json

