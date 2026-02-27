open Core
open Async
open Signature_lib

let find_next_winning_slot ~context:(module Context : Consensus.Intf.CONTEXT)
    ~keypair ~start_slot ~epoch_data_for_vrf ~ledger_snapshot =
  let public_key_compressed = Public_key.compress keypair.Keypair.public_key in
  let logger = Context.logger in
  let { Consensus.Data.Epoch_data_for_vrf.epoch_ledger
      ; epoch_seed
      ; epoch = _
      ; global_slot = epoch_start_hf
      ; global_slot_since_genesis = epoch_start
      ; delegatee_table
      } =
    epoch_data_for_vrf
  in
  let slots_per_epoch =
    Mina_numbers.Length.to_int Context.consensus_constants.slots_per_epoch
  in
  let epoch_end_slot = ((start_slot / slots_per_epoch) + 1) * slots_per_epoch in
  Deferred.repeat_until_finished start_slot
  @@ fun current_slot ->
  if current_slot >= epoch_end_slot then return (`Finished None)
  else
    let global_slot =
      Mina_numbers.Global_slot_since_hard_fork.of_int current_slot
    in
    match%map
      Consensus.Data.Vrf.check
        ~context:(module Context)
        ~global_slot ~seed:epoch_seed
        ~get_delegators:(Public_key.Compressed.Table.find delegatee_table)
        ~producer_private_key:keypair.private_key
        ~producer_public_key:public_key_compressed
        ~total_stake:epoch_ledger.total_currency
      |> Interruptible.force
    with
    | Error _ ->
        [%log fatal] "VRF check failed" ;
        failwith "VRF check failed"
    | Ok None ->
        `Repeat (current_slot + 1)
    | Ok
        (Some
          (`Vrf_eval _vrf_eval, `Vrf_output vrf_result, `Delegator delegator) )
      ->
        [%log info] "Found winning slot at global slot $slot"
          ~metadata:[ ("slot", `Int current_slot) ] ;
        let slot_won =
          { Consensus.Data.Slot_won.delegator
          ; producer = keypair
          ; global_slot
          ; global_slot_since_genesis =
              Mina_numbers.Global_slot_since_genesis.add epoch_start
                ( Mina_numbers.Global_slot_since_hard_fork.diff global_slot
                    epoch_start_hf
                |> Option.value_exn ~message:"failed to diff global slots" )
          ; vrf_result
          }
        in
        `Finished (Some ((slot_won, ledger_snapshot), current_slot + 1))
