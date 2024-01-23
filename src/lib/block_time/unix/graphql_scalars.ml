open Graphql_basic_scalars.Utils
open Graphql_basic_scalars.Testing

module Make (Schema : Schema) = struct
  module type Json_intf =
    Json_intf_any_typ with type ('a, 'b) typ := ('a, 'b) Schema.typ

  module BlockTime : Json_intf with type t = Block_time.t = struct
    type nonrec t = Block_time.t

    let parse json =
      Yojson.Basic.Util.to_string json |> Block_time.of_string_exn

    let serialize timestamp = `String (Block_time.to_string_exn timestamp)

    let typ () = Schema.scalar "BlockTime" ~coerce:serialize
  end
end

include Make (Schema)

let%test_module "Roundtrip tests" =
  ( module struct
    include Make (Test_schema)

    let%test_module "BlockTime" = (module Make_test (BlockTime) (Block_time))
  end )
