[%%import "/src/config.mlh"]

[%%ifdef consensus_mechanism]

include module type of Mina_numbers.Token_id

[%%else]

include module type of Mina_numbers_nonconsensus.Token_id

[%%endif]
