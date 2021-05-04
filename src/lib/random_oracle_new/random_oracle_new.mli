[%%import "/src/config.mlh"]

module Input = Random_oracle_input

[%%ifdef consensus_mechanism]

module Field = Pickles.Impls.Step.Internal_Basic.Field

[%%else]

module Field = Snark_params_nonconsensus.Field

[%%endif]

include
  Random_oracle_to_extract.S
  with type boolean := bool
   and type field := Field.t
   and type field_constant := Field.t
