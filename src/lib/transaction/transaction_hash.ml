open Core_kernel
open Mina_base

[%%import "/src/config.mlh"]

module T = struct
  include Blake2.Make ()
end

include T

module Base58_check = Codable.Make_base58_check (struct
  type t = Stable.Latest.t [@@deriving bin_io_unversioned]

  let version_byte = Base58_check.Version_bytes.transaction_hash

  let description = "Transaction hash"
end)

[%%define_locally
Base58_check.(of_base58_check, of_base58_check_exn, to_base58_check)]

let to_yojson t = `String (to_base58_check t)

let of_yojson = function
  | `String str ->
      Result.map_error (of_base58_check str) ~f:(fun _ ->
          "Transaction_hash.of_yojson: Error decoding string from base58_check \
           format" )
  | _ ->
      Error "Transaction_hash.of_yojson: Expected a string"

let hash_signed_command, hash_zkapp_command =
  let mk_hasher (type a) (module M : Bin_prot.Binable.S with type t = a)
      (cmd : a) =
    cmd |> Binable.to_string (module M) |> digest_string
  in
  let signed_cmd_hasher = mk_hasher (module Signed_command.Stable.Latest) in
  let zkapp_cmd_hasher = mk_hasher (module Zkapp_command.Stable.Latest) in
  (* replace actual signatures, proofs with dummies for hashing, so we can
     reproduce the transaction hashes if signatures, proofs omitted in
     archive db
  *)
  let hash_signed_command (cmd : Signed_command.t) =
    let cmd_dummy_signature = { cmd with signature = Signature.dummy } in
    signed_cmd_hasher cmd_dummy_signature
  in
  let hash_zkapp_command (cmd : Zkapp_command.t) =
    let cmd_dummy_signatures_and_proofs =
      { cmd with
        fee_payer = { cmd.fee_payer with authorization = Signature.dummy }
      ; account_updates =
          Zkapp_command.Call_forest.map cmd.account_updates
            ~f:(fun (acct_update : Account_update.t) ->
              let dummy_auth =
                match acct_update.authorization with
                | Control.Proof _ ->
                    Control.Proof Proof.transaction_dummy
                | Control.Signature _ ->
                    Control.Signature Signature.dummy
                | Control.None_given ->
                    Control.None_given
              in
              { acct_update with authorization = dummy_auth } )
      }
    in
    zkapp_cmd_hasher cmd_dummy_signatures_and_proofs
  in
  (hash_signed_command, hash_zkapp_command)

[%%ifdef consensus_mechanism]

let hash_command cmd =
  match cmd with
  | User_command.Signed_command s ->
      hash_signed_command s
  | User_command.Zkapp_command p ->
      hash_zkapp_command p

let hash_signed_command_v2 = hash_signed_command

(* hash V1 signed commands as if V2 commands *)
let hash_signed_command_v1 (cmd_v1 : Signed_command.t_v1) =
  let cmd = Signed_command.Stable.V1.to_latest cmd_v1 in
  hash_signed_command cmd

let hash_zkapp_command_v1 = hash_zkapp_command

let hash_fee_transfer fee_transfer =
  fee_transfer |> Fee_transfer.Single.to_base58_check |> digest_string

let hash_coinbase coinbase =
  coinbase |> Coinbase.to_base58_check |> digest_string

let hash_of_transaction_id (transaction_id : string) : t Or_error.t =
  (* A transaction id might be:
     - original Base58Check transaction ids of signed commands (Signed_command.V1.t), or
     - a Base64 encoding of signed commands and zkApps (Signed_command.Vn.t, for n >= 2,
       or Zkapp_command.Vm.t, for m >= 1)

     For the Base64 case, the Bin_prot serialization leads with a version tag
  *)
  match Signed_command.of_base58_check_exn_v1 transaction_id with
  | Ok cmd_legacy ->
      Ok (hash_signed_command_v1 cmd_legacy)
  | Error _ -> (
      match Base64.decode transaction_id with
      | Ok s -> (
          let len = String.length s in
          let buf = Bin_prot.Common.create_buf len in
          Bin_prot.Common.blit_string_buf s buf ~len ;
          let pos_ref = ref 0 in
          let version = Bin_prot.Std.bin_read_int ~pos_ref buf in
          match version with
          | 1 -> (
              (* must be a zkApp command *)
              try
                let cmd = Zkapp_command.Stable.V1.bin_read_t ~pos_ref buf in
                Ok (hash_zkapp_command_v1 cmd)
              with _ ->
                Or_error.error_string
                  "Could not decode serialized zkApp command (version 1)" )
          | 2 -> (
              (* must be a signed command, until there's a V2 for zkApp commands *)
              try
                let cmd = Signed_command.Stable.V2.bin_read_t ~pos_ref buf in
                Ok (hash_signed_command_v2 cmd)
              with _ ->
                Or_error.error_string
                  "Could not decode serialized signed command (version 2)" )
          | _ ->
              Or_error.error_string
                (sprintf
                   "Transaction hashing not implemented for command with \
                    version %d"
                   version ) )
      | Error _ ->
          Or_error.error_string
            "Could not decode transaction id as either Base58Check or Base64" )

module User_command_with_valid_signature = struct
  type hash = T.t [@@deriving sexp, compare, hash]

  let hash_to_yojson = to_yojson

  let hash_of_yojson = of_yojson

  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        ( (User_command.Valid.Stable.V2.t[@hash.ignore])
        , (T.Stable.V1.t[@to_yojson hash_to_yojson]) )
        With_hash.Stable.V1.t
      [@@deriving sexp, hash, to_yojson]

      let to_latest = Fn.id

      (* Compare only on hashes, comparing on the data too would be slower and
         add no value.
      *)
      let compare (x : t) (y : t) = T.compare x.hash y.hash
    end
  end]

  let create (c : User_command.Valid.t) : t =
    { data = c; hash = hash_command (User_command.forget_check c) }

  let data ({ data; _ } : t) = data

  let command ({ data; _ } : t) = User_command.forget_check data

  let hash ({ hash; _ } : t) = hash

  let forget_check ({ data; hash } : t) =
    { With_hash.data = User_command.forget_check data; hash }

  include Comparable.Make (Stable.Latest)

  let make data hash : t = { data; hash }
end

module User_command = struct
  type hash = T.t [@@deriving sexp, compare, hash]

  let hash_to_yojson = to_yojson

  let hash_of_yojson = of_yojson

  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        ( (User_command.Stable.V2.t[@hash.ignore])
        , (T.Stable.V1.t[@to_yojson hash_to_yojson]) )
        With_hash.Stable.V1.t
      [@@deriving sexp, hash, to_yojson]

      let to_latest = Fn.id

      (* Compare only on hashes, comparing on the data too would be slower and
         add no value.
      *)
      let compare (x : t) (y : t) = T.compare x.hash y.hash
    end
  end]

  let create (c : User_command.t) : t = { data = c; hash = hash_command c }

  let data ({ data; _ } : t) = data

  let command ({ data; _ } : t) = data

  let hash ({ hash; _ } : t) = hash

  let of_checked ({ data; hash } : User_command_with_valid_signature.t) : t =
    { With_hash.data = User_command.forget_check data; hash }

  include Comparable.Make (Stable.Latest)
end

let%test "signed command v1 hash from transaction id" =
  let transaction_id =
    "BD421DxjdoLimeUh4RA4FEvHdDn6bfxyMVWiWUwbYzQkqhNUv8B5M4gCSREpu9mVueBYoHYWkwB8BMf6iS2jjV8FffvPGkuNeczBfY7YRwLuUGBRCQJ3ktFBrNuu4abqgkYhXmcS2xyzoSGxHbXkJRAokTwjQ9HP6TLSeXz9qa92nJaTeccMnkoZBmEitsZWWnTCMqDc6rhN4Z9UMpg4wzdPMwNJvLRuJBD14Dd5pR84KBoY9rrnv66rHPc4m2hH9QSEt4aEJC76BQ446pHN9ZLmyhrk28f5xZdBmYxp3hV13fJEJ3Gv1XqJMBqFxRhzCVGoKDbLAaNRb5F1u1WxTzJu5n4cMMDEYydGEpNirY2PKQqHkR8gEqjXRTkpZzP8G19qT"
  in
  (* N.B.: this is the old-style hash, computed by digesting the Base58Check serialization *)
  let expected_hash = "5Jua7BcbaiRN7uRBHw2meaJen9pwD4Ct3YMY7o5tfagjayhtusAg" in
  let hash =
    match hash_of_transaction_id transaction_id with
    | Ok hash ->
        to_base58_check hash
    | Error err ->
        failwithf "Error getting hash: %s" (Error.to_string_hum err) ()
  in
  String.equal hash expected_hash

let%test "signed command v2 hash from transaction id" =
  let transaction_id =
    "Av0BlDV3VklWpVXVRQr7cidImXn8E9nqCAxPjuyUNZ2pu3pJJxkBAP//IgAgpNU5narWobUpPXWnrzjilYnd9C6DVcafO/ZLc3vdrMgAVklWpVXVRQr7cidImXn8E9nqCAxPjuyUNZ2pu3pJJxkBFeE3d36c7ThjtioG6XUJjkISr2jfgpa99wHwhZ6neSQB/rQkVklWpVXVRQr7cidImXn8E9nqCAxPjuyUNZ2pu3pJJxkBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=="
  in
  let expected_hash = "5JuhZ8sR6gQZQCUMpZJpacn9XrXTksSj6zRWHQQXZtZzjiQZ5dNb" in
  let hash =
    match hash_of_transaction_id transaction_id with
    | Ok hash ->
        to_base58_check hash
    | Error err ->
        failwithf "Error getting hash: %s" (Error.to_string_hum err) ()
  in
  String.equal hash expected_hash

(* To regenerate:
   * Run dune in this library's directory
        dune utop src/lib/transaction
   * Generate a zkapp transaction:
        let txn = let txn = Mina_base.Zkapp_command.dummy in {txn with account_updates = Mina_base.Zkapp_command.Call_forest.map txn.account_updates ~f:(fun x -> {x with Mina_base.Account_update.authorization= Proof Mina_base.Proof.blockchain_dummy})};;
   * Print the transaction:
        Core_kernel.Out_channel.with_file "txn_id" ~f:(fun file -> Out_channel.output_string file (Core_kernel.Binable.to_string (module Mina_base.User_command.Stable.V2) (Zkapp_command txn) |> Base64.encode |> (function Ok x -> x | Error _ -> "")));;
    * Get the hash:
        Mina_transaction.Transaction_hash.(hash_command (Zkapp_command txn) |> to_base58_check);;
*)

let%test "zkApp v1 hash from transaction id" =
  let transaction_id =
    "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"
  in
  let expected_hash = "5JuJzo9DuLKnuTTord9SWDoS7hToQTgfuQSR6BfexNk43MGBMbKC" in
  let hash =
    match hash_of_transaction_id transaction_id with
    | Ok hash ->
        to_base58_check hash
    | Error err ->
        failwithf "Error getting hash: %s" (Error.to_string_hum err) ()
  in
  String.equal hash expected_hash

[%%endif]
