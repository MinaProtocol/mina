open Core_kernel
open Async_kernel

module Make (Inputs : Inputs.Base.S) = struct
  open Inputs
  open Consensus_mechanism

  let assert_materialization_of {With_hash.data= t; hash= tip_state_hash}
      {With_hash.data= transition; hash= transition_state_hash} =
    [%test_result: State_hash.t]
      ~message:
        "Protocol state in tip should be the target state of the transition"
      ~expect:transition_state_hash tip_state_hash ;
    [%test_result: Ledger_builder_hash.t]
      ~message:
        (Printf.sprintf
           !"Ledger_builder_hash inside protocol state inconsistent with \
             materialized ledger_builder's hash for transition: %{sexp: \
             External_transition.t}"
           transition)
      ~expect:
        ( External_transition.protocol_state transition
        |> Protocol_state.blockchain_state
        |> Blockchain_state.ledger_builder_hash )
      (Ledger_builder.hash t.Tip.ledger_builder)

  let transition_unchecked t
      ( {With_hash.data= transition; hash= transition_state_hash} as
      transition_with_hash ) logger =
    let%map () =
      let open Deferred.Let_syntax in
      match%map
        Ledger_builder.apply t.Tip.ledger_builder
          (External_transition.ledger_builder_diff transition)
          ~logger
      with
      | Ok None -> ()
      | Ok (Some _) -> ()
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
        Tip.protocol_state= External_transition.protocol_state transition
      ; proof= External_transition.protocol_state_proof transition }
    in
    let res = {With_hash.data= tip'; hash= transition_state_hash} in
    assert_materialization_of res transition_with_hash ;
    res

  let is_parent_of ~child:{With_hash.data= child; hash= _}
      ~parent:{With_hash.data= _; hash= parent_hash} =
    State_hash.equal parent_hash
      ( External_transition.protocol_state child
      |> Protocol_state.previous_state_hash )

  let is_materialization_of {With_hash.data= _; hash= tip_hash}
      {With_hash.data= _; hash= transition_hash} =
    State_hash.equal transition_hash tip_hash
end
