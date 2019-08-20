open Core_kernel
open Coda_base
open Coda_state
open Async_kernel

module type Inputs_intf = sig
  include Transition_frontier.Inputs_intf

  module Transition_frontier :
    Coda_intf.Transition_frontier_intf
    with type external_transition_validated := External_transition.Validated.t
     and type mostly_validated_external_transition :=
                ( [`Time_received] * unit Truth.true_t
                , [`Proof] * unit Truth.true_t
                , [`Delta_transition_chain]
                  * State_hash.t Non_empty_list.t Truth.true_t
                , [`Frontier_dependencies] * unit Truth.true_t
                , [`Staged_ledger_diff] * unit Truth.false_t )
                External_transition.Validation.with_transition
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type staged_ledger := Staged_ledger.t
     and type verifier := Verifier.t
end

module Make (Inputs : Inputs_intf) :
  Coda_intf.Best_tip_prover_intf
  with type transition_frontier := Inputs.Transition_frontier.t
   and type external_transition := Inputs.External_transition.t
   and type external_transition_with_initial_validation :=
              Inputs.External_transition.with_initial_validation
   and type verifier := Inputs.Verifier.t = struct
  open Inputs

  module Merkle_list_prover = Merkle_list_prover.Make (struct
    type value = External_transition.Validated.t

    type context = Transition_frontier.t

    type proof_elem = State_body_hash.t

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
  end)

  module Merkle_list_verifier = Merkle_list_verifier.Make (struct
    type hash = State_hash.t [@@deriving eq]

    type proof_elem = State_body_hash.t

    let hash acc body_hash =
      Protocol_state.hash_abstract ~hash_body:Fn.id
        {previous_state_hash= acc; body= body_hash}
  end)

  let prove ~logger frontier =
    let open Option.Let_syntax in
    let%map () =
      Option.some_if
        (Transition_frontier.best_tip_path_length_exn frontier = max_length)
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
    let root =
      Transition_frontier.root frontier
      |> Transition_frontier.Breadcrumb.transition_with_hash |> With_hash.data
    in
    let _, merkle_list =
      Merkle_list_prover.prove ~context:frontier best_verified_tip
    in
    Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
      ~metadata:
        [ ( "merkle_list"
          , `List (List.map ~f:State_body_hash.to_yojson merkle_list) ) ]
      "Best tip prover produced a merkle list of $merkle_list" ;
    Proof_carrying_data.
      { data= best_tip
      ; proof=
          (merkle_list, root |> External_transition.Validated.forget_validation)
      }

  let validate_proof ~verifier transition_with_hash =
    let open Deferred.Result.Monad_infix in
    External_transition.(
      Validation.wrap transition_with_hash
      |> skip_time_received_validation
           `This_transition_was_not_received_via_gossip
      |> validate_proof ~verifier
      >>= Fn.compose Deferred.Result.return
            (skip_delta_transition_chain_validation
               `This_transition_was_not_received_via_gossip)
      |> Deferred.map
           ~f:
             (Result.map_error ~f:(Fn.const (Error.of_string "invalid proof"))))

  let verify ~verifier
      {Proof_carrying_data.data= best_tip; proof= merkle_list, root} =
    let open Deferred.Or_error.Let_syntax in
    let merkle_list_length = List.length merkle_list in
    let%bind () =
      Deferred.return
        (Result.ok_if_true
           ~error:
             ( Error.of_string
             @@ sprintf
                  !"Peer should have given a proof of length %d but got %d"
                  max_length merkle_list_length )
           (Int.equal max_length merkle_list_length))
    in
    let best_tip_with_hash =
      With_hash.of_data best_tip ~hash_data:External_transition.state_hash
    in
    let root_transition_with_hash =
      With_hash.of_data root ~hash_data:External_transition.state_hash
    in
    let%bind (_ : State_hash.t Non_empty_list.t) =
      Deferred.return
        (Result.of_option
           (Merkle_list_verifier.verify ~init:root_transition_with_hash.hash
              merkle_list best_tip_with_hash.hash)
           ~error:
             (Error.of_string
                "Peer should have given a valid merkle list proof for their \
                 best tip"))
    in
    let%map root, best_tip =
      Deferred.Or_error.both
        (validate_proof ~verifier root_transition_with_hash)
        (validate_proof ~verifier best_tip_with_hash)
    in
    (`Root root, `Best_tip best_tip)
end

include Make (struct
  include Transition_frontier.Inputs
  module Transition_frontier = Transition_frontier
end)
