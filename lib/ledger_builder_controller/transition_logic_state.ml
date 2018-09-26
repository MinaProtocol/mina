open Core_kernel
open Async_kernel

module type S = sig
  type external_transition

  type tip

  type state_hash

  type work

  module Transition_tree :
    Coda.Ktree_intf
    with type elem := (external_transition, state_hash) With_hash.t
     and type 'a rose := 'a Ktree.Rose.t

  type t

  val locked_tip : t -> (tip, state_hash) With_hash.t

  val longest_branch_tip : t -> (tip, state_hash) With_hash.t

  val ktree : t -> Transition_tree.t option

  val assert_state_valid : t -> unit

  module Change : sig
    type t =
      | Locked_tip of (tip, state_hash) With_hash.t
      | Longest_branch_tip of (tip, state_hash) With_hash.t
      | Ktree of Transition_tree.t
    [@@deriving sexp]
  end

  val apply_all : relevant_work_changes_writer: (work, int) List.Assoc.t Linear_pipe.Writer.t -> t -> Change.t list -> t Deferred.t
  (** Invariant: Changes must be applied to atomically result in a consistent state *)

  val create : (tip, state_hash) With_hash.t -> t
end

module Make (Security : sig
  val max_depth : [`Infinity | `Finite of int]
end) (Ledger_proof : sig
  type t
end) (Work : sig
  type t

  module Table : Hashtbl.S with type key := t
end) (Ledger_builder : sig
  module Super_transaction_with_witness : sig
    type t

    val statement : t -> Work.t
  end

  type t

  val scan_state : t -> (Ledger_proof.t * Work.t, Super_transaction_with_witness.t) Parallel_scan.State.t
end) (State_hash : sig
  type t [@@deriving compare, sexp, bin_io]

  val zero : t
end) (Transition : sig
  type t [@@deriving compare, sexp, bin_io]

  val genesis : t
end) (Tip : sig
  type t [@@deriving sexp]

  val ledger_builder : t -> Ledger_builder.t

  val assert_materialization_of :
       (t, State_hash.t) With_hash.t
    -> (Transition.t, State_hash.t) With_hash.t
    -> unit
end) :
  S
  with type tip := Tip.t
   and type external_transition := Transition.t
   and type state_hash := State_hash.t
   and type work := Work.t =
struct
  module Transition_tree =
    Ktree.Make (struct
        type t = (Transition.t, State_hash.t) With_hash.t
        [@@deriving compare, bin_io, sexp]

        let empty =
          let open With_hash in
          { data= Transition.genesis
          ; hash= State_hash.zero }
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
    (* TODO: This impl assumes we have the original Ouroboros assumption. In
       order to work with the Praos assumption we'll need to keep a linked
       list as well at the prefix of size (#blocks possible out of order)
     *)
    }
  [@@deriving fields]

  let apply ~relevant_work_changes_writer t = function
    | Locked_tip locked_tip -> Deferred.return {t with locked_tip}
    | Longest_branch_tip longest_branch_tip ->
        let work_of_tip tip =
          let work = Work.Table.create () in
          let incr_work = Hashtbl.incr ~remove_if_zero:true work in
          Tip.ledger_builder tip
          |> Ledger_builder.scan_state
          |> (fun state -> Parallel_scan.next_jobs ~state)
          |> List.iter ~f:(function
            | Merge ((_, a), (_, b)) ->
                incr_work a;
                incr_work b
            | Base a ->
                incr_work (Ledger_builder.Super_transaction_with_witness.statement a));
          work
        in
        let diff_hashtbl a b =
          let r = Work.Table.create () in
          Hashtbl.iteri a ~f:(fun ~key:k ~data:va ->
            let vb = Option.value ~default:0 (Hashtbl.find b k) in
            let diff = va - vb in
            (if diff <> 0 then Hashtbl.set r ~key:k ~data:diff));
          r
        in
        let old_work = work_of_tip t.longest_branch_tip.data in
        let new_work = work_of_tip longest_branch_tip.data in
        let work_changes = diff_hashtbl new_work old_work in
        let%map () =
          Linear_pipe.write
            relevant_work_changes_writer
            (Hashtbl.to_alist work_changes)
        in
        {t with longest_branch_tip}
    | Ktree k -> Deferred.return {t with ktree= Some k}

  (* Invariant: state is consistent after change applications *)
  let assert_state_valid t =
    Debug_assert.debug_assert (fun () ->
        match t.ktree with
        | None -> ()
        | Some ktree ->
          match Transition_tree.longest_path ktree with
          | [] -> failwith "Impossible, paths are non-empty"
          | [x] ->
              Tip.assert_materialization_of t.locked_tip x ;
              Tip.assert_materialization_of t.longest_branch_tip x
          | x :: y :: rest ->
              let last = List.last_exn (y :: rest) in
              Tip.assert_materialization_of t.locked_tip x ;
              Tip.assert_materialization_of t.longest_branch_tip last )

  let apply_all ~relevant_work_changes_writer t changes =
    assert_state_valid t ;
    let%map t' = Deferred.List.fold changes ~init:t ~f:(apply ~relevant_work_changes_writer) in
    assert_state_valid t' ;
    t'

  let create genesis_heavy =
    {locked_tip= genesis_heavy; longest_branch_tip= genesis_heavy; ktree= None}
end
