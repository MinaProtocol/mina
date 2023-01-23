open Core_kernel
open Mina_base

[%%import "/src/config.mlh"]

module T = struct
  include Blake2.Make ()
end

include T

module Base58_check = Codable.Make_base58_check (struct
  (* for legacy compatibility *)
  include Stable.Latest.With_top_version_tag

  let version_byte = Base58_check.Version_bytes.transaction_hash

  let description = "Transaction Hash"
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

let hash_signed_command_v1 (cmd : Signed_command.t_v1) =
  let b58 = Signed_command.Base58_check_v1.to_base58_check cmd in
  digest_string b58

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
  let expected_hash = "CkpZUiKxdNnT53v5LAxnsohbLc9xabe6HcsQUtFsVVAQZB2pdNUjc" in
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
  let expected_hash = "CkpZcAHDStkSGLD8Whb4vjk4qMrf79TL8gKUT3sC8PUHpKmV8mpMx" in
  let hash =
    match hash_of_transaction_id transaction_id with
    | Ok hash ->
        to_base58_check hash
    | Error err ->
        failwithf "Error getting hash: %s" (Error.to_string_hum err) ()
  in
  String.equal hash expected_hash

let%test "zkApp v1 hash from transaction id" =
  let transaction_id =
    "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"
  in
  let expected_hash = "CkpZsMJKBPUigtJp9An9iHA5dXtpug3cb4asYd7DHJu2orBQA2nSP" in
  let hash =
    match hash_of_transaction_id transaction_id with
    | Ok hash ->
        to_base58_check hash
    | Error err ->
        failwithf "Error getting hash: %s" (Error.to_string_hum err) ()
  in
  String.equal hash expected_hash

[%%endif]
