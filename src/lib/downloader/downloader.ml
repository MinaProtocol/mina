open Async
open Core
open Pipe_lib
open Network_peer

module Job = struct
  type ('key, 'attempt, 'a) t =
    { key : 'key
    ; attempts : 'attempt Peer.Map.t
    ; res :
        ('a Envelope.Incoming.t * 'attempt Peer.Map.t, [ `Finished ]) Result.t
        Ivar.t
    }

  let to_yojson ~key ~attempt (t : _ t) : Yojson.Safe.t =
    `Assoc
      [ ("key", key t.key)
      ; ( "attempts"
        , `Assoc
            (List.map (Map.to_alist t.attempts) ~f:(fun (p, a) ->
                 (Peer.to_multiaddr_string p, attempt a) ) ) )
      ]

  let result t = Ivar.read t.res
end

let sample_k_from_list lst k =
  let arr = Array.of_list lst in
  let len = Array.length arr in
  let k = min k len in
  for i = 0 to k - 1 do
    let j = i + Random.int (len - i) in
    let temp = arr.(i) in
    arr.(i) <- arr.(j) ;
    arr.(j) <- temp
  done ;
  Array.sub arr ~pos:0 ~len:k |> Array.to_list

module Yojson' = struct
  module List = struct
    let chunked (type a) ~(f : a -> Yojson.Safe.t) ~(limit : int) (l : a list) :
        Yojson.Safe.t =
      let len = List.length l in
      let representatives =
        if limit >= len then l else sample_k_from_list l limit
      in
      `Assoc
        [ ("length", `Int len)
        ; ("representatives", `List (List.map ~f representatives))
        ]

    let with_length ~f l : Yojson.Safe.t =
      `Assoc
        [ ("length", `Int (List.length l)); ("elts", `List (List.map ~f l)) ]
  end
end

(** What a peer claims to know, as reported during a knowledge-refresh query.
    This is the positive side of a peer's knowledge: it describes which keys the
    peer asserts it can serve.  The negative side (keys we tried and the peer
    couldn't deliver) is tracked separately in [Knowledge.tried_and_failed].

    The three variants reflect how precise the peer's self-report is:
    - [`All]      – the peer claims to have every key; no enumeration needed.
    - [`Some ks]  – the peer returned an explicit list of keys it holds.
    - [`Call f]   – knowledge is encoded as a predicate, used when the caller
                    merges an incoming [`Some] list on top of an existing [`Call]
                    (see [Useful_peers.update / Add_knowledge]). *)
module Claimed_knowledge = struct
  type 'key t =
    [ `All
    | `Some of 'key list [@to_yojson fun f -> Yojson'.List.chunked ~f]
    | `Call of
      ('key -> bool[@sexp.opaque] [@to_yojson fun _ -> `String "<opaque>"]) ]
  [@@deriving sexp_of, to_yojson]

  let to_yojson f t =
    match t with
    | `Some keys ->
        Yojson'.List.chunked ~f ~limit:5 keys
    | _ ->
        to_yojson f t

  (** [check ~equal t k] returns [true] iff this claimed knowledge covers key [k].
      - [`All]    always returns [true].
      - [`Some ks] does a linear membership test using [equal].
      - [`Call f] delegates to the stored predicate. *)
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
end) =
struct
  let max_wait = Time.Span.of_ms 100.

  type job = (Key.t, Attempt.t, Result.t) Job.t

  (** Per-peer knowledge record: what a peer claims to have ([claimed]) minus
      what we have empirically learned it cannot deliver ([tried_and_failed]).

      The two fields form a two-layer filter used by [knows]:
      - [tried_and_failed] is the authoritative negative evidence — real download
        attempts that the peer failed and that are not worth retrying.  It
        overrides whatever [claimed] says.
      - [claimed] is the peer's self-reported positive knowledge.  [None] means
        we have never queried this peer; a [Some] value comes from a
        knowledge-refresh response (see [Useful_peers.update / Knowledge]).

      A fresh record (from [create]) starts with [claimed = None] and an empty
      [tried_and_failed], meaning the peer is a complete unknown — treated as a
      low-priority candidate rather than excluded outright. *)
  module Knowledge = struct
    type t =
      { claimed : Key.t Claimed_knowledge.t option
      ; tried_and_failed : Key.Set.t
            [@to_yojson fun t -> `List (List.map Key.to_yojson (Set.to_list t))]
      }
    [@@deriving sexp_of, to_yojson]

    let empty = { claimed = None; tried_and_failed = Key.Set.empty }

    (** [knows t k] answers whether this peer is expected to have key [k].

        Returns:
        - [`No]           – [k] is in [tried_and_failed] (empirical failure), or
                            the peer's [claimed] set explicitly excludes [k].
        - [`No_information] – [claimed] is [None]; we have never queried the peer.
                              The peer is still a candidate with a small score bonus.
        - [`Claims_to]    – [k] passes [Claimed_knowledge.check] on [claimed].

        [tried_and_failed] is checked first and takes precedence over [claimed]. *)
    let knows t k =
      if Set.mem t.tried_and_failed k then `No
      else
        match t.claimed with
        | None ->
            `No_information
        | Some claimed when Claimed_knowledge.check ~equal:Key.equal claimed k
          ->
            `Claims_to
        | _ ->
            `No
  end

  (** Tracks which peers are candidates for the next download batch and what
      each peer is believed to know.

      The module has two responsibilities:
      1. **State maintenance** – mutated via [update] as downloads start/finish,
         knowledge-refresh responses arrive, and the peer set changes.
      2. **Peer selection** – [useful_peer] reads the accumulated state and
         returns the single best available peer for the current pending queue,
         or a signal explaining why no peer can be selected right now.

      The [r]/[w] strict pipe is an internal wakeup channel: every [update] call
      writes a unit to [w] so that the downloader loop, which may be blocked
      reading [r], wakes up and re-evaluates peer selection. *)
  module Useful_peers = struct
    (** Priority queue of peers that have recently delivered at least one
        successful result.  Preferred peers are tried before ordinary peers in
        [useful_peer].  A peer enters this set on a successful [Download_finished]
        and is evicted when [reset_knowledge] is called (stall recovery). *)
    module Preferred_peers = struct
      include
        Mina_stdlib.Job_pool.Make
          (Peer)
          (struct
            include Peer

            let id = Fn.id
          end)

      let sexp_of_t (t : t) =
        Sexp.List
          ( to_list t
          |> List.map ~f:(fun { job; scheduled } ->
                 [%sexp_of: Peer.t * Time.t] (job, scheduled) ) )
    end

    (** State held for the full peer pool.

        - [knowledge]                  – per-peer [Knowledge.t]; the primary
                                         data structure for peer selection.
        - [downloading_peers]          – peers with an in-flight download; excluded
                                         from selection until the download completes.
        - [knowledge_requesting_peers] – peers currently being queried for knowledge;
                                         excluded from selection to avoid redundant
                                         concurrent queries.
        - [temporary_ignores]          – peers that returned zero successes on their
                                         last download; each entry holds a [Clock.Event]
                                         that removes the peer after [ignore_period]
                                         (2 min) and signals [w].
        - [all_preferred]              – [Preferred_peers] priority queue; these peers
                                         are placed at the front of the candidate list
                                         in [useful_peer].
        - [r]/[w]                      – drop-head buffered pipe of capacity 0; written
                                         on every state change so blocked consumers
                                         wake up exactly once per batch of changes. *)
    type t =
      { downloading_peers : Peer.Hash_set.t
      ; knowledge_requesting_peers : Peer.Hash_set.t
      ; temporary_ignores :
          ((unit, unit) Clock.Event.t[@sexp.opaque]) Peer.Table.t
      ; mutable all_preferred : Preferred_peers.t
      ; knowledge : Knowledge.t Peer.Table.t
            (* Written to when something changes. *)
      ; r : (unit Strict_pipe.Reader.t[@sexp.opaque])
      ; w :
          (( unit
           , Strict_pipe.drop_head Strict_pipe.buffered
           , unit )
           Strict_pipe.Writer.t
          [@sexp.opaque] )
      }
    [@@deriving sexp_of]

    (** [reset_knowledge t ~all_peers] performs a full stall-recovery reset:
        - Clears [all_preferred] so no peer has priority advantage.
        - For every peer in [knowledge]: clears [tried_and_failed] and sets
          [claimed = None], making all keys eligible for retry.
        - Removes knowledge entries for peers no longer in [all_peers].
        - Adds blank [Knowledge.t] entries for any new peers in [all_peers].
        - Signals [w] to wake the downloader loop.

        Called by [step] when [useful_peer] returns [`Stalled]. *)
    let reset_knowledge t ~all_peers =
      (* Reset preferred *)
      t.all_preferred <- Preferred_peers.create () ;
      Hashtbl.filter_mapi_inplace t.knowledge ~f:(fun ~key:p ~data:_ ->
          if Set.mem all_peers p then Some Knowledge.empty else None ) ;
      Set.iter all_peers ~f:(fun p ->
          if not (Hashtbl.mem t.knowledge p) then
            Hashtbl.add_exn t.knowledge ~key:p ~data:Knowledge.empty ) ;
      Strict_pipe.Writer.write t.w ()

    let to_yojson
        { knowledge
        ; all_preferred
        ; knowledge_requesting_peers
        ; temporary_ignores
        ; downloading_peers
        ; r = _
        ; w = _
        } =
      let list xs =
        `Assoc [ ("length", `Int (List.length xs)); ("elts", `List xs) ]
      in
      let f q = Knowledge.to_yojson q in
      `Assoc
        [ ( "all"
          , `Assoc
              (List.map (Hashtbl.to_alist knowledge) ~f:(fun (p, s) ->
                   (Peer.to_multiaddr_string p, f s) ) ) )
        ; ( "preferred"
          , `List
              (List.map (Preferred_peers.to_list all_preferred)
                 ~f:(fun { job = peer; _ } ->
                   `String (Peer.to_multiaddr_string peer) ) ) )
        ; ( "temporary_ignores"
          , list (List.map ~f:Peer.to_yojson (Hashtbl.keys temporary_ignores))
          )
        ; ( "downloading_peers"
          , list
              (List.map ~f:Peer.to_yojson (Hash_set.to_list downloading_peers))
          )
        ; ( "knowledge_requesting_peers"
          , list
              (List.map ~f:Peer.to_yojson
                 (Hash_set.to_list knowledge_requesting_peers) ) )
        ]

    (** [create ~preferred ~all_peers] allocates a fresh [Useful_peers.t].
        [all_peers] are registered with blank [Knowledge.t] records.
        [preferred] peers are immediately inserted into [all_preferred] so they
        get priority on the very first selection pass. *)
    let create ~preferred ~all_peers =
      let knowledge =
        Peer.Table.of_alist_exn
          (List.map (List.dedup_and_sort ~compare:Peer.compare all_peers)
             ~f:(fun p -> (p, Knowledge.empty)) )
      in
      let r, w =
        Strict_pipe.create ~name:"useful_peers-available" ~warn_on_drop:false
          (Buffered (`Capacity 0, `Overflow (Drop_head ignore)))
      in
      let all_preferred = Preferred_peers.create () in
      List.iter preferred ~f:(fun peer ->
          ignore (Preferred_peers.replace_now ~job:peer all_preferred : Time.t) ) ;
      { downloading_peers = Peer.Hash_set.create ()
      ; knowledge_requesting_peers = Peer.Hash_set.create ()
      ; temporary_ignores = Peer.Table.create ()
      ; knowledge
      ; r
      ; w
      ; all_preferred
      }

    (** [tear_down t] releases all resources: cancels pending [Clock.Event]
        timers in [temporary_ignores], clears all sets and tables, and closes
        [w] so any reader of [r] sees EOF. *)
    let tear_down
        { downloading_peers
        ; temporary_ignores
        ; knowledge_requesting_peers
        ; knowledge
        ; r = _
        ; w
        ; all_preferred = _
        } =
      Hashtbl.iter temporary_ignores ~f:(fun e ->
          Clock.Event.abort_if_possible e () ) ;
      Hashtbl.clear temporary_ignores ;
      Hash_set.clear downloading_peers ;
      Hash_set.clear knowledge_requesting_peers ;
      Hashtbl.clear knowledge ;
      Strict_pipe.Writer.close w

    (** Aggregated view of a peer's knowledge over all pending jobs, used to
        rank peers in [useful_peer].

        - [claims_to]     – number of pending jobs the peer explicitly claims to have.
        - [no_information] – number of pending jobs for which we have no data.
        - [no]            – number of pending jobs the peer is known not to have
                            (not used in scoring, kept for diagnostics). *)
    module Knowledge_summary = struct
      type t = { no_information : int; no : int; claims_to : int }
      [@@deriving fields]

      (* Score needs revising -- should be more lexicographic *)
      let score { no_information; no = _; claims_to } =
        Float.of_int claims_to +. (0.1 *. Float.of_int no_information)
    end

    (** [maxes ~compare xs] returns all elements of [xs] that are tied for the
        maximum according to [compare], preserving their relative order. *)
    let maxes ~compare xs =
      O1trace.sync_thread "compute_downloader_maxes" (fun () ->
          Sequence.fold xs ~init:[] ~f:(fun acc x ->
              match acc with
              | [] ->
                  [ x ]
              | best :: _ ->
                  let c = compare best x in
                  if c = 0 then x :: acc else if c < 0 then [ x ] else acc )
          |> List.rev )

    (** [useful_peer t ~pending_jobs] selects the best available peer to serve
        the current pending queue.

        Selection algorithm:
        1. Build a candidate list with [all_preferred] peers first, then the rest.
        2. Among candidates, find those with the best claim on the *first* pending
           job ([`Claims_to] beats [`No_information]); if any exist, restrict the
           candidate set to them.
        3. Score each remaining candidate across *all* pending jobs using
           [Knowledge_summary.score] and collect the jobs the peer might know.
        4. Exclude peers that are currently in [downloading_peers],
           [knowledge_requesting_peers], or [temporary_ignores].
        5. Return:
           - [`Useful (peer, jobs)] – best available peer and the jobs to send it.
           - [`Useful_but_busy]     – a suitable peer exists but is currently busy;
                                      caller should wait on [t.r].
           - [`Stalled]             – all candidates score 0; caller should call
                                      [reset_knowledge] and retry after a delay.
           - [`No_peers]            – no peers at all in [knowledge]. *)
    let useful_peer t ~pending_jobs =
      O1trace.sync_thread "compute_downloader_useful_peers" (fun () ->
          let ts =
            List.rev
              (Preferred_peers.fold t.all_preferred ~init:[]
                 ~f:(fun acc { job = p; _ } ->
                   match Hashtbl.find t.knowledge p with
                   | None ->
                       acc
                   | Some k ->
                       (p, k) :: acc ) )
            @ Hashtbl.fold t.knowledge ~init:[] ~f:(fun ~key:p ~data:k acc ->
                  if
                    Option.is_empty (Preferred_peers.find t.all_preferred ~id:p)
                  then (p, k) :: acc
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
                    match Knowledge.knows k j.Job.key with
                    | `No ->
                        None
                    | `Claims_to ->
                        Some ((p, k), `Claims_to)
                    | `No_information ->
                        Some ((p, k), `No_information) )
                |> maxes ~compare:(fun (_, c1) (_, c2) ->
                       match (c1, c2) with
                       | `Claims_to, `Claims_to
                       | `No_information, `No_information ->
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
                      ( { Knowledge_summary.no_information = 0
                        ; no = 0
                        ; claims_to = 0
                        }
                      , [] )
                    pending_jobs
                    ~f:(fun (acc, js) j ->
                      let field, js =
                        let open Knowledge_summary.Fields in
                        match Knowledge.knows k j.Job.key with
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
          let useful_exists =
            List.exists knowledge ~f:(fun (_, s) -> Float.(s > 0.))
          in
          let best =
            List.max_elt
              (List.filter knowledge ~f:(fun ((p, _), _) ->
                   (not (Hashtbl.mem t.temporary_ignores p))
                   && (not (Hash_set.mem t.downloading_peers p))
                   && not (Hash_set.mem t.knowledge_requesting_peers p) ) )
              ~compare:(fun (_, s1) (_, s2) -> Float.compare s1 s2)
          in
          match best with
          | None ->
              if useful_exists then `Useful_but_busy else `No_peers
          | Some ((p, k), score) ->
              if Float.(score <= 0.) then `Stalled else `Useful (p, k) )

    (** Events that drive state transitions in [update].

        - [Refreshed_peers]           – the live peer set changed; sync [knowledge].
        - [Download_starting]         – mark peer as busy in [downloading_peers].
        - [Download_finished]         – unmark busy; promote to [all_preferred] on
                                        success, or add to [temporary_ignores] on
                                        total failure; record unsuccessful keys in
                                        [tried_and_failed].
        - [Job_cancelled]             – remove the key from all [tried_and_failed]
                                        sets so it doesn't pollute future queries.
        - [Knowledge_request_starting] – mark peer as busy in
                                         [knowledge_requesting_peers].
        - [Knowledge]                 – full knowledge refresh for a peer; replaces
                                        [claimed] and re-derives [tried_and_failed]
                                        from [active_jobs].
        - [Add_knowledge]             – incremental update; merges new keys into the
                                        peer's existing [claimed] set. *)
    type update =
      | Refreshed_peers of { all_peers : Peer.Set.t }
      | Download_finished of
          Peer.t * [ `Successful of Key.t list ] * [ `Unsuccessful of Key.Set.t ]
      | Download_starting of Peer.t
      | Job_cancelled of Key.t
      | Add_knowledge of
          { peer : Peer.t; claimed : Key.t list; out_of_band : bool }
      | Knowledge_request_starting of Peer.t
      | Knowledge of
          { peer : Peer.t
          ; claimed : Key.t Claimed_knowledge.t
          ; active_jobs : job list
          ; out_of_band : bool
          }

    (** [jobs_no_longer_needed t ks] removes keys [ks] from every peer's
        [tried_and_failed].  Called after successful downloads and job
        cancellations so stale failure records don't prevent future retries on
        unrelated jobs. *)
    let jobs_no_longer_needed t ks =
      Hashtbl.filter_mapi_inplace t.knowledge ~f:(fun ~key:_ ~data ->
          Some
            { data with
              Knowledge.tried_and_failed = Key.Set.diff data.tried_and_failed ks
            } )

    (** Duration a peer is ignored after delivering zero successes. *)
    let ignore_period = Time.Span.of_min 2.

    (** Internal [update] without the wakeup write. *)
    let update t u =
      O1trace.sync_thread "update_downloader" (fun () ->
          match u with
          | Add_knowledge { peer; claimed; out_of_band } ->
              if not out_of_band then
                Hash_set.remove t.knowledge_requesting_peers peer ;
              Hashtbl.update t.knowledge peer ~f:(function
                | None ->
                    { Knowledge.claimed = Some (`Some claimed)
                    ; tried_and_failed = Key.Set.empty
                    }
                | Some k ->
                    let claimed =
                      match k.claimed with
                      | None ->
                          `Some claimed
                      | Some (`Some claimed') ->
                          `Some
                            (List.dedup_and_sort ~compare:Key.compare
                               (claimed' @ claimed) )
                      | Some `All ->
                          `All
                      | Some (`Call f) ->
                          let s = Key.Hash_set.of_list claimed in
                          `Call (fun key -> f key || Hash_set.mem s key)
                    in
                    { k with claimed = Some claimed } )
          | Knowledge_request_starting peer ->
              Hash_set.add t.knowledge_requesting_peers peer
          | Knowledge { peer; claimed; active_jobs; out_of_band } ->
              if not out_of_band then
                Hash_set.remove t.knowledge_requesting_peers peer ;
              let extra_failed =
                List.filter_map active_jobs ~f:(fun j ->
                    match Map.find j.attempts peer with
                    | Some a when Attempt.worth_retrying a ->
                        Some j.key
                    | _ ->
                        None )
                |> Key.Set.of_list
              in
              let update_knowledge = function
                | None ->
                    { Knowledge.claimed = Some claimed
                    ; tried_and_failed = extra_failed
                    }
                | Some { Knowledge.tried_and_failed; _ } ->
                    { Knowledge.claimed = Some claimed
                    ; tried_and_failed =
                        Key.Set.union tried_and_failed extra_failed
                    }
              in

              Hashtbl.update t.knowledge peer ~f:update_knowledge
          | Job_cancelled h ->
              jobs_no_longer_needed t (Key.Set.singleton h) ;
              Hashtbl.filter_mapi_inplace t.knowledge ~f:(fun ~key:_ ~data ->
                  Some
                    { data with
                      Knowledge.tried_and_failed =
                        Set.remove data.tried_and_failed h
                    } )
          | Download_starting peer ->
              Hash_set.add t.downloading_peers peer
          | Download_finished (peer0, `Successful succs, `Unsuccessful unsuccs)
            ->
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
                 ignore
                   ( Preferred_peers.replace_now ~job:peer0 t.all_preferred
                     : Time.t ) ) ) ;
              Hash_set.remove t.downloading_peers peer0 ;
              jobs_no_longer_needed t (Key.Set.of_list succs) ;
              Hashtbl.change t.knowledge peer0 ~f:(function
                | None ->
                    None
                | Some ({ tried_and_failed; _ } as k) ->
                    Some
                      { k with
                        tried_and_failed =
                          Key.Set.union tried_and_failed unsuccs
                      } )
          | Refreshed_peers { all_peers } ->
              Hashtbl.filter_keys_inplace t.knowledge ~f:(Set.mem all_peers) ;
              Set.iter all_peers ~f:(fun p ->
                  if not (Hashtbl.mem t.knowledge p) then
                    Hashtbl.add_exn t.knowledge ~key:p
                      ~data:
                        { Knowledge.claimed = None
                        ; tried_and_failed = Key.Set.empty
                        } ) )

    (** [update t u] applies event [u] to [t] then unconditionally signals [t.w]
        to wake any consumer blocked on [t.r]. *)
    let update t u : unit =
      update t u ;
      if not (Strict_pipe.Writer.is_closed t.w) then
        Strict_pipe.Writer.write t.w ()
  end

  type t =
    { mutable proposed_new_flush_at : Time.t option
    ; mutable flush_scheduled : bool
    ; mutable all_peers : Peer.Set.t
    ; mutable pending : job Key.Map.t
    ; downloading : (Peer.t * job * Time.t) Key.Table.t
    ; useful_peers : Useful_peers.t
    ; flush_r : unit Strict_pipe.Reader.t (* Single reader *)
    ; flush_w :
        ( unit
        , Strict_pipe.drop_head Strict_pipe.buffered
        , unit )
        Strict_pipe.Writer.t
          (* buffer of length 0 *)
    ; jobs_added_bvar : (unit, read_write) Bvar.t
    ; get : Peer.t -> Key.t list -> Result.t list Deferred.Or_error.t
    ; max_batch_size : int
          (* A peer is useful if there is a job in the pending queue which has not
             been attempted with that peer. *)
    ; got_new_peers_w :
        ( unit
        , Strict_pipe.drop_head Strict_pipe.buffered
        , unit )
        Strict_pipe.Writer.t
          (* buffer of length 0 *)
    ; got_new_peers_r : unit Strict_pipe.Reader.t
    ; logger : Logger.t
    ; trust_system : Trust_system.t
    ; stop : unit Deferred.t
    }

  let logger t = t.logger

  let jobs_added t = Bvar.broadcast t.jobs_added_bvar ()

  let total_jobs (t : t) = Map.length t.pending + Hashtbl.length t.downloading

  (* Checks disjointness *)
  let check_invariant (t : t) =
    Set.length
      (Key.Set.union_list
         [ Key.Map.keys t.pending |> Key.Set.of_list
         ; Key.Set.of_hashtbl_keys t.downloading
         ] )
    |> [%test_eq: int] (total_jobs t)

  let check_invariant_r = ref check_invariant

  let set_check_invariant f = check_invariant_r := f

  let job_finished t j x =
    Hashtbl.remove t.downloading j.Job.key ;
    Ivar.fill_if_empty j.res x ;
    try !check_invariant_r t
    with e ->
      [%log' debug t.logger]
        ~metadata:[ ("exn", `String (Exn.to_string e)) ]
        "job_finished $exn"

  let kill_job j = Ivar.fill_if_empty j.Job.res (Error `Finished)

  let hard_flush_batch_rate = 3

  (* WARN: we should ensure we're always enqueuing jobs before invoking
     [flush_soon], o.w. this function can delay flushing indefinitely *)
  let flush_soon t =
    let flush_now () =
      if not (Strict_pipe.Writer.is_closed t.flush_w) then
        Strict_pipe.Writer.write t.flush_w () ;
      t.flush_scheduled <- false ;
      t.proposed_new_flush_at <- None
    in
    let rec schedule_flush ~at =
      let%bind () = after Time.(diff at (now ())) in
      match t.proposed_new_flush_at with
      | None ->
          Deferred.return @@ flush_now ()
      | Some proposed_new_flush_at ->
          let possible_delayed_flush_time =
            Time.add proposed_new_flush_at max_wait
          in
          if
            Time.is_later possible_delayed_flush_time ~than:at
            && Key.Map.length t.pending
               < t.max_batch_size * hard_flush_batch_rate
          then schedule_flush ~at:possible_delayed_flush_time
          else Deferred.return @@ flush_now ()
    in
    if not t.flush_scheduled then (
      t.flush_scheduled <- true ;
      Deferred.don't_wait_for (schedule_flush ~at:Time.(add (now ()) max_wait))
      )
    else t.proposed_new_flush_at <- Some (Time.now ())

  let cancel t h =
    let job =
      List.find_map ~f:Lazy.force
        [ lazy (Map.find t.pending h)
        ; lazy
            (Option.map ~f:(fun (_, j, _) -> j) (Hashtbl.find t.downloading h))
        ]
    in
    t.pending <- Key.Map.remove t.pending h ;
    Hashtbl.remove t.downloading h ;
    match job with
    | None ->
        ()
    | Some j ->
        kill_job j ;
        Useful_peers.update t.useful_peers (Job_cancelled h)

  let enqueue t e =
    match Key.Map.add t.pending ~key:e.Job.key ~data:e with
    | `Duplicate ->
        `Key_already_present
    | `Ok new_pending ->
        t.pending <- new_pending ;
        jobs_added t ;
        flush_soon t ;
        `Ok

  let enqueue_exn t e =
    assert ([%equal: [ `Ok | `Key_already_present ]] (enqueue t e) `Ok)

  let active_jobs t =
    Key.Map.data t.pending
    @ List.map (Hashtbl.data t.downloading) ~f:(fun (_, j, _) -> j)

  let refresh_peers t peers =
    Broadcast_pipe.Reader.iter peers ~f:(fun peers ->
        O1trace.sync_thread "refresh_downloader_peers" (fun () ->
            let peers' = Peer.Set.of_list peers in
            let new_peers = Set.diff peers' t.all_peers in
            Useful_peers.update t.useful_peers
              (Refreshed_peers { all_peers = peers' }) ;
            if
              (not (Set.is_empty new_peers))
              && not (Strict_pipe.Writer.is_closed t.got_new_peers_w)
            then Strict_pipe.Writer.write t.got_new_peers_w () ;
            t.all_peers <- Peer.Set.of_list peers ) ;
        Deferred.unit )
    |> don't_wait_for

  let tear_down
      { proposed_new_flush_at = _
      ; flush_scheduled = _
      ; all_peers = _
      ; flush_w
      ; get = _
      ; got_new_peers_w
      ; flush_r = _
      ; jobs_added_bvar = _
      ; useful_peers
      ; got_new_peers_r = _
      ; pending
      ; downloading
      ; max_batch_size = _
      ; logger = _
      ; trust_system = _
      ; stop = _
      } =
    Strict_pipe.Writer.close flush_w ;
    Useful_peers.tear_down useful_peers ;
    Strict_pipe.Writer.close got_new_peers_w ;
    Hashtbl.iter downloading ~f:(fun (_, j, _) -> kill_job j) ;
    Hashtbl.clear downloading ;
    Key.Map.iter pending ~f:kill_job

  let download t peer xs =
    O1trace.thread "download" (fun () ->
        let keys = List.map xs ~f:(fun x -> x.Job.key) in
        let fail (e : Error.t) =
          let e = Error.to_string_hum e in
          [%log' debug t.logger]
            "Downloading from $peer failed ($error) on $keys"
            ~metadata:
              [ ("peer", Peer.to_yojson peer)
              ; ("error", `String e)
              ; ("keys", Yojson'.List.chunked ~f:Key.to_yojson ~limit:8 keys)
              ] ;
          List.iter xs ~f:(fun x ->
              enqueue_exn t
                { x with
                  attempts = Map.set x.attempts ~key:peer ~data:Attempt.download
                } )
        in
        List.iter xs ~f:(fun x ->
            Hashtbl.set t.downloading ~key:x.key ~data:(peer, x, Time.now ()) ) ;
        jobs_added t ;
        Useful_peers.update t.useful_peers (Download_starting peer) ;
        let download_deferred = t.get peer keys in
        upon download_deferred (fun res ->
            let succs, unsuccs =
              match res with
              | Error _ ->
                  ([], Key.Set.of_list keys)
              | Ok rs ->
                  let all = Key.Hash_set.of_list keys in
                  let succ =
                    List.filter_map rs ~f:(fun r ->
                        let k = Result.key r in
                        if Hash_set.mem all k then Some k else None )
                  in
                  List.iter succ ~f:(Hash_set.remove all) ;
                  (succ, Hash_set.to_list all |> Key.Set.of_list)
            in
            Useful_peers.update t.useful_peers
              (Download_finished (peer, `Successful succs, `Unsuccessful unsuccs)
              ) ) ;
        let%map res =
          Deferred.choose
            [ Deferred.choice download_deferred (fun x -> `Not_stopped x)
            ; Deferred.choice t.stop (fun () -> `Stopped)
            ; Deferred.choice
                (* This happens if all the jobs are cancelled. *)
                (Deferred.List.map xs ~f:(fun x -> Ivar.read x.res))
                (fun _ -> `Stopped)
            ]
        in
        List.iter xs ~f:(fun j -> Hashtbl.remove t.downloading j.key) ;
        match res with
        | `Stopped ->
            List.iter xs ~f:kill_job
        | `Not_stopped r -> (
            match r with
            | Error e ->
                fail e
            | Ok rs ->
                [%log' debug t.logger] "result is $result"
                  ~metadata:
                    [ ( "result"
                      , Yojson'.List.chunked ~f:Key.to_yojson ~limit:8 keys )
                    ; ("peer", `String (Peer.to_multiaddr_string peer))
                    ] ;
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
                             ( { Envelope.Incoming.data = r
                               ; received_at
                               ; sender = Remote peer
                               }
                             , j.attempts ) ) ) ;
                (* Anything left in jobs, we did not get results for :( *)
                Hashtbl.iter jobs ~f:(fun x ->
                    Hashtbl.remove t.downloading x.Job.key ;
                    enqueue_exn t
                      { x with
                        attempts =
                          Map.set x.attempts ~key:peer ~data:Attempt.download
                      } ) ) )

  let to_yojson t : Yojson.Safe.t =
    check_invariant t ;
    let now = Time.now () in
    let jobs_to_yojson =
      Yojson'.List.with_length
        ~f:(Job.to_yojson ~key:Key.to_yojson ~attempt:Attempt.to_yojson)
    in
    let pending_to_yojson pending = jobs_to_yojson @@ Key.Map.data pending in
    `Assoc
      [ ("total_jobs", `Int (total_jobs t))
      ; ("useful_peers", Useful_peers.to_yojson t.useful_peers)
      ; ("pending", pending_to_yojson t.pending)
      ; ( "downloading"
        , Yojson'.List.with_length
            ~f:(fun (h, (p, _, start)) ->
              `Assoc
                [ ("hash", Key.to_yojson h)
                ; ("start", `String (Time.to_string start))
                ; ( "time_since_start"
                  , `String (Time.Span.to_string_hum (Time.diff now start)) )
                ; ("peer", `String (Peer.to_multiaddr_string p))
                ] )
            (Hashtbl.to_alist t.downloading) )
      ]

  let post_stall_retry_delay = Time.Span.of_min 1.

  let step t =
    if Key.Map.length t.pending = 0 then (
      [%log' debug t.logger] "Downloader: no jobs. waiting" ;
      match%map Strict_pipe.Reader.read t.flush_r with
      | `Eof ->
          [%log' debug t.logger] "Downloader: flush eof" ;
          `Finished ()
      | `Ok () ->
          `Repeat t )
    else
      match
        Useful_peers.useful_peer t.useful_peers
          ~pending_jobs:(Key.Map.data t.pending)
      with
      | `No_peers -> (
          match%map Strict_pipe.Reader.read t.got_new_peers_r with
          | `Eof ->
              [%log' debug t.logger] "Downloader: new peers eof" ;
              `Finished ()
          | `Ok () ->
              `Repeat t )
      | `Useful_but_busy -> (
          [%log' debug t.logger] "Downloader: Waiting. All useful peers busy" ;
          let read p =
            Pipe.read_choice_single_consumer_exn
              (Strict_pipe.Reader.to_linear_pipe p).pipe [%here]
          in
          match%map
            Deferred.choose [ read t.flush_r; read t.useful_peers.r ]
          with
          | `Eof ->
              [%log' debug t.logger] "Downloader: flush eof" ;
              `Finished ()
          | `Ok () ->
              (* Try again, something might have changed *)
              `Repeat t )
      | `Stalled ->
          [%log' debug t.logger]
            "Downloader: all stalled. Resetting knowledge, waiting %s and then \
             retrying."
            (Time.Span.to_string_hum post_stall_retry_delay) ;
          Useful_peers.reset_knowledge t.useful_peers ~all_peers:t.all_peers ;
          let%map () = after post_stall_retry_delay in
          [%log' debug t.logger] "Downloader: continuing after reset" ;
          `Repeat t
      | `Useful (peer, might_know) -> (
          let to_download = List.take might_know t.max_batch_size in
          [%log' debug t.logger] "Downloader: downloading $n from $peer"
            ~metadata:
              [ ("n", `Int (List.length to_download))
              ; ("peer", Peer.to_yojson peer)
              ] ;
          List.iter to_download ~f:(fun j ->
              t.pending <- Key.Map.remove t.pending j.key ) ;
          match to_download with
          | [] ->
              Deferred.return @@ `Repeat t
          | _ :: _ ->
              don't_wait_for (download t peer to_download) ;
              Deferred.return @@ `Repeat t )

  let add_knowledge t peer claimed =
    Useful_peers.update t.useful_peers
      (Add_knowledge { peer; claimed; out_of_band = true })

  let update_knowledge t peer claimed =
    Useful_peers.update t.useful_peers
      (Knowledge
         { peer; claimed; active_jobs = active_jobs t; out_of_band = true } )

  let mark_preferred_now t peer =
    ignore
      ( Useful_peers.Preferred_peers.replace_now t.useful_peers.all_preferred
          ~job:peer
        : Time.t )

  let create ~max_batch_size ~stop ~logger ~trust_system ~get ~knowledge_context
      ~knowledge ~peers ~preferred =
    let%map all_peers = peers () in
    let pipe ~name c =
      Strict_pipe.create ~warn_on_drop:false ~name
        (Buffered (`Capacity c, `Overflow (Drop_head ignore)))
    in
    let flush_r, flush_w = pipe ~name:"flush" 0 in
    let got_new_peers_r, got_new_peers_w = pipe ~name:"got_new_peers" 0 in
    let t =
      { all_peers = Peer.Set.of_list all_peers
      ; pending = Key.Map.empty
      ; proposed_new_flush_at = None
      ; flush_scheduled = false
      ; flush_r
      ; flush_w
      ; jobs_added_bvar = Bvar.create ()
      ; got_new_peers_r
      ; got_new_peers_w
      ; useful_peers = Useful_peers.create ~all_peers ~preferred
      ; get
      ; max_batch_size
      ; logger
      ; trust_system
      ; downloading = Key.Table.create ()
      ; stop
      }
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
    let rec jobs_to_download stop =
      O1trace.thread "wait_for_jobs_to_download" (fun () ->
          if total_jobs t <> 0 then return `Ok
          else
            match%bind
              Deferred.choose
                [ choice stop (Fn.const `Eof)
                ; choice (Bvar.wait t.jobs_added_bvar) (Fn.const `Ok)
                ]
            with
            | `Eof ->
                return `Finished
            | `Ok ->
                jobs_to_download stop )
    in
    let request_r, request_w =
      Strict_pipe.create ~name:"knowledge-requests" Strict_pipe.Synchronous
    in
    upon stop (fun () -> Strict_pipe.Writer.close request_w) ;
    let refresh_knowledge stop peer =
      Clock.every' (Time.Span.of_min 7.) ~stop (fun () ->
          match%bind jobs_to_download stop with
          | `Finished ->
              Deferred.unit
          | `Ok ->
              if not (Strict_pipe.Writer.is_closed request_w) then
                Strict_pipe.Writer.write request_w peer
              else Deferred.unit )
    in
    let ps : unit Ivar.t Peer.Table.t = Peer.Table.create () in
    Broadcast_pipe.Reader.iter peers ~f:(fun peers ->
        O1trace.sync_thread "maintain_downloader_peers" (fun () ->
            let peers = Peer.Hash_set.of_list peers in
            Hashtbl.filteri_inplace ps ~f:(fun ~key:p ~data:finished ->
                let keep = Hash_set.mem peers p in
                if not keep then Ivar.fill_if_empty finished () ;
                keep ) ;
            Hash_set.iter peers ~f:(fun p ->
                if not (Hashtbl.mem ps p) then (
                  let finished = Ivar.create () in
                  refresh_knowledge (Ivar.read finished) p ;
                  Hashtbl.add_exn ps ~key:p ~data:finished ) ) ) ;
        Deferred.unit )
    |> don't_wait_for ;
    let throttle =
      Throttle.create ~continue_on_error:true ~max_concurrent_jobs:8
    in
    let get_knowledge ctx peer =
      Throttle.enqueue throttle (fun () -> knowledge ctx peer)
    in
    O1trace.background_thread "refresh_downloader_knowledge" (fun () ->
        Broadcast_pipe.Reader.iter knowledge_context ~f:(fun _ ->
            O1trace.sync_thread "refresh_downloader_knowledge" (fun () ->
                Hashtbl.mapi_inplace ps ~f:(fun ~key:p ~data:finished ->
                    Ivar.fill_if_empty finished () ;
                    let finished = Ivar.create () in
                    refresh_knowledge (Ivar.read finished) p ;
                    finished ) ) ;
            Deferred.unit ) ) ;
    O1trace.background_thread "dispatch_downloader_requests" (fun () ->
        Strict_pipe.Reader.iter request_r ~f:(fun peer ->
            (* TODO: The pipe/clock logic is not quite right, but it is good enough. *)
            if Deferred.is_determined stop then Deferred.unit
            else
              let%map () = Throttle.capacity_available throttle in
              don't_wait_for
                (let ctx = Broadcast_pipe.Reader.peek knowledge_context in
                 (* TODO: Check if already downloading a job from them here. *)
                 Useful_peers.update t.useful_peers
                   (Knowledge_request_starting peer) ;
                 let%map k = get_knowledge ctx peer in
                 Useful_peers.update t.useful_peers
                   (Knowledge
                      { out_of_band = false
                      ; peer
                      ; claimed = k
                      ; active_jobs = active_jobs t
                      } ) ) ) ) ;
    O1trace.background_thread "execute_downlader_node_fstm" (fun () ->
        Deferred.repeat_until_finished t step ) ;
    upon stop (fun () -> tear_down t) ;
    every ~stop (Time.Span.of_sec 30.) (fun () ->
        [%log' debug t.logger]
          ~metadata:[ ("jobs", to_yojson t) ]
          "Downloader $jobs" ) ;
    refresh_peers t peers ;
    t

  (* After calling download, if no one else has called within time [max_wait],
       we flush our queue. *)
  let download t ~key ~attempts : job =
    match (Key.Map.find t.pending key, Hashtbl.find t.downloading key) with
    | Some _, Some _ ->
        assert false
    | Some x, None | None, Some (_, x, _) ->
        x
    | None, None ->
        let e = { Job.key; attempts; res = Ivar.create () } in
        enqueue_exn t e ; e
end
