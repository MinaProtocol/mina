open Core
open Async
open Coda_base
open Coda_state

module type Inputs_intf = sig
  include Transition_frontier.Inputs_intf

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
end

module Make (Inputs : Inputs_intf) = struct
  open Inputs

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
      let%map breadcrumb =
        Option.merge
          (Transition_frontier.find context parent_hash)
          (Transition_frontier.find_in_root_history context parent_hash)
          ~f:Fn.const
      in
      With_hash.data
      @@ Transition_frontier.Breadcrumb.transition_with_hash breadcrumb

    let hash previous_state_hash state_body_hash =
      Protocol_state.hash_abstract ~hash_body:Fn.id
        {previous_state_hash; body= state_body_hash}
  end)

  let prove ~logger ~frontier state_hash :
      (External_transition.t, State_body_hash.t List.t) Proof_carrying_data.t
      Option.t =
    let open Option.Let_syntax in
    let%bind requested_breadcrumb =
      Option.merge
        (Transition_frontier.find frontier state_hash)
        (Transition_frontier.find_in_root_history frontier state_hash)
        ~f:Fn.const
    in
    let requested_transition =
      Transition_frontier.Breadcrumb.transition_with_hash requested_breadcrumb
      |> With_hash.data |> External_transition.Validated.forget_validation
    in
    let oldest_breadcrumb = Transition_frontier.oldest_breadcrumb frontier in
    ()
end
