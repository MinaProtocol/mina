open Core_kernel

module Make (Inputs : Inputs.Base.S) :
  Transition_logic_state_intf.S
  with type tip := Inputs.Tip.t
   and type consensus_local_state := Inputs.Consensus_mechanism.Local_state.t
   and type external_transition :=
              Inputs.Consensus_mechanism.External_transition.t
   and type state_hash := Inputs.State_hash.t = struct
  open Inputs
  open Consensus_mechanism
  module Ops = Tip_ops.Make (Inputs)
  include Ops

  module Transition_tree =
    Ktree.Make (struct
        type t = (External_transition.t, State_hash.t) With_hash.t
        [@@deriving compare, bin_io, sexp]
      end)
      (Security)

  module Change = struct
    type t =
      | Locked_tip of (Tip.t, State_hash.t) With_hash.t
      | Longest_branch_tip of (Tip.t, State_hash.t) With_hash.t
      | Ktree of Transition_tree.t
    [@@deriving sexp]
  end

  open Change

  (**
   *       /-----
   *      *
   *      ^\-------
   *      |      \----
   *      O          ^
   *                 |
   *                 O
   *
   *    The ktree represents the fork tree. We annotate
   *    the root and longest_branch with Tip.t's.
   *)
  type t =
    { locked_tip: (Tip.t, State_hash.t) With_hash.t
    ; longest_branch_tip: (Tip.t, State_hash.t) With_hash.t
    ; ktree: Transition_tree.t option
    ; consensus_local_state: Local_state.t
    (* TODO: This impl assumes we have the original Ouroboros assumption. In
       order to work with the Praos assumption we'll need to keep a linked
       list as well at the prefix of size (#blocks possible out of order)
     *)
    }
  [@@deriving fields]

  let apply t = function
    | Locked_tip locked_tip ->
        let consensus_state_of_tip tip =
          Tip.protocol_state tip |> Protocol_state.consensus_state
        in
        let old_tip = t.locked_tip.data in
        let new_tip = locked_tip.data in
        let snarked_ledger_hash =
          Tip.protocol_state old_tip |> Protocol_state.blockchain_state
          |> Blockchain_state.ledger_hash
        in
        lock_transition
          (consensus_state_of_tip old_tip)
          (consensus_state_of_tip new_tip)
          ~snarked_ledger:(fun () ->
            Ledger_builder.snarked_ledger
              (Tip.ledger_builder new_tip)
              ~snarked_ledger_hash )
          ~local_state:t.consensus_local_state ;
        {t with locked_tip}
    | Longest_branch_tip h -> {t with longest_branch_tip= h}
    | Ktree k -> {t with ktree= Some k}

  (* Invariant: state is consistent after change applications *)
  let assert_state_valid t =
    Debug_assert.debug_assert (fun () ->
        match t.ktree with
        | None -> ()
        | Some ktree -> (
          match Transition_tree.longest_path ktree with
          | [] -> failwith "Impossible, paths are non-empty"
          | [x] ->
              assert_materialization_of t.locked_tip x ;
              assert_materialization_of t.longest_branch_tip x
          | x :: y :: rest ->
              let last = List.last_exn (y :: rest) in
              assert_materialization_of t.locked_tip x ;
              assert_materialization_of t.longest_branch_tip last ) )

  let apply_all t changes =
    assert_state_valid t ;
    let t' = List.fold changes ~init:t ~f:apply in
    assert_state_valid t' ; t'

  let create ~consensus_local_state genesis_heavy =
    { locked_tip= genesis_heavy
    ; longest_branch_tip= genesis_heavy
    ; ktree= None
    ; consensus_local_state }
end
