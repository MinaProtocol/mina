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

  module T = Transaction_snark.Make ()

  module B = Blockchain_snark.Blockchain_snark_state.Make (T)

  let key_hashes = hashes

  let protocol_state_with_hash =
    Lazy.force Genesis_protocol_state.compile_time_genesis

  let compiled_values =
    Genesis_proof.create_values
      (module B)
      { genesis_constants= Genesis_constants.compiled
      ; genesis_ledger= (module Test_genesis_ledger)
      ; protocol_state_with_hash }

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

  let base_proof_expr =
    [%expr
      Core.Binable.of_string
        (module Coda_base.Proof.Stable.V1)
        [%e
          estring
            (Binable.to_string
               (module Coda_base.Proof.Stable.V1)
               compiled_values.genesis_proof)]]
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
      module T = Genesis_proof.T
      include T

      let compiled_base_proof = [%e M.base_proof_expr]

      let compiled =
        lazy
          (let protocol_state_with_hash =
             Lazy.force Coda_state.Genesis_protocol_state.compile_time_genesis
           in
           { genesis_constants= Genesis_constants.compiled
           ; genesis_ledger= (module Test_genesis_ledger)
           ; protocol_state_with_hash
           ; genesis_proof= compiled_base_proof })

      let unit_test_base_proof = Coda_base.Proof.dummy

      let for_unit_tests =
        lazy
          (let protocol_state_with_hash =
             Lazy.force Coda_state.Genesis_protocol_state.compile_time_genesis
           in
           { genesis_constants= Genesis_constants.for_unit_tests
           ; genesis_ledger= Genesis_ledger.for_unit_tests
           ; protocol_state_with_hash
           ; genesis_proof= unit_test_base_proof })

      let key_hashes = [%e M.key_hashes]

      let blockchain_verification = [%e M.blockchain_verification]

      let transaction_verification = [%e M.transaction_verification]]
  in
  Pprintast.top_phrase fmt (Ptop_def structure) ;
  exit 0

let () =
  don't_wait_for (main ()) ;
  never_returns (Scheduler.go ())
