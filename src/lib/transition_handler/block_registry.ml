open Core_kernel
open Async_kernel
open Mina_base
open Cache_lib

type t =
  { cache : Unprocessed_transition_cache.t
  ; callbacks : Mina_net2.Validation_callback.t State_hash.Table.t
  ; header_callbacks : Mina_net2.Validation_callback.t list State_hash.Table.t
  }

type outcome = [ `Added | `Rejected | `Ignored ]

let create ~logger ~cache_exceptions =
  { cache = Unprocessed_transition_cache.create ~logger ~cache_exceptions
  ; callbacks = State_hash.Table.create ()
  ; header_callbacks = State_hash.Table.create ()
  }

let cache t = t.cache

let register_exn t block ~valid_cb =
  let cached = Unprocessed_transition_cache.register_exn t.cache block in
  Option.iter valid_cb ~f:(fun valid_cb ->
      let state_hash = Cached.original cached in
      Hashtbl.set t.callbacks ~key:state_hash ~data:valid_cb ;
      (* A block finalized without [finish] no longer needs its callback
         kept. *)
      upon
        (Ivar.read (Cached.final_state cached))
        (fun _ -> Hashtbl.remove t.callbacks state_hash) ) ;
  cached

let answer outcome valid_cb =
  Mina_net2.Validation_callback.fire_if_not_already_fired valid_cb
    (match outcome with `Rejected -> `Reject | `Ignored -> `Ignore)

let finish_added t cached =
  if Ivar.is_full (Cached.final_state cached) then None
  else
    let valid_cb =
      Hashtbl.find_and_remove t.callbacks (Cached.original cached)
    in
    ignore (Cached.invalidate_with_success cached : _) ;
    valid_cb

let finish t cached outcome =
  if not (Ivar.is_full (Cached.final_state cached)) then
    match outcome with
    | `Added ->
        ignore (finish_added t cached : Mina_net2.Validation_callback.t option)
    | (`Rejected | `Ignored) as outcome ->
        let valid_cb =
          Hashtbl.find_and_remove t.callbacks (Cached.original cached)
        in
        ignore (Cached.invalidate_with_failure cached : _) ;
        Option.iter valid_cb ~f:(answer outcome)

let header_state_hash header =
  State_hash.With_state_hashes.state_hash
    (fst (Network_peer.Envelope.Incoming.data header))

let register_header t header ~valid_cb =
  Option.iter valid_cb ~f:(fun valid_cb ->
      Hashtbl.add_multi t.header_callbacks ~key:(header_state_hash header)
        ~data:valid_cb )

let finish_header t header outcome =
  Hashtbl.find_and_remove t.header_callbacks (header_state_hash header)
  |> Option.iter ~f:(List.iter ~f:(answer outcome))

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

    let%test_unit "An added block's callback is handed over once" =
      let handed_over = ref [] in
      let events, answers =
        finishing (fun t cached ->
            let first = finish_added t cached in
            let second = finish_added t cached in
            handed_over := List.map [ first; second ] ~f:Option.is_some )
      in
      [%test_eq: bool list] !handed_over [ true; false ] ;
      [%test_eq: Block_outcome_log.event list * answer list] (events, answers)
        (removed `Consumed, [])

    (* The genesis block's header, validated as far as a header entering the
       registry is. *)
    let header =
      Network_peer.Envelope.Incoming.map block
        ~f:Mina_block.Validation.to_header

    let callback_answers () =
      let valid_cb =
        Mina_net2.Validation_callback.create
          (Time_ns.add (Time_ns.now ()) (Time_ns.Span.of_min 1.))
      in
      let answers = ref [] in
      Mina_net2.Validation_callback.set_on_resolve valid_cb (fun answer ->
          answers := answer :: !answers ) ;
      (valid_cb, answers)

    let%test_unit "A header is answered through each of its callbacks, once" =
      let t = create ~logger:(Logger.null ()) ~cache_exceptions:false in
      let first, first_answers = callback_answers () in
      let second, second_answers = callback_answers () in
      register_header t header ~valid_cb:(Some first) ;
      register_header t header ~valid_cb:(Some second) ;
      finish_header t header `Rejected ;
      finish_header t header `Ignored ;
      [%test_eq: answer list * answer list]
        (!first_answers, !second_answers)
        ([ `Reject ], [ `Reject ])

    let%test_unit "Finishing a transformed block finishes it" =
      [%test_eq: Block_outcome_log.event list * answer list]
        (finishing (fun t cached ->
             finish t (Cached.transform cached ~f:(fun _ -> ())) `Rejected ) )
        (removed `Failure, [ `Reject ])
  end )
