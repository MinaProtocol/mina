open Async
open Core
open Pipe_lib
open Network_peer

module Job = struct
  type ('key, 'attempt, 'a) t =
    { key: 'key
    ; attempts: 'attempt Peer.Map.t
    ; res:
        ('a Envelope.Incoming.t * 'attempt Peer.Map.t, [`Finished]) Result.t
        Ivar.t }

  let result t = Ivar.read t.res
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
    -> peers:(unit -> Peer.t list Deferred.t)
    -> preferred:Peer.t list
    -> t Deferred.t

  val download : t -> key:Key.t -> attempts:Attempt.t Peer.Map.t -> Job.t

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

    let clear t =
      Hashtbl.clear t.table ;
      Doubly_linked.clear t.queue

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

    let enqueue_exn t e = assert (enqueue t e = `Ok)

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

    let is_empty t = Doubly_linked.is_empty t.queue

    let to_list t = List.map (Doubly_linked.to_list t.queue) ~f:Key_value.value

    let create () = {table= Key.Table.create (); queue= Doubly_linked.create ()}
  end

  module Q = Make_hash_queue (Key)

  module Useful_peers = struct
    module Peer_queue = Make_hash_queue (Peer)

    module Available_and_useful = struct
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
        else
          let s = if preferred then t.preferred else t.non_preferred in
          Hashtbl.add s ~key:p ~data:v
    end

    type t =
      { available_and_useful: Available_and_useful.t
      ; downloading_peers: Peer.Hash_set.t
      ; downloading_keys: Key.Hash_set.t
      ; all_preferred: Peer.Hash_set.t
      ; knowledge: Key.Hash_set.t Peer.Table.t
            (* Written to when something changes. *)
      ; r: unit Strict_pipe.Reader.t sexp_opaque
      ; w:
          ( unit
          , Strict_pipe.drop_head Strict_pipe.buffered
          , unit )
          Strict_pipe.Writer.t
          sexp_opaque }
    [@@deriving sexp]

    let reset_knowledge t ~all_peers ~preferred ~active_jobs =
      (* Clear knowledge *)
      Hashtbl.clear t.knowledge ;
      (* Reset preferred *)
      Hash_set.clear t.all_preferred ;
      List.iter preferred ~f:(Hash_set.add t.all_preferred) ;
      (* Clear availability state *)
      Available_and_useful.clear t.available_and_useful ;
      (* Reset availability state *)
      Set.iter all_peers ~f:(fun p ->
          let to_try =
            let to_try = Key.Hash_set.create () in
            List.iter active_jobs ~f:(fun (j : Job.t) ->
                match Map.find j.attempts p with
                | None ->
                    Hash_set.add to_try j.key
                | Some a ->
                    if Attempt.worth_retrying a then Hash_set.add to_try j.key
                    else () ) ;
            to_try
          in
          Peer.Table.add t.knowledge ~key:p ~data:to_try |> ignore ;
          if not (Hash_set.mem t.downloading_peers p) then
            Available_and_useful.add t.available_and_useful p
              (Hash_set.diff to_try t.downloading_keys)
              ~preferred:(Hash_set.mem t.all_preferred p)
            |> ignore ) ;
      Strict_pipe.Writer.write t.w ()

    let to_yojson {knowledge; all_preferred; available_and_useful; _} =
      `Assoc
        [ ( "all"
          , `Assoc
              (List.map (Hashtbl.to_alist knowledge) ~f:(fun (p, s) ->
                   (Peer.to_multiaddr_string p, `Int (Hash_set.length s)) )) )
        ; ( "preferred"
          , `List
              (List.map (Hash_set.to_list all_preferred) ~f:(fun p ->
                   `String (Peer.to_multiaddr_string p) )) )
        ; ( "available_and_useful"
          , `List
              (List.map
                 ( Hashtbl.keys available_and_useful.preferred
                 @ Hashtbl.keys available_and_useful.non_preferred )
                 ~f:(fun p -> `String (Peer.to_multiaddr_string p))) ) ]

    let create ~preferred ~all_peers =
      let knowledge = Peer.Table.create () in
      let available_and_useful = Available_and_useful.create () in
      let preferred = Peer.Hash_set.of_list preferred in
      List.iter all_peers ~f:(fun p ->
          Peer.Table.add knowledge ~key:p ~data:(Key.Hash_set.create ())
          |> ignore ;
          Available_and_useful.add available_and_useful p
            (Key.Hash_set.create ()) ~preferred:(Hash_set.mem preferred p)
          |> ignore ) ;
      let r, w =
        Strict_pipe.create ~name:"useful_peers-available"
          (Buffered (`Capacity 0, `Overflow Drop_head))
      in
      { available_and_useful
      ; downloading_peers= Peer.Hash_set.create ()
      ; downloading_keys= Key.Hash_set.create ()
      ; knowledge
      ; r
      ; w
      ; all_preferred= preferred }

    let tear_down
        { available_and_useful
        ; downloading_peers
        ; downloading_keys
        ; knowledge
        ; r= _
        ; w
        ; all_preferred } =
      Hash_set.clear downloading_peers ;
      Hash_set.clear downloading_keys ;
      Hashtbl.iter knowledge ~f:Hash_set.clear ;
      Hashtbl.clear knowledge ;
      Hash_set.clear all_preferred ;
      Available_and_useful.clear available_and_useful ;
      Strict_pipe.Writer.close w

    (* TODO: Still not right somehow *)
    let rec read t =
      match Available_and_useful.get t.available_and_useful with
      | Some r ->
          return (`Ok r)
      | None -> (
          match%bind Strict_pipe.Reader.read t.r with
          | `Eof ->
              return `Eof
          | `Ok () ->
              read t )

    type update =
      | New_job of Job.t
      | Refreshed_peers of {all_peers: Peer.Set.t; active_jobs: Key.Hash_set.t}
      | Download_finished of
          Peer.t * [`Successful of Key.t list] * [`Unsuccessful of Key.t list]
      | Download_starting of Peer.t * Key.t list
      | Job_cancelled of Key.t

    let jobs_no_longer_needed t ks =
      Hashtbl.iter t.knowledge ~f:(fun s -> List.iter ks ~f:(Hash_set.remove s)) ;
      Available_and_useful.filter_inplace t.available_and_useful
        ~f:(fun to_try ->
          List.iter ~f:(Hash_set.remove to_try) ks ;
          not (Hash_set.is_empty to_try) )

    let update t u =
      match u with
      | Job_cancelled h ->
          jobs_no_longer_needed t [h] ;
          Hashtbl.iter t.knowledge ~f:(fun s -> Hash_set.remove s h)
      | Download_starting (peer, ks) ->
          (* WHen a download starts for a job, we should remove all peers from
           available and useful whose only useful jobs are in downloading.. *)
          Hash_set.add t.downloading_peers peer ;
          List.iter ks ~f:(Hash_set.add t.downloading_keys) ;
          Available_and_useful.remove t.available_and_useful peer ;
          Available_and_useful.don't_need_keys t.available_and_useful ks
      | Download_finished (peer0, `Successful succs, `Unsuccessful unsuccs) ->
          if not (List.is_empty succs) then Hash_set.add t.all_preferred peer0 ;
          Hash_set.remove t.downloading_peers peer0 ;
          List.iter ~f:(Hash_set.remove t.downloading_keys) unsuccs ;
          jobs_no_longer_needed t succs ;
          ( match Hashtbl.find t.knowledge peer0 with
          | None ->
              ()
          | Some to_try ->
              List.iter unsuccs ~f:(Hash_set.remove to_try) ;
              let s = Hash_set.diff to_try t.downloading_keys in
              Available_and_useful.add t.available_and_useful peer0 s
                ~preferred:(Hash_set.mem t.all_preferred peer0)
              |> ignore ) ;
          (* Update the things in "available_and_useful" with the jobs that are now available. *)
          (* Move things over from "t.knowledge" into available_and_useful if they are now available and useful *)
          Hashtbl.iteri t.knowledge ~f:(fun ~key:peer ~data:to_try ->
              if not (Hash_set.mem t.downloading_peers peer) then
                match
                  Available_and_useful.find t.available_and_useful peer
                with
                | Some s ->
                    List.iter unsuccs ~f:(fun k ->
                        if Hash_set.mem to_try k then Hash_set.add s k )
                | None ->
                    let s = Hash_set.diff to_try t.downloading_keys in
                    Available_and_useful.add t.available_and_useful peer s
                      ~preferred:(Hash_set.mem t.all_preferred peer)
                    |> ignore )
      | Refreshed_peers {all_peers; active_jobs} ->
          Available_and_useful.filter_keys_inplace t.available_and_useful
            ~f:(Set.mem all_peers) ;
          Hashtbl.filter_keys_inplace t.knowledge ~f:(Set.mem all_peers) ;
          Set.iter all_peers ~f:(fun p ->
              if not (Hashtbl.mem t.knowledge p) then
                ( Hashtbl.add_exn t.knowledge ~key:p
                    ~data:(Hash_set.copy active_jobs) ;
                  Available_and_useful.add t.available_and_useful p
                    (Hash_set.diff active_jobs t.downloading_keys)
                    ~preferred:(Hash_set.mem t.all_preferred p) )
                |> ignore )
      | New_job new_job ->
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

    let update t u : unit =
      update t u ;
      if not (Strict_pipe.Writer.is_closed t.w) then
        Strict_pipe.Writer.write t.w ()
  end

  type t =
    { mutable next_flush: (unit, unit) Clock.Event.t option
    ; mutable all_peers: Peer.Set.t
    ; pending: Job.t Q.t
    ; stalled: Job.t Q.t
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
    ; peers: unit -> Peer.t list Deferred.t
    ; max_batch_size: int
    ; preferred: Peer.t list
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

  let total_jobs (t : t) =
    Q.length t.pending + Q.length t.stalled + Hashtbl.length t.downloading

  (* Checks disjointness *)
  let check_invariant (t : t) =
    Set.length
      (Key.Set.union_list
         [ Q.to_list t.pending
           |> List.map ~f:(fun j -> j.key)
           |> Key.Set.of_list
         ; Q.to_list t.stalled
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
        ; lazy (Q.lookup t.stalled h)
        ; lazy (Option.map ~f:snd (Hashtbl.find t.downloading h)) ]
    in
    Q.remove t.pending h ;
    Q.remove t.stalled h ;
    Hashtbl.remove t.downloading h ;
    match job with
    | None ->
        ()
    | Some j ->
        kill_job t j ;
        Useful_peers.update t.useful_peers (Job_cancelled h)

  let is_stalled t e = Set.for_all t.all_peers ~f:(Map.mem e.J.attempts)

  let enqueue t e =
    if is_stalled t e then Q.enqueue t.stalled e else Q.enqueue t.pending e

  let enqueue_exn t e = assert (enqueue t e = `Ok)

  let active_job_keys t =
    let res = Key.Hash_set.create () in
    Q.iter t.pending ~f:(fun j -> Hash_set.add res j.key) ;
    Q.iter t.stalled ~f:(fun j -> Hash_set.add res j.key) ;
    Hashtbl.iter_keys t.downloading ~f:(Hash_set.add res) ;
    res

  let active_jobs t =
    Q.to_list t.pending @ Q.to_list t.stalled
    @ List.map (Hashtbl.data t.downloading) ~f:snd

  let refresh_peers t =
    let%map peers = t.peers () in
    let peers' = Peer.Set.of_list peers in
    let new_peers = Set.diff peers' t.all_peers in
    Useful_peers.update t.useful_peers
      (Refreshed_peers {all_peers= peers'; active_jobs= active_job_keys t}) ;
    if
      (not (Set.is_empty new_peers))
      && not (Strict_pipe.Writer.is_closed t.got_new_peers_w)
    then Strict_pipe.Writer.write t.got_new_peers_w () ;
    t.all_peers <- Peer.Set.of_list peers ;
    let rec go n =
      (* We need the initial length explicitly because we may re-enqueue things
           while looping. *)
      if n = 0 then ()
      else
        match Q.dequeue t.stalled with
        | None ->
            ()
        | Some e ->
            enqueue_exn t e ;
            go (n - 1)
    in
    go (Q.length t.stalled)

  let peer_refresh_interval = Time.Span.of_min 1.

  let tear_down
      ( { next_flush
        ; all_peers= _
        ; flush_w
        ; peers= _
        ; get= _
        ; got_new_peers_w
        ; flush_r= _
        ; useful_peers
        ; got_new_peers_r= _
        ; pending
        ; stalled
        ; preferred= _
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
    clear_queue pending ;
    clear_queue stalled

  let download t peer xs =
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
      match r with
      | Error e ->
          fail e
      | Ok rs ->
          [%log' debug t.logger] "result is $result"
            ~metadata:[("result", `Int (List.length rs))] ;
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
                  attempts= Map.set x.attempts ~key:peer ~data:Attempt.download
                } ) ;
          flush_soon t )

  let is_empty t = Q.is_empty t.pending && Q.is_empty t.stalled

  let all_stalled t = Q.is_empty t.pending

  let to_yojson t : Yojson.Safe.t =
    check_invariant t ;
    let list xs = `Assoc [("length", `Int (List.length xs))] in
    let f q = list (List.map ~f:Job.to_yojson (Q.to_list q)) in
    `Assoc
      [ ("total_jobs", `Int (total_jobs t))
      ; ("useful_peers", Useful_peers.to_yojson t.useful_peers)
      ; ("pending", f t.pending)
      ; ("stalled", f t.stalled)
      ; ( "downloading"
        , list
            (List.map (Hashtbl.to_alist t.downloading) ~f:(fun (h, (p, _)) ->
                 `Assoc
                   [ ("hash", Key.to_yojson h)
                   ; ("peer", `String (Peer.to_multiaddr_string p)) ] )) ) ]

  let post_stall_retry_delay = Time.Span.of_min 1.

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
              ; ("to_download", f to_download) ] ;
          match to_download with
          | [] ->
              step t
          | _ :: _ ->
              don't_wait_for (download t peer to_download) ;
              step t ) )

  let create ~max_batch_size ~stop ~trust_system ~get ~peers ~preferred =
    let%map all_peers = peers () in
    let pipe ~name c =
      Strict_pipe.create ~name (Buffered (`Capacity c, `Overflow Drop_head))
    in
    let flush_r, flush_w = pipe ~name:"flush" 0 in
    let got_new_peers_r, got_new_peers_w = pipe ~name:"got_new_peers" 0 in
    let t =
      { all_peers= Peer.Set.of_list all_peers
      ; pending= Q.create ()
      ; stalled= Q.create ()
      ; next_flush= None
      ; flush_r
      ; flush_w
      ; got_new_peers_r
      ; got_new_peers_w
      ; useful_peers= Useful_peers.create ~all_peers ~preferred
      ; preferred
      ; get
      ; peers
      ; max_batch_size
      ; logger= Logger.create ()
      ; trust_system
      ; downloading= Key.Table.create ()
      ; stop }
    in
    don't_wait_for (step t) ;
    upon stop (fun () -> tear_down t) ;
    every ~stop (Time.Span.of_sec 10.) (fun () ->
        [%log' debug t.logger]
          ~metadata:[("jobs", to_yojson t)]
          "Downloader jobs" ) ;
    Clock.every' ~stop peer_refresh_interval (fun () -> refresh_peers t) ;
    t

  (* After calling download, if no one else has called within time [max_wait], 
       we flush our queue. *)
  let download t ~key ~attempts : Job.t =
    match
      ( Q.lookup t.pending key
      , Q.lookup t.stalled key
      , Hashtbl.find t.downloading key )
    with
    | Some _, Some _, Some _
    | None, Some _, Some _
    | Some _, None, Some _
    | Some _, Some _, None ->
        assert false
    | Some x, None, None | None, Some x, None | None, None, Some (_, x) ->
        x
    | None, None, None ->
        flush_soon t ;
        let e = {J.key; attempts; res= Ivar.create ()} in
        enqueue_exn t e ;
        Useful_peers.update t.useful_peers (New_job e) ;
        e
end
