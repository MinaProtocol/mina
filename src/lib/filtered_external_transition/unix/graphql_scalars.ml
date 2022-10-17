module FeeTransferType :
  Graphql_basic_scalars.Json_intf
    with type t = Filtered_external_transition.Fee_transfer_type.t = struct
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
    Graphql_async.Schema.scalar "FeeTransferType" ~doc:"fee transfer type"
      ~coerce:serialize
end

(* TESTS *)

let%test_module "FeeTransferType" =
  ( module struct
    module FeeTransferType_gen = struct
      include Filtered_external_transition.Fee_transfer_type

      let gen = quickcheck_generator
    end

    include
      Graphql_basic_scalars.Make_test (FeeTransferType) (FeeTransferType_gen)
  end )
