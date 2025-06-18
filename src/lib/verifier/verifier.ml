module Common = Common
module Failure = Verification_failure
module Prod = Prod
module Dummy = Dummy

(* Spawning a process using [Rpc_parallel] calls the current binary with a
   particular set of arguments. Unfortunately, unit tests use the inline test
   binary -- which doesn't support these arguments -- and so we're not able to
   use these [Rpc_parallel] calls. Here we detect this and call out to the dummy
   verifier instead.
   The implementation of dummy is equivalent to the one with
   [proof_level != Full], so this should make no difference. Inline tests
   shouldn't be run with [proof_level = Full].
   WARN: do NOT attempt to log anything here! Some of our util would write
   STDOUT to files and use them, e.g. GraphQL schema
*)
let implementation :
    (module Verifier_intf.S with type ledger_proof = Ledger_proof.t) =
  match (Base__Import.am_testing, Sys.getenv_opt "MINA_USE_DUMMY_VERIFIER") with
  | true, _ | _, Some "1" ->
      (module Dummy)
  | _ ->
      (* WARN: must set below code for Prod verifier!
         Parallel.init_master () ; *)
      (module Prod)

include (val implementation)

module For_tests = struct
  let get_verification_keys_eagerly ~constraint_constants ~proof_level =
    let module T = Transaction_snark.Make (struct
      let constraint_constants = constraint_constants

      let proof_level = proof_level
    end) in
    let module B = Blockchain_snark.Blockchain_snark_state.Make (struct
      let tag = T.tag

      let constraint_constants = constraint_constants

      let proof_level = proof_level
    end) in
    let open Async.Deferred.Let_syntax in
    let%bind blockchain_vk = Lazy.force B.Proof.verification_key in
    let%bind transaction_vk = Lazy.force T.verification_key in
    return (`Blockchain blockchain_vk, `Transaction transaction_vk)

  let default ~logger ~constraint_constants ?enable_internal_tracing
      ?internal_trace_filename ~proof_level
      ?(pids = Child_processes.Termination.create_pid_table ()) ?conf_dir
      ?(commit_id = "unspecified") () =
    let%bind.Async.Deferred ( `Blockchain blockchain_verification_key
                            , `Transaction transaction_verification_key ) =
      get_verification_keys_eagerly ~constraint_constants ~proof_level
    in
    create ~logger ?enable_internal_tracing ?internal_trace_filename
      ~proof_level ~pids ~conf_dir ~commit_id ~blockchain_verification_key
      ~transaction_verification_key ()
end
