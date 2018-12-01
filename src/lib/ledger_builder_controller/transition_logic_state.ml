open Core

module Make (Inputs : Inputs.Base.S) :
  Transition_logic_state_intf.S
  with type tip := Inputs.Tip.t
   and type consensus_local_state := Inputs.Consensus_mechanism.Local_state.t
   and type external_transition := Inputs.External_transition.t
   and type public_key_compressed := Inputs.Public_key.Compressed.t
   and type state_hash := Inputs.State_hash.t = struct
  open Inputs
  open Consensus_mechanism
  module Ops = Tip_ops.Make (Inputs)
  include Ops

  module Transition = struct
    type t = (External_transition.t, State_hash.t) With_hash.t
    [@@deriving compare, bin_io, sexp]

    open With_hash

    let equal {hash= a; _} {hash= b; _} = State_hash.equal a b

    let hash {hash; _} = String.hash (State_hash.to_bytes hash)

    let hash_fold_t state {hash; _} =
      String.hash_fold_t state (State_hash.to_bytes hash)

    let id {hash; _} =
      "\"" ^ Base64.encode_string (State_hash.to_bytes hash) ^ "\""

    let to_string_record t =
      Printf.sprintf "{%s|%s}"
        (Base64.encode_string (State_hash.to_bytes t.hash))
        (Protocol_state.to_string_record
           (External_transition.protocol_state t.data))
  end

  module Transition_tree = Ktree.Make (Transition) (Security)

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
    ; proposer_public_key: Public_key.Compressed.t option
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
        lock_transition ?proposer_public_key:t.proposer_public_key
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

  let apply_all t changes ~logger =
    assert_state_valid t ;
    let t' = List.fold changes ~init:t ~f:apply in
    try assert_state_valid t' ; t' with exn ->
      Logger.error logger
        "fatal exception while applying changes to transition logic -- locked \
         tip state hash: %s"
        (Base64.encode_string (State_hash.to_bytes t'.locked_tip.hash)) ;
      Option.iter t'.ktree ~f:(fun ktree ->
          let filename, _ = Unix.mkstemp "lbc-graph" in
          Out_channel.with_file filename ~f:(fun channel ->
              Transition_tree.Graph.output_graph channel
                (Transition_tree.to_graph ktree) ) ;
          Logger.info logger "dot graph dumped to %s" filename ) ;
      raise exn

  let create ?proposer_public_key ~consensus_local_state genesis_heavy =
    { locked_tip= genesis_heavy
    ; longest_branch_tip= genesis_heavy
    ; ktree= None
    ; proposer_public_key
    ; consensus_local_state }
end
