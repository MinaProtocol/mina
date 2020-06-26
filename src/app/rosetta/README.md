Implementation of the [Rosetta Node API](https://www.rosetta-api.org/docs/node_api_introduction.html) for Coda.

To regenerate the models:
```
git clone https://github.com/coinbase/rosetta-specifications.git
cd rosetta-specifications
`brew install openapi`
openapi-generator generate -i api.json -g ocaml
mv src/models $CODA/src/app/rosetta/models
```
