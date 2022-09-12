# Mina Local Network Manager

## Instructions

1. Checkout `Mina` repository.
2. Go to its root directory and execute commands staying in the same root directory.
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
        DUNE_PROFILE="testnet_postake_medium_curves" \
          dune build \
            src/app/cli/src/mina.exe \
            src/app/archive/archive.exe \
            src/app/logproc/logproc.exe
        ```

      - If you’d like to work with the `zkApps` locally.
        - Build the `SnarkyJS`:

          ```shell
          ./scripts/build-snarkyjs-node.sh
          ```

5. Within the `Mina` repository root directory, execute the `./scripts/mina-local-network/mina-local-network.sh`, for example:

    ```shell
    ./scripts/mina-local-network/mina-local-network.sh \
      -sp 3100 \
      -w 3 \
      -f 2 \
      -n 2 \
      -u \
      -ll Info \
      -fll Info \
      -a
    ```

    Please use `-h` argument to get more information.

## SnarkyJS and zkApps

- Now, if you’d like to work with the `zkApps` locally, you need to update the `SnarkyJS` reference for your `zkApp` project (e.g. created using the `zkApp-CLI` like this: `zk project foo`).
  - Suppose you’ve created `zkApp` at following path:
    - `~/projcts/zkapps/foo`
  - Go to `zkApp` project root (☝️).
  - Remove old `SnarkyJS` Node Module:
    - `rm -rf node_modules/snarkyjs`
  - Install its fresh version (build as described above) instead:

    ```shell
    npm i ${HOME}/<path_to_Mina_repo>/src/lib/snarky_js_bindings/snarkyjs
    ```

## Notes

- `Always run` at least `2` block producers, for example `-w 2`, otherwise the network might halt.
- Don’t forget to provide additional `PostgreSQL` connection configuration in case of using the `-a` argument.
- Work directory will be:
  - `${HOME}/.mina-network`
- Accounts private key passphrase will be: `naughty blue worm`.
- The `GraphQL` endpoints will be available at
  - [http://localhost:4001/graphql](http://localhost:4001/graphql)
  - [http://localhost:4006/graphql](http://localhost:4006/graphql)
  - Etc.
  - Depending on you environment configuration (number of zkApp commands, starting port of ranges, etc.)
- You might want to get `encoded private key` instead of the raw data generated for you. You can do this using the following command:

  ```shell
  ./_build/default/src/app/cli/src/mina.exe \
    advanced dump-keypair \
      --privkey-path ~/.mina-network/mina-local-network-2-1-1/offline_whale_keys/offline_whale_account_1

    Output:
    Private-key password:
    Public key:  B62q...
    Private key: EKDp...
  ```

- In order to start sending payments or anything else account related, you first need to import and unlock the account:

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
