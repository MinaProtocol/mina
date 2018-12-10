open Core_kernel
open Protocols.Coda_pow
open Pipe_lib.Strict_pipe
open Coda_base
open O1trace

module Make (Inputs : Inputs.S) :
  Transition_handler_processor_intf
  with type state_hash := State_hash.t
   and type time_controller := Inputs.Time.Controller.t
   and type external_transition := Inputs.External_transition.t
   and type transition_frontier := Inputs.Transition_frontier.t
   and type transition_frontier_breadcrumb :=
              Inputs.Transition_frontier.Breadcrumb.t = struct
  open Inputs
  open Consensus.Mechanism
  module Catchup_monitor = Catchup_monitor.Make (Inputs)

  (* TODO: calculate a sensible value from postake consensus arguments *)
  let catchup_timeout_duration = Time.Span.of_ms 6000L

  let transition_parent_hash t =
    External_transition.protocol_state t |> Protocol_state.previous_state_hash

  let run ~logger ~time_controller ~frontier ~valid_transition_reader
      ~catchup_job_writer ~catchup_breadcrumbs_reader =
    let logger = Logger.child logger "Transition_handler.Catchup" in
    let catchup_monitor = Catchup_monitor.create ~catchup_job_writer in
    ignore
      (Reader.Merge.iter_sync
         [ Reader.map catchup_breadcrumbs_reader ~f:(fun cb ->
               `Catchup_breadcrumbs cb )
         ; Reader.map valid_transition_reader ~f:(fun vt ->
               `Valid_transition vt ) ]
         ~f:(fun msg ->
           trace_task "transition_handler_processor" (fun () ->
               match msg with
               | `Catchup_breadcrumbs [] ->
                   Logger.error logger "read empty catchup transitions"
               | `Catchup_breadcrumbs (_ :: _ as breadcrumbs) ->
                   List.iter breadcrumbs
                     ~f:(Transition_frontier.attach_breadcrumb_exn frontier)
               | `Valid_transition transition -> (
                   match
                     Transition_frontier.find frontier
                       (transition_parent_hash (With_hash.data transition))
                   with
                   | None ->
                       Catchup_monitor.watch catchup_monitor ~logger
                         ~time_controller
                         ~timeout_duration:catchup_timeout_duration ~transition
                   | Some _ ->
                       ignore
                         (Transition_frontier.add_transition_exn frontier
                            transition) ;
                       Catchup_monitor.notify catchup_monitor ~time_controller
                         ~transition ) ) ))
end

let%test_module "Transition_handler.Processor tests" =
  ( module struct
    open Async
    open Pipe_lib
    open Strict_pipe

    module Time = Coda_base.Block_time

    module State_proof = struct
      include Coda_base.Proof

      let verify _ = failwith "stub"
    end

    module Ledger_proof = struct
      type t =
        Transaction_snark.Statement.t
        * Coda_base.Sok_message.Digest.Stable.V1.t
      [@@deriving sexp, bin_io]

      let underlying_proof (_ : t) = Proof.dummy

      let statement ((t, _) : t) : Transaction_snark.Statement.t = t

      let statement_target (t : Transaction_snark.Statement.t) = t.target

      let sok_digest (_, d) = d

      let create ~statement ~sok_digest ~proof:_ = (statement, sok_digest)
    end

    module Ledger_proof_statement = Transaction_snark.Statement

    module Ledger_proof_verifier = struct
      let verify _ = failwith "stub"
    end

    module Staged_ledger_aux_hash = struct
      include Coda_base.Staged_ledger_hash.Aux_hash.Stable.V1

      let of_bytes = Coda_base.Staged_ledger_hash.Aux_hash.of_bytes
    end

    (*
    module User_command = struct
      include (
        Coda_base.User_command :
          module type of Coda_base.User_command
          with module With_valid_signature := Coda_base.User_command
                                              .With_valid_signature )

      let fee (t : t) = Payload.fee t.payload

      let sender (t : t) = Signature_lib.Public_key.compress t.sender

      let seed = Coda_base.Secure_random.string ()

      let compare t1 t2 = Coda_base.User_command.Stable.V1.compare ~seed t1 t2

      module With_valid_signature = struct
        module T = struct
          include Coda_base.User_command.With_valid_signature

          let compare t1 t2 =
            Coda_base.User_command.With_valid_signature.compare ~seed t1 t2
        end

        include T
        include Comparable.Make (T)
      end
    end

    module Transaction = struct
      module T = struct
        type t = Coda_base.Transaction.t =
          | User_command of User_command.With_valid_signature.t
          | Fee_transfer of Coda_base.Fee_transfer.t
          | Coinbase of Coda_base.Coinbase.t
        [@@deriving compare, eq]
      end

      let fee_excess = Coda_base.Transaction.fee_excess

      let supply_increase = Coda_base.Transaction.supply_increase

      include T

      include (
        Coda_base.Transaction :
          module type of Coda_base.Transaction with type t := t )
    end

    module Completed_work =
      Ledger_builder.Make_completed_work
        (Signature_lib.Public_key.Compressed)
        (Ledger_proof)
        (Ledger_proof_statement)

    module Ledger_builder_diff = Ledger_builder.Make_diff (struct
      module Ledger_hash = Coda_base.Ledger_hash
      module Ledger_proof = Ledger_proof
      module Ledger_builder_aux_hash = Ledger_builder_aux_hash
      module Ledger_builder_hash = Coda_base.Ledger_builder_hash
      module Compressed_public_key = Signature_lib.Public_key.Compressed
      module User_command = User_command
      module Completed_work = Completed_work
    end)
    *)

    module Transaction_snark_work = struct
      let proofs_length = 2

      module Statement = struct
        module T = struct
          type t = Transaction_snark.Statement.t list [@@deriving bin_io, sexp, hash, compare]
        end

        include T

        include Hashable.Make_binable (T)

        let gen =
          Quickcheck.Generator.list_with_length proofs_length
            Transaction_snark.Statement.gen
      end

      type t = {fee: Currency.Fee.t; proofs: Ledger_proof.t list; prover: Signature_lib.Public_key.Compressed.t}
      [@@deriving sexp, bin_io]

      type unchecked = t
      [@@deriving sexp, bin_io]

      module Checked = struct
        type t = unchecked [@@deriving sexp, bin_io]

        let create_unsafe = Fn.id
      end

      let forget = Fn.id
    end

    module Staged_ledger_diff = struct
      module At_most_two = struct
        type 'a t = Zero | One of 'a option | Two of ('a * 'a option) option
        [@@deriving sexp, bin_io]

        let increase _ _ = failwith "stub"
      end

      module At_most_one = struct
        type 'a t = Zero | One of 'a option [@@deriving sexp, bin_io]

        let increase _ _ = failwith "stub"
      end

      type diff =
        {completed_works: Transaction_snark_work.t list; user_commands: Coda_base.User_command.t list}
      [@@deriving sexp, bin_io]

      type diff_with_at_most_two_coinbase =
        {diff: diff; coinbase_parts: Transaction_snark_work.t At_most_two.t}
      [@@deriving sexp, bin_io]

      type diff_with_at_most_one_coinbase =
        {diff: diff; coinbase_added: Transaction_snark_work.t At_most_one.t}
      [@@deriving sexp, bin_io]

      type pre_diffs =
        ( diff_with_at_most_one_coinbase
        , diff_with_at_most_two_coinbase * diff_with_at_most_one_coinbase )
        Either.t
      [@@deriving sexp, bin_io]

      type t =
        {pre_diffs: pre_diffs; prev_hash: Coda_base.Staged_ledger_hash.t; creator: Signature_lib.Public_key.Compressed.t}
      [@@deriving sexp, bin_io]

      module With_valid_signatures_and_proofs = struct
        type diff =
          { completed_works: Transaction_snark_work.Checked.t list
          ; user_commands: Coda_base.User_command.With_valid_signature.t list }
        [@@deriving sexp]

        type diff_with_at_most_two_coinbase =
          {diff: diff; coinbase_parts: Transaction_snark_work.Checked.t At_most_two.t}
        [@@deriving sexp]

        type diff_with_at_most_one_coinbase =
          {diff: diff; coinbase_added: Transaction_snark_work.Checked.t At_most_one.t}
        [@@deriving sexp]

        type pre_diffs =
          ( diff_with_at_most_one_coinbase
          , diff_with_at_most_two_coinbase * diff_with_at_most_one_coinbase )
          Either.t
        [@@deriving sexp]

        type t =
          { pre_diffs: pre_diffs
          ; prev_hash: Coda_base.Staged_ledger_hash.t
          ; creator: Signature_lib.Public_key.Compressed.t }
        [@@deriving sexp]

        let user_commands _ = failwith "stub"
      end

      let forget _ = failwith "stub"

      let user_commands _ = failwith "stub"
    end

    module External_transition =
      Coda_base.External_transition.Make
        (Staged_ledger_diff)
        (Consensus.Mechanism.Protocol_state)

    module Staged_ledger = struct
      type t = unit [@@deriving sexp]

      type serializable = unit [@@deriving bin_io, sexp]

      module Scan_state = struct
        type t = unit [@@deriving bin_io]

        let hash _ = failwith "stub"

        let is_valid _ = failwith "stub"

        let empty () = ()
      end

      let ledger _ = failwith "stub"

      let create ~ledger:_ = ()

      let of_scan_state_and_ledger ~snarked_ledger_hash:_ ~ledger:_ ~scan_state:_ =
        Or_error.return ()

      let of_serialized_and_unserialized ~serialized:_ ~unserialized:_ = ()

      let copy () = ()

      let hash () = failwith "stub"

      let scan_state () = failwith "stub"

      let serializable_of_t _ = failwith "stub"

      let apply () _ ~logger:_ = failwith "stub"

      let apply_diff_unchecked () _ = failwith "stub"

      let snarked_ledger () ~snarked_ledger_hash:_ = failwith "stub"

      let ledger () = failwith "stub"

      let current_ledger_proof () = failwith "stub"

      let create_diff () ~self:_ ~logger:_ ~transactions_by_fee:_ ~get_completed_work:_ =
        failwith "stub"

      let all_work_pairs () = failwith "stub"

      let statement_exn () = failwith "stub"
    end

    (*
    module Ledger_builder = Ledger_builder.Make (struct
      module Compressed_public_key = Signature_lib.Public_key.Compressed
      module User_command = User_command
      module Fee_transfer = Coda_base.Fee_transfer
      module Coinbase = Coda_base.Coinbase
      module Transaction = Transaction
      module Ledger_hash = Coda_base.Ledger_hash
      module Frozen_ledger_hash = Coda_base.Frozen_ledger_hash
      module Ledger_proof_statement = Ledger_proof_statement
      module Proof = Proof
      module Sok_message = Coda_base.Sok_message
      module Ledger_proof = Ledger_proof
      module Ledger_proof_verifier = Ledger_proof_verifier
      module Account = Coda_base.Account
      module Ledger = Coda_base.Ledger
      module Sparse_ledger = Coda_base.Sparse_ledger
      module Ledger_builder_aux_hash = Ledger_builder_aux_hash
      module Ledger_builder_hash = Coda_base.Ledger_builder_hash
      module Completed_work = Completed_work
      module Ledger_builder_diff = Ledger_builder_diff

      module Config = struct
        let transaction_capacity_log_2 = 8
      end

      let check = failwith "stub"
    end)
    *)

    module Base_inputs = struct
      module Ledger_proof_statement = Ledger_proof_statement
      module Ledger_proof = Ledger_proof
      module Transaction_snark_work = Transaction_snark_work
      module External_transition = External_transition
      module Staged_ledger_aux_hash = Staged_ledger_aux_hash
      module Staged_ledger_diff = Staged_ledger_diff
      module Staged_ledger = Staged_ledger
    end

    module Transition_frontier = Transition_frontier.Make (Base_inputs)

    module Processor = Make (struct
      include Base_inputs
      module Time = Time
      module State_proof = State_proof
      module Transition_frontier = Transition_frontier
    end)

    let dummy_staged_ledger_diff =
      let creator = Quickcheck.random_value Signature_lib.Public_key.Compressed.gen in
      { Staged_ledger_diff.pre_diffs=
          Either.First
            { diff=
                { completed_works= []
                ; user_commands= [] }
            ; coinbase_added= Staged_ledger_diff.At_most_one.Zero }
      ; prev_hash= Coda_base.Staged_ledger_hash.dummy
      ; creator }

    let gen_external_transition previous_protocol_state =
      let open Quickcheck.Generator.Let_syntax in
      let blockchain_state = Consensus.Mechanism.Blockchain_state.genesis in
      let%map consensus_state = Consensus.Mechanism.For_tests.gen_consensus_state
        ~gen_slot_advancement:(Int.gen_incl 1 10)
        ~previous_protocol_state
        ~snarked_ledger_hash:Coda_base.Frozen_ledger_hash.empty_hash
      in
      let protocol_state = Consensus.Mechanism.Protocol_state.create_value ~blockchain_state ~consensus_state ~previous_state_hash:(With_hash.hash previous_protocol_state) in
      let transition = External_transition.create ~protocol_state ~protocol_state_proof:Proof.dummy ~staged_ledger_diff:dummy_staged_ledger_diff in
      {With_hash.data= transition; hash= Consensus.Mechanism.Protocol_state.hash protocol_state}

    let dummy_protocol_state =
      let blockchain_state =
        Consensus.Mechanism.Blockchain_state.create_value
          ~staged_ledger_hash:Coda_base.Staged_ledger_hash.dummy
          ~ledger_hash:Coda_base.Frozen_ledger_hash.empty_hash
          ~timestamp:(Time.now ())
      in
      let consensus_state = Consensus.Mechanism.Protocol_state.consensus_state Consensus.Mechanism.genesis_protocol_state in
      let protocol_state = Consensus.Mechanism.Protocol_state.create_value ~blockchain_state ~consensus_state ~previous_state_hash:Coda_base.State_hash.(of_hash zero) in
      With_hash.of_data ~hash_data:Consensus.Mechanism.Protocol_state.hash protocol_state

    let dummy_external_transition =
      Quickcheck.random_value (gen_external_transition dummy_protocol_state)

    let gen_transition ~seed ~choice frontier =
      if choice then
        let parent =
          Transition_frontier.all_breadcrumbs frontier
          |> List.permute
          |> List.hd_exn
          |> Transition_frontier.Breadcrumb.transition_with_hash
          |> With_hash.map ~f:External_transition.protocol_state
        in
        ( `Exists
        , Quickcheck.random_value ~seed
            (gen_external_transition parent) )
      else
        (`Does_not_exist, Quickcheck.random_value ~seed (gen_external_transition (With_hash.map dummy_external_transition ~f:External_transition.protocol_state)))

    let%test "valid transition behavior" =
      (* number of transitions to write during test *)
      let test_size = 200 in
      Thread_safe.block_on_async_exn (fun () ->
         let seed = `Nondeterministic in
         let logger = Logger.create () in
         let time_controller = Time.Controller.create () in
         let root_snarked_ledger = Coda_base.Ledger.Db.create () in
         let root_transaction_snark_scan_state = () in
         let root_transition =
           { With_hash.data=
               External_transition.create
                 ~protocol_state:(
                   Consensus.Mechanism.Protocol_state.create_value
                     ~previous_state_hash:(Coda_base.State_hash.(of_hash zero))
                     ~blockchain_state:(
                       Consensus.Mechanism.Blockchain_state.create_value
                         ~ledger_hash:(Coda_base.Frozen_ledger_hash.of_ledger_hash (Coda_base.Ledger.Db.merkle_root root_snarked_ledger))
                         ~staged_ledger_hash:Coda_base.Staged_ledger_hash.dummy
                         ~timestamp:(Time.now ()))
                     ~consensus_state:(
                       Consensus.Mechanism.Protocol_state.consensus_state Consensus.Mechanism.genesis_protocol_state))
                 ~protocol_state_proof:Proof.dummy
                 ~staged_ledger_diff:dummy_staged_ledger_diff
           ; hash= Consensus.Mechanism.Protocol_state.hash Consensus.Mechanism.genesis_protocol_state }
         in
         let frontier =
           Transition_frontier.create
             ~logger
             ~root_transition
             ~root_snarked_ledger
             ~root_transaction_snark_scan_state
             ~root_staged_ledger_diff:None
         in
         let valid_transition_reader, valid_transition_writer =
           Strict_pipe.create (Buffered (`Capacity test_size, `Overflow Drop_head))
         in
         let catchup_job_reader, catchup_job_writer =
           Strict_pipe.create (Buffered (`Capacity test_size, `Overflow Drop_head))
         in
         let catchup_breadcrumbs_reader, _ =
           Strict_pipe.create (Buffered (`Capacity 0, `Overflow Crash))
         in
         let expected_transitions = ref Coda_base.State_hash.Set.empty in
         let expected_catchup_jobs = ref Coda_base.State_hash.Set.empty in
         let expect_transition hash =
           expected_transitions := Set.add !expected_transitions hash
         in
         let expect_catchup_job hash =
           expected_catchup_jobs := Set.add !expected_catchup_jobs hash
         in
         let check_catchup_job catchup_job =
           let hash = With_hash.hash catchup_job in
           if Set.mem !expected_catchup_jobs hash then
             expected_catchup_jobs := Set.remove !expected_catchup_jobs hash
           else
             failwith "received unexpected catchup job"
         in
         Processor.run ~logger ~time_controller ~frontier
           ~valid_transition_reader ~catchup_job_writer
           ~catchup_breadcrumbs_reader ;
         don't_wait_for
           (Reader.iter_without_pushback catchup_job_reader ~f:check_catchup_job) ;
         for _ = 1 to test_size do
           let status, transition =
             gen_transition ~seed
               ~choice:(Quickcheck.random_value ~seed Bool.gen)
               frontier
           in
           ( match status with
           | `Exists -> expect_transition (With_hash.hash transition)
           | `Does_not_exist -> expect_catchup_job (With_hash.hash transition) ) ;
           Writer.write valid_transition_writer transition
         done ;
         (*
           Ivar.wait_for all_transitions_read;
           Ivar.wait_for all_catchups_read;
         *)
         Deferred.create (fun test_completed ->
           ignore (
             Time.Timeout.create () (Time.Span.of_ms (Int64.of_int 500)) ~f:(fun _ ->
                 assert (
                   List.for_all
                     (Transition_frontier.all_hashes frontier)
                     ~f:(fun hash ->
                         Set.exists !expected_transitions ~f:(Coda_base.State_hash.equal hash) ));
                 assert (Set.is_empty !expected_catchup_jobs);
                 Ivar.fill test_completed true ))))
  end )
