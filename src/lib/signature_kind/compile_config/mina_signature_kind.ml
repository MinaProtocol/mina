[%%import "/src/config.mlh"]

type t = Testnet | Mainnet | Other_network of string

[%%if network = "mainnet"]

let t = Mainnet

[%%elif network = "testnet"]

let t = Testnet

[%%else]

[%%inject "network", chain_name]

let t = Other_network chain_name

[%%endif]
