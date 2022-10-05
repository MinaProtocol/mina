

To use:
run `scripts/bake <testnet_name> --docker-image=<version tag> --commit-hash=<hash>` from the root of the repo

This will run docker build on `bake/Dockerfile`. It attempts to
1. create a docker image from `codaprotocol/coda-daemon:<version tag>`
2. download the ledger file specified by the testnet name and the commit hash.
3. run the coda-daemon and get the keys/proofs required for the node to run.
