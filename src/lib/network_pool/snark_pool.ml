open Core_kernel
open Async
open Pipe_lib
open Network_peer
module Statement_table = Transaction_snark_work.Statement.Table

module Snark_tables = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { all:
            Ledger_proof.Stable.V1.t One_or_two.Stable.V1.t
            Priced_proof.Stable.V1.t
            Transaction_snark_work.Statement.Stable.V1.Table.t
              (** Every SNARK in the pool *)
        ; rebroadcastable:
            ( Ledger_proof.Stable.V1.t One_or_two.Stable.V1.t
              Priced_proof.Stable.V1.t
            * Core.Time.Stable.With_utc_sexp.V2.t )
            Transaction_snark_work.Statement.Stable.V1.Table.t
              (** Rebroadcastable SNARKs generated on this machine, along with
                  when they were first added. *)
        }
      [@@deriving sexp]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t =
    { all:
        Ledger_proof.t One_or_two.t Priced_proof.t
        Transaction_snark_work.Statement.Table.t
    ; rebroadcastable:
        ( Ledger_proof.t One_or_two.t Priced_proof.t
        * Time.Stable.With_utc_sexp.V2.t )
        Transaction_snark_work.Statement.Table.t }
  [@@deriving sexp]
end

module type S = sig
  type transition_frontier

  module Resource_pool : sig
    include
      Intf.Snark_resource_pool_intf
      with type transition_frontier := transition_frontier
       and type serializable := Snark_tables.t

    val remove_solved_work : t -> Transaction_snark_work.Statement.t -> unit

    module Diff : Intf.Snark_pool_diff_intf with type resource_pool := t
  end

  module For_tests : sig
    val get_rebroadcastable :
         Resource_pool.t
      -> is_expired:(Time.t -> [`Expired | `Ok])
      -> Resource_pool.Diff.t list
  end

  include
    Intf.Network_pool_base_intf
    with type resource_pool := Resource_pool.t
     and type resource_pool_diff := Resource_pool.Diff.t
     and type transition_frontier := transition_frontier
     and type config := Resource_pool.Config.t
     and type transition_frontier_diff :=
                Resource_pool.transition_frontier_diff
     and type rejected_diff := Resource_pool.Diff.rejected

  val get_completed_work :
       t
    -> Transaction_snark_work.Statement.t
    -> Transaction_snark_work.Checked.t option

  val load :
       config:Resource_pool.Config.t
    -> logger:Logger.t
    -> constraint_constants:Genesis_constants.Constraint_constants.t
    -> disk_location:string
    -> incoming_diffs:( Resource_pool.Diff.t Envelope.Incoming.t
                      * (bool -> unit) )
                      Strict_pipe.Reader.t
    -> local_diffs:( Resource_pool.Diff.t
                   * (   (Resource_pool.Diff.t * Resource_pool.Diff.rejected)
                         Or_error.t
                      -> unit) )
                   Strict_pipe.Reader.t
    -> frontier_broadcast_pipe:transition_frontier option
                               Broadcast_pipe.Reader.t
    -> t Deferred.t
end

module type Transition_frontier_intf = sig
  type t

  val snark_pool_refcount_pipe :
       t
    -> (int * int Transaction_snark_work.Statement.Table.t)
       Pipe_lib.Broadcast_pipe.Reader.t
end

module Make (Transition_frontier : Transition_frontier_intf) :
  S with type transition_frontier := Transition_frontier.t = struct
  module Batcher : sig
    type t [@@deriving sexp]

    val create : Verifier.t -> t

    val verify :
         t
      -> (Ledger_proof.t * Coda_base.Sok_message.t) list
      -> bool Deferred.Or_error.t
  end = struct
    type state =
      | Waiting
      | Verifying of
          { out_for_verification:
              (Ledger_proof.t * Coda_base.Sok_message.t) list
          ; next_finished: bool Or_error.t Ivar.t sexp_opaque }
    [@@deriving sexp]

    type t =
      { mutable state: state
      ; queue: (Ledger_proof.t * Coda_base.Sok_message.t) Queue.t
      ; verifier: Verifier.t sexp_opaque }
    [@@deriving sexp]

    let create verifier = {state= Waiting; queue= Queue.create (); verifier}

    let call_verifier t ps = Verifier.verify_transaction_snarks t.verifier ps

    (* When new proofs come in put them in the queue.
       If state = Waiting, verify those proofs immediately.
       Whenever the verifier returns, if the queue is nonempty, flush it into the verifier.
    *)

    let rec start_verifier t finished =
      if Queue.is_empty t.queue then (
        (* we looped in the else after verifier finished but no pending work. *)
        t.state <- Waiting ;
        Ivar.fill finished (Ok true) )
      else
        let out_for_verification = Queue.to_list t.queue in
        let next_finished = Ivar.create () in
        t.state <- Verifying {next_finished; out_for_verification} ;
        Queue.clear t.queue ;
        let res = call_verifier t out_for_verification in
        upon res (fun x ->
            Ivar.fill finished x ;
            start_verifier t next_finished )

    let verify t proofs =
      if List.is_empty proofs then Deferred.return (Ok true)
      else (
        Queue.enqueue_all t.queue proofs ;
        match t.state with
        | Verifying {next_finished; _} ->
            Ivar.read next_finished
        | Waiting ->
            let finished = Ivar.create () in
            start_verifier t finished ; Ivar.read finished )
  end

  module Resource_pool = struct
    module T = struct
      module Config = struct
        type t =
          { trust_system: Trust_system.t sexp_opaque
          ; verifier: Verifier.t sexp_opaque }
        [@@deriving sexp, make]
      end

      type transition_frontier_diff =
        int * int Transaction_snark_work.Statement.Table.t

      type t =
        { snark_tables: Snark_tables.t
        ; mutable ref_table: int Statement_table.t option
        ; config: Config.t
        ; logger: Logger.t sexp_opaque
        ; mutable removed_counter: int
              (*A counter for transition frontier breadcrumbs removed. When this reaches a certain value, unreferenced snark work is removed from ref_table*)
        ; batcher: Batcher.t }
      [@@deriving sexp]

      type serializable = Snark_tables.Stable.Latest.t
      [@@deriving bin_io_unversioned]

      let make_config = Config.make

      let removed_breadcrumb_wait = 10

      let of_serializable tables ~config ~logger : t =
        { snark_tables= tables
        ; batcher= Batcher.create config.verifier
        ; ref_table= None
        ; config
        ; logger
        ; removed_counter= removed_breadcrumb_wait }

      let snark_pool_json t : Yojson.Safe.t =
        `List
          (Statement_table.fold ~init:[] t.snark_tables.all
             ~f:(fun ~key ~data:{proof= _; fee= {fee; prover}} acc ->
               let work_ids =
                 Transaction_snark_work.Statement.compact_json key
               in
               `Assoc
                 [ ("work_ids", work_ids)
                 ; ("fee", Currency.Fee.Stable.V1.to_yojson fee)
                 ; ( "prover"
                   , Signature_lib.Public_key.Compressed.Stable.V1.to_yojson
                       prover ) ]
               :: acc ))

      let all_completed_work (t : t) : Transaction_snark_work.Info.t list =
        Statement_table.fold ~init:[] t.snark_tables.all
          ~f:(fun ~key ~data:{proof= _; fee= {fee; prover}} acc ->
            let work_ids = Transaction_snark_work.Statement.work_ids key in
            {Transaction_snark_work.Info.statements= key; work_ids; fee; prover}
            :: acc )

      (** True when there is no active transition_frontier or
          when the refcount for the given work is 0 *)
      let work_is_referenced t work =
        match t.ref_table with
        | None ->
            true
        | Some ref_table -> (
          match Statement_table.find ref_table work with
          | None ->
              false
          | Some _ ->
              true )

      let handle_transition_frontier_diff (removed, refcount_table) t =
        t.ref_table <- Some refcount_table ;
        t.removed_counter <- t.removed_counter + removed ;
        if t.removed_counter < removed_breadcrumb_wait then return ()
        else (
          t.removed_counter <- 0 ;
          Statement_table.filter_keys_inplace t.snark_tables.rebroadcastable
            ~f:(fun work ->
              (* Rebroadcastable should always be a subset of all. *)
              assert (Hashtbl.mem t.snark_tables.all work) ;
              work_is_referenced t work ) ;
          Statement_table.filter_keys_inplace t.snark_tables.all
            ~f:(work_is_referenced t) ;
          return
            (*when snark works removed from the pool*)
            Coda_metrics.(
              Gauge.set Snark_work.snark_pool_size
                (Float.of_int @@ Hashtbl.length t.snark_tables.all)) )

      let listen_to_frontier_broadcast_pipe frontier_broadcast_pipe (t : t)
          ~tf_diff_writer =
        (* start with empty ref table *)
        t.ref_table <- None ;
        let tf_deferred =
          Broadcast_pipe.Reader.iter frontier_broadcast_pipe ~f:(function
            | Some tf ->
                (* Start the count at the max so we flush after reconstructing
                   the transition_frontier *)
                t.removed_counter <- removed_breadcrumb_wait ;
                let pipe = Transition_frontier.snark_pool_refcount_pipe tf in
                Broadcast_pipe.Reader.iter pipe
                  ~f:(Strict_pipe.Writer.write tf_diff_writer)
                |> Deferred.don't_wait_for ;
                return ()
            | None ->
                t.ref_table <- None ;
                return () )
        in
        Deferred.don't_wait_for tf_deferred

      let create ~constraint_constants:_ ~frontier_broadcast_pipe ~config
          ~logger ~tf_diff_writer =
        let t =
          { snark_tables=
              { all= Statement_table.create ()
              ; rebroadcastable= Statement_table.create () }
          ; batcher= Batcher.create config.verifier
          ; logger
          ; config
          ; ref_table= None
          ; removed_counter= removed_breadcrumb_wait }
        in
        listen_to_frontier_broadcast_pipe frontier_broadcast_pipe t
          ~tf_diff_writer ;
        t

      let get_logger t = t.logger

      let request_proof t = Statement_table.find t.snark_tables.all

      let add_snark ?(is_local = false) t ~work
          ~(proof : Ledger_proof.t One_or_two.t) ~fee =
        if work_is_referenced t work then (
          (*Note: fee against existing proofs and the new proofs are checked in
          Diff.unsafe_apply which calls this function*)
          Hashtbl.set t.snark_tables.all ~key:work ~data:{proof; fee} ;
          if is_local then
            Hashtbl.set t.snark_tables.rebroadcastable ~key:work
              ~data:({proof; fee}, Time.now ())
          else
            (* Stop rebroadcasting locally generated snarks if they are
               overwritten. No-op if there is no rebroadcastable SNARK with that
               statement. *)
            Hashtbl.remove t.snark_tables.rebroadcastable work ;
          (*when snark work is added to the pool*)
          Coda_metrics.(
            Gauge.set Snark_work.snark_pool_size
              (Float.of_int @@ Hashtbl.length t.snark_tables.all)) ;
          Coda_metrics.(
            Snark_work.Snark_fee_histogram.observe Snark_work.snark_fee
              ( fee.Coda_base.Fee_with_prover.fee |> Currency.Fee.to_int
              |> Float.of_int )) ;
          `Added )
        else (
          if is_local then
            [%log' warn t.logger]
              "Rejecting locally generated snark work $stmt, statement not \
               referenced"
              ~metadata:
                [ ( "stmt"
                  , One_or_two.to_yojson Transaction_snark.Statement.to_yojson
                      work ) ] ;
          `Statement_not_referenced )

      let verify_and_act t ~work ~sender =
        let statements, priced_proof = work in
        let {Priced_proof.proof= proofs; fee= {prover; fee}} = priced_proof in
        let trust_record =
          Trust_system.record_envelope_sender t.config.trust_system t.logger
            sender
        in
        let log_and_punish ?(punish = true) statement e =
          (* TODO: For now, we must not punish since we batch across messages received from
             different senders and we don't isolate the bad proof in a batch, so we cannot
             properly attribute blame.
          *)
          ignore punish ;
          let punish = false in
          let metadata =
            [ ("work_id", `Int (Transaction_snark.Statement.hash statement))
            ; ("prover", Signature_lib.Public_key.Compressed.to_yojson prover)
            ; ("fee", Currency.Fee.to_yojson fee)
            ; ("error", `String (Error.to_string_hum e)) ]
          in
          [%log' error t.logger] ~metadata
            "Error verifying transaction snark: $error" ;
          if punish then
            trust_record
              ( Trust_system.Actions.Sent_invalid_proof
              , Some ("Error verifying transaction snark: $error", metadata) )
          else Deferred.return ()
        in
        let message = Coda_base.Sok_message.create ~fee ~prover in
        let verify proofs =
          let open Deferred.Let_syntax in
          let bad_statements =
            List.filter_map proofs ~f:(fun (p, s) ->
                if
                  Transaction_snark.Statement.( <> ) (Ledger_proof.statement p)
                    s
                then Some s
                else None )
          in
          match bad_statements with
          | _ :: _ ->
              let e = Error.of_string "Statement and proof do not match" in
              let%map () =
                Deferred.List.iter bad_statements ~f:(fun s ->
                    log_and_punish s e )
              in
              false
          | [] -> (
              let log ?punish e =
                Deferred.List.iter proofs ~f:(fun (_, s) ->
                    log_and_punish ?punish s e )
              in
              match%bind
                Batcher.verify t.batcher
                  (List.map proofs ~f:(fun (p, _) -> (p, message)))
              with
              | Ok true ->
                  Deferred.return true
              | Ok false ->
                  (*Invalid proof*)
                  let e = Error.of_string "Invalid proof" in
                  let%map () = log e in
                  false
              | Error e ->
                  (* Verifier crashed or other errors at our end. Don't punish the peer*)
                  let%map () = log ~punish:false e in
                  false )
        in
        match One_or_two.zip proofs statements with
        | Ok pairs ->
            verify (One_or_two.to_list pairs)
        | Error e ->
            [%log' error t.logger]
              ~metadata:[("error", `String (Error.to_string_hum e))]
              "One_or_two length mismatch: $error" ;
            Deferred.return false
    end

    include T
    module Diff = Snark_pool_diff.Make (Transition_frontier) (T)

    let get_rebroadcastable t ~is_expired =
      Hashtbl.filteri_inplace t.snark_tables.rebroadcastable
        ~f:(fun ~key:stmt ~data:(_proof, time) ->
          match is_expired time with
          | `Expired ->
              [%log' debug t.logger]
                "No longer rebroadcasting SNARK with statement $stmt, it was \
                 added at $time its rebroadcast period is now expired"
                ~metadata:
                  [ ( "stmt"
                    , One_or_two.to_yojson
                        Transaction_snark.Statement.to_yojson stmt )
                  ; ( "time"
                    , `String (Time.to_string_abs ~zone:Time.Zone.utc time) )
                  ] ;
              false
          | `Ok ->
              true ) ;
      Hashtbl.to_alist t.snark_tables.rebroadcastable
      |> List.map ~f:(fun (stmt, (snark, _time)) ->
             Diff.Add_solved_work (stmt, snark) )

    let remove_solved_work t work =
      Statement_table.remove t.snark_tables.all work ;
      Statement_table.remove t.snark_tables.rebroadcastable work
  end

  include Network_pool_base.Make (Transition_frontier) (Resource_pool)

  module For_tests = struct
    let get_rebroadcastable = Resource_pool.get_rebroadcastable
  end

  let get_completed_work t statement =
    Option.map
      (Resource_pool.request_proof (resource_pool t) statement)
      ~f:(fun Priced_proof.{proof; fee= {fee; prover}} ->
        Transaction_snark_work.Checked.create_unsafe
          {Transaction_snark_work.fee; proofs= proof; prover} )

  let load ~config ~logger ~constraint_constants ~disk_location ~incoming_diffs
      ~local_diffs ~frontier_broadcast_pipe =
    let tf_diff_reader, tf_diff_writer =
      Strict_pipe.(
        create ~name:"Snark pool Transition frontier diffs" Synchronous)
    in
    match%map
      Async.Reader.load_bin_prot disk_location
        Snark_tables.Stable.Latest.bin_reader_t
    with
    | Ok snark_table ->
        let pool = Resource_pool.of_serializable snark_table ~config ~logger in
        let network_pool =
          of_resource_pool_and_diffs pool ~logger ~constraint_constants
            ~incoming_diffs ~local_diffs ~tf_diffs:tf_diff_reader
        in
        Resource_pool.listen_to_frontier_broadcast_pipe frontier_broadcast_pipe
          pool ~tf_diff_writer ;
        network_pool
    | Error _e ->
        create ~config ~logger ~constraint_constants ~incoming_diffs
          ~local_diffs ~frontier_broadcast_pipe
end

(* TODO: defunctor or remove monkey patching (#3731) *)
include Make (struct
  include Transition_frontier

  let snark_pool_refcount_pipe t =
    Extensions.(get_view_pipe (extensions t) Snark_pool_refcount)
end)

module Diff_versioned = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Resource_pool.Diff.t =
        | Add_solved_work of
            Transaction_snark_work.Statement.Stable.V1.t
            * Ledger_proof.Stable.V1.t One_or_two.Stable.V1.t
              Priced_proof.Stable.V1.t
      [@@deriving compare, sexp, to_yojson]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t =
    | Add_solved_work of
        Transaction_snark_work.Statement.t
        * Ledger_proof.t One_or_two.t Priced_proof.t
  [@@deriving compare, sexp, to_yojson]
end

let%test_module "random set test" =
  ( module struct
    open Coda_base

    let trust_system = Mocks.trust_system

    let proof_level = Genesis_constants.Proof_level.for_unit_tests

    let constraint_constants =
      Genesis_constants.Constraint_constants.for_unit_tests

    let logger = Logger.null ()

    module Mock_snark_pool = Make (Mocks.Transition_frontier)
    open Ledger_proof.For_tests

    let apply_diff resource_pool work
        ?(proof = One_or_two.map ~f:mk_dummy_proof)
        ?(sender = Envelope.Sender.Local) fee =
      let diff =
        Mock_snark_pool.Resource_pool.Diff.Add_solved_work
          (work, {Priced_proof.Stable.Latest.proof= proof work; fee})
      in
      Mock_snark_pool.Resource_pool.Diff.unsafe_apply resource_pool
        {Envelope.Incoming.data= diff; sender}

    let config verifier =
      Mock_snark_pool.Resource_pool.make_config ~verifier ~trust_system

    let gen =
      let open Quickcheck.Generator.Let_syntax in
      let gen_entry =
        Quickcheck.Generator.tuple2 Mocks.Transaction_snark_work.Statement.gen
          Fee_with_prover.gen
      in
      let%map sample_solved_work = Quickcheck.Generator.list gen_entry in
      (*This has to be None because otherwise (if frontier_broadcast_pipe_r is
      seeded with (0, empty-table)) add_snark function wouldn't add snarks in
      the snark pool (see work_is_referenced) until the first diff (first block)
      and there are no best tip diffs being fed into this pipe from the mock
      transition frontier*)
      let frontier_broadcast_pipe_r, _ = Broadcast_pipe.create None in
      let incoming_diff_r, _incoming_diff_w =
        Strict_pipe.(create ~name:"Snark pool test" Synchronous)
      in
      let local_diff_r, _local_diff_w =
        Strict_pipe.(create ~name:"Snark pool test" Synchronous)
      in
      let res =
        let open Deferred.Let_syntax in
        let%bind verifier =
          Verifier.create ~logger ~proof_level
            ~pids:(Child_processes.Termination.create_pid_table ())
            ~conf_dir:None
        in
        let config = config verifier in
        let resource_pool =
          Mock_snark_pool.create ~config ~logger ~constraint_constants
            ~frontier_broadcast_pipe:frontier_broadcast_pipe_r
            ~incoming_diffs:incoming_diff_r ~local_diffs:local_diff_r
          |> Mock_snark_pool.resource_pool
        in
        let%map () =
          let open Deferred.Let_syntax in
          Deferred.List.iter sample_solved_work ~f:(fun (work, fee) ->
              let%map res = apply_diff resource_pool work fee in
              assert (Result.is_ok res) ;
              () )
        in
        resource_pool
      in
      res

    let%test_unit "Invalid proofs are not accepted" =
      let open Quickcheck.Generator.Let_syntax in
      let invalid_work_gen =
        let gen =
          let gen_entry =
            Quickcheck.Generator.tuple3
              Mocks.Transaction_snark_work.Statement.gen Fee_with_prover.gen
              Signature_lib.Public_key.Compressed.gen
          in
          let%map solved_work = Quickcheck.Generator.list gen_entry in
          List.fold ~init:[] solved_work
            ~f:(fun acc (work, fee, some_other_pk) ->
              (*Making it invalid by forging*)
              let invalid_sok_digest =
                Sok_message.(
                  digest @@ create ~prover:some_other_pk ~fee:fee.fee)
              in
              ( work
              , One_or_two.map work ~f:(fun statement ->
                    Ledger_proof.create ~statement
                      ~sok_digest:invalid_sok_digest
                      ~proof:Proof.transaction_dummy )
              , fee
              , some_other_pk )
              :: acc )
        in
        Quickcheck.Generator.filter gen ~f:(fun ls ->
            List.for_all ls ~f:(fun (_, _, fee, mal_pk) ->
                not
                @@ Signature_lib.Public_key.Compressed.equal mal_pk fee.prover
            ) )
      in
      Quickcheck.test ~trials:5
        ~sexp_of:
          [%sexp_of:
            Mock_snark_pool.Resource_pool.t Deferred.t
            * ( Transaction_snark_work.Statement.t
              * Ledger_proof.t One_or_two.t
              * Fee_with_prover.t
              * Signature_lib.Public_key.Compressed.t )
              list] (Quickcheck.Generator.tuple2 gen invalid_work_gen)
        ~f:(fun (t, invalid_work_lst) ->
          Async.Thread_safe.block_on_async_exn (fun () ->
              let open Deferred.Let_syntax in
              let%bind t = t in
              let completed_works =
                Mock_snark_pool.Resource_pool.all_completed_work t
              in
              let%map () =
                Deferred.List.iter invalid_work_lst
                  ~f:(fun (statements, proofs, fee, _) ->
                    let diff =
                      Mock_snark_pool.Resource_pool.Diff.Add_solved_work
                        ( statements
                        , {Priced_proof.Stable.Latest.proof= proofs; fee} )
                      |> Envelope.Incoming.local
                    in
                    let%map res =
                      Mock_snark_pool.Resource_pool.Diff.verify t diff
                    in
                    assert (not res) )
              in
              [%test_eq: Transaction_snark_work.Info.t list] completed_works
                (Mock_snark_pool.Resource_pool.all_completed_work t) ) )

    let%test_unit "When two priced proofs of the same work are inserted into \
                   the snark pool, the fee of the work is at most the minimum \
                   of those fees" =
      Quickcheck.test
        ~sexp_of:
          [%sexp_of:
            Mock_snark_pool.Resource_pool.t Deferred.t
            * Mocks.Transaction_snark_work.Statement.t
            * Fee_with_prover.t
            * Fee_with_prover.t]
        (Async.Quickcheck.Generator.tuple4 gen
           Mocks.Transaction_snark_work.Statement.gen Fee_with_prover.gen
           Fee_with_prover.gen) ~f:(fun (t, work, fee_1, fee_2) ->
          Async.Thread_safe.block_on_async_exn (fun () ->
              let%bind t = t in
              let%bind _ = apply_diff t work fee_1 in
              let%map _ = apply_diff t work fee_2 in
              let fee_upper_bound = Currency.Fee.min fee_1.fee fee_2.fee in
              let {Priced_proof.fee= {fee; _}; _} =
                Option.value_exn
                  (Mock_snark_pool.Resource_pool.request_proof t work)
              in
              assert (fee <= fee_upper_bound) ) )

    let%test_unit "A priced proof of a work will replace an existing priced \
                   proof of the same work only if it's fee is smaller than \
                   the existing priced proof" =
      Quickcheck.test
        ~sexp_of:
          [%sexp_of:
            Mock_snark_pool.Resource_pool.t Deferred.t
            * Mocks.Transaction_snark_work.Statement.t
            * Fee_with_prover.t
            * Fee_with_prover.t]
        (Quickcheck.Generator.tuple4 gen
           Mocks.Transaction_snark_work.Statement.gen Fee_with_prover.gen
           Fee_with_prover.gen) ~f:(fun (t, work, fee_1, fee_2) ->
          Async.Thread_safe.block_on_async_exn (fun () ->
              let%bind t = t in
              Mock_snark_pool.Resource_pool.remove_solved_work t work ;
              let expensive_fee = max fee_1 fee_2
              and cheap_fee = min fee_1 fee_2 in
              let%bind _ = apply_diff t work cheap_fee in
              let%map res = apply_diff t work expensive_fee in
              assert (Result.is_error res) ;
              assert (
                cheap_fee.fee
                = (Option.value_exn
                     (Mock_snark_pool.Resource_pool.request_proof t work))
                    .fee
                    .fee ) ) )

    let fake_work =
      `One
        (Quickcheck.random_value ~seed:(`Deterministic "worktest")
           Transaction_snark.Statement.gen)

    let%test_unit "Work that gets fed into apply_and_broadcast will be \
                   received in the pool's reader" =
      Async.Thread_safe.block_on_async_exn (fun () ->
          let pool_reader, _pool_writer =
            Strict_pipe.(create ~name:"Snark pool test" Synchronous)
          in
          let local_reader, _local_writer =
            Strict_pipe.(create ~name:"Snark pool test" Synchronous)
          in
          let frontier_broadcast_pipe_r, _ =
            Broadcast_pipe.create (Some (Mocks.Transition_frontier.create ()))
          in
          let%bind verifier =
            Verifier.create ~logger ~proof_level
              ~pids:(Child_processes.Termination.create_pid_table ())
              ~conf_dir:None
          in
          let config = config verifier in
          let network_pool =
            Mock_snark_pool.create ~config ~constraint_constants
              ~incoming_diffs:pool_reader ~local_diffs:local_reader ~logger
              ~frontier_broadcast_pipe:frontier_broadcast_pipe_r
          in
          let priced_proof =
            { Priced_proof.proof=
                `One
                  (mk_dummy_proof
                     (Quickcheck.random_value
                        ~seed:(`Deterministic "test proof")
                        Transaction_snark.Statement.gen))
            ; fee=
                { fee= Currency.Fee.of_int 0
                ; prover= Signature_lib.Public_key.Compressed.empty } }
          in
          let command =
            Mock_snark_pool.Resource_pool.Diff.Add_solved_work
              (fake_work, priced_proof)
          in
          don't_wait_for
          @@ Linear_pipe.iter (Mock_snark_pool.broadcasts network_pool)
               ~f:(fun _ ->
                 let pool = Mock_snark_pool.resource_pool network_pool in
                 ( match
                     Mock_snark_pool.Resource_pool.request_proof pool fake_work
                   with
                 | Some {proof; fee= _} ->
                     assert (proof = priced_proof.proof)
                 | None ->
                     failwith "There should have been a proof here" ) ;
                 Deferred.unit ) ;
          Mock_snark_pool.apply_and_broadcast network_pool
            (Envelope.Incoming.local command, Fn.const (), Fn.const ()) )

    let%test_unit "when creating a network, the incoming diffs and locally \
                   generated diffs in reader pipes will automatically get \
                   process" =
      Async.Thread_safe.block_on_async_exn (fun () ->
          let work_count = 10 in
          let works =
            Quickcheck.random_sequence ~seed:(`Deterministic "works")
              Transaction_snark.Statement.gen
            |> Fn.flip Sequence.take work_count
            |> Sequence.map ~f:(fun x -> `One x)
            |> Sequence.to_list
          in
          let per_reader = work_count / 2 in
          let create_work work =
            Mock_snark_pool.Resource_pool.Diff.Add_solved_work
              ( work
              , Priced_proof.
                  { proof= One_or_two.map ~f:mk_dummy_proof work
                  ; fee=
                      { fee= Currency.Fee.of_int 0
                      ; prover= Signature_lib.Public_key.Compressed.empty } }
              )
          in
          let verify_unsolved_work () =
            let pool_reader, pool_writer =
              Strict_pipe.(create ~name:"Snark pool test" Synchronous)
            in
            let local_reader, local_writer =
              Strict_pipe.(create ~name:"Snark pool test" Synchronous)
            in
            (*incomming diffs*)
            List.map (List.take works per_reader) ~f:create_work
            |> List.map ~f:(fun work ->
                   (Envelope.Incoming.local work, Fn.const ()) )
            |> List.iter ~f:(fun diff ->
                   Strict_pipe.Writer.write pool_writer diff
                   |> Deferred.don't_wait_for ) ;
            (* locally generated diffs *)
            List.map (List.drop works per_reader) ~f:create_work
            |> List.iter ~f:(fun diff ->
                   Strict_pipe.Writer.write local_writer (diff, Fn.const ())
                   |> Deferred.don't_wait_for ) ;
            let%bind () = Async.Scheduler.yield_until_no_jobs_remain () in
            let frontier_broadcast_pipe_r, _ =
              Broadcast_pipe.create
                (Some (Mocks.Transition_frontier.create ()))
            in
            let%bind verifier =
              Verifier.create ~logger ~proof_level
                ~pids:(Child_processes.Termination.create_pid_table ())
                ~conf_dir:None
            in
            let config = config verifier in
            let network_pool =
              Mock_snark_pool.create ~logger ~config ~constraint_constants
                ~incoming_diffs:pool_reader ~local_diffs:local_reader
                ~frontier_broadcast_pipe:frontier_broadcast_pipe_r
            in
            don't_wait_for
            @@ Linear_pipe.iter (Mock_snark_pool.broadcasts network_pool)
                 ~f:(fun work_command ->
                   let work =
                     match work_command with
                     | Mock_snark_pool.Resource_pool.Diff.Add_solved_work
                         (work, _) ->
                         work
                   in
                   assert (List.mem works work ~equal:( = )) ;
                   Deferred.unit ) ;
            Deferred.unit
          in
          verify_unsolved_work () )

    let%test_unit "rebroadcast behavior" =
      let pool_reader, _pool_writer =
        Strict_pipe.(create ~name:"Snark pool test" Synchronous)
      in
      let local_reader, _local_writer =
        Strict_pipe.(create ~name:"Snark pool test" Synchronous)
      in
      let frontier_broadcast_pipe_r, _w = Broadcast_pipe.create None in
      let stmt1, stmt2 =
        Quickcheck.random_value ~seed:(`Deterministic "")
          (Quickcheck.Generator.filter
             ~f:(fun (a, b) ->
               Mocks.Transaction_snark_work.Statement.compare a b <> 0 )
             (Quickcheck.Generator.tuple2
                Mocks.Transaction_snark_work.Statement.gen
                Mocks.Transaction_snark_work.Statement.gen))
      in
      let fee1, fee2 =
        Quickcheck.random_value ~seed:(`Deterministic "")
          (Quickcheck.Generator.tuple2 Fee_with_prover.gen Fee_with_prover.gen)
      in
      let fake_sender =
        Envelope.Sender.Remote
          ( Unix.Inet_addr.of_string "1.2.4.8"
          , Peer.Id.unsafe_of_string "contents should be irrelevant" )
      in
      Async.Thread_safe.block_on_async_exn (fun () ->
          let open Deferred.Let_syntax in
          let%bind verifier =
            Verifier.create ~logger ~proof_level
              ~pids:(Child_processes.Termination.create_pid_table ())
              ~conf_dir:None
          in
          let config = config verifier in
          let network_pool =
            Mock_snark_pool.create ~logger:(Logger.null ()) ~config
              ~constraint_constants ~incoming_diffs:pool_reader
              ~local_diffs:local_reader
              ~frontier_broadcast_pipe:frontier_broadcast_pipe_r
          in
          let resource_pool = Mock_snark_pool.resource_pool network_pool in
          let%bind res1 =
            apply_diff ~sender:fake_sender resource_pool stmt1 fee1
          in
          let ok_exn = function
            | Ok e ->
                e
            | Error (`Other e) ->
                Or_error.ok_exn (Error e)
            | Error (`Locally_generated _) ->
                failwith "rejected because locally generated"
          in
          ok_exn res1 |> ignore ;
          let rebroadcastable1 =
            Mock_snark_pool.For_tests.get_rebroadcastable resource_pool
              ~is_expired:(Fn.const `Ok)
          in
          [%test_eq: Mock_snark_pool.Resource_pool.Diff.t list]
            rebroadcastable1 [] ;
          let%bind res2 = apply_diff resource_pool stmt2 fee2 in
          let proof2 = One_or_two.map ~f:mk_dummy_proof stmt2 in
          ok_exn res2 |> ignore ;
          let rebroadcastable2 =
            Mock_snark_pool.For_tests.get_rebroadcastable resource_pool
              ~is_expired:(Fn.const `Ok)
          in
          [%test_eq: Mock_snark_pool.Resource_pool.Diff.t list]
            rebroadcastable2
            [Add_solved_work (stmt2, {proof= proof2; fee= fee2})] ;
          let rebroadcastable3 =
            Mock_snark_pool.For_tests.get_rebroadcastable resource_pool
              ~is_expired:(Fn.const `Expired)
          in
          [%test_eq: Mock_snark_pool.Resource_pool.Diff.t list]
            rebroadcastable3 [] ;
          Deferred.unit )
  end )
