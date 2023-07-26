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
          ( ( Mina_block.initial_valid_block Envelope.Incoming.t
            , State_hash.t )
            Cached.t
          * Mina_net2.Validation_callback.t option )
      | Wait_for_parent of
          ( ( Mina_block.almost_valid_block Envelope.Incoming.t
            , State_hash.t )
            Cached.t
          * Mina_net2.Validation_callback.t option )
      | To_build_breadcrumb of
          ( [ `Parent of State_hash.t ]
          * ( Mina_block.almost_valid_block Envelope.Incoming.t
            , State_hash.t )
            Cached.t
          * Mina_net2.Validation_callback.t option )
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

(* Invariant: The length of the path from each best tip to its oldest
   ancestor is at most k *)
type t =
  { nodes : Node.t State_hash.Table.t
  ; states : State_hash.Set.t Node.State.Enum.Table.t
  ; logger : Logger.t
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

let finish t (node : Node.t) b =
  let s, r =
    if Result.is_error b then (Node.State.Failed, Error node.attempts)
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

let create_node_full t b : unit =
  let h = Breadcrumb.state_hash b in
  let node : Node.t =
    { state = Finished
    ; state_hash = h
    ; blockchain_length =
        Consensus.Data.Consensus_state.blockchain_length
        @@ Breadcrumb.consensus_state b
    ; attempts = Attempt_history.empty
    ; parent = Breadcrumb.parent_hash b
    ; result = Ivar.create_full (Ok `Added_to_frontier)
    }
  in
  add_state t.states node ;
  Hashtbl.add_exn t.nodes ~key:h ~data:node

let breadcrumb_added (t : t) b =
  let h = Breadcrumb.state_hash b in
  match Hashtbl.find t.nodes h with
  | None ->
      create_node_full t b
  | Some node -> (
      Ivar.fill_if_empty node.result (Ok `Added_to_frontier) ;
      match node.state with
      | Root _ | Failed | Finished ->
          ()
      | To_download _
      (* TODO: Cancel download job somehow.. maybe wait on the ivar? *)
      | Wait_for_parent _
      | To_initial_validate _
      | To_verify _
      | To_build_breadcrumb _ ->
          set_state t node Finished )

let remove_node' t (node : Node.t) =
  Hashtbl.remove t.nodes node.state_hash ;
  remove_state t.states node ;
  Ivar.fill_if_empty node.result (Error node.attempts) ;
  match node.state with
  | Root _ | Failed | Finished ->
      ()
  | Wait_for_parent _ ->
      (* cache invalidation for this case is handled explicitly in the super catchup fstm *)
      ()
  | To_download _job ->
      (* TODO: Cancel job somehow *)
      ()
  | To_initial_validate _ ->
      ()
  | To_verify (c, vc) ->
      Option.value_map ~default:ignore
        ~f:Mina_net2.Validation_callback.fire_if_not_already_fired vc `Ignore ;
      ignore
        ( Cached.invalidate_with_failure c
          : Mina_block.initial_valid_block Envelope.Incoming.t )
  | To_build_breadcrumb (_parent, c, vc) ->
      Option.value_map ~default:ignore
        ~f:Mina_net2.Validation_callback.fire_if_not_already_fired vc `Ignore ;
      ignore
        ( Cached.invalidate_with_failure c
          : Mina_block.almost_valid_block Envelope.Incoming.t )

let remove_node t h =
  match Hashtbl.find t.nodes h with
  | None ->
      ()
  | Some node ->
      remove_node' t node

let prune t ~root_hash =
  let cache = State_hash.Table.create () in
  let rec reachable_from_root (node : Node.t) =
    Hashtbl.find_or_add cache node.state_hash ~default:(fun () ->
        if State_hash.equal node.state_hash root_hash then true
        else
          match Hashtbl.find t.nodes node.parent with
          | None ->
              false
          | Some parent ->
              reachable_from_root parent )
  in
  let to_remove =
    Hashtbl.fold t.nodes ~init:[] ~f:(fun ~key:_ ~data acc ->
        if reachable_from_root data then acc else data :: acc )
  in
  List.iter to_remove ~f:(remove_node' t)

let apply_diffs (t : t) (ds : Diff.Full.E.t list) =
  List.iter ds ~f:(function
    | E (New_node (Full b)) ->
        breadcrumb_added t b
    | E (Root_transitioned { new_root; garbage = Full hs; _ }) ->
        List.iter (Diff.Node_list.to_lite hs) ~f:(remove_node t) ;
        let h = (Root_data.Limited.hashes new_root).state_hash in
        if Hashtbl.mem t.nodes h then prune t ~root_hash:h
        else (
          [%log' debug t.logger]
            ~metadata:
              [ ("hash", State_hash.to_yojson h); ("tree", to_yojson t) ]
            "catchup $tree invariant broken: new root $hash not present. Diffs \
             may have been applied out of order. This may lead to a memory \
             leak" ;
          () )
    | E (Best_tip_changed _) ->
        () )

let create ~root =
  let t =
    { states = Node.State.Enum.Table.create ()
    ; nodes = State_hash.Table.create ()
    ; logger = Logger.create ()
    }
  in
  create_node_full t root ; t
