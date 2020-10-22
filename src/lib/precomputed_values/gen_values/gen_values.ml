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
  val blockchain_proof_system_id : Parsetree.expression

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
  let constraint_constants = Genesis_constants.Constraint_constants.compiled in
  let proof_level = Genesis_constants.Proof_level.compiled in
  let ts =
    Transaction_snark.constraint_system_digests ~constraint_constants ()
  in
  let bs =
    Blockchain_snark.Blockchain_snark_state.constraint_system_digests
      ~proof_level ~constraint_constants ()
  in
  elist (List.map ts ~f @ List.map bs ~f)

module Dummy = struct
  let loc = Ppxlib.Location.none

  let base_proof_expr = [%expr Coda_base.Proof.blockchain_dummy]

  let blockchain_proof_system_id =
    [%expr fun () -> Pickles.Verification_key.Id.dummy ()]

  let transaction_verification =
    [%expr fun () -> Lazy.force Pickles.Verification_key.dummy]

  let blockchain_verification =
    [%expr fun () -> Lazy.force Pickles.Verification_key.dummy]

  let key_hashes = hashes
end

module Make_real () = struct
  let loc = Ppxlib.Location.none

  module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end)

  open E

  module T = Transaction_snark.Make (struct
    let constraint_constants = Genesis_constants.Constraint_constants.compiled
  end)

  module B = Blockchain_snark.Blockchain_snark_state.Make (struct
    let tag = T.tag

    let constraint_constants = Genesis_constants.Constraint_constants.compiled

    let proof_level = Genesis_constants.Proof_level.compiled
  end)

  let key_hashes = hashes

  let constraint_constants = Genesis_constants.Constraint_constants.compiled

  let genesis_constants = Genesis_constants.compiled

  let consensus_constants =
    Consensus.Constants.create ~constraint_constants
      ~protocol_constants:genesis_constants.protocol

  let protocol_state_with_hash =
    Genesis_protocol_state.t ~genesis_ledger:Test_genesis_ledger.t
      ~constraint_constants ~consensus_constants

  let compiled_values =
    Genesis_proof.create_values
      (module B)
      { runtime_config= Runtime_config.default
      ; constraint_constants
      ; proof_level= Full
      ; genesis_constants
      ; genesis_ledger= (module Test_genesis_ledger)
      ; consensus_constants
      ; protocol_state_with_hash
      ; blockchain_proof_system_id= Some (Lazy.force B.Proof.id) }

  let blockchain_proof_system_id =
    [%expr
      let t =
        lazy
          (Core.Sexp.of_string_conv_exn
             [%e
               estring
                 (Core.Sexp.to_string
                    (Pickles.Verification_key.Id.sexp_of_t
                       (Lazy.force B.Proof.id)))]
             Pickles.Verification_key.Id.t_of_sexp)
      in
      fun () -> Lazy.force t]

  let transaction_verification =
    [%expr
      let t =
        lazy
          (Core.Binable.of_string
             (module Pickles.Verification_key.Stable.Latest)
             [%e
               estring
                 (Binable.to_string
                    (module Pickles.Verification_key.Stable.Latest)
                    (Lazy.force T.verification_key))])
      in
      fun () -> Lazy.force t]

  let blockchain_verification =
    [%expr
      let t =
        lazy
          (Core.Binable.of_string
             (module Pickles.Verification_key.Stable.Latest)
             [%e
               estring
                 (Binable.to_string
                    (module Pickles.Verification_key.Stable.Latest)
                    (Lazy.force B.Proof.verification_key))])
      in
      fun () -> Lazy.force t]

  let base_proof_expr =
    [%expr
      Core.Binable.of_string
        (module Coda_base.Proof.Stable.Latest)
        [%e
          estring
            (Binable.to_string
               (module Coda_base.Proof.Stable.Latest)
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

      let blockchain_proof_system_id = [%e M.blockchain_proof_system_id]

      let compiled_base_proof = [%e M.base_proof_expr]

      let for_unit_tests =
        lazy
          (let protocol_state_with_hash =
             Coda_state.Genesis_protocol_state.t
               ~genesis_ledger:Genesis_ledger.(Packed.t for_unit_tests)
               ~constraint_constants:
                 Genesis_constants.Constraint_constants.for_unit_tests
               ~consensus_constants:
                 (Lazy.force Consensus.Constants.for_unit_tests)
           in
           { runtime_config= Runtime_config.default
           ; constraint_constants=
               Genesis_constants.Constraint_constants.for_unit_tests
           ; proof_level= Genesis_constants.Proof_level.for_unit_tests
           ; genesis_constants= Genesis_constants.for_unit_tests
           ; genesis_ledger= Genesis_ledger.for_unit_tests
           ; consensus_constants= Lazy.force Consensus.Constants.for_unit_tests
           ; protocol_state_with_hash
           ; genesis_proof= Coda_base.Proof.blockchain_dummy })

      let key_hashes = [%e M.key_hashes]

      let blockchain_verification = [%e M.blockchain_verification]

      let transaction_verification = [%e M.transaction_verification]

      let compiled =
        lazy
          (let constraint_constants =
             Genesis_constants.Constraint_constants.compiled
           in
           let genesis_constants = Genesis_constants.compiled in
           let consensus_constants =
             Consensus.Constants.create ~constraint_constants
               ~protocol_constants:genesis_constants.protocol
           in
           let protocol_state_with_hash =
             Coda_state.Genesis_protocol_state.t
               ~genesis_ledger:Test_genesis_ledger.t ~constraint_constants
               ~consensus_constants
           in
           { runtime_config= Runtime_config.default
           ; constraint_constants
           ; proof_level= Genesis_constants.Proof_level.compiled
           ; genesis_constants
           ; genesis_ledger= (module Test_genesis_ledger)
           ; consensus_constants
           ; protocol_state_with_hash
           ; genesis_proof= compiled_base_proof })]
  in
  Pprintast.top_phrase fmt (Ptop_def structure) ;
  exit 0

let () =
  don't_wait_for (main ()) ;
  never_returns (Scheduler.go ())
