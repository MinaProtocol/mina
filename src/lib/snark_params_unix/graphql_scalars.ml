open Graphql_basic_scalars.Utils
open Graphql_basic_scalars.Testing

module Make (Schema : Schema) = struct
  module Action =
    Make_scalar_using_to_string
      (Snark_params.Tick.Field)
      (struct
        let name = "Action"

        let doc = "action"
      end)
      (Schema)
end

include Make (Schema)

let%test_module "Roundtrip tests" =
  ( module struct
    include Make (Test_schema)

    let%test_module "Action" =
      (module Make_test (Action) (Snark_params.Tick.Field))
  end )
