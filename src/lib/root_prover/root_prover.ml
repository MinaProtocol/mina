open Core
open Async
open Coda_base
open Coda_state

module type Inputs_intf = sig
  include Coda_intf.Inputs_intf

  module Transition_frontier :
    Coda_intf.Transition_frontier_intf
    with type external_transition_validated := External_transition.Validated.t
     and type mostly_validated_external_transition :=
                ( [`Time_received] * Truth.true_t
                , [`Proof] * Truth.true_t
                , [`Frontier_dependencies] * Truth.true_t
                , [`Staged_ledger_diff] * Truth.false_t )
                External_transition.Validation.with_transition
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type staged_ledger := Staged_ledger.t
     and type verifier := Verifier.t
     and type 'a transaction_snark_work_statement_table :=
       'a Transaction_snark_work.Statement.Table.t
end

module Make (Inputs : Inputs_intf) :
  Coda_intf.Root_prover_intf
  with type transition_frontier := Inputs.Transition_frontier.t
   and type external_transition := Inputs.External_transition.t
   and type external_transition_with_initial_validation :=
              ( [`Time_received] * Truth.true_t
              , [`Proof] * Truth.true_t
              , [`Frontier_dependencies] * Truth.false_t
              , [`Staged_ledger_diff] * Truth.false_t )
              Inputs.External_transition.Validation.with_transition
   and type verifier := Inputs.Verifier.t = struct
  open Inputs

  let hash_transition =
    Fn.compose Protocol_state.hash External_transition.protocol_state

  let consensus_state transition =
    External_transition.(
      protocol_state transition |> Protocol_state.consensus_state)

  module Merkle_list = Merkle_list.Make (struct
    type value = External_transition.Validated.t

    type context = Transition_frontier.t

    type proof_elem = State_body_hash.t

    type hash = State_hash.t [@@deriving eq]

    let to_proof_elem external_transition =
      external_transition |> External_transition.Validated.protocol_state
      |> Protocol_state.body |> Protocol_state.Body.hash

    let get_previous ~context transition =
      let parent_hash =
        transition |> External_transition.Validated.protocol_state
        |> Protocol_state.previous_state_hash
      in
      let open Option.Let_syntax in
      let%map breadcrumb = Transition_frontier.find context parent_hash in
      With_hash.data
      @@ Transition_frontier.Breadcrumb.transition_with_hash breadcrumb

    let hash acc body_hash =
      Protocol_state.hash_abstract ~hash_body:Fn.id
        {previous_state_hash= acc; body= body_hash}
  end)

  let prove ~logger ~frontier seen_consensus_state :
      ( External_transition.t
      , State_body_hash.t List.t * External_transition.t )
      Proof_carrying_data.t
      option =
    let open Option.Let_syntax in
    let%bind () =
      Option.some_if
        ( Transition_frontier.best_tip_path_length_exn frontier
        = Transition_frontier.max_length )
        ()
    in
    let best_tip_breadcrumb = Transition_frontier.best_tip frontier in
    let best_verified_tip =
      Transition_frontier.Breadcrumb.transition_with_hash best_tip_breadcrumb
      |> With_hash.data
    in
    let best_tip =
      External_transition.Validated.forget_validation best_verified_tip
    in
    let is_tip_better =
      Consensus.Hooks.select
        ~logger:
          (Logger.extend logger
             [("selection_context", `String "Root_prover.prove")])
        ~existing:(consensus_state best_tip) ~candidate:seen_consensus_state
      = `Keep
    in
    let%bind () = Option.some_if is_tip_better () in
    let root =
      Transition_frontier.root frontier
      |> Transition_frontier.Breadcrumb.transition_with_hash |> With_hash.data
    in
    let merkle_list = Merkle_list.prove ~context:frontier best_verified_tip in
    Logger.info logger ~module_:__MODULE__ ~location:__LOC__
      ~metadata:
        [ ( "merkle_list"
          , `List (List.map ~f:State_body_hash.to_yojson merkle_list) ) ]
      "Produced a merkle list of $merkle_list" ;
    Some
      Proof_carrying_data.
        { data= root |> External_transition.Validated.forget_validation
        ; proof= (merkle_list, best_tip) }

  let check_error ~message cond =
    let open Deferred.Or_error in
    if cond then return () else error_string message

  let verify ~logger ~verifier ~observed_state
      ~peer_root:{Proof_carrying_data.data= root; proof= merkle_list, best_tip}
      =
    let open Deferred.Result.Let_syntax in
    let merkle_list_length = List.length merkle_list in
    let root_transition_with_hash =
      With_hash.of_data root ~hash_data:hash_transition
    in
    let root_hash = With_hash.hash root_transition_with_hash in
    let%bind () =
      check_error
        ~message:
          (sprintf
             !"Peer should have given a proof of length %d but got %d"
             Transition_frontier.max_length merkle_list_length)
        (Int.equal Transition_frontier.max_length merkle_list_length)
    in
    let best_tip_with_hash =
      With_hash.of_data best_tip ~hash_data:hash_transition
    in
    let best_tip_hash = With_hash.hash best_tip_with_hash in
    (* This statement might not see a peer's best_tip as the best_tip *)
    let is_before_best_tip candidate =
      Consensus.Hooks.select
        ~logger:
          (Logger.extend logger
             [("selection_context", `String "Root_prover.verify")])
        ~existing:(consensus_state best_tip) ~candidate
      = `Keep
    in
    let%bind () =
      check_error
        ~message:
          (sprintf
             !"Peer lied about it's best tip %{sexp:State_hash.t}"
             best_tip_hash)
        (is_before_best_tip observed_state)
    in
    let%bind () =
      check_error ~message:"Peer gave an invalid proof of it's root"
        (Merkle_list.verify ~init:root_hash merkle_list best_tip_hash)
    in
    let root_with_validation =
      External_transition.skip_time_received_validation
        `This_transition_was_not_received_via_gossip
        (External_transition.Validation.wrap root_transition_with_hash)
    in
    let best_tip_with_validation =
      External_transition.skip_time_received_validation
        `This_transition_was_not_received_via_gossip
        (External_transition.Validation.wrap best_tip_with_hash)
    in
    let%bind validated_root =
      Deferred.map
        (External_transition.validate_proof ~verifier root_with_validation)
        ~f:(Result.map_error ~f:(Fn.const (Error.of_string "invalid proof")))
    in
    let%map validated_best_tip =
      Deferred.map
        (External_transition.validate_proof ~verifier best_tip_with_validation)
        ~f:(Result.map_error ~f:(Fn.const (Error.of_string "invalid proof")))
    in
    (validated_root, validated_best_tip)
end
