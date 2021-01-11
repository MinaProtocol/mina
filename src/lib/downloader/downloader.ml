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
  type t

  val download : t
end) (Result : sig
  type t [@@deriving to_yojson]

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

    let to_yojson ({key; _} : t) = Key.to_yojson key

    let result = Job.result
  end

  module Q = struct
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

    let enqueue t (e : Job.t) =
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

    let enqueue_exn t e =
      match enqueue t e with
      | `Key_already_present ->
          failwith "key already present"
      | `Ok ->
          ()

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

  module Useful_peers = struct
    type t =
      { all: Key.Hash_set.t Peer.Table.t
      ; preferred: Peer.Hash_set.t
      ; r: (Peer.t * Key.Hash_set.t) Strict_pipe.Reader.t sexp_opaque
      ; w:
          ( Peer.t * Key.Hash_set.t
          , Strict_pipe.drop_head Strict_pipe.buffered
          , unit )
          Strict_pipe.Writer.t
          sexp_opaque }
    [@@deriving sexp]

    let create ~preferred ~all_peers =
      let all = Peer.Table.create () in
      List.iter all_peers ~f:(fun p ->
          Hashtbl.set all ~key:p ~data:(Key.Hash_set.create ()) ) ;
      let r, w =
        Strict_pipe.create ~name:"useful_peers"
          (Buffered (`Capacity 4096, `Overflow Drop_head))
      in
      Hashtbl.iteri all ~f:(fun ~key ~data ->
          Strict_pipe.Writer.write w (key, data) ) ;
      {all; r; w; preferred= Peer.Hash_set.of_list preferred}

    let tear_down {all; r= _; w; preferred} =
      Hashtbl.iter all ~f:Hash_set.clear ;
      Hashtbl.clear all ;
      Hash_set.clear preferred ;
      Strict_pipe.Writer.close w

    let read t =
      match%bind Strict_pipe.Reader.read' t.r with
      | `Eof ->
          return `Eof
      | `Ok q -> (
          Queue.filter_inplace q ~f:(fun (p, s) ->
              (not (Hash_set.is_empty s)) && Hashtbl.mem t.all p ) ;
          let preferred =
            Queue.find q ~f:(fun (p, _) -> Hash_set.mem t.preferred p)
          in
          match preferred with
          | Some ((p, _) as res) ->
              Queue.iter q ~f:(fun ((p', _) as x) ->
                  if not (Peer.equal p p') then Strict_pipe.Writer.write t.w x
              ) ;
              return (`Ok res)
          | None ->
              let res = Queue.dequeue_exn q in
              Queue.iter q ~f:(Strict_pipe.Writer.write t.w) ;
              return (`Ok res) )

    type update =
      | New_job of {new_job: Job.t; all_peers: Peer.Set.t}
      | New_peers of
          { new_peers: Peer.Set.t
          ; lost_peers: Peer.Set.t
          ; pending: Job.t Q.t }
      | Download_finished of Peer.t * Key.t list * bool
      | Job_cancelled of Key.t

    let replace t peer =
      match Hashtbl.find t.all peer with
      | None ->
          ()
      | Some s ->
          Strict_pipe.Writer.write t.w (peer, s)

    let update t u =
      match u with
      | Job_cancelled h ->
          Hashtbl.filter_inplace t.all ~f:(fun s ->
              Hash_set.remove s h ; Hash_set.is_empty s )
      | Download_finished (peer, hs, success) -> (
          if success then Hash_set.add t.preferred peer ;
          match Hashtbl.find t.all peer with
          | None ->
              ()
          | Some s ->
              List.iter hs ~f:(Hash_set.remove s) ;
              if Hash_set.is_empty s then Hashtbl.remove t.all peer
              else Strict_pipe.Writer.write t.w (peer, s) )
      | New_peers {new_peers; lost_peers; pending} ->
          Set.iter lost_peers ~f:(fun p ->
              match Hashtbl.find t.all p with
              | None ->
                  ()
              | Some s ->
                  Hash_set.clear s ;
                  Hashtbl.remove t.all p ;
                  Hash_set.remove t.preferred p ) ;
          Set.iter new_peers ~f:(fun p ->
              if not (Hashtbl.mem t.all p) then (
                let to_try = Key.Hash_set.create () in
                Q.iter pending ~f:(fun j ->
                    if not (Map.mem j.attempts p) then
                      Hash_set.add to_try j.key ) ;
                Hashtbl.add_exn t.all ~key:p ~data:to_try ;
                Strict_pipe.Writer.write t.w (p, to_try) ) )
      | New_job {new_job; all_peers} ->
          Hash_set.filter_inplace t.preferred ~f:(Peer.Set.mem all_peers) ;
          Set.iter all_peers ~f:(fun p ->
              let useful_for_job = not (Map.mem new_job.attempts p) in
              if useful_for_job then
                match Hashtbl.find t.all p with
                | Some s ->
                    Hash_set.add s new_job.key
                | None ->
                    let s = Key.Hash_set.of_list [new_job.key] in
                    Hashtbl.add_exn t.all ~key:p ~data:s ;
                    Strict_pipe.Writer.write t.w (p, s) )
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
            (fun () -> Strict_pipe.Writer.write t.flush_w ())
            ())

  let cancel t h =
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

  (* TODO: rewrite as "enqueue_all" *)
  let enqueue t e =
    if is_stalled t e then Q.enqueue t.stalled e
    else
      let r = Q.enqueue t.pending e in
      ( match r with
      | `Key_already_present ->
          ()
      | `Ok ->
          Useful_peers.update t.useful_peers
            (New_job {new_job= e; all_peers= t.all_peers}) ) ;
      r

  let enqueue_exn t e = assert (enqueue t e = `Ok)

  let refresh_peers t =
    let%map peers = t.peers () in
    let peers' = Peer.Set.of_list peers in
    let new_peers = Set.diff peers' t.all_peers in
    let lost_peers = Set.diff t.all_peers peers' in
    Useful_peers.update t.useful_peers
      (New_peers {new_peers; lost_peers; pending= t.pending}) ;
    if not (Set.is_empty new_peers) then
      Strict_pipe.Writer.write t.got_new_peers_w () ;
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

  let make_peer_available t p =
    if Set.mem t.all_peers p then Useful_peers.replace t.useful_peers p

  let reader r = (Strict_pipe.Reader.to_linear_pipe r).pipe

  let download t peer xs =
    let hs = List.map xs ~f:(fun x -> x.J.key) in
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
          ; ("keys", `List (List.map hs ~f:Key.to_yojson)) ] ;
      (* TODO: Log error *)
      List.iter xs ~f:(fun x ->
          enqueue_exn t
            { x with
              attempts= Map.set x.attempts ~key:peer ~data:Attempt.download }
      ) ;
      flush_soon t
    in
    List.iter xs ~f:(fun x ->
        Hashtbl.add_exn t.downloading ~key:x.key ~data:(peer, x) ) ;
    let%map res =
      Deferred.choose
        [ Deferred.choice (t.get peer hs) (fun x -> `Not_stopped x)
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
    | `Not_stopped r ->
        let success = ref false in
        ( match r with
        | Error e ->
            fail e
        | Ok rs ->
            [%log' debug t.logger] "result is $result"
              ~metadata:[("result", `List (List.map rs ~f:Result.to_yojson))] ;
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
                    success := true ;
                    job_finished t j
                      (Ok
                         ( { Envelope.Incoming.data= r
                           ; received_at
                           ; sender= Remote peer }
                         , j.attempts )) ) ;
            (* These we did not get results for :( *)
            Hashtbl.iter jobs ~f:(fun x ->
                Hashtbl.remove t.downloading x.J.key ;
                enqueue_exn t
                  { x with
                    attempts=
                      Map.set x.attempts ~key:peer ~data:Attempt.download } ) ;
            flush_soon t ) ;
        Useful_peers.update t.useful_peers
          (Download_finished (peer, hs, !success))

  let is_empty t = Q.is_empty t.pending && Q.is_empty t.stalled

  let all_stalled t = Q.is_empty t.pending

  let rec step t =
    if is_empty t then (
      match%bind Strict_pipe.Reader.read t.flush_r with
      | `Eof ->
          [%log' debug t.logger] "Downloader: flush eof" ;
          Deferred.unit
      | `Ok () ->
          [%log' debug t.logger] "Downloader: flush" ;
          step t )
    else if all_stalled t then (
      [%log' debug t.logger] "Downloader: all stalled" ;
      (* TODO: Put a log here *)
      match%bind
        choose
          [ Pipe.read_choice_single_consumer_exn (reader t.flush_r) [%here]
          ; Pipe.read_choice_single_consumer_exn (reader t.got_new_peers_r)
              [%here] ]
      with
      | `Ok () ->
          [%log' debug t.logger] "Downloader: keep going" ;
          step t
      | `Eof ->
          [%log' debug t.logger] "Downloader: other eof" ;
          Deferred.unit )
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
      | `Ok (peer, _hs) -> (
          [%log' debug t.logger] "Downloader: got $peer"
            ~metadata:[("peer", Peer.to_yojson peer)] ;
          let to_download =
            let rec go n acc skipped =
              if n >= t.max_batch_size then acc
              else
                match Q.dequeue t.pending with
                | None ->
                    (* We can just enqueue directly into pending without going thru
                    enqueue_exn since we know these skipped jobs are not stalled*)
                    List.iter (List.rev skipped) ~f:(Q.enqueue_exn t.pending) ;
                    List.rev acc
                | Some x ->
                    if Map.mem x.attempts peer then go n acc (x :: skipped)
                    else go (n + 1) (x :: acc) skipped
            in
            go 0 [] []
          in
          [%log' debug t.logger] "Downloader: to download $n"
            ~metadata:[("n", `Int (List.length to_download))] ;
          match to_download with
          | [] ->
              make_peer_available t peer ; step t
          | _ :: _ ->
              don't_wait_for (download t peer to_download) ;
              step t ) )

  let to_yojson t : Yojson.Safe.t =
    check_invariant t ;
    let list xs =
      `Assoc [("length", `Int (List.length xs)); ("elts", `List xs)]
    in
    let f q = list (List.map ~f:Job.to_yojson (Q.to_list q)) in
    `Assoc
      [ ("total_jobs", `Int (total_jobs t))
      ; ("pending", f t.pending)
      ; ("stalled", f t.stalled)
      ; ( "downloading"
        , list
            (List.map (Hashtbl.to_alist t.downloading) ~f:(fun (h, (p, _)) ->
                 `Assoc
                   [ ("hash", Key.to_yojson h)
                   ; ("peer", `String (Peer.to_multiaddr_string p)) ] )) ) ]

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
        enqueue_exn t e ; e
end
