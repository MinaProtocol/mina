# Mina Local Network Manager

## Instructions

1. Checkout `Mina` repository.
2. Go to its root directory and execute commands staying in this root directory.
3. Install dependencies.

   - OS dependencies:
     - `PostgreSQL`, its client and credentials configuration, if you'd like to also run the Archive Node.
     - `Python3`.
     - `jq` tool.
   - Python dependencies:

     ```shell
     pip3 install -r ./scripts/mina-local-network/requirements.txt
     ```

4. Build `Mina` executables.

   - Perhaps the easiest way is to use [Nix](https://github.com/MinaProtocol/mina/tree/develop/nix).

     - After installation open the `devShell`:

       ```shell
       nix develop mina
       ```

     - Build the executables:

       ```shell
       MINA_COMMIT_SHA1=$(git rev-parse HEAD) \
       DUNE_PROFILE="devnet" \
         dune build \
           src/app/cli/src/mina.exe \
           src/app/archive/archive.exe \
           src/app/logproc/logproc.exe
       ```

     - If you’d like to work with [zkApps](https://github.com/MinaProtocol/MIPs/blob/main/MIPS/mip-zkapps.md) using [SnarkyJS](https://github.com/o1-labs/snarkyjs) locally.

       - Build the `SnarkyJS`:

         ```shell
         ./scripts/update-snarkyjs-bindings.sh
         ```

5. Execute the `./scripts/mina-local-network/mina-local-network.sh` script, for example:

   ```shell
   ./scripts/mina-local-network/mina-local-network.sh \
     -sp 3100 \
     -w 2 \
     -f 1 \
     -n 1 \
     -u \
     -ll Trace \
     -fll Trace \
     -a
   ```

   Please use `-h` argument to get more information about script's possible options.

## SnarkyJS and zkApps

- Now, if you’d like to work with `zkApps` using `SnarkyJS` locally, you need to update the `SnarkyJS` reference for your `zkApp` project (e.g. created using [zkApp-CLI](https://github.com/o1-labs/zkapp-cli) like this: `zk project foo`).

  - Suppose you’ve created `zkApp` at following path:
    - `~/projcts/zkapps/foo`
  - Go to `zkApp` project root (☝️).
  - Remove old `SnarkyJS` Node Module:
    - `rm -rf node_modules/snarkyjs`
  - Install its fresh version (built from sources as described above) instead:

    ```shell
    npm i ${HOME}/<path_to_Mina_repo>/src/lib/snarkyjs
    ```

  - Note: you can also refer to [this repo](https://github.com/o1-labs/e2e-zkapp/) in order to get environment setting up scripts.

## Mina Lightweight Network

It is possible to run faster and less resources demanding networks.  
First of all you need to either:

- Build `Mina` using [lightnet](https://github.com/MinaProtocol/mina/tree/develop/src/config/lightnet.mlh) Dune profile:

  ```shell
       MINA_COMMIT_SHA1=$(git rev-parse HEAD) \
       DUNE_PROFILE="lightnet" \
         dune build \
           src/app/cli/src/mina.exe \
           src/app/archive/archive.exe \
           src/app/logproc/logproc.exe
  ```

- Or override compile-time constants in Genesis Ledger JSON configuration:

  ```json
  {
    "genesis": {
      "proof_level": "none", # After the fix of https://github.com/MinaProtocol/mina/issues/13289
      "k": 30,
      "slots_per_epoch": 720,
      "block_window_duration": 20000,
      "genesis_state_timestamp": "2023-05-26T20:14:28+0300"
    },
    "ledger": {
      "name": "testnet",
      "num_accounts": 4,
      "accounts": [
        {
          "pk": "B62qr81JquSrKixS4x48fzCWmDHueZgqYmdyKp4kHsKnoXuzc8qcE9g",
          "sk": null,
          "balance": "5.000000000",
          "delegate": null
        },
        {},
        {},
        {}
      ]
    }
  }
  ```

Then you will need to run the network manager script with additional `-pl` argument:

```shell
./scripts/mina-local-network/mina-local-network.sh \
  -sp 3100 \
  -w 2 \
  -f 1 \
  -n 1 \
  -u \
  -ll Trace \
  -fll Trace \
  -pl none \
  -a
```

Resulting network will have the following qualities:

- New blocks will be produced every `~20` seconds.
- Transactions finality will be `30` blocks.
- The network proving will be disabled (dummy proofs will be in use).
  - Please be cautious with this one.
  - You should **ALWAYS** double check your changes or run your final tests against the networks with the `proof_level=full` configured.

Note though, that such a network might be unstable and cause different issues like this one: https://github.com/MinaProtocol/mina/issues/8331.  
Thus, don't overload it with too many transactions.

## Notes

- `Always run` at least `2` block producers, for example `-w 2`, otherwise the network might halt.
- Don’t forget to provide additional `PostgreSQL` connection configuration in case of using the `-a` argument.
- Work directory will be:
  - `${HOME}/.mina-network`
- Accounts private key passphrase will be: `naughty blue worm`.
- The `GraphQL` endpoints will be available at
  - [http://localhost:4001/graphql](http://localhost:4001/graphql)
  - [http://localhost:4006/graphql](http://localhost:4006/graphql)
  - Etc. (you will see more details in the script's output).
- In order to get `encoded private key` instead of the raw data generated, you can use the following command:

  ```shell
  ./_build/default/src/app/cli/src/mina.exe \
    advanced dump-keypair \
      --privkey-path ~/.mina-network/mina-local-network-2-1-1/offline_whale_keys/offline_whale_account_1

    Output:
    Private-key password:
    Public key:  B62q...
    Private key: EKDp...
  ```

- In order to start sending payments using GraphQL endpoint or do else account related activities, you first need to import and unlock the account:

  ```shell
  _build/default/src/app/cli/src/mina.exe \
    accounts import \
      --privkey-path ~/.mina-network/mina-local-network-2-1-1/offline_whale_keys/offline_whale_account_1 \
    --rest-server 4006

  _build/default/src/app/cli/src/mina.exe \
    accounts unlock \
      --public-key "B62q..." \
      --rest-server 4006
  ```
