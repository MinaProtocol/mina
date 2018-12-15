open Core_kernel
open Async_kernel

module Make (Inputs : Inputs.Base.S) = struct
  open Inputs
  open Consensus_mechanism

  let assert_materialization_of {With_hash.data= tip; hash= tip_state_hash}
      {With_hash.data= transition; hash= transition_state_hash} =
    [%test_result: State_hash.t]
      ~message:
        "Protocol state in tip should be the target state of the transition"
      ~expect:transition_state_hash tip_state_hash ;
    [%test_result: Staged_ledger_hash.t]
      ~message:
        (Printf.sprintf
           !"Staged_ledger_hash inside protocol state inconsistent with \
             materialized staged_ledger's hash for transition: %{sexp: \
             External_transition.Verified.t}"
           transition)
      ~expect:
        ( External_transition.Verified.protocol_state transition
        |> Protocol_state.blockchain_state
        |> Blockchain_state.staged_ledger_hash )
      (Staged_ledger.hash tip.Tip.staged_ledger)

  let transition_unchecked t
      ( {With_hash.data= transition; hash= transition_state_hash} as
      transition_with_hash ) logger =
    let%map () =
      let open Deferred.Let_syntax in
      match
        Staged_ledger.apply t.Tip.staged_ledger
          (External_transition.Verified.staged_ledger_diff transition)
          ~logger
      with
      | Ok (_, `Ledger_proof None, _) -> return ()
      | Ok (_, `Ledger_proof (Some _), _) -> return ()
      (* We've already verified that all the patches can be
        applied successfully before we added to the ktree, so we
        can force-unwrap here *)
      | Error e ->
          failwithf
            "We should have already verified patches can be applied: %s"
            (Error.to_string_hum e) ()
    in
    let tip' =
      { t with
        state= External_transition.Verified.protocol_state transition
      ; proof= External_transition.Verified.protocol_state_proof transition }
    in
    let res = {With_hash.data= tip'; hash= transition_state_hash} in
    assert_materialization_of res transition_with_hash ;
    res

  let is_parent_of ~child:{With_hash.data= child; hash= _}
      ~parent:{With_hash.data= _; hash= parent_hash} =
    State_hash.equal parent_hash
      ( External_transition.Verified.protocol_state child
      |> Protocol_state.previous_state_hash )

  let is_materialization_of {With_hash.data= _; hash= tip_hash}
      {With_hash.data= _; hash= transition_hash} =
    State_hash.equal transition_hash tip_hash
end
