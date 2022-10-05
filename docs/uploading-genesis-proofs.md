We currently have an option to generate a genesis proof for the current configuration when a daemon is started by passing the `--generate-genesis-proof true` flag. When this flag isn't passed, the daemon will attempt to download a proof from our snark-keys S3 bucket, or exit with an error if one isn't found.

To avoid asking all users to pass this flag manually, it is useful to generate this file and place it in the bucket. This can be done manually, but it is easiest to open a dummy pull request and let CI upload the file for you.

### Getting the genesis configuration

If you are creating the release manually, you may already have the configuration file. The important information to have is the genesis timestamp and the list of the accounts in the ledger, resulting in a file that looks like

```json
{
  "genesis": {
    "genesis_state_timestamp": "2021-02-17T19:30:00Z"
  },
  "ledger": {
    "accounts": [ ... ]
}
```

If this is for a testnet that has already been released, you can get this information from the `.deb` file used to install it. For example, the zenith testnet release (version `0.4.2-245a3f7`) can be found at the following URL:
```
https://packages.o1test.net/pool/release/m/mi/mina-testnet-postake-medium-curves-noprovingkeys_0.4.2-245a3f7.deb
```

where `release` corresponds to the debian repository, and the suffix `_0.4.2-24a3f7` is the particular version number.

Using a tool that supports opening archives (e.g. `file-roller` on ubuntu), you can open the `.deb` file and the `data.tar.xz` file inside that to see the files that would be installed by the `.deb`. In `var/lib/coda/config*.json` (this may migrate to `var/lib/mina/config*.json` in the future) you should see the configuration for that release.

### Generating a genesis proof in CI

Pull requests on CI will run the ['Build Mina daemon debian package' job](https://github.com/MinaProtocol/mina/blob/2d99c24fec9bf5264c1f76e6ace91eb4c7625c98/buildkite/src/Jobs/Release/MinaArtifact.dhall#L52), which [uploads the genesis ledger and proof](https://github.com/MinaProtocol/mina/blob/2d99c24fec9bf5264c1f76e6ace91eb4c7625c98/scripts/upload-genesis.sh#L10) as part of the [build process](https://github.com/MinaProtocol/mina/blob/2d99c24fec9bf5264c1f76e6ace91eb4c7625c98/buildkite/scripts/build-artifact.sh#L34). So, to make this happen, you can
* checkout the commit you are interested in, as a new branch
  - `git checkout -b do-not-merge/generate-genesis-24a3f7 24a3f7`
* replace `genesis_ledgers/phase_three/config.json` with your desired config
* `git add genesis_ledgers/phase_three/config.json && git commit`
* push the branch and open a pull request
  - It's good practice to add a title like `[DO NOT MERGE] Generate genesis proof for foo`
* set CI to run on the pull request by adding the `ci-build-me` label, or by commenting `!ci-build-me`
* when CI has finished, close the pull request

### Manually generate the proof and upload to CI
* checkout the commit you are interested in
  - `git checkout 24a37`
* build the `runtime_genesis_ledger` tool
  - `export DUNE_PROFILE=testnet_postake_medium_curves`
  - `dune build --profile=${DUNE_PROFILE} src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe`
* run the `runtime_genesis_ledger` tool on your configuration file
  - `_build/default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe --config-file PATH/TO/YOUR/config.json`
* upload the generated ledger and proof files to S3
  - You will need the access keys for the `snark-keys` bucket, and the `aws` tool installed to use this command
  - `aws s3 sync --exclude "*" --include "genesis_*" --acl public-read /tmp/coda_cache_dir/genesis_* s3://snark-keys.o1test.net/`
