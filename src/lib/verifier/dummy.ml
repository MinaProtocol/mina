open Core_kernel
open Async_kernel
open Mina_base

type t =
  { proof_level : Genesis_constants.Proof_level.t
  ; constraint_constants : Genesis_constants.Constraint_constants.t
  ; verify_blockchain_snarks :
         Blockchain_snark.Blockchain.t list
      -> unit Or_error.t Or_error.t Deferred.t
  ; verification_key : Pickles.Verification_key.t Lazy.t
  ; verify_transaction_snarks :
         (Ledger_proof.Prod.t * Mina_base.Sok_message.t) list
      -> unit Or_error.t Or_error.t Deferred.t
  }

type invalid = Common.invalid [@@deriving bin_io_unversioned, to_yojson]

let invalid_to_error = Common.invalid_to_error

type ledger_proof = Ledger_proof.t

let create ~logger:_ ?enable_internal_tracing:_ ?internal_trace_filename:_
    ~proof_level ~constraint_constants ~pids:_ ~conf_dir:_ () =
  let module T = Transaction_snark.Make (struct
    let constraint_constants = constraint_constants

    let proof_level = proof_level
  end) in
  let module B = Blockchain_snark.Blockchain_snark_state.Make (struct
    let tag = T.tag

    let constraint_constants = constraint_constants

    let proof_level = proof_level
  end) in
  let verify_blockchain_snarks chains =
    match proof_level with
    | Genesis_constants.Proof_level.Full ->
        B.Proof.verify
          (List.map chains ~f:(fun snark ->
               ( Blockchain_snark.Blockchain.state snark
               , Blockchain_snark.Blockchain.proof snark ) ) )
        |> Deferred.Or_error.map ~f:Or_error.return
    | Check | None ->
        Deferred.Or_error.return (Ok ())
  in
  let verify_transaction_snarks ts =
    match proof_level with
    | Full -> (
        match Or_error.try_with (fun () -> T.verify ts) with
        | Ok result ->
            result |> Deferred.map ~f:Or_error.return
        | Error e ->
            failwith (Error.to_string_hum e) )
    | Check | None ->
        (* Don't check if the proof has default sok, becasue they were probably not
           intended to be checked. If it has some value then check that against the
           message passed.
           This is particularly used to test that invalid proofs are not added to the
           snark pool
        *)
        if
          List.for_all ts ~f:(fun (proof, message) ->
              let msg_digest = Sok_message.digest message in
              let sok_digest = Transaction_snark.sok_digest proof in
              Sok_message.Digest.(equal sok_digest default)
              || Mina_base.Sok_message.Digest.equal sok_digest msg_digest )
        then Deferred.Or_error.return (Ok ())
        else
          Deferred.Or_error.return
            (Or_error.error_string
               "Transaction_snark.verify: Mismatched sok_message" )
  in

  Deferred.return
    { proof_level
    ; constraint_constants
    ; verify_blockchain_snarks
    ; verification_key = B.Proof.verification_key
    ; verify_transaction_snarks
    }

let verify_blockchain_snarks { verify_blockchain_snarks; _ } chains =
  verify_blockchain_snarks chains

(* N.B.: Valid_assuming is never returned, in fact; we assert a return type
   containing Valid_assuming to match the expected type
*)
let verify_commands { proof_level; _ }
    (cs : User_command.Verifiable.t With_status.t list) :
    [ `Valid of Mina_base.User_command.Valid.t
    | `Valid_assuming of
      ( Pickles.Side_loaded.Verification_key.t
      * Mina_base.Zkapp_statement.t
      * Pickles.Side_loaded.Proof.t )
      list
    | Common.invalid ]
    list
    Deferred.Or_error.t =
  match proof_level with
  | Check | None ->
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
          | `Invalid_proof err ->
              `Invalid_proof err
          | `Missing_verification_key keys ->
              `Missing_verification_key keys
          | `Unexpected_verification_key keys ->
              `Unexpected_verification_key keys
          | `Mismatched_authorization_kind keys ->
              `Mismatched_authorization_kind keys )
      |> Deferred.Or_error.return
  | Full ->
      let cs = List.map cs ~f:Common.check in
      let to_verify =
        List.concat_map cs ~f:(function
          | `Valid _ ->
              []
          | `Valid_assuming (_, xs) ->
              xs
          | `Invalid_keys _
          | `Invalid_signature _
          | `Invalid_proof _
          | `Missing_verification_key _
          | `Unexpected_verification_key _
          | `Mismatched_authorization_kind _ ->
              [] )
      in
      let%map all_verified =
        Pickles.Side_loaded.verify ~typ:Zkapp_statement.typ to_verify
      in
      Ok
        (List.map cs ~f:(function
          | `Valid c ->
              `Valid c
          | `Valid_assuming (c, xs) ->
              if Or_error.is_ok all_verified then `Valid c
              else `Valid_assuming xs
          | `Invalid_keys keys ->
              `Invalid_keys keys
          | `Invalid_signature keys ->
              `Invalid_signature keys
          | `Invalid_proof err ->
              `Invalid_proof err
          | `Missing_verification_key keys ->
              `Missing_verification_key keys
          | `Unexpected_verification_key keys ->
              `Unexpected_verification_key keys
          | `Mismatched_authorization_kind keys ->
              `Mismatched_authorization_kind keys ) )

let verify_transaction_snarks { verify_transaction_snarks; _ } ts =
  verify_transaction_snarks ts

let get_blockchain_verification_key { verification_key; _ } =
  Deferred.Or_error.try_with ~here:[%here] (fun () ->
      Deferred.return @@ Lazy.force verification_key )

let toggle_internal_tracing _ _ = Deferred.Or_error.ok_unit

let set_itn_logger_data _ ~daemon_port:_ = Deferred.Or_error.ok_unit
