open Graphql_basic_scalars.Utils
open Graphql_basic_scalars.Testing

module Make (Schema : Schema) = struct
  module SequenceEvent =
    Make_scalar_using_to_string
      (Snark_params.Tick.Field)
      (struct
        let name = "SequenceEvent"

        let doc = "sequence event"
      end)
      (Schema)
end

include Make (Schema)

let%test_module "Roundtrip tests" =
  ( module struct
    include Make (Test_schema)

    let%test_module "SequenceEvent" =
      (module Make_test (SequenceEvent) (Snark_params.Tick.Field))
  end )
