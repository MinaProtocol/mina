open Graphql_basic_scalars

module SequenceEvent =
  Make_scalar_using_to_string
    (Snark_params.Step.Field)
    (struct
      let name = "SequenceEvent"

      let doc = "sequence event"
    end)
