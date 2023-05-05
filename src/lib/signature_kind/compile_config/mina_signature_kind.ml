[%%import "/src/config.mlh"]

type t = Testnet | Mainnet

[%%if network = "mainnet"]

let t = Mainnet

[%%elif network = "testnet"]

let t = Testnet

[%%endif]
