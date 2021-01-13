open Async
open Core
open Pipe_lib
open Network_peer

module Download_id = Unique_id.Int ()

module Job = struct
  type ('key, 'attempt, 'a) t =
    { key: 'key
    ; attempts: 'attempt Peer.Map.t
    ; res:
        ('a Envelope.Incoming.t * 'attempt Peer.Map.t, [`Finished]) Result.t
        Ivar.t }

  let result t = Ivar.read t.res
end

type 'a pred = 'a -> bool

let pred_to_yojson _f _x = `String "<opaque>"

let sexp_opaque_to_yojson _f _x = `String "<opaque>"

module Claimed_knowledge = struct
  type 'key t = [`All | `Some of 'key list | `Call of 'key pred sexp_opaque]
  [@@deriving sexp, to_yojson]

  let check ~equal t k =
    match t with
    | `All ->
        true
    | `Some ks ->
        List.mem ~equal ks k
    | `Call f ->
        f k
end

module Make (Key : sig
  type t [@@deriving to_yojson, hash, sexp, compare]

  include Hashable.S with type t := t

  include Comparable.S with type t := t
end) (Attempt : sig
  type t [@@deriving to_yojson]

  val download : t

  val worth_retrying : t -> bool
end) (Result : sig
  type t

  val key : t -> Key.t
end) (Knowledge_context : sig
  type t
end) : sig
  type t [@@deriving to_yojson]

  module Job : sig
    type t = (Key.t, Attempt.t, Result.t) Job.t

    val result :
         t
      -> ( Result.t Envelope.Incoming.t * Attempt.t Peer.Map.t
         , [`Finished] )
         Base.Result.t
         Deferred.t
  end

  val cancel : t -> Key.t -> unit

  val create :
       max_batch_size:int
    -> stop:unit Deferred.t
    -> trust_system:Trust_system.t
    -> get:(Peer.t -> Key.t list -> Result.t list Deferred.Or_error.t)
    -> knowledge_context:Knowledge_context.t Broadcast_pipe.Reader.t
    -> knowledge:(   Knowledge_context.t
                  -> Peer.t
                  -> Key.t Claimed_knowledge.t Deferred.t)
    -> peers:(unit -> Peer.t list Deferred.t)
    -> preferred:(*     -> knowledge:( (Peer.t * [ `All | `Some of Key.t list | `Call of (Key.t -> bool)]) Strict_pipe.Reader.t) *)
                 (*     -> peers:( Peer.t list Broadcast_pipe.Reader.t) *)
       Peer.t list
    -> t Deferred.t

  val download : t -> key:Key.t -> attempts:Attempt.t Peer.Map.t -> Job.t

  val mark_preferred : t -> Peer.t -> now:Time.t -> unit

  val add_knowledge : t -> Peer.t -> Key.t list -> unit

  val update_knowledge : t -> Peer.t -> Key.t Claimed_knowledge.t -> unit

  val total_jobs : t -> int

  val check_invariant : t -> unit

  val set_check_invariant : (t -> unit) -> unit
end = struct
  let max_wait = Time.Span.of_ms 100.

  module J = Job

  module Job = struct
    type t = (Key.t, Attempt.t, Result.t) Job.t

    let to_yojson ({key; attempts; _} : t) : Yojson.Safe.t =
      `Assoc
        [ ("key", Key.to_yojson key)
        ; ( "attempts"
          , `Assoc
              (List.map (Map.to_alist attempts) ~f:(fun (p, a) ->
                   (Peer.to_multiaddr_string p, Attempt.to_yojson a) )) ) ]

    let result = Job.result
  end

  module Make_hash_queue (Key : Hashable.S) = struct
    module Key_value = struct
      type 'a t = {key: Key.t; mutable value: 'a} [@@deriving fields]
    end

    (* Hash_queue would be perfect, but it doesn't expose enough for
         us to make sure the underlying queue is sorted by blockchain_length. *)
    type 'a t =
      { queue: 'a Key_value.t Doubly_linked.t
      ; table: 'a Key_value.t Doubly_linked.Elt.t Key.Table.t }

    let dequeue t =
      Option.map (Doubly_linked.remove_first t.queue) ~f:(fun {key; value} ->
          Hashtbl.remove t.table key ; value )

    let first t = Option.map (Doubly_linked.first t.queue) ~f:Key_value.value

    (*
    let fold t ~init ~f =
      Doubly_linked.fold t.queue ~init
        ~f:(fun acc x -> f acc x.value)

    let clear t =
      Hashtbl.clear t.table ;
      Doubly_linked.clear t.queue
*)

    let enqueue t (e : _ J.t) =
      if Hashtbl.mem t.table e.key then `Key_already_present
      else
        let kv = {Key_value.key= e.key; value= e} in
        let elt =
          match
            Doubly_linked.find_elt t.queue ~f:(fun {value; _} ->
                Key.compare e.key value.J.key < 0 )
          with
          | None ->
              (* e is >= everything. Put it at the back. *)
              Doubly_linked.insert_last t.queue kv
          | Some pred ->
              Doubly_linked.insert_before t.queue pred kv
        in
        Hashtbl.set t.table ~key:e.key ~data:elt ;
        `Ok

    (*     let enqueue_exn t e = assert (enqueue t e = `Ok) *)

    let iter t ~f = Doubly_linked.iter t.queue ~f:(fun {value; _} -> f value)

    let lookup t k =
      Option.map (Hashtbl.find t.table k) ~f:(fun x ->
          (Doubly_linked.Elt.value x).value )

    let remove t k =
      match Hashtbl.find_and_remove t.table k with
      | None ->
          ()
      | Some elt ->
          Doubly_linked.remove t.queue elt

    let length t = Doubly_linked.length t.queue

    (*     let is_empty t = Doubly_linked.is_empty t.queue *)

    let to_list t = List.map (Doubly_linked.to_list t.queue) ~f:Key_value.value

    let create () = {table= Key.Table.create (); queue= Doubly_linked.create ()}
  end

  module Q = Make_hash_queue (Key)

  module Knowledge = struct
    module Key_set = struct
      type t = Key.Hash_set.t [@@deriving sexp]

      let to_yojson t = `List (List.map (Hash_set.to_list t) ~f:Key.to_yojson)
    end

    type t =
      {claimed: Key.t Claimed_knowledge.t option; tried_and_failed: Key_set.t}
    [@@deriving sexp, to_yojson]

    let clear t = Hash_set.clear t.tried_and_failed

    let create () = {claimed= None; tried_and_failed= Key.Hash_set.create ()}

    let knows t k =
      if Hash_set.mem t.tried_and_failed k then `No
      else
        match t.claimed with
        | None ->
            `No_information
        | Some claimed ->
            if Claimed_knowledge.check ~equal:Key.equal claimed k then
              `Claims_to
            else `No
  end

  module Useful_peers = struct
    module Peer_queue = Make_hash_queue (Peer)

    (*
    module Available_and_useful_ = struct
      type t =
        { preferred: Key.Hash_set.t Peer.Table.t
        ; non_preferred: Key.Hash_set.t Peer.Table.t }
      [@@deriving sexp]

      let create () =
        {preferred= Peer.Table.create (); non_preferred= Peer.Table.create ()}

      let clear {preferred; non_preferred} =
        let f s =
          Hashtbl.iter s ~f:Hash_set.clear ;
          Hashtbl.clear s
        in
        f preferred ; f non_preferred

      let get t =
        let get tbl =
          with_return (fun {return} ->
              Hashtbl.iteri tbl ~f:(fun ~key ~data -> return (Some (key, data))) ;
              None )
        in
        let rec go tbl =
          match get tbl with
          | None ->
              None
          | Some ((key, data) as r) ->
              if Hash_set.is_empty data then ( Hashtbl.remove tbl key ; go tbl )
              else Some r
        in
        match go t.preferred with
        | Some r ->
            Some r
        | None ->
            go t.non_preferred

      let find t p =
        match Hashtbl.find t.preferred p with
        | Some x ->
            Some x
        | None ->
            Hashtbl.find t.non_preferred p

      let remove t p =
        let f s =
          Option.iter (Hashtbl.find_and_remove s p) ~f:Hash_set.clear
        in
        f t.preferred ; f t.non_preferred

      let filter_inplace t ~f =
        Hashtbl.filter_inplace t.preferred ~f ;
        Hashtbl.filter_inplace t.non_preferred ~f

      let filter_keys_inplace t ~f =
        Hashtbl.filter_keys_inplace t.preferred ~f ;
        Hashtbl.filter_keys_inplace t.non_preferred ~f

      let don't_need_keys t ks =
        filter_inplace t ~f:(fun to_try ->
            List.iter ks ~f:(Hash_set.remove to_try) ;
            not (Hash_set.is_empty to_try) )

      let add t ~preferred p v =
        if Hash_set.is_empty v then `Ok
        else (
          let s, other = if preferred then t.preferred,t.non_preferred else t.non_preferred,t.preferred in
          Hashtbl.remove other p ;
          Hashtbl.add s ~key:p ~data:v )
    end
*)

    (* downloading_keys: Key.Hash_set.t
           ; *)

    module Preferred_heap = struct
      type t =
        { heap: (Peer.t * Time.t) Heap.t
        ; table: (Peer.t * Time.t) Heap.Elt.t Peer.Table.t }

      let cmp (p1, t1) (p2, t2) =
        (* Later is smaller *)
        match Int.neg (Time.compare t1 t2) with
        | 0 ->
            Peer.compare p1 p2
        | c ->
            c

      let clear t =
        let rec go t = match Heap.pop t with None -> () | Some _ -> go t in
        go t.heap ; Hashtbl.clear t.table

      let create () = {heap= Heap.create ~cmp (); table= Peer.Table.create ()}

      let add t (p, time) =
        Option.iter (Hashtbl.find t.table p) ~f:(fun elt ->
            Heap.remove t.heap elt ) ;
        Hashtbl.set t.table ~key:p ~data:(Heap.add_removable t.heap (p, time))

      let sexp_of_t (t : t) =
        List.sexp_of_t [%sexp_of: Peer.t * Time.t] (Heap.to_list t.heap)

      let t_of_sexp s =
        let elts = [%of_sexp: (Peer.t * Time.t) list] s in
        let t = create () in
        List.iter elts ~f:(add t) ;
        t

      let of_list xs =
        let now = Time.now () in
        let t = create () in
        List.iter xs ~f:(fun p -> add t (p, now)) ;
        t

      let mem t p = Hashtbl.mem t.table p

      let fold t ~init ~f =
        Heap.fold t.heap ~init ~f:(fun acc (p, _) -> f acc p)

      let to_list (t : t) = List.map ~f:fst (Heap.to_list t.heap)
    end

    type t =
      { downloading_peers: Peer.Hash_set.t
      ; knowledge_requesting_peers: Peer.Hash_set.t
      ; temporary_ignores: (unit, unit) Clock.Event.t sexp_opaque Peer.Table.t
      ; mutable all_preferred: Preferred_heap.t
      ; knowledge: Knowledge.t Peer.Table.t
            (* Written to when something changes. *)
      ; r: unit Strict_pipe.Reader.t sexp_opaque
      ; w:
          ( unit
          , Strict_pipe.drop_head Strict_pipe.buffered
          , unit )
          Strict_pipe.Writer.t
          sexp_opaque }
    [@@deriving sexp]

    (*
    let available_and_useful 
      ~downloading_peers
      ~downloading_keys
      ~all_preferred
      ~all_peers
      ~knowledge
      =
      let open Sequence in
      fold_until ~f:(fun acc p ->
          if Hash_set.mem downloading_peers p
          then Continue acc
          else
            match Hashtbl.find knowledge p with
            | None -> Continue acc
            | Some to_try ->
              let s = Hash_set.diff to_try downloading_keys in
              if 
        )
        (append
           (of_list (Hash_set.to_list all_preferred))
           (filter ~f:(fun x -> not (Hash_set.mem all_preferred x))
             (of_list all_peers)) )
*)

    let reset_knowledge t ~all_peers =
      (* Reset preferred *)
      Preferred_heap.clear t.all_preferred ;
      (*       Hash_set.iter preferred ~f:(Hash_set.add t.all_preferred) ; *)
      Hashtbl.filteri_inplace t.knowledge ~f:(fun ~key:p ~data:k ->
          Hash_set.clear k.tried_and_failed ;
          Set.mem all_peers p ) ;
      Set.iter all_peers ~f:(fun p ->
          if not (Hashtbl.mem t.knowledge p) then
            Hashtbl.add_exn t.knowledge ~key:p ~data:(Knowledge.create ()) ) ;
      Strict_pipe.Writer.write t.w ()

    let to_yojson {knowledge; all_preferred; _} =
      let _list xs =
        `Assoc [("length", `Int (List.length xs)); ("elts", `List xs)]
      in
      let f q = Knowledge.to_yojson q in
      `Assoc
        [ ( "all"
          , `Assoc
              (List.map (Hashtbl.to_alist knowledge) ~f:(fun (p, s) ->
                   (Peer.to_multiaddr_string p, f s) )) )
        ; ( "preferred"
          , `List
              (List.map (Preferred_heap.to_list all_preferred) ~f:(fun p ->
                   `String (Peer.to_multiaddr_string p) )) )
          (*
        ; ( "available_and_useful"
          , `Assoc
              (List.map
                 ( Hashtbl.to_alist available_and_useful.preferred
                 @ Hashtbl.to_alist available_and_useful.non_preferred )
                 ~f:(fun (p, s) ->
                     (Peer.to_multiaddr_string p, (f s)) )) ) 
*)
         ]

    let create ~preferred ~all_peers =
      let knowledge =
        Peer.Table.of_alist_exn
          (List.map all_peers ~f:(fun p -> (p, Knowledge.create ())))
      in
      let r, w =
        Strict_pipe.create ~name:"useful_peers-available" ~warn_on_drop:false
          (Buffered (`Capacity 0, `Overflow Drop_head))
      in
      { downloading_peers= Peer.Hash_set.create ()
      ; knowledge_requesting_peers= Peer.Hash_set.create ()
      ; temporary_ignores= Peer.Table.create ()
      ; knowledge
      ; r
      ; w
      ; all_preferred= Preferred_heap.of_list preferred }

    let tear_down
        { downloading_peers
        ; temporary_ignores
        ; knowledge_requesting_peers
        ; knowledge
        ; r= _
        ; w
        ; all_preferred } =
      Hashtbl.iter temporary_ignores ~f:(fun e ->
          Clock.Event.abort_if_possible e () ) ;
      Hashtbl.clear temporary_ignores ;
      Hash_set.clear downloading_peers ;
      Hash_set.clear knowledge_requesting_peers ;
      Hashtbl.iter knowledge ~f:Knowledge.clear ;
      Hashtbl.clear knowledge ;
      Preferred_heap.clear all_preferred ;
      Strict_pipe.Writer.close w

    let logger = Logger.create ()

    module Knowledge_summary = struct
      type t = {no_information: int; no: int; claims_to: int}
      [@@deriving fields]

      (* Prioritize getting things early in the queue. Like if there is 
         a peer who claims to know the earliest item, pick them. *)
      (*
      let compare t1 t2 =
        match compare t1.claims_to t2.claims_to with
        | 0 ->
          ( match t1.claims_to
*)

      (* Score needs revising -- should be more lexicographic *)
      let score {no_information; no= _; claims_to} =
        Float.of_int claims_to +. (0.1 *. Float.of_int no_information)
    end

    let maxes ~compare xs =
      Sequence.fold xs ~init:[] ~f:(fun acc x ->
          match acc with
          | [] ->
              [x]
          | best :: _ ->
              let c = compare best x in
              if c = 0 then x :: acc else if c < 0 then [x] else acc )
      |> List.rev

    (* TODO now: Sort preferred peers by the last time they returned a good result. *)

    let useful_peer t ~pending_jobs =
      let ts =
        (* TODO: Optimize with a datastructure that doesn't require iterating over everything.
          I.e., it separates out 
          - preferred peers
          - not preferred with claimed != `None
          - not preferred with no claimed knowledge
      *)
        List.rev
          (Preferred_heap.fold t.all_preferred ~init:[] ~f:(fun acc p ->
               match Hashtbl.find t.knowledge p with
               | None ->
                   acc
               | Some k ->
                   (p, k) :: acc ))
        @ Hashtbl.fold t.knowledge ~init:[] ~f:(fun ~key:p ~data:k acc ->
              if not (Preferred_heap.mem t.all_preferred p) then (p, k) :: acc
              else acc )
      in
      (* 
         Algorithm:
         - Look at the pending jobs
         - Find all peers who have the best claim to knowing the first job in the queue.
         - If there are any, pick the one of those who has the best total knowledge score.
         - If there are none, pick the one of all the peers who has the best total knowledge score.
      *)
      let with_best_claim_to_knowing_first_job =
        match List.hd pending_jobs with
        | None ->
            []
        | Some j ->
            Sequence.filter_map (Sequence.of_list ts) ~f:(fun (p, k) ->
                match Knowledge.knows k j.J.key with
                | `No ->
                    None
                | `Claims_to ->
                    Some ((p, k), `Claims_to)
                | `No_information ->
                    Some ((p, k), `No_information) )
            |> maxes ~compare:(fun (_, c1) (_, c2) ->
                   match (c1, c2) with
                   | `Claims_to, `Claims_to | `No_information, `No_information
                     ->
                       0
                   | `Claims_to, `No_information ->
                       1
                   | `No_information, `Claims_to ->
                       -1 )
            |> List.map ~f:fst
      in
      let ts =
        match with_best_claim_to_knowing_first_job with
        | [] ->
            ts
        | _ :: _ ->
            with_best_claim_to_knowing_first_job
      in
      let knowledge =
        List.map ts ~f:(fun (p, k) ->
            let summary, js =
              List.fold
                ~init:
                  ( {Knowledge_summary.no_information= 0; no= 0; claims_to= 0}
                  , [] )
                pending_jobs
                ~f:(fun (acc, js) j ->
                  let field, js =
                    let open Knowledge_summary.Fields in
                    match Knowledge.knows k j.J.key with
                    | `Claims_to ->
                        (claims_to, j :: js)
                    | `No ->
                        (no, js)
                    | `No_information ->
                        (no_information, j :: js)
                  in
                  (Field.map field acc ~f:(( + ) 1), js) )
            in
            ((p, List.rev js), Knowledge_summary.score summary) )
      in
      (*
      let module T = struct
        type t = ( (Peer.t * Job.t list) * float ) list [@@deriving to_yojson]
      end in
      [%log' debug logger]
        "useful_peer"
        ~metadata:[
          "pending", `List (List.map pending_jobs ~f:Job.to_yojson);
          "knowledge", T.to_yojson knowledge
        ] ; *)
      let useful_exists = List.exists knowledge ~f:(fun (_, s) -> s > 0.) in
      let best =
        List.max_elt
          (List.filter knowledge ~f:(fun ((p, _), _) ->
               (not (Hashtbl.mem t.temporary_ignores p))
               && (not (Hash_set.mem t.downloading_peers p))
               && not (Hash_set.mem t.knowledge_requesting_peers p) ))
          ~compare:(fun (_, s1) (_, s2) -> Float.compare s1 s2)
      in
      match best with
      | None ->
          if useful_exists then `Useful_but_busy else `No_peers
      | Some ((p, k), score) ->
          if score <= 0. then `Stalled else `Useful (p, k)

    let time lab f =
      let start = Time.now () in
      let x = f () in
      let stop = Time.now () in
      [%log' debug logger] "%s took %s" lab
        (Time.Span.to_string_hum (Time.diff stop start)) ;
      x

    let useful_peer t ~pending_jobs =
      time "useful_peer" (fun () -> useful_peer t ~pending_jobs)

    (*
      let f p k useful_but_busy =
          let available_jobs =
            List.filter pending_jobs
              ~f:(fun j -> Knowledge.might_know k j.J.key  ) 
          in 
          if List.is_empty available_jobs
          then (
            [%log' debug logger]
              "peer useless"
              ~metadata:[
                "peer", `String (Peer.to_multiaddr_string p) ;
                "knowledge", Knowledge.to_yojson k
              ] ;
            useful_but_busy
          )
          else 
            (if not (Hash_set.mem t.downloading_peers p)
              then return (`Useful (p, available_jobs))
              else true)
      in 
      let useful_but_busy =
        let init =
          (Hash_set.fold t.all_preferred ~init:false ~f:(fun acc p ->
                f p (Hashtbl.find_exn t.knowledge p) acc))
        in 
        Hashtbl.fold ~init t.knowledge ~f:(fun ~key:p ~data:k useful_but_busy ->
            if Hash_set.mem t.all_preferred p
            then useful_but_busy
            else
              let available_jobs =
                List.filter pending_jobs
                  ~f:(fun j -> Knowledge.might_know k j.J.key  ) 
              in 
              if List.is_empty available_jobs
              then (
                [%log' debug logger]
                  "peer useless"
                  ~metadata:[
                    "peer", `String (Peer.to_multiaddr_string p) ;
                    "knowledge", Knowledge.to_yojson k
                  ] ;
                useful_but_busy
              )
              else 
                (if not (Hash_set.mem t.downloading_peers p)
                then return (`Useful (p, available_jobs))
                else true) )
      in
      if useful_but_busy
      then `Useful_but_busy
      else 
        (* There is no peer thath has any non-empty "available jobs"  *)
        `Stalled

*)
    (*
    let rec read t ~pending_jobs =
      match useful_peer t ~pending_jobs with
      | Some r ->
          return (`Ok r)
      | None -> (
          match%bind Strict_pipe.Reader.read t.r with
          | `Eof ->
              return `Eof
          | `Ok () ->
              read t ~pending_jobs ) *)

    type update =
      | New_job of Job.t
      | Refreshed_peers of {all_peers: Peer.Set.t; active_jobs: Key.Hash_set.t}
      | Download_finished of
          Peer.t * [`Successful of Key.t list] * [`Unsuccessful of Key.t list]
      | Download_starting of Peer.t * Key.t list
      | Job_cancelled of Key.t
      | Add_knowledge of {peer: Peer.t; claimed: Key.t list; out_of_band: bool}
      | Knowledge_request_starting of Peer.t
      | Knowledge of
          { peer: Peer.t
          ; claimed: Key.t Claimed_knowledge.t
          ; active_jobs: Job.t list
          ; out_of_band: bool }

    let jobs_no_longer_needed t ks =
      Hashtbl.iter t.knowledge ~f:(fun s ->
          List.iter ks ~f:(Hash_set.remove s.tried_and_failed) )

    (*
    let update_availability t peer to_try
        ~new_open_jobs
      =
      if (Hash_set.mem t.downloading_peers peer) then
        Available_and_useful.remove t.available_and_useful peer
      else 
        match
          Available_and_useful.find t.available_and_useful peer
        with
        | Some s ->
            List.iter new_open_jobs ~f:(fun k ->
                if Hash_set.mem to_try k then Hash_set.add s k )
        | None ->
            let s = Hash_set.diff to_try t.downloading_keys in
            Available_and_useful.add t.available_and_useful peer s
              ~preferred:(Hash_set.mem t.all_preferred peer)
            |> ignore 

*)
    let ignore_period = Time.Span.of_min 2.

    let update t u =
      match u with
      | Add_knowledge {peer; claimed; out_of_band} ->
          if not out_of_band then
            Hash_set.remove t.knowledge_requesting_peers peer ;
          Hashtbl.update t.knowledge peer ~f:(function
            | None ->
                { Knowledge.claimed= Some (`Some claimed)
                ; tried_and_failed= Key.Hash_set.create () }
            | Some k ->
                let claimed =
                  match k.claimed with
                  | None ->
                      `Some claimed
                  | Some (`Some claimed') ->
                      `Some
                        (List.dedup_and_sort ~compare:Key.compare
                           (claimed' @ claimed))
                  | Some `All ->
                      `All
                  | Some (`Call f) ->
                      let s = Key.Hash_set.of_list claimed in
                      `Call (fun key -> f key || Hash_set.mem s key)
                in
                {k with claimed= Some claimed} )
      | Knowledge_request_starting peer ->
          Hash_set.add t.knowledge_requesting_peers peer
      | Knowledge {peer; claimed; active_jobs; out_of_band} ->
          if not out_of_band then
            Hash_set.remove t.knowledge_requesting_peers peer ;
          let tried_and_failed =
            let s = Key.Hash_set.create () in
            List.iter active_jobs ~f:(fun j ->
                match Map.find j.J.attempts peer with
                | None ->
                    ()
                | Some a ->
                    if not (Attempt.worth_retrying a) then Hash_set.add s j.key
            ) ;
            s
          in
          Hashtbl.set t.knowledge ~key:peer
            ~data:{Knowledge.claimed= Some claimed; tried_and_failed}
      | Job_cancelled h ->
          jobs_no_longer_needed t [h] ;
          Hashtbl.iter t.knowledge ~f:(fun s ->
              Hash_set.remove s.tried_and_failed h )
      | Download_starting (peer, (* TODO: Remove *) _ks) ->
          (* WHen a download starts for a job, we should remove all peers from
           available and useful whose only useful jobs are in downloading.. *)
          Hash_set.add t.downloading_peers peer
      (*           List.iter ks ~f:(Hash_set.add t.downloading_keys) ; *)
      | Download_finished (peer0, `Successful succs, `Unsuccessful unsuccs)
        -> (
          (let cancel =
             Option.iter ~f:(fun e -> Clock.Event.abort_if_possible e ())
           in
           if List.is_empty succs then
             Hashtbl.update t.temporary_ignores peer0 ~f:(fun x ->
                 cancel x ;
                 Clock.Event.run_after ignore_period
                   (fun () ->
                     Hashtbl.remove t.temporary_ignores peer0 ;
                     if not (Strict_pipe.Writer.is_closed t.w) then
                       Strict_pipe.Writer.write t.w () )
                   () )
           else (
             Hashtbl.find_and_remove t.temporary_ignores peer0 |> cancel ;
             Preferred_heap.add t.all_preferred (peer0, Time.now ()) )) ;
          Hash_set.remove t.downloading_peers peer0 ;
          jobs_no_longer_needed t succs ;
          match Hashtbl.find t.knowledge peer0 with
          | None ->
              ()
          | Some {tried_and_failed; claimed= _} ->
              List.iter unsuccs ~f:(Hash_set.add tried_and_failed) )
      | Refreshed_peers {all_peers; (* TODO: Remove *) active_jobs= _} ->
          Hashtbl.filter_keys_inplace t.knowledge ~f:(Set.mem all_peers) ;
          Set.iter all_peers ~f:(fun p ->
              if not (Hashtbl.mem t.knowledge p) then
                Hashtbl.add_exn t.knowledge ~key:p
                  ~data:
                    { Knowledge.claimed= None
                    ; tried_and_failed= Key.Hash_set.create () } )
      | New_job _new_job ->
          ()

    (*
          Hashtbl.iteri t.knowledge ~f:(fun ~key:p ~data:to_try ->
              let useful_for_job = not (Map.mem new_job.attempts p) in
              if useful_for_job then (
                Hash_set.add to_try new_job.key ;
                match Available_and_useful.find t.available_and_useful p with
                | Some s ->
                    Hash_set.add s new_job.key
                | None ->
                    if not (Hash_set.mem t.downloading_peers p) then
                      let s = Hash_set.diff to_try t.downloading_keys in
                      Available_and_useful.add t.available_and_useful p s
                        ~preferred:(Hash_set.mem t.all_preferred p)
                      |> ignore ) )
*)

    let update t u : unit =
      update t u ;
      if not (Strict_pipe.Writer.is_closed t.w) then
        Strict_pipe.Writer.write t.w ()
  end

  type t =
    { mutable next_flush: (unit, unit) Clock.Event.t option
    ; mutable all_peers: Peer.Set.t
    ; pending: Job.t Q.t
    ; downloading: (Peer.t * Job.t) Key.Table.t
    ; useful_peers: Useful_peers.t
    ; flush_r: unit Strict_pipe.Reader.t (* Single reader *)
    ; flush_w:
        ( unit
        , Strict_pipe.drop_head Strict_pipe.buffered
        , unit )
        Strict_pipe.Writer.t
          (* buffer of length 0 *)
    ; get: Peer.t -> Key.t list -> Result.t list Deferred.Or_error.t
    ; max_batch_size: int
          (* A peer is useful if there is a job in the pending queue which has not
   been attempted with that peer. *)
    ; got_new_peers_w:
        ( unit
        , Strict_pipe.drop_head Strict_pipe.buffered
        , unit )
        Strict_pipe.Writer.t
          (* buffer of length 0 *)
    ; got_new_peers_r: unit Strict_pipe.Reader.t
    ; logger: Logger.t
    ; trust_system: Trust_system.t
    ; stop: unit Deferred.t }

  let total_jobs (t : t) = Q.length t.pending + Hashtbl.length t.downloading

  (* Checks disjointness *)
  let check_invariant (t : t) =
    Set.length
      (Key.Set.union_list
         [ Q.to_list t.pending
           |> List.map ~f:(fun j -> j.key)
           |> Key.Set.of_list
         ; Key.Set.of_hashtbl_keys t.downloading ])
    |> [%test_eq: int] (total_jobs t)

  let check_invariant_r = ref check_invariant

  let set_check_invariant f = check_invariant_r := f

  let job_finished t j x =
    Hashtbl.remove t.downloading j.J.key ;
    Ivar.fill_if_empty j.res x ;
    try !check_invariant_r t
    with e ->
      [%log' debug t.logger]
        ~metadata:[("exn", `String (Exn.to_string e))]
        "job_finished $exn"

  let kill_job _t j = Ivar.fill_if_empty j.J.res (Error `Finished)

  let flush_soon t =
    Option.iter t.next_flush ~f:(fun e -> Clock.Event.abort_if_possible e ()) ;
    t.next_flush
    <- Some
         (Clock.Event.run_after max_wait
            (fun () ->
              if not (Strict_pipe.Writer.is_closed t.flush_w) then
                Strict_pipe.Writer.write t.flush_w () )
            ())

  let cancel t h =
    [%log' debug t.logger]
      ~metadata:[("key", Key.to_yojson h)]
      "cancel the download $key" ;
    let job =
      List.find_map ~f:Lazy.force
        [ lazy (Q.lookup t.pending h)
        ; lazy (Option.map ~f:snd (Hashtbl.find t.downloading h)) ]
    in
    Q.remove t.pending h ;
    Hashtbl.remove t.downloading h ;
    match job with
    | None ->
        ()
    | Some j ->
        kill_job t j ;
        Useful_peers.update t.useful_peers (Job_cancelled h)

  let enqueue t e = Q.enqueue t.pending e

  let enqueue_exn t e = assert (enqueue t e = `Ok)

  let active_job_keys t =
    let res = Key.Hash_set.create () in
    Q.iter t.pending ~f:(fun j -> Hash_set.add res j.key) ;
    Hashtbl.iter_keys t.downloading ~f:(Hash_set.add res) ;
    res

  let active_jobs t =
    Q.to_list t.pending @ List.map (Hashtbl.data t.downloading) ~f:snd

  let refresh_peers t peers =
    Broadcast_pipe.Reader.iter peers ~f:(fun peers ->
        let peers' = Peer.Set.of_list peers in
        let new_peers = Set.diff peers' t.all_peers in
        Useful_peers.update t.useful_peers
          (Refreshed_peers {all_peers= peers'; active_jobs= active_job_keys t}) ;
        if
          (not (Set.is_empty new_peers))
          && not (Strict_pipe.Writer.is_closed t.got_new_peers_w)
        then Strict_pipe.Writer.write t.got_new_peers_w () ;
        t.all_peers <- Peer.Set.of_list peers ;
        Deferred.unit )
    |> don't_wait_for

  let tear_down
      ( { next_flush
        ; all_peers= _
        ; flush_w
        ; get= _
        ; got_new_peers_w
        ; flush_r= _
        ; useful_peers
        ; got_new_peers_r= _
        ; pending
        ; downloading
        ; max_batch_size= _
        ; logger= _
        ; trust_system= _
        ; stop= _ } as t ) =
    let rec clear_queue q =
      match Q.dequeue q with
      | None ->
          ()
      | Some j ->
          kill_job t j ; clear_queue q
    in
    Option.iter next_flush ~f:(fun e -> Clock.Event.abort_if_possible e ()) ;
    Strict_pipe.Writer.close flush_w ;
    Useful_peers.tear_down useful_peers ;
    Strict_pipe.Writer.close got_new_peers_w ;
    Hashtbl.iter downloading ~f:(fun (_, j) -> kill_job t j) ;
    Hashtbl.clear downloading ;
    clear_queue pending

  let most_important_key t =
    let in_pending =
      Option.map (Q.first t.pending) ~f:(fun x -> ("pending", x.key))
    in
    let in_downloading =
      Hashtbl.fold t.downloading ~init:None ~f:(fun ~key:k ~data:_ acc ->
          Option.merge acc (Some k) ~f:Key.min )
      |> Option.map ~f:(fun x -> ("downloading", x))
    in
    let module T = struct
      type t = (string * Key.t) option [@@deriving to_yojson]
    end in
    Option.merge in_pending in_downloading ~f:(fun (lab1, k1) (lab2, k2) ->
        if Key.( < ) k1 k2 then (lab1, k1) else (lab2, k2) )
    |> T.to_yojson

  let download t peer xs =
    let id = Download_id.create () in
    let f xs =
      `Assoc
        [ ("length", `Int (List.length xs))
        ; ("elts", `List (List.map xs ~f:(fun j -> Key.to_yojson j.J.key))) ]
    in
    [%log' debug t.logger] "cooldebug Downloader: to download $n"
      ~metadata:
        [ ("n", `Int (List.length xs))
        ; ("id", `Int (Download_id.to_int_exn id))
        ; ("most_important", most_important_key t)
        ; ("to_download", f xs)
          (*         ; ("downloading", f (Hashtbl.data t.downloading |> List.map ~f:snd)) *)
        ; ("peer", `String (Peer.to_multiaddr_string peer)) ] ;
    let keys = List.map xs ~f:(fun x -> x.J.key) in
    let fail ?punish (e : Error.t) =
      let e = Error.to_string_hum e in
      if Option.is_some punish then
        (* TODO: Make this an insta ban *)
        Trust_system.(
          record t.trust_system t.logger peer
            Actions.(Violated_protocol, Some (e, [])))
        |> don't_wait_for ;
      [%log' debug t.logger] "Downloading from $peer failed ($error) on $keys"
        ~metadata:
          [ ("peer", Peer.to_yojson peer)
          ; ("error", `String e)
          ; ("keys", `List (List.map keys ~f:Key.to_yojson)) ] ;
      (* TODO: Log error *)
      List.iter xs ~f:(fun x ->
          enqueue_exn t
            { x with
              attempts= Map.set x.attempts ~key:peer ~data:Attempt.download }
      ) ;
      flush_soon t
    in
    List.iter xs ~f:(fun x ->
        Hashtbl.set t.downloading ~key:x.key ~data:(peer, x) ) ;
    Useful_peers.update t.useful_peers (Download_starting (peer, keys)) ;
    let download_deferred = t.get peer keys in
    upon download_deferred (fun res ->
        [%log' debug t.logger] "cooldebug Downloader: fished download $n"
          ~metadata:
            [ ("n", `Int (List.length xs))
            ; ("id", `Int (Download_id.to_int_exn id))
            ; ("to_download", f xs)
            ; ("most_important", most_important_key t)
              (*             ; ("downloading", f (Hashtbl.data t.downloading |> List.map ~f:snd)) *)
            ; ("peer", `String (Peer.to_multiaddr_string peer)) ] ;
        let succs, unsuccs =
          match res with
          | Error _ ->
              ([], keys)
          | Ok rs ->
              let all = Key.Hash_set.of_list keys in
              let succ =
                List.filter_map rs ~f:(fun r ->
                    let k = Result.key r in
                    if Hash_set.mem all k then Some k else None )
              in
              List.iter succ ~f:(Hash_set.remove all) ;
              (succ, Hash_set.to_list all)
        in
        Useful_peers.update t.useful_peers
          (Download_finished (peer, `Successful succs, `Unsuccessful unsuccs))
    ) ;
    let%map res =
      Deferred.choose
        [ Deferred.choice download_deferred (fun x -> `Not_stopped x)
        ; Deferred.choice t.stop (fun () -> `Stopped)
        ; Deferred.choice
            (* This happens if all the jobs are cancelled. *)
            (Deferred.List.map xs ~f:(fun x -> Ivar.read x.res))
            (fun _ -> `Stopped) ]
    in
    List.iter xs ~f:(fun j -> Hashtbl.remove t.downloading j.key) ;
    match res with
    | `Stopped ->
        List.iter xs ~f:(kill_job t)
    | `Not_stopped r -> (
        [%log' debug t.logger] "cooldebug Downloader: fished download indeed"
          ~metadata:[("id", `Int (Download_id.to_int_exn id))] ;
        match r with
        | Error e ->
            fail e
        | Ok rs ->
            [%log' debug t.logger] "result is $result"
              ~metadata:
                [ ( "result"
                  , let n = List.length rs in
                    if n > 5 then `Int n
                    else
                      `List
                        (List.map rs ~f:(fun r -> Key.to_yojson (Result.key r)))
                  )
                ; ("peer", `String (Peer.to_multiaddr_string peer)) ] ;
            let received_at = Time.now () in
            let jobs =
              Key.Table.of_alist_exn (List.map xs ~f:(fun x -> (x.key, x)))
            in
            List.iter rs ~f:(fun r ->
                match Hashtbl.find jobs (Result.key r) with
                | None ->
                    (* Got something we didn't ask for. *)
                    Trust_system.(
                      record t.trust_system t.logger peer
                        Actions.(Violated_protocol, None))
                    |> don't_wait_for
                | Some j ->
                    Hashtbl.remove jobs j.key ;
                    job_finished t j
                      (Ok
                         ( { Envelope.Incoming.data= r
                           ; received_at
                           ; sender= Remote peer }
                         , j.attempts )) ) ;
            (* Anything left in jobs, we did not get results for :( *)
            Hashtbl.iter jobs ~f:(fun x ->
                Hashtbl.remove t.downloading x.J.key ;
                enqueue_exn t
                  { x with
                    attempts=
                      Map.set x.attempts ~key:peer ~data:Attempt.download } ) ;
            flush_soon t )

  (*
  let is_empty t = Q.is_empty t.pending && Hashtbl.is_empty t.downloading
*)

  let to_yojson t : Yojson.Safe.t =
    check_invariant t ;
    let list xs =
      `Assoc [("length", `Int (List.length xs)); ("elts", `List xs)]
    in
    let f q = list (List.map ~f:Job.to_yojson (Q.to_list q)) in
    `Assoc
      [ ("total_jobs", `Int (total_jobs t))
      ; ("useful_peers", Useful_peers.to_yojson t.useful_peers)
      ; ("pending", f t.pending)
      ; ( "downloading"
        , list
            (List.map (Hashtbl.to_alist t.downloading) ~f:(fun (h, (p, _)) ->
                 `Assoc
                   [ ("hash", Key.to_yojson h)
                   ; ("peer", `String (Peer.to_multiaddr_string p)) ] )) ) ]

  let post_stall_retry_delay = Time.Span.of_min 1.

  (*
  let rec step t =
    [%log' debug t.logger] "Downloader: Mownload step"
      ~metadata:[("downloader", to_yojson t)] ;
    if is_empty t then (
      match%bind Strict_pipe.Reader.read t.flush_r with
      | `Eof ->
          [%log' debug t.logger] "Downloader: flush eof" ;
          Deferred.unit
      | `Ok () ->
          [%log' debug t.logger] "Downloader: flush" ;
          step t )
    else if all_stalled t then (
      [%log' debug t.logger]
        "Downloader: all stalled. Resetting knowledge, waiting %s and then \
         retrying."
        (Time.Span.to_string_hum post_stall_retry_delay) ;
      Useful_peers.reset_knowledge t.useful_peers ~all_peers:t.all_peers
        ~preferred:t.preferred ~active_jobs:(active_jobs t) ;
      Q.iter t.stalled ~f:(Q.enqueue_exn t.pending) ;
      Q.clear t.stalled ;
      let%bind () = after post_stall_retry_delay in
      [%log' debug t.logger] "Downloader: continuing after reset" ;
      step t )
    else (
      [%log' debug t.logger] "Downloader: else"
        ~metadata:
          [ ( "peer_available"
            , `Bool
                (Option.is_some
                   ( Strict_pipe.Reader.to_linear_pipe t.useful_peers.r
                   |> Linear_pipe.peek )) ) ] ;
      match%bind Useful_peers.read t.useful_peers with
      | `Eof ->
          Deferred.unit
      | `Ok (peer, useful_for) -> (
          let f xs = `Assoc [("length", `Int (List.length xs))] in
          (let in_pending_useful_self =
             List.filter (Q.to_list t.pending) ~f:(fun x ->
                 Hash_set.mem useful_for x.J.key )
           in
           let in_pending_useful_them =
             List.filter (Q.to_list t.pending) ~f:(fun x ->
                 not (Map.mem x.attempts peer) )
           in
           let in_downloading_useful_self =
             List.filter_map (Hashtbl.to_alist t.downloading)
               ~f:(fun (_, (_, x)) ->
                 if Hash_set.mem useful_for x.J.key then Some x else None )
           in
           let in_downloading_useful_them =
             List.filter_map (Hashtbl.to_alist t.downloading)
               ~f:(fun (_, (_, x)) ->
                 if not (Map.mem x.attempts peer) then Some x else None )
           in
           [%log' debug t.logger] "cooldebug Downloader: got $peer"
             ~metadata:
               [ ("peer", Peer.to_yojson peer)
               ; ( "in_pending_useful_agree"
                 , `Bool
                     (Int.equal
                        (List.length in_pending_useful_self)
                        (List.length in_pending_useful_them)) )
               ; ( "in_downloading_useful_agree"
                 , `Bool
                     (Int.equal
                        (List.length in_downloading_useful_self)
                        (List.length in_downloading_useful_them)) )
               ; ("in_pending_useful_self", f in_pending_useful_self)
               ; ("in_pending_useful_them", f in_pending_useful_them)
               ; ("in_downloading_useful_self", f in_downloading_useful_self)
               ; ("in_downloading_useful_them", f in_downloading_useful_them)
               ]) ;
          let to_download =
            let rec go n acc skipped =
              if n >= t.max_batch_size then (acc, skipped)
              else
                match Q.dequeue t.pending with
                | None ->
                    (acc, skipped)
                | Some x ->
                    if not (Hash_set.mem useful_for x.key) then
                      go n acc (x :: skipped)
                    else go (n + 1) (x :: acc) skipped
            in
            let acc, skipped = go 0 [] [] in
            List.iter (List.rev skipped) ~f:(enqueue_exn t) ;
            List.rev acc
          in
          [%log' debug t.logger] "cooldebug Downloader: to download $n"
            ~metadata:
              [ ("n", `Int (List.length to_download))
              ; ("to_download", f to_download) 
              ; ("peer", `String (Peer.to_multiaddr_string peer))
              ] ;
          match to_download with
          | [] ->
              step t
          | _ :: _ ->
              don't_wait_for (download t peer to_download) ;
              step t ) )
*)

  let rec step t =
    [%log' debug t.logger] "Downloader: Mownload step"
      ~metadata:[("downloader", to_yojson t)] ;
    if Q.length t.pending = 0 then (
      [%log' debug t.logger] "Downloader: no jobs. waiting"
        ~metadata:[("downloader", to_yojson t)] ;
      match%bind Strict_pipe.Reader.read t.flush_r with
      | `Eof ->
          [%log' debug t.logger] "Downloader: flush eof" ;
          Deferred.unit
      | `Ok () ->
          step t )
    else
      match
        Useful_peers.useful_peer t.useful_peers
          ~pending_jobs:(Q.to_list t.pending)
      with
      | `No_peers -> (
          match%bind Strict_pipe.Reader.read t.got_new_peers_r with
          | `Eof ->
              [%log' debug t.logger] "Downloader: new peers eof" ;
              Deferred.unit
          | `Ok () ->
              step t )
      | `Useful_but_busy -> (
          [%log' debug t.logger] "Downloader: Waiting. All useful peers busy"
            ~metadata:[("downloader", to_yojson t)] ;
          let read p =
            Pipe.read_choice_single_consumer_exn
              (Strict_pipe.Reader.to_linear_pipe p).pipe [%here]
          in
          match%bind
            Deferred.choose [read t.flush_r; read t.useful_peers.r]
          with
          | `Eof ->
              [%log' debug t.logger] "Downloader: flush eof" ;
              Deferred.unit
          | `Ok () ->
              (* Try again, something might have changed *)
              step t )
      | `Stalled ->
          [%log' debug t.logger]
            "Downloader: all stalled. Resetting knowledge, waiting %s and \
             then retrying."
            (Time.Span.to_string_hum post_stall_retry_delay) ;
          Useful_peers.reset_knowledge t.useful_peers ~all_peers:t.all_peers ;
          let%bind () = after post_stall_retry_delay in
          [%log' debug t.logger] "Downloader: continuing after reset" ;
          step t
      | `Useful (peer, might_know) -> (
          let to_download = List.take might_know t.max_batch_size in
          [%log' debug t.logger] "cooldebug Downloader: most important"
            ~metadata:
              [ ("most_important", most_important_key t)
                (*             ; ("downloading", f (Hashtbl.data t.downloading |> List.map ~f:snd)) *)
              ; ("peer", `String (Peer.to_multiaddr_string peer)) ] ;
          List.iter to_download ~f:(fun j -> Q.remove t.pending j.key) ;
          match to_download with
          | [] ->
              step t
          | _ :: _ ->
              don't_wait_for (download t peer to_download) ;
              step t )

  (*
        (let in_pending_useful_self =
            List.filter (Q.to_list t.pending) ~f:(fun x ->
                Hash_set.mem useful_for x.J.key )
          in
          let in_pending_useful_them =
            List.filter (Q.to_list t.pending) ~f:(fun x ->
                not (Map.mem x.attempts peer) )
          in
          let in_downloading_useful_self =
            List.filter_map (Hashtbl.to_alist t.downloading)
              ~f:(fun (_, (_, x)) ->
                if Hash_set.mem useful_for x.J.key then Some x else None )
          in
          let in_downloading_useful_them =
            List.filter_map (Hashtbl.to_alist t.downloading)
              ~f:(fun (_, (_, x)) ->
                if not (Map.mem x.attempts peer) then Some x else None )
          in
          [%log' debug t.logger] "cooldebug Downloader: got $peer"
            ~metadata:
              [ ("peer", Peer.to_yojson peer)
              ; ( "in_pending_useful_agree"
                , `Bool
                    (Int.equal
                      (List.length in_pending_useful_self)
                      (List.length in_pending_useful_them)) )
              ; ( "in_downloading_useful_agree"
                , `Bool
                    (Int.equal
                      (List.length in_downloading_useful_self)
                      (List.length in_downloading_useful_them)) )
              ; ("in_pending_useful_self", f in_pending_useful_self)
              ; ("in_pending_useful_them", f in_pending_useful_them)
              ; ("in_downloading_useful_self", f in_downloading_useful_self)
              ; ("in_downloading_useful_them", f in_downloading_useful_them)
              ]) ; *)
  (*
    if is_empty t then (
      match%bind Strict_pipe.Reader.read t.flush_r with
      | `Eof ->
          [%log' debug t.logger] "Downloader: flush eof" ;
          Deferred.unit
      | `Ok () ->
          [%log' debug t.logger] "Downloader: flush" ;
          step t )
    else if all_stalled t then (
      [%log' debug t.logger]
        "Downloader: all stalled. Resetting knowledge, waiting %s and then \
         retrying."
        (Time.Span.to_string_hum post_stall_retry_delay) ;
      Useful_peers.reset_knowledge t.useful_peers ~all_peers:t.all_peers
        ~preferred:t.preferred ~active_jobs:(active_jobs t) ;
      Q.iter t.stalled ~f:(Q.enqueue_exn t.pending) ;
      Q.clear t.stalled ;
      let%bind () = after post_stall_retry_delay in
      [%log' debug t.logger] "Downloader: continuing after reset" ;
      step t )
    else (
      [%log' debug t.logger] "Downloader: else"
        ~metadata:
          [ ( "peer_available"
            , `Bool
                (Option.is_some
                   ( Strict_pipe.Reader.to_linear_pipe t.useful_peers.r
                   |> Linear_pipe.peek )) ) ] ;
*)

  let add_knowledge t peer claimed =
    Useful_peers.update t.useful_peers
      (Add_knowledge {peer; claimed; out_of_band= true})

  let update_knowledge t peer claimed =
    Useful_peers.update t.useful_peers
      (Knowledge {peer; claimed; active_jobs= active_jobs t; out_of_band= true})

  let mark_preferred t peer ~now =
    Useful_peers.Preferred_heap.add t.useful_peers.all_preferred (peer, now)

  let create ~max_batch_size ~stop ~trust_system ~get ~knowledge_context
      ~knowledge ~peers ~preferred =
    let%map all_peers = peers () in
    let pipe ~name c =
      Strict_pipe.create ~warn_on_drop:false ~name
        (Buffered (`Capacity c, `Overflow Drop_head))
    in
    let flush_r, flush_w = pipe ~name:"flush" 0 in
    let got_new_peers_r, got_new_peers_w = pipe ~name:"got_new_peers" 0 in
    let t =
      { all_peers= Peer.Set.of_list all_peers
      ; pending= Q.create ()
      ; next_flush= None
      ; flush_r
      ; flush_w
      ; got_new_peers_r
      ; got_new_peers_w
      ; useful_peers= Useful_peers.create ~all_peers ~preferred
      ; get
      ; max_batch_size
      ; logger= Logger.create ()
      ; trust_system
      ; downloading= Key.Table.create ()
      ; stop }
    in
    let peers =
      let r, w = Broadcast_pipe.create [] in
      upon stop (fun () -> Broadcast_pipe.Writer.close w) ;
      Clock.every' ~stop (Time.Span.of_min 1.) (fun () ->
          peers ()
          >>= fun ps ->
          try Broadcast_pipe.Writer.write w ps
          with Broadcast_pipe.Already_closed _ -> Deferred.unit ) ;
      r
    in
    let rec jobs_to_download () =
      if total_jobs t <> 0 then Deferred.return `Ok
      else
        match%bind
          Deferred.any
            [ (stop >>| fun _ -> `Eof)
            ; Pipe.values_available
                (Strict_pipe.Reader.to_linear_pipe t.flush_r).pipe
            ; Pipe.values_available
                (Strict_pipe.Reader.to_linear_pipe t.useful_peers.r).pipe ]
        with
        | `Eof ->
            Deferred.return `Finshed
        | `Ok ->
            jobs_to_download ()
    in
    let () =
      (* TODO now: stop querying if there are zero download jobs *)
      let request_r, request_w =
        Strict_pipe.create ~name:"knowledge-requests" Strict_pipe.Synchronous
      in
      upon stop (fun () -> Strict_pipe.Writer.close request_w) ;
      let refresh_knowledge stop peer =
        Clock.every' (Time.Span.of_min 7.) ~stop (fun () ->
            let%bind _ = jobs_to_download () in
            if not (Strict_pipe.Writer.is_closed request_w) then
              Strict_pipe.Writer.write request_w peer
            else Deferred.unit )
      in
      let ps : unit Ivar.t Peer.Table.t = Peer.Table.create () in
      Broadcast_pipe.Reader.iter peers ~f:(fun peers ->
          let peers = Peer.Hash_set.of_list peers in
          Hashtbl.filteri_inplace ps ~f:(fun ~key:p ~data:finished ->
              let keep = Hash_set.mem peers p in
              if not keep then Ivar.fill_if_empty finished () ;
              keep ) ;
          Hash_set.iter peers ~f:(fun p ->
              if not (Hashtbl.mem ps p) then (
                let finished = Ivar.create () in
                refresh_knowledge (Ivar.read finished) p ;
                Hashtbl.add_exn ps ~key:p ~data:finished ) ) ;
          Deferred.unit )
      |> don't_wait_for ;
      let throttle =
        Throttle.create ~continue_on_error:true ~max_concurrent_jobs:8
      in
      let get_knowledge ctx peer =
        Throttle.enqueue throttle (fun () -> knowledge ctx peer)
      in
      Broadcast_pipe.Reader.iter knowledge_context ~f:(fun _ ->
          Hashtbl.mapi_inplace ps ~f:(fun ~key:p ~data:finished ->
              Ivar.fill_if_empty finished () ;
              let finished = Ivar.create () in
              refresh_knowledge (Ivar.read finished) p ;
              finished ) ;
          Deferred.unit )
      |> don't_wait_for ;
      let logger = Logger.create () in
      Strict_pipe.Reader.iter request_r ~f:(fun peer ->
          (* TODO: The pipe/clock logic is not quite right. *)
          if Deferred.is_determined stop then Deferred.unit
          else
            let%map () = Throttle.capacity_available throttle in
            don't_wait_for
              (let ctx = Broadcast_pipe.Reader.peek knowledge_context in
               (* TODO: Check if already downloading a job from them here. *)
               Useful_peers.update t.useful_peers
                 (Knowledge_request_starting peer) ;
               let%map k = get_knowledge ctx peer in
               [%log' debug logger]
                 ~metadata:
                   [ ("p", `String (Peer.to_multiaddr_string peer))
                   ; ( "knowledge"
                     , match k with
                       | `All ->
                           `String "all"
                       | `Call _ ->
                           `String "call"
                       | `Some xs ->
                           `List (List.map xs ~f:Key.to_yojson) ) ]
                 "knowledge" ;
               Useful_peers.update t.useful_peers
                 (Knowledge
                    { out_of_band= false
                    ; peer
                    ; claimed= k
                    ; active_jobs= active_jobs t })) )
      |> don't_wait_for
    in
    don't_wait_for (step t) ;
    upon stop (fun () -> tear_down t) ;
    every ~stop (Time.Span.of_sec 10.) (fun () ->
        [%log' debug t.logger]
          ~metadata:[("jobs", to_yojson t)]
          "Downloader jobs" ) ;
    refresh_peers t peers ;
    t

  (* After calling download, if no one else has called within time [max_wait], 
       we flush our queue. *)
  let download t ~key ~attempts : Job.t =
    match (Q.lookup t.pending key, Hashtbl.find t.downloading key) with
    | Some _, Some _ ->
        assert false
    | Some x, None | None, Some (_, x) ->
        x
    | None, None ->
        flush_soon t ;
        let e = {J.key; attempts; res= Ivar.create ()} in
        enqueue_exn t e ;
        Useful_peers.update t.useful_peers (New_job e) ;
        e
end
