let verify_functions ~constraint_constants ~proof_level ~signature_kind () =
  let module T = Transaction_snark.Make (struct
    let signature_kind = signature_kind

    let constraint_constants = constraint_constants

    let proof_level = proof_level
  end) in
  let module B = Blockchain_snark.Blockchain_snark_state.Make (struct
    let tag = T.tag

    let constraint_constants = constraint_constants

    let proof_level = proof_level
  end) in
  (B.Proof.verify, T.verify)

open Async

module Make (Source : Submission.Data_source) = struct
  let verify_snark_work ~verify_transaction_snarks ~proof ~message =
    verify_transaction_snarks [ (proof, message) ]

  let verify_blockchain_snarks = Source.verify_blockchain_snarks

  let intialize_submission ?validate (src : Source.t) (sub : Source.submission)
      =
    let block_hash = Source.block_hash sub in
    if Known_blocks.is_known block_hash then ()
    else
      Known_blocks.add ?validate ~verify_blockchain_snarks ~block_hash
        (Source.load_block sub src)

  let verify ~validate (submission : Source.submission) =
    let open Async.Deferred.Result.Let_syntax in
    let block_hash = Source.block_hash submission in
    let%bind block = Known_blocks.get block_hash in
    let%bind () = Known_blocks.is_valid block_hash in
    let%map () =
      if validate then
        match%bind Deferred.return @@ Source.snark_work submission with
        | None ->
            Deferred.Result.return ()
        | Some
            Uptime_service.Proof_data.{ proof; proof_time = _; snark_work_fee }
          ->
            let message =
              Mina_base.Sok_message.create ~fee:snark_work_fee
                ~prover:(Source.submitter submission)
            in
            verify_snark_work
              ~verify_transaction_snarks:Source.verify_transaction_snarks ~proof
              ~message
      else return ()
    in
    let header = Mina_block.Stable.Latest.header block in
    let protocol_state = Mina_block.Header.protocol_state header in
    let consensus_state =
      Mina_state.Protocol_state.consensus_state protocol_state
    in
    ( Mina_state.Protocol_state.hashes protocol_state
      |> Mina_base.State_hash.State_hashes.state_hash
    , Mina_state.Protocol_state.previous_state_hash protocol_state
    , Consensus.Data.Consensus_state.blockchain_length consensus_state
    , Consensus.Data.Consensus_state.global_slot_since_genesis consensus_state
    )
end
