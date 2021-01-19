

To use:

1. run `scripts/get_daemon_config.sh <namespace>` from the root of the repo
2. run `docker build -t deb -f deb/Dockerfile .` from the root of the repo
3. run `docker run --memory=12G --network host -it deb /bin/bash`
4. from inside the docker, run `coda daemon -peer /dns4/seed-two.pickles-nightly.o1test.net/tcp/10001/p2p/12D3KooWFcGGeUmbmCNq51NBdGvCWjiyefdNZbDXADMK5CDwNRm5/ -peer /dns4/<KUBERNETES_SEED_IP>/tcp/10001/p2p/12D3KooWAFFq2yEQFFzhU5dt64AWqawRuomG9hL8rSmm5vxhAsgr -config-file /config/daemon.json -generate-genesis-proof true -log-json -log-level Trace | coda-logproc | tee log.txt`

