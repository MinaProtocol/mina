open Graphql_basic_scalars
open Data_hash_lib

module StateHashAsDecimal : Json_intf with type t = State_hash.t = struct
  open State_hash

  type nonrec t = t

  let parse json = Yojson.Basic.Util.to_string json |> of_decimal_string

  let serialize x = `String (to_decimal_string x)

  let typ () =
    Graphql_async.Schema.scalar "StateHashAsDecimal"
      ~doc:"Experimental: Bigint field-element representation of stateHash"
      ~coerce:serialize
end

let%test_module "StateHashAsDecimal" =
  (module Make_test (StateHashAsDecimal) (State_hash))
