[%%import
"/src/config.mlh"]

open Ppxlib
open Asttypes
open Parsetree
open Longident
open Core
open Coda_state

(* TODO: refactor to do compile time selection *)
[%%if
proof_level = "full"]

let use_dummy_values = false

[%%else]

let use_dummy_values = true

[%%endif]

module type S = sig
  val base_proof_expr : Parsetree.expression

  val transaction_verification : Parsetree.expression

  val blockchain_verification : Parsetree.expression

  val key_hashes : Parsetree.expression
end

let hashes =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = Location.none
  end) in
  let open E in
  let f (_, x) = estring (Core.Md5.to_hex x) in
  let ts = Transaction_snark.constraint_system_digests () in
  let bs =
    Blockchain_snark.Blockchain_snark_state.constraint_system_digests ()
  in
  elist (List.map ts ~f @ List.map bs ~f)

module Dummy = struct
  let loc = Ppxlib.Location.none

  let base_proof_expr = [%expr Coda_base.Proof.dummy]

  let transaction_verification =
    [%expr fun () -> Pickles.Verification_key.dummy]

  let blockchain_verification =
    [%expr fun () -> Pickles.Verification_key.dummy]

  let key_hashes = hashes
end

module Make_real () = struct
  let loc = Ppxlib.Location.none

  module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end)

  open E

  let t0 = Time.now ()

  module T = Transaction_snark.Make ()

  let t1 = Time.now ()

  let () =
    printf "%s: %s\n%!" "Transaction_snark.Make"
      (Time.Span.to_string_hum (Time.diff t1 t0))

  module B = Blockchain_snark.Blockchain_snark_state.Make (T)

  let key_hashes = hashes

  let transaction_verification =
    [%expr
      let t =
        lazy
          (Core.Binable.of_string
             (module Pickles.Verification_key)
             [%e
               estring
                 (Binable.to_string
                    (module Pickles.Verification_key)
                    (Lazy.force T.verification_key))])
      in
      fun () -> Lazy.force t]

  let blockchain_verification =
    [%expr
      let t =
        lazy
          (Core.Binable.of_string
             (module Pickles.Verification_key)
             [%e
               estring
                 (Binable.to_string
                    (module Pickles.Verification_key)
                    (Lazy.force B.Proof.verification_key))])
      in
      fun () -> Lazy.force t]

  let t2 = Time.now ()

  let () =
    printf "%s: %s\n%!" "Blockchain_snark.Make"
      (Time.Span.to_string_hum (Time.diff t2 t1))

  let loc = Ppxlib.Location.none

  let protocol_state_with_hash = Genesis_protocol_state.compile_time_genesis ()

  let base_proof_expr =
    let prev_state =
      Protocol_state.negative_one ~genesis_ledger:Test_genesis_ledger.t
    in
    let curr = protocol_state_with_hash.data in
    let dummy_txn_stmt : Transaction_snark.Statement.With_sok.t =
      { sok_digest= Coda_base.Sok_message.Digest.default
      ; source=
          Blockchain_state.snarked_ledger_hash
            (Protocol_state.blockchain_state prev_state)
      ; target=
          Blockchain_state.snarked_ledger_hash
            (Protocol_state.blockchain_state curr)
      ; supply_increase= Currency.Amount.zero
      ; fee_excess= Currency.Amount.Signed.zero
      ; pending_coinbase_stack_state=
          { source= Coda_base.Pending_coinbase.Stack.empty
          ; target= Coda_base.Pending_coinbase.Stack.empty } }
    in
    let dummy = Coda_base.Proof.dummy in
    let proof =
      B.step
        ~handler:
          (Consensus.Data.Prover_state.precomputed_handler
             ~genesis_ledger:Test_genesis_ledger.t)
        { transition=
            Snark_transition.genesis ~genesis_ledger:Test_genesis_ledger.t
        ; prev_state }
        [(prev_state, dummy); (dummy_txn_stmt, dummy)]
        protocol_state_with_hash.data
    in
    [%expr
      Core.Binable.of_string
        (module Coda_base.Proof.Stable.V1)
        [%e
          estring (Binable.to_string (module Coda_base.Proof.Stable.V1) proof)]]
end

open Async

let main () =
  let target = Sys.argv.(1) in
  let fmt = Format.formatter_of_out_channel (Out_channel.create target) in
  let loc = Ppxlib.Location.none in
  let (module M) =
    if use_dummy_values then (module Dummy : S) else (module Make_real () : S)
  in
  let structure =
    [%str
      let base_proof = [%e M.base_proof_expr]

      let key_hashes = [%e M.key_hashes]

      let blockchain_verification = [%e M.blockchain_verification]

      let transaction_verification = [%e M.transaction_verification]]
  in
  Pprintast.top_phrase fmt (Ptop_def structure) ;
  exit 0

let () =
  don't_wait_for (main ()) ;
  never_returns (Scheduler.go ())
