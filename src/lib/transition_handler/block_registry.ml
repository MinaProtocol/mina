open Core_kernel
open Async_kernel
open Mina_base
open Cache_lib

type t =
  { cache : Unprocessed_transition_cache.t
  ; callbacks : Mina_net2.Validation_callback.t State_hash.Table.t
  }

type outcome = [ `Added | `Rejected | `Ignored ]

let create ~logger ~cache_exceptions =
  { cache = Unprocessed_transition_cache.create ~logger ~cache_exceptions
  ; callbacks = State_hash.Table.create ()
  }

let cache t = t.cache

let register_exn t block ~valid_cb =
  let cached = Unprocessed_transition_cache.register_exn t.cache block in
  Option.iter valid_cb ~f:(fun valid_cb ->
      let state_hash = Cached.original cached in
      Hashtbl.set t.callbacks ~key:state_hash ~data:valid_cb ;
      (* A block finalized without [finish] no longer needs its callback
         kept. The block may have been registered again before this runs, so
         leave a callback that isn't this registration's. *)
      upon
        (Ivar.read (Cached.final_state cached))
        (fun _ ->
          Hashtbl.change t.callbacks state_hash ~f:(function
            | Some kept when phys_equal kept valid_cb ->
                None
            | kept ->
                kept ) ) ) ;
  cached

let finish t cached outcome =
  if not (Ivar.is_full (Cached.final_state cached)) then
    let state_hash = Cached.original cached in
    let valid_cb = Hashtbl.find_and_remove t.callbacks state_hash in
    match outcome with
    | `Added ->
        ignore (Cached.invalidate_with_success cached : _)
    | (`Rejected | `Ignored) as outcome ->
        ignore (Cached.invalidate_with_failure cached : _) ;
        Option.iter valid_cb ~f:(fun valid_cb ->
            Mina_net2.Validation_callback.fire_if_not_already_fired valid_cb
              (match outcome with `Rejected -> `Reject | `Ignored -> `Ignore) )

let%test_module "Block_registry" =
  ( module struct
    open Network_peer

    let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

    (* The genesis block, validated as far as a block entering the registry
       is. *)
    let block =
      Mina_block.genesis ~precomputed_values
      |> Mina_block.Validation.reset_frontier_dependencies_validation
      |> Mina_block.Validation.reset_staged_ledger_diff_validation
      |> Envelope.Incoming.local

    let state_hash =
      State_hash.With_state_hashes.state_hash
        (Mina_block.Validation.block_with_hash (Envelope.Incoming.data block))

    type answer = [ `Accept | `Reject | `Ignore | `Expired ]
    [@@deriving compare, sexp]

    (* Register [block] with a callback, run [f] on it, and return how its
       cache entry was removed and how its callback was answered. *)
    let finishing f =
      let t = create ~logger:(Logger.null ()) ~cache_exceptions:false in
      let valid_cb =
        Mina_net2.Validation_callback.create
          (Time_ns.add (Time_ns.now ()) (Time_ns.Span.of_min 1.))
      in
      let answers = ref [] in
      Mina_net2.Validation_callback.set_on_resolve valid_cb (fun answer ->
          answers := answer :: !answers ) ;
      let (), events =
        Block_outcome_log.For_tests.recording (fun () ->
            f t (register_exn t block ~valid_cb:(Some valid_cb)) )
      in
      (events, List.rev !answers)

    let removed outcome =
      [ Block_outcome_log.Cache_removed { state_hash; outcome } ]

    let%test_unit "A rejected block fails its entry and is answered Reject" =
      [%test_eq: Block_outcome_log.event list * answer list]
        (finishing (fun t cached -> finish t cached `Rejected))
        (removed `Failure, [ `Reject ])

    let%test_unit "An ignored block fails its entry and is answered Ignore" =
      [%test_eq: Block_outcome_log.event list * answer list]
        (finishing (fun t cached -> finish t cached `Ignored))
        (removed `Failure, [ `Ignore ])

    let%test_unit "An added block consumes its entry and is left unanswered" =
      [%test_eq: Block_outcome_log.event list * answer list]
        (finishing (fun t cached -> finish t cached `Added))
        (removed `Consumed, [])

    let%test_unit "A block finishes once" =
      [%test_eq: Block_outcome_log.event list * answer list]
        (finishing (fun t cached ->
             finish t cached `Ignored ;
             finish t cached `Added ) )
        (removed `Failure, [ `Ignore ])

    let%test_unit "Finishing a transformed block finishes it" =
      [%test_eq: Block_outcome_log.event list * answer list]
        (finishing (fun t cached ->
             finish t (Cached.transform cached ~f:(fun _ -> ())) `Rejected ) )
        (removed `Failure, [ `Reject ])

    let%test_unit "A block registered again keeps its callback" =
      let t = create ~logger:(Logger.null ()) ~cache_exceptions:false in
      let callback () =
        Mina_net2.Validation_callback.create_without_expiration ()
      in
      let second_cb = callback () in
      let answers = ref [] in
      Mina_net2.Validation_callback.set_on_resolve second_cb (fun answer ->
          answers := answer :: !answers ) ;
      finish t (register_exn t block ~valid_cb:(Some (callback ()))) `Ignored ;
      (* The clean-up job of the first registration has not run yet. *)
      let second = register_exn t block ~valid_cb:(Some second_cb) in
      Async.Thread_safe.block_on_async_exn (fun () ->
          Async_kernel_scheduler.yield_until_no_jobs_remain () ) ;
      finish t second `Rejected ;
      [%test_eq: answer list] !answers [ `Reject ]
  end )
