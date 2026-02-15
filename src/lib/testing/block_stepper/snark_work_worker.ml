open Core
open Async
open Mina_base

(* RPC argument types — bin_io required by rpc_parallel *)

type prove_base_input =
  { statement : Mina_state.Snarked_ledger_state.With_sok.Stable.V2.t
  ; witness : Transaction_witness.Stable.V2.t
  }
[@@deriving bin_io_unversioned]

type prove_zkapp_segment_input =
  { statement : Mina_state.Snarked_ledger_state.With_sok.Stable.V2.t
  ; witness : Transaction_snark.Zkapp_command_segment.Witness.Stable.V1.t
  ; spec : Transaction_snark.Zkapp_command_segment.Basic.Stable.V1.t
  }
[@@deriving bin_io_unversioned]

type prove_merge_input =
  { proof1 : Ledger_proof.Stable.V2.t
  ; proof2 : Ledger_proof.Stable.V2.t
  ; sok_digest : Sok_message.Digest.Stable.V1.t
  }
[@@deriving bin_io_unversioned]

module Worker_state = struct
  (* The module type uses stable types matching the RPC boundary. *)
  module type S = sig
    val prove_base :
         Mina_state.Snarked_ledger_state.With_sok.Stable.V2.t
      -> Transaction_witness.Stable.V2.t
      -> Ledger_proof.t Deferred.Or_error.t

    val prove_zkapp_segment :
         Mina_state.Snarked_ledger_state.With_sok.Stable.V2.t
      -> Transaction_snark.Zkapp_command_segment.Witness.Stable.V1.t
      -> Transaction_snark.Zkapp_command_segment.Basic.Stable.V1.t
      -> Ledger_proof.t Deferred.Or_error.t

    val prove_merge :
         Ledger_proof.Stable.V2.t
      -> Ledger_proof.Stable.V2.t
      -> sok_digest:Sok_message.Digest.Stable.V1.t
      -> Ledger_proof.t Deferred.Or_error.t
  end

  (* bin_io required by rpc_parallel *)
  type init_arg =
    { proof_level : Genesis_constants.Proof_level.t
    ; constraint_constants : Genesis_constants.Constraint_constants.t
    ; signature_kind : Mina_signature_kind_type.t
    }
  [@@deriving bin_io_unversioned]

  type t = (module S)

  let create { proof_level; constraint_constants; signature_kind } :
      t Deferred.t =
    match proof_level with
    | Genesis_constants.Proof_level.Full ->
        let module T = Transaction_snark.Make (struct
          let signature_kind = signature_kind

          let constraint_constants = constraint_constants

          let proof_level = proof_level
        end) in
        (* Identity cache: proofs are sent back to the host, no persistent
           caching needed in the worker process. *)
        let proof_cache_db = Proof_cache_tag.create_identity_db () in
        Deferred.return
          ( module struct
            let prove_base statement (w : Transaction_witness.Stable.V2.t) =
              let open Deferred.Or_error.Let_syntax in
              match w.transaction with
              | Command (Signed_command cmd) ->
                  let%bind cmd =
                    Deferred.return
                    @@ Result.of_option
                         (Signed_command.check ~signature_kind cmd)
                         ~error:
                           (Error.of_string "Command has an invalid signature")
                  in
                  Deferred.Or_error.try_with ~here:[%here] (fun () ->
                      T.of_non_zkapp_command_transaction ~statement
                        { Transaction_protocol_state.Poly.transaction =
                            Command (Signed_command cmd)
                        ; block_data = w.protocol_state_body
                        ; global_slot = w.block_global_slot
                        }
                        ~init_stack:w.init_stack
                        (unstage
                           (Mina_ledger.Sparse_ledger.handler
                              w.first_pass_ledger ) ) )
              | Fee_transfer ft ->
                  Deferred.Or_error.try_with ~here:[%here] (fun () ->
                      T.of_non_zkapp_command_transaction ~statement
                        { Transaction_protocol_state.Poly.transaction =
                            Fee_transfer ft
                        ; block_data = w.protocol_state_body
                        ; global_slot = w.block_global_slot
                        }
                        ~init_stack:w.init_stack
                        (unstage
                           (Mina_ledger.Sparse_ledger.handler
                              w.first_pass_ledger ) ) )
              | Coinbase cb ->
                  Deferred.Or_error.try_with ~here:[%here] (fun () ->
                      T.of_non_zkapp_command_transaction ~statement
                        { Transaction_protocol_state.Poly.transaction =
                            Coinbase cb
                        ; block_data = w.protocol_state_body
                        ; global_slot = w.block_global_slot
                        }
                        ~init_stack:w.init_stack
                        (unstage
                           (Mina_ledger.Sparse_ledger.handler
                              w.first_pass_ledger ) ) )
              | Command (Zkapp_command _) ->
                  Deferred.Or_error.error_string
                    "prove_base called with zkapp command"

            let prove_zkapp_segment statement witness_stable spec =
              let witness =
                Transaction_snark.Zkapp_command_segment.Witness
                .write_all_proofs_to_disk ~signature_kind ~proof_cache_db
                  witness_stable
              in
              Deferred.Or_error.try_with ~here:[%here] (fun () ->
                  T.of_zkapp_command_segment_exn ~statement ~witness ~spec )

            let prove_merge proof1 proof2 ~sok_digest =
              T.merge proof1 proof2 ~sok_digest
          end : S )
    | Check | No_check ->
        Deferred.return
          ( module struct
            let prove_base statement _w =
              Deferred.Or_error.return
                (Ledger_proof.For_tests.mk_dummy_proof
                   { statement with sok_digest = () } )

            let prove_zkapp_segment statement _witness _spec =
              Deferred.Or_error.return
                (Ledger_proof.For_tests.mk_dummy_proof
                   { statement with sok_digest = () } )

            let prove_merge proof1 _proof2 ~sok_digest:_ =
              Deferred.Or_error.return
                (Ledger_proof.For_tests.mk_dummy_proof
                   (Ledger_proof.statement proof1) )
          end : S )

  let get = Fn.id
end

module Functions = struct
  type ('i, 'o) t =
    'i Bin_prot.Type_class.t
    * 'o Bin_prot.Type_class.t
    * (Worker_state.t -> 'i -> 'o Deferred.t)

  let create input output f : ('i, 'o) t = (input, output, f)

  let prove_base =
    create bin_prove_base_input
      [%bin_type_class: Ledger_proof.Stable.Latest.t Or_error.t]
      (fun w { statement; witness } ->
        let (module W) = Worker_state.get w in
        W.prove_base statement witness )

  let prove_zkapp_segment =
    create bin_prove_zkapp_segment_input
      [%bin_type_class: Ledger_proof.Stable.Latest.t Or_error.t]
      (fun w { statement; witness; spec } ->
        let (module W) = Worker_state.get w in
        W.prove_zkapp_segment statement witness spec )

  let prove_merge =
    create bin_prove_merge_input
      [%bin_type_class: Ledger_proof.Stable.Latest.t Or_error.t]
      (fun w { proof1; proof2; sok_digest } ->
        let (module W) = Worker_state.get w in
        W.prove_merge proof1 proof2 ~sok_digest )
end

module Worker = struct
  module T = struct
    module F = Rpc_parallel.Function

    type 'w functions =
      { prove_base : ('w, prove_base_input, Ledger_proof.t Or_error.t) F.t
      ; prove_zkapp_segment :
          ('w, prove_zkapp_segment_input, Ledger_proof.t Or_error.t) F.t
      ; prove_merge : ('w, prove_merge_input, Ledger_proof.t Or_error.t) F.t
      }

    module Worker_state = Worker_state

    module Connection_state = struct
      (* bin_io required by rpc_parallel *)
      type init_arg = unit [@@deriving bin_io_unversioned]

      type t = unit
    end

    module Functions
        (C : Rpc_parallel.Creator
               with type worker_state := Worker_state.t
                and type connection_state := Connection_state.t) =
    struct
      let functions =
        let f (i, o, f) =
          C.create_rpc
            ~f:(fun ~worker_state ~conn_state:_ i -> f worker_state i)
            ~bin_input:i ~bin_output:o ()
        in
        { prove_base = f Functions.prove_base
        ; prove_zkapp_segment = f Functions.prove_zkapp_segment
        ; prove_merge = f Functions.prove_merge
        }

      let init_worker_state
          Worker_state.{ proof_level; constraint_constants; signature_kind } =
        Worker_state.create
          { proof_level; constraint_constants; signature_kind }

      let init_connection_state ~connection:_ ~worker_state:_ () = Deferred.unit
    end
  end

  include Rpc_parallel.Make (T)
end

type t =
  { connection : Worker.Connection.t; process : Process.t; logger : Logger.t }

let create ~logger ~proof_level ~constraint_constants ~signature_kind =
  [%log info] "Starting a new snark work worker process" ;
  let on_failure err =
    [%log error] "Snark work worker process failed with error $err"
      ~metadata:[ ("err", Error_json.error_to_yojson err) ] ;
    Error.raise err
  in
  let%map connection, process =
    (* Circuit compilation on startup is slow, need long timeout *)
    Worker.spawn_in_foreground_exn ~connection_timeout:(Time.Span.of_min 10.)
      ~on_failure ~shutdown_on:Connection_closed ~connection_state_init_arg:()
      { proof_level; constraint_constants; signature_kind }
  in
  [%log info] "Snark work worker started with pid %d"
    (Process.pid process |> Pid.to_int) ;
  don't_wait_for
  @@ Pipe.iter
       (Process.stderr process |> Reader.pipe)
       ~f:(fun stderr ->
         return
         @@ [%log error] "Snark work worker stderr: $stderr"
              ~metadata:[ ("stderr", `String stderr) ] ) ;
  { connection; process; logger }

let prove_base t statement witness =
  Worker.Connection.run t.connection ~f:Worker.functions.prove_base
    ~arg:{ statement; witness }
  >>| Or_error.join

let prove_zkapp_segment t statement witness spec =
  Worker.Connection.run t.connection ~f:Worker.functions.prove_zkapp_segment
    ~arg:{ statement; witness; spec }
  >>| Or_error.join

let prove_merge t proof1 proof2 sok_digest =
  Worker.Connection.run t.connection ~f:Worker.functions.prove_merge
    ~arg:{ proof1; proof2; sok_digest }
  >>| Or_error.join

let close t =
  let%map () = Worker.Connection.close t.connection in
  Signal.send_i Signal.term (`Pid (Process.pid t.process))
