open Graphql_basic_scalars.Utils
open Graphql_basic_scalars.Testing

module Make (Schema : Schema) = struct
  module type Json_intf =
    Json_intf_any_typ with type ('a, 'b) typ := ('a, 'b) Schema.typ

  module FeeTransferType :
    Json_intf with type t = Filtered_external_transition.Fee_transfer_type.t =
  struct
    type t = Filtered_external_transition.Fee_transfer_type.t

    let parse json : t =
      match Yojson.Basic.Util.to_string json with
      | "Fee_transfer_via_coinbase" ->
          Fee_transfer_via_coinbase
      | "Fee_transfer" ->
          Fee_transfer
      | s ->
          failwith
          @@ Format.sprintf
               "Could not parse string <%s> into a Fee_transfer_type.t" s

    let serialize (transfer_type : t) : Yojson.Basic.t =
      `String
        ( match transfer_type with
        | Fee_transfer_via_coinbase ->
            "Fee_transfer_via_coinbase"
        | Fee_transfer ->
            "Fee_transfer" )

    let typ () =
      Schema.scalar "FeeTransferType" ~doc:"fee transfer type" ~coerce:serialize
  end
end

include Make (Schema)

let%test_module "Roundtrip tests" =
  ( module struct
    include Make (Test_schema)

    let%test_module "FeeTransferType" =
      ( module struct
        module FeeTransferType_gen = struct
          include Filtered_external_transition.Fee_transfer_type

          let gen = quickcheck_generator
        end

        include Make_test (FeeTransferType) (FeeTransferType_gen)
      end )
  end )
