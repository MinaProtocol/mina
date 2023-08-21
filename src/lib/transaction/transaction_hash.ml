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
                    Control.Proof Proof.(!transaction_dummy)
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

[%%ifdef consensus_mechanism]

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
            let txn = let txn = (Lazy.force Mina_base.Zkapp_command.dummy) in {txn with account_updates = Mina_base.Zkapp_command.Call_forest.map txn.account_updates ~f:(fun x -> {x with Mina_base.Account_update.authorization= Proof Mina_base.Proof.(!blockchain_dummy)})};;
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
        "5Jv9H3FWr4Uepj8FWhpMQErTaxuXUuk6zGeVziMSCZM5rdaTvY3B"
      in
      run_test ~transaction_id ~expected_hash
  end )

[%%endif]
