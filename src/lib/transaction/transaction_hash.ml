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
  let expected_hash = "CkpZoJ5FpDjCQcgV7xuKHjLzCM9kzKroMW31cRKAJhJiLcvBaYrox" in
  let hash =
    match hash_of_transaction_id transaction_id with
    | Ok hash ->
        to_base58_check hash
    | Error err ->
        failwithf "Error getting hash: %s" (Error.to_string_hum err) ()
  in
  String.equal hash expected_hash

[%%endif]
