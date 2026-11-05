open Core
open Async
open Cache_lib
open Mina_base
open Network_peer
open Mina_numbers

module Attempt_history = struct
  module Attempt = struct
    type reason = [ `Download | `Initial_validate | `Verify | `Build_breadcrumb ]
    [@@deriving yojson]

    type t = { failure_reason : reason } [@@deriving yojson]
  end

  type t = Attempt.t Peer.Map.t

  let to_yojson (t : t) =
    `Assoc
      (List.map (Map.to_alist t) ~f:(fun (peer, a) ->
           (Peer.to_multiaddr_string peer, Attempt.to_yojson a) ) )

  let empty : t = Peer.Map.empty
end

open Frontier_base

module Downloader_job = struct
  type t =
    ( State_hash.t * Length.t
    , Attempt_history.Attempt.t
    , Mina_block.t )
    Downloader.Job.t

  let to_yojson (t : t) : Yojson.Safe.t =
    let h, l = t.key in
    `Assoc
      [ ("hash", State_hash.to_yojson h)
      ; ("length", Length.to_yojson l)
      ; ("attempts", Attempt_history.to_yojson t.attempts)
      ]

  let result (t : t) = Ivar.read t.res
end

module Node = struct
  module State = struct
    type t =
      | Finished
      | Failed
      | To_download of Downloader_job.t
      | To_initial_validate of Mina_block.t Envelope.Incoming.t
      | To_verify of
          ( Mina_block.initial_valid_block Envelope.Incoming.t
          , State_hash.t )
          Cached.t
      | Wait_for_parent of
          ( Mina_block.almost_valid_block Envelope.Incoming.t
          , State_hash.t )
          Cached.t
      | To_build_breadcrumb of
          [ `Parent of State_hash.t ]
          * ( Mina_block.almost_valid_block Envelope.Incoming.t
            , State_hash.t )
            Cached.t
      (* TODO: Name this to Initial_root *)
      | Root of Breadcrumb.t Ivar.t

    module Enum = struct
      module T = struct
        type t =
          | Finished
          | Failed
          | To_download
          | To_initial_validate
          | To_verify
          | Wait_for_parent
          | To_build_breadcrumb
          | Root
        [@@deriving sexp, hash, equal, compare, yojson, bin_io_unversioned]
      end

      include T
      include Hashable.Make (T)
    end

    let enum : t -> Enum.t = function
      | To_download _ ->
          To_download
      | To_initial_validate _ ->
          To_initial_validate
      | To_verify _ ->
          To_verify
      | Wait_for_parent _ ->
          Wait_for_parent
      | To_build_breadcrumb _ ->
          To_build_breadcrumb
      | Root _ ->
          Root
      | Finished ->
          Finished
      | Failed ->
          Failed
  end

  type t =
    { mutable state : State.t
    ; mutable attempts : Attempt_history.t
    ; state_hash : State_hash.t
    ; blockchain_length : Length.t
    ; parent : State_hash.t
    ; result : ([ `Added_to_frontier ], Attempt_history.t) Result.t Ivar.t
    }

  let trace_state_change ~logger t = function
    | State.Finished | State.Root _ ->
        Internal_tracing.with_state_hash t.state_hash
        @@ fun () -> [%log internal] "Catchup_job_finished"
    | State.Failed ->
        Internal_tracing.with_state_hash t.state_hash
        @@ fun () -> [%log internal] "Failure"
    | State.To_download _ ->
        Internal_tracing.with_state_hash t.state_hash
        @@ fun () -> [%log internal] "To_download"
    | State.To_initial_validate _ ->
        Internal_tracing.with_state_hash t.state_hash
        @@ fun () -> [%log internal] "To_initial_validate"
    | State.To_verify _ ->
        Internal_tracing.with_state_hash t.state_hash
        @@ fun () -> [%log internal] "To_verify"
    | State.Wait_for_parent _ ->
        Internal_tracing.with_state_hash t.state_hash
        @@ fun () -> [%log internal] "Wait_for_parent"
    | State.To_build_breadcrumb _ ->
        Internal_tracing.with_state_hash t.state_hash
        @@ fun () -> [%log internal] "To_build_breadcrumb"

  let set_state t s =
    trace_state_change ~logger:(Logger.null ()) t s ;
    t.state <- s
end

let add_state states (node : Node.t) =
  Hashtbl.update states (Node.State.enum node.state) ~f:(function
    | None ->
        State_hash.Set.singleton node.state_hash
    | Some hashes ->
        State_hash.Set.add hashes node.state_hash )

let remove_state states (node : Node.t) =
  Hashtbl.update states (Node.State.enum node.state) ~f:(function
    | None ->
        State_hash.Set.empty
    | Some hashes ->
        State_hash.Set.remove hashes node.state_hash )

(** How the catchup tree gives up the block a removed node holds. *)
type release = { release : 'a. ('a, State_hash.t) Cached.t -> unit }

(* Invariant: The length of the path from each best tip to its oldest
   ancestor is at most k *)
type t =
  { nodes : Node.t State_hash.Table.t
  ; states : State_hash.Set.t Node.State.Enum.Table.t
  ; logger : Logger.t
  ; release : release
  }

(* mutable root: Node.t ; *)
(*     ; mutable target: State_hash.t Envelope.Incoming.t (* So that we know who to punish if the process fails *) *)

let tear_down { nodes; states; _ } =
  Hashtbl.iter nodes ~f:(fun x ->
      match x.state with
      | Root _ | Failed | Finished ->
          ()
      | Wait_for_parent _
      | To_download _
      | To_initial_validate _
      | To_verify _
      | To_build_breadcrumb _ ->
          Ivar.fill_if_empty x.result (Error x.attempts) ) ;
  Hashtbl.clear nodes ;
  Hashtbl.clear states

let set_state t (node : Node.t) s =
  remove_state t.states node ; Node.set_state node s ; add_state t.states node

let finish ~is_error t (node : Node.t) =
  let s, r =
    if is_error then (Node.State.Failed, Error node.attempts)
    else (Finished, Ok `Added_to_frontier)
  in
  set_state t node s ;
  Ivar.fill_if_empty node.result r

let to_yojson =
  let module T = struct
    type t = (Node.State.Enum.t * (int * State_hash.t list)) list
    [@@deriving to_yojson]
  end in
  fun (t : t) ->
    T.to_yojson
    @@ List.map (Hashtbl.to_alist t.states) ~f:(fun (state, hashes) ->
           (state, (State_hash.Set.length hashes, State_hash.Set.to_list hashes)) )

type job_states =
  { finished : int
  ; failed : int
  ; to_download : int
  ; to_initial_validate : int
  ; wait_for_parent : int
  ; to_verify : int
  ; to_build_breadcrumb : int
  }
[@@deriving to_yojson]

let to_node_status_report (t : t) =
  let init =
    { finished = 0
    ; failed = 0
    ; to_download = 0
    ; to_initial_validate = 0
    ; to_verify = 0
    ; wait_for_parent = 0
    ; to_build_breadcrumb = 0
    }
  in
  Hashtbl.fold t.states ~init ~f:(fun ~key ~data acc ->
      let n = Set.length data in
      match key with
      | Finished ->
          { acc with finished = n }
      | Failed ->
          { acc with failed = n }
      | To_download ->
          { acc with to_download = n }
      | To_initial_validate ->
          { acc with to_initial_validate = n }
      | To_verify ->
          { acc with to_verify = n }
      | Wait_for_parent ->
          { acc with wait_for_parent = n }
      | To_build_breadcrumb ->
          { acc with to_build_breadcrumb = n }
      | Root ->
          acc )

let max_catchup_chain_length (t : t) =
  (* Find the longest directed path *)
  let lengths = State_hash.Table.create () in
  let rec longest_starting_at (node : Node.t) =
    match Hashtbl.find lengths node.state_hash with
    | Some n ->
        n
    | None ->
        let n =
          match node.state with
          | Root _ | Finished ->
              0
          | Failed
          | Wait_for_parent _
          | To_download _
          | To_initial_validate _
          | To_verify _
          | To_build_breadcrumb _ -> (
              match Hashtbl.find t.nodes node.parent with
              | None ->
                  1
              | Some parent ->
                  1 + longest_starting_at parent )
        in
        Hashtbl.set lengths ~key:node.state_hash ~data:n ;
        n
  in
  Hashtbl.fold t.nodes ~init:0 ~f:(fun ~key:_ ~data acc ->
      Int.max acc (longest_starting_at data) )

(** Remove the node for a block the frontier has added, if there is one: the
    block is no longer being caught up. The nodes waiting for it see it added.
    The block itself is not released, because whoever added it owns it. Blocks
    without a node are not being caught up, and the tree does not track them. *)
let block_added (t : t) h =
  Option.iter (Hashtbl.find t.nodes h) ~f:(fun node ->
      (* TODO: Cancel the node's download job, if it has one. *)
      Ivar.fill_if_empty node.result (Ok `Added_to_frontier) ;
      Hashtbl.remove t.nodes h ;
      remove_state t.states node )

let remove_node' t (node : Node.t) =
  Hashtbl.remove t.nodes node.state_hash ;
  remove_state t.states node ;
  Ivar.fill_if_empty node.result (Error node.attempts) ;
  match node.state with
  | Root _ | Failed | Finished ->
      ()
  | Wait_for_parent c ->
      if not (Cached.was_consumed c) then t.release.release c
  | To_download _job ->
      (* TODO: Cancel job somehow *)
      ()
  | To_initial_validate _ ->
      ()
  | To_verify c ->
      t.release.release c
  | To_build_breadcrumb (_parent, c) ->
      t.release.release c

let remove_node t h =
  match Hashtbl.find t.nodes h with
  | None ->
      ()
  | Some node ->
      remove_node' t node

(** Of the nodes with the given hashes and parents, those to end because the
    root has moved to [new_root] and the blocks [left] have left the frontier:
    the nodes for those blocks, and every node descending from one other than
    through the new root. *)
let discarded ~(parents : (State_hash.t * State_hash.t) list) ~new_root
    ~(left : State_hash.t list) =
  let parent = State_hash.Table.of_alist_exn parents in
  let left = State_hash.Hash_set.of_list left in
  let memo = State_hash.Table.create () in
  let rec discarded hash =
    (not (State_hash.equal hash new_root))
    && ( Hash_set.mem left hash
       || Hashtbl.find_or_add memo hash ~default:(fun () ->
              Option.value_map (Hashtbl.find parent hash) ~default:false
                ~f:discarded ) )
  in
  List.filter_map parents ~f:(fun (hash, _) ->
      Option.some_if (discarded hash) hash )

(** Update the tree for a breadcrumb the frontier has added, and for the root
    move the add applied, if any: the new root, and the blocks that left the
    frontier - the previous root and the blocks on the branches the move
    discarded. Nodes for those blocks, and their descendants other than through
    the new root, are removed; nothing else is. *)
let frontier_added (t : t) breadcrumb ~root_moved =
  block_added t (Breadcrumb.state_hash breadcrumb) ;
  Option.iter root_moved ~f:(fun (new_root, left) ->
      discarded
        ~parents:
          (Hashtbl.fold t.nodes ~init:[] ~f:(fun ~key ~data acc ->
               (key, data.Node.parent) :: acc ) )
        ~new_root ~left
      |> List.iter ~f:(remove_node t) )

(** A tree that gives up the blocks of the nodes it removes with
    [release]. *)
let create ~logger ~release =
  { states = Node.State.Enum.Table.create ()
  ; nodes = State_hash.Table.create ()
  ; logger
  ; release
  }
