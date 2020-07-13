# Rosetta

Implementation of the [Rosetta Node API](https://www.rosetta-api.org/docs/node_api_introduction.html) for Coda.

## Run locally

(Tested on macOS)

1. Install postgres through homebrew
2. brew services start postgres
3. Run `./make-db.sh` (just once if you want to reuse the same table)
4. Run `./start.sh` to rebuild and rerun the genesis ledger, the archive node, coda daemon running in "demo mode" (producing blocks quickly), and finally the rosetta server.
5. Rerun `./start.sh` whenever you touch any code

Note: Coda is in the `dev` profile, so snarks are turned off and every runs very quickly. On my machine, buffers overflow after around 85 blocks.

If everything is working:

```
𝝺 ./test/network_list.sh
{"network_identifiers":[{"blockchain":"coda","network":"testnet"}]}
```

## Model Regen

To regenerate the models:

```
git clone https://github.com/coinbase/rosetta-specifications.git
cd rosetta-specifications
`brew install openapi-generator`
openapi-generator generate -i api.json -g ocaml
mv src/models $CODA/src/app/rosetta/models
```
