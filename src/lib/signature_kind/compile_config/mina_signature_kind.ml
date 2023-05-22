[%%import "/src/config.mlh"]

type t = Testnet | Mainnet | Other_network

[%%if network = "mainnet"]

let t = Mainnet

[%%elif network = "testnet"]

let t = Testnet

[%%else]

let t = Other_network

[%%endif]
