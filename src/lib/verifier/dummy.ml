open Core_kernel
open Async_kernel
open Mina_base

type t =
  { proof_level : Genesis_constants.Proof_level.t
  ; constraint_constants : Genesis_constants.Constraint_constants.t
  }

type invalid = Common.invalid [@@deriving bin_io_unversioned, to_yojson]

let invalid_to_string = Common.invalid_to_string

type ledger_proof = Ledger_proof.t

let create ~logger:_ ~proof_level ~constraint_constants ~pids:_ ~conf_dir:_ =
  match proof_level with
  | Genesis_constants.Proof_level.Full ->
      failwith "Unable to handle proof-level=Full"
  | Check | None ->
      Deferred.return { proof_level; constraint_constants }

let verify_blockchain_snarks _ _ = Deferred.Or_error.return true

(* N.B.: Valid_assuming is never returned, in fact; we assert a return type
   containing Valid_assuming to match the expected type
*)
let verify_commands _ (cs : User_command.Verifiable.t list) :
    [ `Valid of Mina_base.User_command.Valid.t
    | `Valid_assuming of
      ( Pickles.Side_loaded.Verification_key.t
      * Mina_base.Zkapp_statement.t
      * Pickles.Side_loaded.Proof.t )
      list
    | Common.invalid ]
    list
    Deferred.Or_error.t =
  List.map cs ~f:(fun c ->
      match Common.check c with
      | `Valid c ->
          `Valid c
      | `Valid_assuming (c, _) ->
          `Valid c
      | `Invalid_keys keys ->
          `Invalid_keys keys
      | `Invalid_signature keys ->
          `Invalid_signature keys
      | `Invalid_proof ->
          `Invalid_proof
      | `Missing_verification_key keys ->
          `Missing_verification_key keys )
  |> Deferred.Or_error.return

let verify_transaction_snarks _ ts =
  (* Don't check if the proof has default sok, becasue they were probably not
     intended to be checked. If it has some value then check that against the
     message passed.
     This is particularly used to test that invalid proofs are not added to the
     snark pool
  *)
  List.for_all ts ~f:(fun (proof, message) ->
      let msg_digest = Sok_message.digest message in
      let sok_digest = Transaction_snark.sok_digest proof in
      Sok_message.Digest.(equal sok_digest default)
      || Mina_base.Sok_message.Digest.equal sok_digest msg_digest )
  |> Deferred.Or_error.return

let get_blockchain_verification_key { proof_level; constraint_constants } =
  Deferred.Or_error.try_with (fun () ->
      let module T = Transaction_snark.Make (struct
        let constraint_constants = constraint_constants

        let proof_level = proof_level
      end) in
      let module B = Blockchain_snark.Blockchain_snark_state.Make (struct
        let tag = T.tag

        let constraint_constants = constraint_constants

        let proof_level = proof_level
      end) in
      Deferred.return @@ Lazy.force B.Proof.verification_key )
