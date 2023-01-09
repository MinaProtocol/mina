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
    "ASPLCDaggJwUNe9wX1TSjbTnVCTH51R2Mlr9YAhdwSIuAf0Aypo7AAEQlx+0PHwy1Cb+oKgJtAv5XkXviSZfuWzzI/rTX9woP3a5Ilo1NBRJkWDOwChdUZfNMJbqaXhdlB24jL40UXAcAd8wb7wJNR26XRLGu9resn9Q7FnSekWJJbzHVIJyksogAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQEBAQEAAQEBAQEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAQEAAQEBAQEBAQEBAQEBAQECAQEAAAGxCjqo+F57NmK1i0VRgbrN1CleW+p+lEvANMPhQNHsFlMD7G68UB0IJCKhSUVwJFTZTK5QIBHcIqLEzZvdudE8AAAAIgEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
  in
  let expected_hash = "CkpYaEsbQwjgwvmdR7ttwLjTBmRdjmuPNmmmdZp3MsVVuH5fzajL4" in
  let hash =
    match hash_of_transaction_id transaction_id with
    | Ok hash ->
        to_base58_check hash
    | Error err ->
        failwithf "Error getting hash: %s" (Error.to_string_hum err) ()
  in
  String.equal hash expected_hash

[%%endif]
