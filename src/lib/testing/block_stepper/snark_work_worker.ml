open Core
open Async
open Mina_base

module Worker_state = struct
  module type S = sig
    val prove :
         Snark_work_lib.Spec.Single.Stable.Latest.t
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
    let sok_digest = Sok_message.Digest.default in
    match proof_level with
    | Genesis_constants.Proof_level.Full ->
        let module T = Transaction_snark.Make (struct
          let signature_kind = signature_kind

          let constraint_constants = constraint_constants

          let proof_level = proof_level
        end) in
        (* The worker uses an identity cache since proofs are sent back to the
           host and don't need persistent caching in the worker process. *)
        let proof_cache_db = Proof_cache_tag.create_identity_db () in
        let logger = Logger.null () in
        Deferred.return
          ( module struct
            let prove spec =
              Snark_work_proving.prove_from_stable_spec ~proof_cache_db
                ~signature_kind ~sok_digest ~logger
                (module T)
                spec
          end : S )
    | Check | No_check ->
        Deferred.return
          ( module struct
            let prove spec =
              Snark_work_proving.prove_dummy_from_stable_spec spec
          end : S )

  let get = Fn.id
end

module Functions = struct
  type ('i, 'o) t =
    'i Bin_prot.Type_class.t
    * 'o Bin_prot.Type_class.t
    * (Worker_state.t -> 'i -> 'o Deferred.t)

  let create input output f : ('i, 'o) t = (input, output, f)

  let prove_single =
    create Snark_work_lib.Spec.Single.Stable.Latest.bin_t
      [%bin_type_class: Ledger_proof.Stable.Latest.t Or_error.t] (fun w spec ->
        let (module W) = Worker_state.get w in
        W.prove spec )
end

module Worker = struct
  module T = struct
    module F = Rpc_parallel.Function

    type 'w functions =
      { prove_single :
          ( 'w
          , Snark_work_lib.Spec.Single.Stable.Latest.t
          , Ledger_proof.t Or_error.t )
          F.t
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
        { prove_single = f Functions.prove_single }

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

let prove_single t spec =
  Worker.Connection.run t.connection ~f:Worker.functions.prove_single ~arg:spec
  >>| Or_error.join

let close t =
  let%map () = Worker.Connection.close t.connection in
  Signal.send_i Signal.term (`Pid (Process.pid t.process))
