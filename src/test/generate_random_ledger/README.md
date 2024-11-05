# Generate random ledger

Test app for generating random ledger with corresponding keys based on input config

# Quick start

## build

```
dune build src/test/generate_random_ledger/generate_random_ledger.exe
```

## run with defaults

```
_build/default/src/test/generate_random_ledger/generate_random_ledger.exe
```

As a result default ledger with 3 accounts will be dumped to local folder.

- `alice , alice.pub` - private and public key for alice account
- `bob , bob.pub` -private and public key for bob account
- `clarice , clarice.pub` - private and public key for clarice account
- `genesis_ledger.config` - ledger config

## specify output folder

```
> _build/default/src/test/generate_random_ledger/generate_random_ledger.exe --output ./data

> ls ./data

alice  alice.pub  bob  bob.pub  clarice  clarice.pub  genesis_ledger.config

> cat data/genesis_ledger.config 

{"ledger":{"accounts":[{"pk":"B62qrA2eWb592uRLtH5ohzQnx7WTLYp2jGirCw5M7Fb9gTf1RrvTPqX","sk":"EKDxCqQGa39sTxtecX4gRmw8MzpG3JB8ooL8uDNqE75sj2uegkuz","balance":"1000000"},{"pk":"B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93","sk":"EKEhAjWjbtAyppEPYUMYaEBuLv2gfgbAMvX2uTbtS2AyMpEmMtGU","balance":"1000000"},{"pk":"B62qp5sdhH48MurWgtHNkXUTphEmUfcKVmZFspYAqxcKZ7YxaPF1pyF","sk":"EKDsKYn9FHx541TcemCx1Y1r2E6K9fZpbXPrfkW6m3X9nrS18RHk","balance":"100000"}],"num_accounts":3,"add_genesis_winner":false}}

```

# Run with input config

App can accept input config defining accounts specifications. For example, for given config file `input.config` with content:

```
{
   "genesis_ledger":[
      {
         "account_name":"alice",
         "balance":"1000000"
      },
      {
         "account_name":"bob",
         "balance":"1000000"
      },
      {
         "account_name":"clarice",
         "balance":"100000"
      }
   ],
   "block_producers":[
      {
         "node_name":"node-a",
         "account_name":"alice"
      },
      {
         "node_name":"node-b",
         "account_name":"bob"
      },
      {
         "node_name":"node-c",
         "account_name":"clarice"
      }
   ]
}
```

and usage: 

```
_build/default/src/test/generate_random_ledger/generate_random_ledger.exe --output data --config ~/genesis.input 
```
