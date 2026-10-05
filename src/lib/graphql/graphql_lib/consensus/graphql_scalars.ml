open Graphql_basic_scalars.Utils
open Graphql_basic_scalars.Testing
open Core_kernel

module Make (Schema : Schema) = struct
  module type Json_intf =
    Json_intf_any_typ with type ('a, 'b) typ := ('a, 'b) Schema.typ

  module Slot_scalar =
    Make_scalar_using_to_string
      (Unsigned.UInt32)
      (struct
        let name = "Slot"

        let doc = "slot"
      end)
      (Schema)

  module Epoch_scalar =
    Make_scalar_using_to_string
      (Unsigned.UInt32)
      (struct
        let name = "Epoch"

        let doc = "epoch"
      end)
      (Schema)

  module VrfScalar =
    Make_scalar_using_to_string
      (Consensus_vrf.Scalar)
      (struct
        let name = "VrfScalar"

        let doc = "consensus vrf scalar"
      end)
      (Schema)

  module VrfOutputTruncated =
    Make_scalar_using_base58_check
      (Consensus_vrf.Output.Truncated)
      (struct
        let name = "VrfOutputTruncated"

        let doc = "truncated vrf output"
      end)
      (Schema)

  module BodyReference : Json_intf with type t = Consensus.Body_reference.t =
  struct
    open Consensus.Body_reference

    type nonrec t = t

    let parse json = Yojson.Basic.Util.to_string json |> of_hex_exn

    let serialize x = `String (to_hex x)

    let typ () =
      Schema.scalar "BodyReference"
        ~doc:
          "A reference to how the block header refers to the body of the block \
           as a hex-encoded string"
        ~coerce:serialize
  end
end

include Make (Schema)
module Slot = Slot_scalar
module Epoch = Epoch_scalar

module Epoch_ledger = struct
  open Mina_base.Epoch_ledger

  let typ () : ('ctx, Value.t option) Graphql_async.Schema.typ =
    let open Graphql_async in
    let open Schema in
    obj "epochLedger" ~fields:(fun _ ->
        [ field "hash"
            ~typ:
              (non_null @@ Mina_base_graphql.Graphql_scalars.LedgerHash.typ ())
            ~args:Arg.[]
            ~resolve:(fun _ { Poly.hash; _ } -> hash)
        ; field "totalCurrency"
            ~typ:(non_null @@ Currency_graphql.Graphql_scalars.Amount.typ ())
            ~args:Arg.[]
            ~resolve:(fun _ { Poly.total_currency; _ } -> total_currency)
        ] )
end

module Epoch_data = struct
  open Mina_base.Epoch_data

  let typ name =
    let open Graphql_async in
    let open Schema in
    obj name ~fields:(fun _ ->
        [ field "ledger"
            ~typ:(non_null @@ Epoch_ledger.typ ())
            ~args:Arg.[]
            ~resolve:(fun _ { Poly.ledger; _ } -> ledger)
        ; field "seed"
            ~typ:(non_null @@ Mina_base_graphql.Graphql_scalars.EpochSeed.typ ())
            ~args:Arg.[]
            ~resolve:(fun _ { Poly.seed; _ } -> seed)
        ; field "startCheckpoint"
            ~typ:(non_null @@ Mina_base_graphql.Graphql_scalars.StateHash.typ ())
            ~args:Arg.[]
            ~resolve:(fun _ { Poly.start_checkpoint; _ } -> start_checkpoint)
        ; field "lockCheckpoint" ~typ:(non_null string)
            ~args:Arg.[]
            ~resolve:(fun _ { Poly.lock_checkpoint; _ } ->
              Mina_base.State_hash.to_base58_check lock_checkpoint )
        ; field "epochLength"
            ~typ:(non_null @@ Mina_numbers_graphql.Graphql_scalars.Length.typ ())
            ~args:Arg.[]
            ~resolve:(fun _ { Poly.epoch_length; _ } -> epoch_length)
        ] )
end

module Consensus_state = struct
  open Consensus.Data.Consensus_state

  let typ () : ('ctx, Value.t option) Graphql_async.Schema.typ =
    let open Graphql_async in
    let open Signature_lib_graphql.Graphql_scalars in
    let public_key = PublicKey.typ () in
    let open Schema in
    let length = Mina_numbers_graphql.Graphql_scalars.Length.typ () in
    let amount = Currency_graphql.Graphql_scalars.Amount.typ () in
    obj "ConsensusState" ~fields:(fun _ ->
        [ field "blockchainLength" ~typ:(non_null length)
            ~doc:"Length of the blockchain at this block"
            ~deprecated:(Deprecated (Some "use blockHeight instead"))
            ~args:Arg.[]
            ~resolve:(const blockchain_length)
        ; field "blockHeight" ~typ:(non_null length)
            ~doc:"Height of the blockchain at this block"
            ~args:Arg.[]
            ~resolve:(const blockchain_length)
        ; field "epochCount" ~typ:(non_null length)
            ~args:Arg.[]
            ~resolve:(const epoch_count)
        ; field "minWindowDensity" ~typ:(non_null length)
            ~args:Arg.[]
            ~resolve:(const min_window_density)
        ; field "lastVrfOutput" ~typ:(non_null string)
            ~args:Arg.[]
            ~resolve:(fun (_ : 'ctx resolve_info) ->
              Fn.compose Consensus_vrf.Output.Truncated.to_base58_check
                last_vrf_output )
        ; field "totalCurrency"
            ~doc:"Total currency in circulation at this block"
            ~typ:(non_null amount)
            ~args:Arg.[]
            ~resolve:(const total_currency)
        ; field "stakingEpochData"
            ~typ:(non_null @@ Epoch_data.typ "StakingEpochData")
            ~args:Arg.[]
            ~resolve:(fun (_ : 'ctx resolve_info) -> staking_epoch_data)
        ; field "nextEpochData"
            ~typ:(non_null @@ Epoch_data.typ "NextEpochData")
            ~args:Arg.[]
            ~resolve:(fun (_ : 'ctx resolve_info) -> next_epoch_data)
        ; field "hasAncestorInSameCheckpointWindow" ~typ:(non_null bool)
            ~args:Arg.[]
            ~resolve:(const has_ancestor_in_same_checkpoint_window)
        ; field "slot" ~doc:"Slot in which this block was created"
            ~typ:(non_null @@ Slot.typ ())
            ~args:Arg.[]
            ~resolve:(const curr_slot)
        ; field "slotSinceGenesis"
            ~doc:"Slot since genesis (across all hard-forks)"
            ~typ:
              ( non_null
              @@ Mina_numbers_graphql.Graphql_scalars.GlobalSlotSinceGenesis.typ
                   () )
            ~args:Arg.[]
            ~resolve:(const global_slot_since_genesis)
        ; field "epoch" ~doc:"Epoch in which this block was created"
            ~typ:(non_null @@ Epoch.typ ())
            ~args:Arg.[]
            ~resolve:(const curr_epoch)
        ; field "superchargedCoinbase" ~typ:(non_null bool)
            ~doc:
              "Whether or not this coinbase was \"supercharged\", ie. created \
               by an account that has no locked tokens"
            ~args:Arg.[]
            ~resolve:(const supercharge_coinbase)
        ; field "blockStakeWinner" ~typ:(non_null public_key)
            ~doc:
              "The public key that is responsible for winning this block \
               (including delegations)"
            ~args:Arg.[]
            ~resolve:(const block_stake_winner)
        ; field "blockCreator" ~typ:(non_null public_key)
            ~doc:"The block producer public key that created this block"
            ~args:Arg.[]
            ~resolve:(const block_creator)
        ; field "coinbaseReceiever" ~typ:(non_null public_key)
            ~args:Arg.[]
            ~resolve:(const coinbase_receiver)
        ] )
end

let%test_module "Roundtrip tests" =
  ( module struct
    module Epoch = Mina_numbers.Nat.Make32 ()

    module Slot = Mina_numbers.Nat.Make32 ()

    include Make (Test_schema)

    let%test_module "Epoch" = (module Make_test (Epoch_scalar) (Epoch))

    let%test_module "Slot" =
      ( module struct
        module Slot_gen = struct
          include Slot

          let gen (constants : Consensus.Constants.t) =
            let open Quickcheck.Let_syntax in
            let epoch_length =
              constants.slots_per_epoch |> Unsigned.UInt32.to_int
            in
            Core.Int.gen_incl 0 epoch_length >>| Unsigned.UInt32.of_int

          let gen =
            Core_kernel.Quickcheck.Generator.map ~f:Slot.of_uint32
              (Consensus.Constants.for_unit_tests |> Lazy.force |> gen)
        end

        include Make_test (Slot_scalar) (Slot_gen)
      end )

    let%test_module "VrfScalar" =
      ( module struct
        module VrfScalar_gen = struct
          include Snark_params.Tick.Inner_curve.Scalar
        end

        include Make_test (VrfScalar) (VrfScalar_gen)
      end )

    let%test_module "VrfOutputTruncated" =
      ( module struct
        module VrfOutputTruncated_gen = struct
          include Consensus_vrf.Output.Truncated

          let gen = Core_kernel.Quickcheck.Generator.return dummy
        end

        include Make_test (VrfOutputTruncated) (VrfOutputTruncated_gen)
      end )

    let%test_module "BodyReference" =
      ( module struct
        module BodyReference_gen = struct
          include Consensus.Body_reference

          let gen = Blake2.gen
        end

        include Make_test (BodyReference) (BodyReference_gen)
      end )
  end )
