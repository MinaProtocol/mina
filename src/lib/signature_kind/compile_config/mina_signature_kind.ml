[%%import "/src/config.mlh"]

type t = Testnet | Mainnet | Other_of_string

[%%if network = "mainnet"]

let t = Mainnet

[%%elif network = "testnet"]

let t = Testnet

[%%else]

let t = Other_of_string

[%%endif]
