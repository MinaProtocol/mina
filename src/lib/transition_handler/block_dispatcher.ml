open Mina_base
open Network_peer

type catchup_job =
  State_hash.t
  * ( ( Mina_block.initial_valid_block Envelope.Incoming.t
      , State_hash.t )
      Cache_lib.Cached.t
    * Mina_net2.Validation_callback.t option )
    Mina_stdlib.Rose_tree.t
    list

type validated =
  [ `Block of
    ( Mina_block.initial_valid_block Envelope.Incoming.t
    , State_hash.t )
    Cache_lib.Cached.t
  | `Header of Mina_block.initial_valid_header Envelope.Incoming.t ]
  * [ `Valid_cb of Mina_net2.Validation_callback.t option ]

type event =
  | Validated of validated
  | Resume_catchup of (unit -> unit)
  | Catchup_job of catchup_job
  | Catchup_ready of (catchup_job -> unit)

type t =
  { loop : event Otp_lib.Event_loop.t
  ; catchup_jobs_before_ready : catchup_job Core_kernel.Queue.t
  ; cleared : bool ref
  }

let create ~on_validated =
  let process_catchup_job = ref None in
  let catchup_jobs_before_ready = Core_kernel.Queue.create () in
  let cleared = ref false in
  let loop =
    O1trace.sync_thread "dispatch_blocks" (fun () ->
        Otp_lib.Event_loop.create ~handle:(function
          | Validated _ when !cleared ->
              ()
          | Validated transition ->
              on_validated transition
          | Resume_catchup resume ->
              resume ()
          | Catchup_job _ when !cleared ->
              ()
          | Catchup_job job -> (
              match !process_catchup_job with
              | Some process ->
                  process job
              | None ->
                  Core_kernel.Queue.enqueue catchup_jobs_before_ready job )
          | Catchup_ready process ->
              process_catchup_job := Some process ;
              Core_kernel.Queue.iter catchup_jobs_before_ready ~f:process ;
              Core_kernel.Queue.clear catchup_jobs_before_ready ) )
  in
  { loop; catchup_jobs_before_ready; cleared }

let submit t event = Otp_lib.Event_loop.submit t.loop event

let clear t =
  t.cleared := true ;
  Core_kernel.Queue.clear t.catchup_jobs_before_ready

let%test_module "Block_dispatcher" =
  ( module struct
    open Core_kernel
    open Async

    let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

    (* The genesis block's header, validated as far as the validator leaves
       it. *)
    let validated : validated =
      ( `Header
          ( Mina_block.genesis ~precomputed_values
          |> Mina_block.Validation.reset_frontier_dependencies_validation
          |> Mina_block.Validation.reset_staged_ledger_diff_validation
          |> Mina_block.Validation.to_header |> Envelope.Incoming.local )
      , `Valid_cb None )

    let job i : catchup_job =
      ( Quickcheck.random_value
          ~seed:(`Deterministic (Int.to_string i))
          State_hash.gen
      , [] )

    type handled = Validated | Job of State_hash.t | Resumed
    [@@deriving compare, sexp]

    (* What the dispatcher handles while [f] submits to it, with [ready] the
       catchup job handler to report ready. *)
    let handled f =
      Thread_safe.block_on_async_exn (fun () ->
          let handled = ref [] in
          let record x = handled := x :: !handled in
          let t = create ~on_validated:(fun _ -> record Validated) in
          let ready = Catchup_ready (fun (hash, _) -> record (Job hash)) in
          let%bind () = f t ~ready ~resume:(fun () -> record Resumed) in
          let%map () = Scheduler.yield_until_no_jobs_remain () in
          List.rev !handled )

    let job_hash i = Job (fst (job i))

    let%test_unit "Catchup jobs held until catchup is ready are handled in \
                   order" =
      [%test_eq: handled list]
        (handled (fun t ~ready ~resume:_ ->
             submit t (Catchup_job (job 1)) ;
             submit t (Catchup_job (job 2)) ;
             submit t ready ;
             submit t (Catchup_job (job 3)) ;
             Deferred.unit ) )
        [ job_hash 1; job_hash 2; job_hash 3 ]

    let%test_unit "Clearing drops held catchup jobs" =
      [%test_eq: handled list]
        (handled (fun t ~ready ~resume:_ ->
             submit t (Catchup_job (job 1)) ;
             let%map () = Scheduler.yield_until_no_jobs_remain () in
             clear t ; submit t ready ) )
        []

    let%test_unit "Clearing drops what is queued and submitted later, but not \
                   resumptions" =
      [%test_eq: handled list]
        (handled (fun t ~ready ~resume ->
             submit t ready ;
             submit t (Validated validated) ;
             submit t (Catchup_job (job 1)) ;
             submit t (Resume_catchup resume) ;
             clear t ;
             submit t (Validated validated) ;
             submit t (Catchup_job (job 2)) ;
             Deferred.unit ) )
        [ Resumed ]

    let%test_unit "Validated transitions are passed on" =
      [%test_eq: handled list]
        (handled (fun t ~ready:_ ~resume:_ ->
             submit t (Validated validated) ;
             Deferred.unit ) )
        [ Validated ]
  end )
