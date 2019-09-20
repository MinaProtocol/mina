open Core_kernel
open Async
open Pipe_lib

module type S = sig
  type ledger_proof

  type transaction_snark_statement

  type transaction_snark_work_statement

  type transaction_snark_work_checked

  type transition_frontier

  type transaction_snark_work_info

  module Resource_pool : sig
    include
      Intf.Snark_resource_pool_intf
      with type ledger_proof := ledger_proof
       and type work := transaction_snark_work_statement
       and type transition_frontier := transition_frontier
       and type work_info := transaction_snark_work_info

    val remove_solved_work : t -> transaction_snark_work_statement -> unit

    module Diff :
      Intf.Snark_pool_diff_intf
      with type ledger_proof := ledger_proof
       and type work := transaction_snark_work_statement
       and type resource_pool := t
  end

  include
    Intf.Network_pool_base_intf
    with type resource_pool := Resource_pool.t
     and type resource_pool_diff := Resource_pool.Diff.t
     and type transition_frontier := transition_frontier

  val get_completed_work :
       t
    -> transaction_snark_work_statement
    -> transaction_snark_work_checked option

  val load :
       logger:Logger.t
    -> pids:Child_processes.Termination.t
    -> trust_system:Trust_system.t
    -> disk_location:string
    -> incoming_diffs:Resource_pool.Diff.t Envelope.Incoming.t
                      Linear_pipe.Reader.t
    -> frontier_broadcast_pipe:transition_frontier option
                               Broadcast_pipe.Reader.t
    -> t Deferred.t

  val add_completed_work :
       t
    -> ( ('a, 'b, 'c) Snark_work_lib.Work.Single.Spec.t
         Snark_work_lib.Work.Spec.t
       , ledger_proof )
       Snark_work_lib.Work.Result.t
    -> unit Deferred.t
end

module type Transition_frontier_intf = sig
  type work

  type t

  module Extensions : sig
    module Work : sig
      type t = work [@@deriving sexp]

      module Stable : sig
        module V1 : sig
          type nonrec t = t [@@deriving sexp, bin_io]

          include Hashable.S_binable with type t := t
        end
      end

      include Hashable.S with type t := t
    end
  end

  val snark_pool_refcount_pipe :
    t -> (int * int Extensions.Work.Table.t) Pipe_lib.Broadcast_pipe.Reader.t
end

module Make
    (Transition_frontier : Transition_frontier_intf
                           with type work := Transaction_snark_work.Statement.t) :
  S
  with type transaction_snark_statement := Transaction_snark.Statement.t
   and type transaction_snark_work_statement :=
              Transaction_snark_work.Statement.t
   and type transaction_snark_work_checked := Transaction_snark_work.Checked.t
   and type transition_frontier := Transition_frontier.t
   and type ledger_proof := Ledger_proof.t
   and type transaction_snark_work_info := Transaction_snark_work.Info.t =
struct
  module Statement_table = Transaction_snark_work.Statement.Stable.V1.Table

  module Resource_pool = struct
    module T = struct
      (* TODO : Version this type *)
      type serializable =
        Ledger_proof.Stable.V1.t One_or_two.Stable.V1.t
        Priced_proof.Stable.V1.t
        Statement_table.t
      [@@deriving sexp, bin_io]

      type t =
        { snark_table: serializable
        ; mutable ref_table: int Statement_table.t option
        ; logger: Logger.t sexp_opaque
        ; pids: Child_processes.Termination.t sexp_opaque
        ; trust_system: Trust_system.t sexp_opaque }
      [@@deriving sexp]

      let of_serializable table ~logger ~pids ~trust_system : t =
        {snark_table= table; ref_table= None; logger; pids; trust_system}

      let removed_breadcrumb_wait = 10

      let snark_pool_json t : Yojson.Safe.json =
        `List
          (Statement_table.fold ~init:[] t.snark_table
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
        Statement_table.fold ~init:[] t.snark_table
          ~f:(fun ~key ~data:{proof= _; fee= {fee; prover}} acc ->
            let work_ids = Transaction_snark_work.Statement.work_ids key in
            {Transaction_snark_work.Info.statements= key; work_ids; fee; prover}
            :: acc )

      let listen_to_frontier_broadcast_pipe frontier_broadcast_pipe (t : t) =
        (* start with empty ref table *)
        t.ref_table <- None ;
        let tf_deferred =
          Broadcast_pipe.Reader.iter frontier_broadcast_pipe ~f:(function
            | Some tf ->
                (* Start the count at the max so we flush after reconstructing the transition_frontier *)
                let removedCounter = ref removed_breadcrumb_wait in
                let pipe = Transition_frontier.snark_pool_refcount_pipe tf in
                let deferred =
                  Broadcast_pipe.Reader.iter pipe
                    ~f:(fun (removed, refcount_table) ->
                      t.ref_table <- Some refcount_table ;
                      removedCounter := !removedCounter + removed ;
                      if !removedCounter < removed_breadcrumb_wait then
                        return ()
                      else (
                        removedCounter := 0 ;
                        Statement_table.filter_keys_inplace t.snark_table
                          ~f:(fun work ->
                            Option.is_some
                              (Statement_table.find refcount_table work) ) ;
                        return
                          (*when snark works removed from the pool*)
                          Coda_metrics.(
                            Gauge.set Snark_work.snark_pool_size
                              (Float.of_int @@ Hashtbl.length t.snark_table)) )
                  )
                in
                deferred
            | None ->
                t.ref_table <- None ;
                return () )
        in
        Deferred.don't_wait_for tf_deferred

      let create ~logger ~pids ~trust_system ~frontier_broadcast_pipe =
        let t =
          { snark_table= Statement_table.create ()
          ; logger
          ; pids
          ; trust_system
          ; ref_table= None }
        in
        listen_to_frontier_broadcast_pipe frontier_broadcast_pipe t ;
        t

      let request_proof t = Statement_table.find t.snark_table

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

      let add_snark t ~work ~(proof : Ledger_proof.t One_or_two.t) ~fee =
        if work_is_referenced t work then (
          (*Note: fee against existing proofs and the new proofs are checked in
          Diff.apply which calls this function*)
          Hashtbl.set t.snark_table ~key:work ~data:{proof; fee} ;
          (*when snark work is added to the pool*)
          Coda_metrics.(
            Gauge.set Snark_work.snark_pool_size
              (Float.of_int @@ Hashtbl.length t.snark_table)) ;
          `Rebroadcast )
        else `Don't_rebroadcast

      let verify_and_act t ~work ~sender =
        let statements, priced_proof = work in
        let open Deferred.Or_error.Let_syntax in
        let {Priced_proof.proof= proofs; fee= {prover; fee}} = priced_proof in
        let trust_record =
          Trust_system.record_envelope_sender t.trust_system t.logger sender
        in
        let log_and_punish ?(punish = true) statement e =
          let metadata =
            [ ("work_id", `Int (Transaction_snark.Statement.hash statement))
            ; ("prover", Signature_lib.Public_key.Compressed.to_yojson prover)
            ; ("fee", Currency.Fee.to_yojson fee)
            ; ("error", `String (Error.to_string_hum e)) ]
          in
          Logger.error t.logger ~module_:__MODULE__ ~location:__LOC__ ~metadata
            "Error verifying transaction snark: $error" ;
          if punish then
            trust_record
              ( Trust_system.Actions.Sent_invalid_proof
              , Some ("Error verifying transaction snark: $error", metadata) )
          else Deferred.return ()
        in
        let message = Coda_base.Sok_message.create ~fee ~prover in
        let verify ~proof ~statement =
          let open Deferred.Let_syntax in
          let statement_eq a b =
            Int.(Transaction_snark.Statement.compare a b = 0)
          in
          if not (statement_eq (Ledger_proof.statement proof) statement) then
            let e = Error.of_string "Statement and proof do not match" in
            let%map () = log_and_punish statement e in
            Error e
          else
            let%bind verifier =
              Verifier.create ~logger:t.logger ~pids:t.pids
            in
            match%bind
              Verifier.verify_transaction_snark verifier proof ~message
            with
            | Ok true ->
                Deferred.Or_error.return ()
            | Ok false ->
                (*Invalid proof*)
                let e = Error.of_string "Invalid proof" in
                let%map () = log_and_punish statement e in
                Error e
            | Error e ->
                (* Verifier crashed or other errors at our end. Don't punish the peer*)
                let%map () = log_and_punish ~punish:false statement e in
                Error e
        in
        let%bind pairs = One_or_two.zip statements proofs |> Deferred.return in
        One_or_two.Deferred_result.fold ~init:() pairs
          ~f:(fun _ (statement, proof) -> verify ~proof ~statement)
    end

    include T
    module Diff =
      Snark_pool_diff.Make
        (Ledger_proof.Stable.V1)
        (Transaction_snark_work.Statement)
        (Transaction_snark_work.Info)
        (Transition_frontier)
        (T)

    let remove_solved_work t = Statement_table.remove t.snark_table
  end

  include Network_pool_base.Make (Transition_frontier) (Resource_pool)

  let get_completed_work t statement =
    Option.map
      (Resource_pool.request_proof (resource_pool t) statement)
      ~f:(fun Priced_proof.{proof; fee= {fee; prover}} ->
        Transaction_snark_work.Checked.create_unsafe
          {Transaction_snark_work.fee; proofs= proof; prover} )

  let load ~logger ~pids ~trust_system ~disk_location ~incoming_diffs
      ~frontier_broadcast_pipe =
    match%map
      Async.Reader.load_bin_prot disk_location
        Resource_pool.bin_reader_serializable
    with
    | Ok snark_table ->
        let pool =
          Resource_pool.of_serializable snark_table ~logger ~pids ~trust_system
        in
        let network_pool =
          of_resource_pool_and_diffs pool ~logger ~incoming_diffs
        in
        Resource_pool.listen_to_frontier_broadcast_pipe frontier_broadcast_pipe
          pool ;
        network_pool
    | Error _e ->
        create ~logger ~pids ~trust_system ~incoming_diffs
          ~frontier_broadcast_pipe

  open Snark_work_lib.Work

  let add_completed_work t
      (res : (('a, 'b, 'c) Single.Spec.t Spec.t, Ledger_proof.t) Result.t) =
    apply_and_broadcast t
      (Envelope.Incoming.wrap
         ~data:
           (Resource_pool.Diff.Stable.V1.Add_solved_work
              ( One_or_two.map res.spec.instances ~f:Single.Spec.statement
              , { proof= res.proofs
                ; fee= {fee= res.spec.fee; prover= res.prover} } ))
         ~sender:Envelope.Sender.Local)
end

include Make (Transition_frontier)

let%test_module "random set test" =
  ( module struct
    open Coda_base

    let trust_system = Mocks.trust_system

    module Mock_snark_pool = Make (Mocks.Transition_frontier)
    open Ledger_proof.For_tests

    let apply_diff resource_pool work
        ?(proof = One_or_two.map ~f:mk_dummy_proof) fee =
      let diff =
        Mock_snark_pool.Resource_pool.Diff.Stable.Latest.Add_solved_work
          (work, {Priced_proof.Stable.Latest.proof= proof work; fee})
      in
      Mock_snark_pool.Resource_pool.Diff.apply resource_pool
        (Envelope.Incoming.local diff)

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
      let resource_pool =
        Mock_snark_pool.Resource_pool.create ~logger:(Logger.null ())
          ~trust_system:(Trust_system.null ())
          ~pids:(Child_processes.Termination.create_pid_set ())
          ~frontier_broadcast_pipe:frontier_broadcast_pipe_r
      in
      Async.Thread_safe.block_on_async_exn (fun () ->
          let open Deferred.Let_syntax in
          Deferred.List.iter sample_solved_work ~f:(fun (work, fee) ->
              let%map _ = apply_diff resource_pool work fee in
              () ) ) ;
      resource_pool

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
                      ~sok_digest:invalid_sok_digest ~proof:Proof.dummy )
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
      Quickcheck.test
        ~sexp_of:
          [%sexp_of:
            Mock_snark_pool.Resource_pool.t
            * ( Transaction_snark_work.Statement.t
              * Ledger_proof.t One_or_two.t
              * Fee_with_prover.t
              * Signature_lib.Public_key.Compressed.t )
              list] (Quickcheck.Generator.tuple2 gen invalid_work_gen)
        ~f:(fun (t, invalid_work_lst) ->
          Async.Thread_safe.block_on_async_exn (fun () ->
              let open Deferred.Let_syntax in
              let completed_works =
                Mock_snark_pool.Resource_pool.all_completed_work t
              in
              let%map () =
                Deferred.List.iter invalid_work_lst
                  ~f:(fun (statements, proofs, fee, _) ->
                    let%map res =
                      apply_diff t statements ~proof:(fun _ -> proofs) fee
                    in
                    assert (Or_error.is_error res) ;
                    () )
              in
              [%test_eq: Transaction_snark_work.Info.t list] completed_works
                (Mock_snark_pool.Resource_pool.all_completed_work t) ) )

    let%test_unit "When two priced proofs of the same work are inserted into \
                   the snark pool, the fee of the work is at most the minimum \
                   of those fees" =
      Quickcheck.test
        ~sexp_of:
          [%sexp_of:
            Mock_snark_pool.Resource_pool.t
            * Mocks.Transaction_snark_work.Statement.t
            * Fee_with_prover.t
            * Fee_with_prover.t]
        (Quickcheck.Generator.tuple4 gen
           Mocks.Transaction_snark_work.Statement.gen Fee_with_prover.gen
           Fee_with_prover.gen) ~f:(fun (t, work, fee_1, fee_2) ->
          Async.Thread_safe.block_on_async_exn (fun () ->
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
            Mock_snark_pool.Resource_pool.t
            * Mocks.Transaction_snark_work.Statement.t
            * Fee_with_prover.t
            * Fee_with_prover.t]
        (Quickcheck.Generator.tuple4 gen
           Mocks.Transaction_snark_work.Statement.gen Fee_with_prover.gen
           Fee_with_prover.gen) ~f:(fun (t, work, fee_1, fee_2) ->
          Async.Thread_safe.block_on_async_exn (fun () ->
              Mock_snark_pool.Resource_pool.remove_solved_work t work ;
              let expensive_fee = max fee_1 fee_2
              and cheap_fee = min fee_1 fee_2 in
              let%bind _ = apply_diff t work cheap_fee in
              let%map res = apply_diff t work expensive_fee in
              assert (Or_error.is_error res) ;
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
      let pool_reader, _pool_writer = Linear_pipe.create () in
      let frontier_broadcast_pipe_r, _ =
        Broadcast_pipe.create (Some (Mocks.Transition_frontier.create ()))
      in
      let network_pool =
        Mock_snark_pool.create ~logger:(Logger.null ())
          ~pids:(Child_processes.Termination.create_pid_set ())
          ~trust_system ~incoming_diffs:pool_reader
          ~frontier_broadcast_pipe:frontier_broadcast_pipe_r
      in
      let priced_proof =
        { Priced_proof.proof=
            `One
              (mk_dummy_proof
                 (Quickcheck.random_value ~seed:(`Deterministic "test proof")
                    Transaction_snark.Statement.gen))
        ; fee=
            { fee= Currency.Fee.of_int 0
            ; prover= Signature_lib.Public_key.Compressed.empty } }
      in
      let command =
        Mock_snark_pool.Resource_pool.Diff.Stable.V1.Add_solved_work
          (fake_work, priced_proof)
      in
      (fun () ->
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
          (Envelope.Incoming.local command) )
      |> Async.Thread_safe.block_on_async_exn

    let%test_unit "when creating a network, the incoming diffs in reader pipe \
                   will automatically get process" =
      let works =
        Quickcheck.random_sequence ~seed:(`Deterministic "works")
          Transaction_snark.Statement.gen
        |> Fn.flip Sequence.take 10
        |> Sequence.map ~f:(fun x -> `One x)
        |> Sequence.to_list
      in
      let verify_unsolved_work () =
        let work_diffs =
          List.map works ~f:(fun work ->
              Envelope.Incoming.local
                (Mock_snark_pool.Resource_pool.Diff.Stable.V1.Add_solved_work
                   ( work
                   , Priced_proof.
                       { proof= One_or_two.map ~f:mk_dummy_proof work
                       ; fee=
                           { fee= Currency.Fee.of_int 0
                           ; prover= Signature_lib.Public_key.Compressed.empty
                           } } )) )
          |> Linear_pipe.of_list
        in
        let frontier_broadcast_pipe_r, _ =
          Broadcast_pipe.create (Some (Mocks.Transition_frontier.create ()))
        in
        let network_pool =
          Mock_snark_pool.create ~logger:(Logger.null ())
            ~pids:(Child_processes.Termination.create_pid_set ())
            ~trust_system ~incoming_diffs:work_diffs
            ~frontier_broadcast_pipe:frontier_broadcast_pipe_r
        in
        don't_wait_for
        @@ Linear_pipe.iter (Mock_snark_pool.broadcasts network_pool)
             ~f:(fun work_command ->
               let work =
                 match work_command with
                 | Mock_snark_pool.Resource_pool.Diff.Stable.V1.Add_solved_work
                     (work, _) ->
                     work
               in
               assert (List.mem works work ~equal:( = )) ;
               Deferred.unit ) ;
        Deferred.unit
      in
      verify_unsolved_work |> Async.Thread_safe.block_on_async_exn
  end )
