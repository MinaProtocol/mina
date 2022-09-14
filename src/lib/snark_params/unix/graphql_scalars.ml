open Graphql_basic_scalars

module SequenceEvent =
  Make_scalar_using_to_string
    (Snark_params.Tick.Field)
    (struct
      let name = "SequenceEvent"

      let doc = "sequence event"
    end)

let%test_module "SequenceEvent" =
  (module Make_test (SequenceEvent) (Snark_params.Tick.Field))
