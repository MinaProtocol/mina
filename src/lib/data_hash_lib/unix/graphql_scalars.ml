open Graphql_basic_scalars.Utils
open Graphql_basic_scalars.Testing
open Data_hash_lib

module Make (Schema : Schema) = struct
  module type Json_intf =
    Json_intf_any_typ with type ('a, 'b) typ := ('a, 'b) Schema.typ

  module StateHashAsDecimal : Json_intf with type t = State_hash.t = struct
    open State_hash

    type nonrec t = t

    let parse json = Yojson.Basic.Util.to_string json |> of_decimal_string

    let serialize x = `String (to_decimal_string x)

    let typ () =
      Schema.scalar "StateHashAsDecimal"
        ~doc:"Experimental: Bigint field-element representation of stateHash"
        ~coerce:serialize
  end
end

include Make (Schema)

let%test_module "Roundtrip tests" =
  ( module struct
    include Make (Test_schema)

    let%test_module "StateHashAsDecimal" =
      (module Make_test (StateHashAsDecimal) (State_hash))
  end )
