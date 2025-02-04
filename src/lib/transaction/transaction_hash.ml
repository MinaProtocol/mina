open Core_kernel
open Mina_base

module T = struct
  include Blake2.Make ()
end

include T

(* Base58Check functions for original mainnet transaction hashes *)
module V1_base58_check = Codable.Make_base58_check (struct
  (* top tag needed for compatibility *)
  type t = Stable.Latest.With_top_version_tag.t [@@deriving bin_io_unversioned]

  let version_byte = Base58_check.Version_bytes.v1_transaction_hash

  let description = "V1 Transaction hash"
end)

let to_base58_check_v1 = V1_base58_check.to_base58_check

let of_base58_check_v1 = V1_base58_check.of_base58_check

let of_base58_check_exn_v1 = V1_base58_check.of_base58_check_exn

(* Base58Check functions for current hard fork *)
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

let ( hash_signed_command_v1
    , hash_signed_command
    , hash_zkapp_command
    , hash_coinbase
    , hash_fee_transfer ) =
  let mk_hasher (type a) (module M : Bin_prot.Binable.S with type t = a)
      (cmd : a) =
    cmd |> Binable.to_string (module M) |> digest_string
  in
  let signed_cmd_hasher_v1 =
    mk_hasher
      ( module struct
        include Signed_command.Stable.V1
      end )
  in
  let signed_cmd_hasher = mk_hasher (module Signed_command.Stable.Latest) in
  let zkapp_cmd_hasher = mk_hasher (module Zkapp_command.Stable.Latest) in
  (* replace actual signatures, proofs with dummies for hashing, so we can
     reproduce the transaction hashes if signatures, proofs omitted in
     archive db
  *)
  let hash_signed_command_v1 (cmd : Signed_command.Stable.V1.t) =
    let cmd_dummy_signature = { cmd with signature = Signature.dummy } in
    signed_cmd_hasher_v1 cmd_dummy_signature
  in
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
                    Control.Proof (Lazy.force Proof.transaction_dummy)
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
  (* no signatures to replace for internal commands *)
  let hash_coinbase = mk_hasher (module Mina_base.Coinbase.Stable.Latest) in
  let hash_fee_transfer =
    mk_hasher (module Fee_transfer.Single.Stable.Latest)
  in
  ( hash_signed_command_v1
  , hash_signed_command
  , hash_zkapp_command
  , hash_coinbase
  , hash_fee_transfer )

let hash_command cmd =
  match cmd with
  | User_command.Signed_command s ->
      hash_signed_command s
  | User_command.Zkapp_command p ->
      hash_zkapp_command p

let hash_signed_command_v2 = hash_signed_command

let hash_of_transaction_id (transaction_id : string) : t Or_error.t =
  (* A transaction id might be:
     - original Base58Check transaction ids of signed commands (Signed_command.V1.t), or
     - a Base64 encoding of signed commands and zkApps (Signed_command.Vn.t, for n >= 2,
       or Zkapp_command.Vm.t, for m >= 1)

     For the Base64 case, the Bin_prot serialization leads with a version tag
  *)
  match Signed_command.of_base58_check_exn_v1 transaction_id with
  | Ok cmd_v1 ->
      Ok (hash_signed_command_v1 cmd_v1)
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
                let cmd = Zkapp_command.Stable.Latest.bin_read_t ~pos_ref buf in
                Ok (hash_zkapp_command cmd)
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

let%test_module "Transaction hashes" =
  ( module struct
    let run_test ~transaction_id ~expected_hash =
      let hash =
        match hash_of_transaction_id transaction_id with
        | Ok hash ->
            to_base58_check hash
        | Error err ->
            failwithf "Error getting hash: %s" (Error.to_string_hum err) ()
      in
      String.equal hash expected_hash

    let%test "decode, recode v1 hashes" =
      let v1_hashes =
        [ "CkpZirFuoLVVab6x2ry4j8Ld5gMmQdak7VHW6f5C7VJYE34WAEWqa"
        ; "CkpZB4WE3wDRJ4CqCXqS4dqF8hoRQDVK8banePKUgTR6kvhTfyjRp"
        ; "CkpYeG32dVJUjs6iq3oroXWitXar1eBtV3GVFyH5agw7HPp9bG4yQ"
        ]
      in
      let decoded = List.map v1_hashes ~f:of_base58_check_exn_v1 in
      let recoded = List.map decoded ~f:to_base58_check_v1 in
      List.equal String.equal v1_hashes recoded

    let%test "signed command v1 hash from transaction id" =
      let transaction_id =
        "BD421DxjdoLimeUh4RA4FEvHdDn6bfxyMVWiWUwbYzQkqhNUv8B5M4gCSREpu9mVueBYoHYWkwB8BMf6iS2jjV8FffvPGkuNeczBfY7YRwLuUGBRCQJ3ktFBrNuu4abqgkYhXmcS2xyzoSGxHbXkJRAokTwjQ9HP6TLSeXz9qa92nJaTeccMnkoZBmEitsZWWnTCMqDc6rhN4Z9UMpg4wzdPMwNJvLRuJBD14Dd5pR84KBoY9rrnv66rHPc4m2hH9QSEt4aEJC76BQ446pHN9ZLmyhrk28f5xZdBmYxp3hV13fJEJ3Gv1XqJMBqFxRhzCVGoKDbLAaNRb5F1u1WxTzJu5n4cMMDEYydGEpNirY2PKQqHkR8gEqjXRTkpZzP8G19qT"
      in
      let expected_hash =
        "5JuV53FPXad1QLC46z7wsou9JjjYP87qaUeryscZqLUMmLSg8j2n"
      in
      run_test ~transaction_id ~expected_hash

    let%test "signed command v2 hash from transaction id" =
      let transaction_id =
        "Av0IlDV3VklWpVXVRQr7cidImXn8E9nqCAxPjuyUNZ2pu3pJJxkBAAD//yIAIKTVOZ2q1qG1KT11p6844pWJ3fQug1XGnzv2S3N73azIABXhN3d+nO04Y7YqBul1CY5CEq9o34KWvfcB8IWep3kkAf60JFZJVqVV1UUK+3InSJl5/BPZ6ggMT47slDWdqbt6SScZAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
      in
      let expected_hash =
        "5JvBt4173K3t7gQSpFoMGtbtZuYWPSg29cWad5pnnRd9BnAowoqY"
      in
      run_test ~transaction_id ~expected_hash

    (* To regenerate:
       * Run dune in this library's directory
       dune utop src/lib/transaction
       * Generate a zkapp transaction:
            let txn = let txn = (Lazy.force Mina_base.Zkapp_command.dummy) in {txn with account_updates = Mina_base.Zkapp_command.Call_forest.map txn.account_updates ~f:(fun x -> {x with Mina_base.Account_update.authorization= Proof (Lazy.force Mina_base.Proof.blockchain_dummy)})};;
       * Print the transaction:
            Core_kernel.Out_channel.with_file "txn_id" ~f:(fun file -> Out_channel.output_string file (Core_kernel.Binable.to_string (module Mina_base.User_command.Stable.V2) (Zkapp_command txn) |> Base64.encode |> (function Ok x -> x | Error _ -> "")));;
        * Get the hash:
            Mina_transaction.Transaction_hash.(hash_command (Zkapp_command txn) |> to_base58_check);;
    *)
    let%test "zkApp v1 hash from transaction id" =
      let transaction_id =
        "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"
      in
      let expected_hash =
        "5JtwzLdsL52i8iUM7xBRK1npv9KoouX2iBnD2UJYCJvZk4epc9pa"
      in
      run_test ~transaction_id ~expected_hash
  end )
