# SNAPP Credit Score Demo

## Dependencies:

```
yarn install
```

or

```
npm install
```

You will additionally need the `credit_score_demo.exe` binary to build SNAPPS.

You can compile the `credit_score_demo.exe` binary by doing the following:

1. Checkout to the `feature/snapp-demo` branch.

```
git checkout feature/snapp-demo
```

2. Build the Mina daemon.

```
DUNE_PROFILE=testnet_postake_medium_curves make build
```

3.  Build the SNAPP demo client.

```
DUNE_PROFILE=testnet_postake_medium_curves dune build src/app/snapp_runner/examples/credit_score_demo/credit_score_demo.exe
```

4.  Once the binary is made, place it in `resources/bin`

You can additionally see `src/app/snapp_runner/examples/credit_score_demo/README.md` for more details on the SNAPP binary.

## Run

**Note:** If you are developing against this, change the `process.env.NODE_ENV` variable to `dev` in `main.js`.

```
npm run start
```

## Package and Create Installer

Run the following to build an installer for Linux:

```
npm run package-linux
```

```
npm run create-installer-linux
```
