module Schema = Graphql_wrapper.Make(Graphql_async.Schema)
open Schema

let uint32 () = Graphql_basic_scalars.UInt32.typ ()

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
