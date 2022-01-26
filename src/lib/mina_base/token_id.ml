[%%import "/src/config.mlh"]

[%%ifdef consensus_mechanism]

include Mina_numbers.Token_id

[%%else]

include Mina_numbers_nonconsensus.Token_id

[%%endif]
