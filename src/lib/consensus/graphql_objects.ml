module Schema = Graphql_wrapper.Make(Graphql_async.Schema)
open Schema

(* let uint32 () = Graphql_basic_scalars.UInt32.typ () *)

  (* let consensus_time = *)
  (*   let module C = Consensus.Data.Consensus_time in *)
  (*   obj "ConsensusTime" ~fields:(fun _ -> *)
  (*       [ field "epoch" ~typ:(non_null uint32) *)
  (*           ~args:Arg.[] *)
  (*           ~resolve:(fun _ global_slot -> C.epoch global_slot) *)
  (*       ; field "slot" ~typ:(non_null uint32) *)
  (*           ~args:Arg.[] *)
  (*           ~resolve:(fun _ global_slot -> C.slot global_slot) *)
  (*       ; field "globalSlot" ~typ:(non_null uint32) *)
  (*           ~args:Arg.[] *)
  (*           ~resolve:(fun _ (global_slot : Consensus.Data.Consensus_time.t) -> *)
  (*             C.to_uint32 global_slot ) *)
  (*       ; field "startTime" ~typ:(non_null string) *)
  (*           ~args:Arg.[] *)
  (*           ~resolve:(fun { ctx = coda; _ } global_slot -> *)
  (*             let constants = *)
  (*               (Mina_lib.config coda).precomputed_values.consensus_constants *)
  (*             in *)
  (*             Block_time.to_string @@ C.start_time ~constants global_slot ) *)
  (*       ; field "endTime" ~typ:(non_null string) *)
  (*           ~args:Arg.[] *)
  (*           ~resolve:(fun { ctx = coda; _ } global_slot -> *)
  (*             let constants = *)
  (*               (Mina_lib.config coda).precomputed_values.consensus_constants *)
  (*             in *)
  (*             Block_time.to_string @@ C.end_time ~constants global_slot ) *)
  (*       ] ) *)


let nn_time a x =
    Graphql_basic_scalars.Reflection.reflect
      (fun t -> Block_time.to_time t |> Core_kernel.Time.to_string)
      ~typ:(non_null string) a x

include struct
    open Graphql_basic_scalars.Shorthand
    let consensus_configuration () : (_, Proof_of_stake.Configuration.t option) typ =
      obj "ConsensusConfiguration" ~fields:(fun _ ->
          List.rev
          @@ Proof_of_stake.Configuration.Fields.fold ~init:[] ~delta:nn_int
               ~k:nn_int ~slots_per_epoch:nn_int ~slot_duration:nn_int
               ~epoch_duration:nn_int ~acceptable_network_delay:nn_int
               ~genesis_state_timestamp:nn_time )
  end

let vrf_message () : ('context, Consensus_vrf.Layout.Message.t option) typ =
  let open Consensus_vrf.Layout.Message in
  obj "VrfMessage" ~doc:"The inputs to a vrf evaluation" ~fields:(fun _ ->
      [ field "globalSlot" ~typ:(non_null @@ Graphql_basic_scalars.UInt32.typ ())
          ~args:Arg.[]
          ~resolve:(fun _ { global_slot; _ } -> global_slot)
      ; field "epochSeed" ~typ:(non_null @@ Mina_base_unix.Graphql_scalars.EpochSeed.typ ())
          ~args:Arg.[]
          ~resolve:(fun _ { epoch_seed; _ } -> epoch_seed)
      ; field "delegatorIndex"
          ~doc:"Position in the ledger of the delegator's account"
          ~typ:(non_null int)
          ~args:Arg.[]
          ~resolve:(fun _ { delegator_index; _ } -> delegator_index)
    ] )

let vrf_threshold () =
  let uint64 = Graphql_basic_scalars.UInt64.typ () in
  obj "VrfThreshold"
    ~doc:
    "The amount of stake delegated, used to determine the threshold for a \
     vrf evaluation winning a slot" ~fields:(fun _ ->
      [ field "delegatedStake"
          ~doc:
          "The amount of stake delegated to the vrf evaluator by the \
           delegating account. This should match the amount in the epoch's \
           staking ledger, which may be different to the amount in the \
           current ledger." ~args:[] ~typ:(non_null uint64)
          ~resolve:(fun
              _
              { Consensus_vrf.Layout.Threshold.delegated_stake; _ }
            -> Currency.Balance.to_uint64 delegated_stake )
      ; field "totalStake"
          ~doc:
          "The total amount of stake across all accounts in the epoch's \
           staking ledger." ~args:[] ~typ:(non_null uint64)
          ~resolve:(fun _ { Consensus_vrf.Layout.Threshold.total_stake; _ } ->
            Currency.Amount.to_uint64 total_stake )
    ] )
