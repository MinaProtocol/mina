# Coda Wallet

Coda is a new cryptocurrency protocol with a lightweight, constant sized blockchain.

The Coda Wallet desktop app allows you to manage your accounts, send and receive transactions, and stake your Coda for coinbase rewards.

We have a [Discord server](https://bit.ly/CodaDiscord)! Please come by if you
need help or have questions. You might also be interested in the [OCaml
Discord](https://discordapp.com/invite/cCYQbqN), for general OCaml help.

## Development 

The Coda Wallet is written in Reason (https://reasonml.github.io/), and built with Electron (https://electronjs.org/).

### Setup

First set up dependencies

1. Install watchman globally: `brew install watchman`
2. Install git lfs: `brew install git-lfs`
3. Run `git lfs install` to update hooks

Download and build the app:

1. Clone the repo via SSH: `git clone git@github.com:CodaProtocol/coda.git`
2. Navigate into coda/frontend/wallet
3. Update submodules: `git submodule update --init`
4. `yarn` to install dependencies
5. [Install coda](https://docs.minaprotocol.com/en/getting-started/)
7. `yarn build` to build app

Run locally with hot reloading:
1. `yarn dev` to start dev server with fake data
1. `yarn dev-real` to start dev server with real mina daemon

### Common Issues

1. If you see something like: `git@github.com: Permission denied (publickey).`
   when updating the submodules you need to set up SSH keys with GitHub, since
   our submodules use SSH URLS. GitHub has some documentation on how to do that
   [here](https://help.github.com/en/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent).
2. If you have a build error involving image assets and upon opening them you
   see that they're just small text files, then git lfs may not have been set
   up before you pulled the code. Make sure you ran `git lfs install` and then
   run `git lfs pull` to download files.

### Repackaging mina.exe [Needs work]

1. cd to root of repo
2. `make build`
3. `make macos-portable`
4. Upload `_build/coda-daemon-macos.zip` to our wallet s3 bucket
