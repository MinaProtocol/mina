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

let hash_signed_command, hash_zkapp_command, hash_coinbase, hash_fee_transfer =
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
  (* no signatures to replace for internal commands *)
  let hash_coinbase = mk_hasher (module Mina_base.Coinbase.Stable.Latest) in
  let hash_fee_transfer =
    mk_hasher (module Fee_transfer.Single.Stable.Latest)
  in
  (hash_signed_command, hash_zkapp_command, hash_coinbase, hash_fee_transfer)

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
      (* the V1 signed command is converted to a V2 signed command, then hashed *)
      let expected_hash =
        "5JvD87Ag3GuTCJhDsWUXDbJ7vTWWVuCnAhNjnnZ78h1mjxrhdS61"
      in
      run_test ~transaction_id ~expected_hash

    let%test "signed command v2 hash from transaction id" =
      let transaction_id =
        "Av0BlDV3VklWpVXVRQr7cidImXn8E9nqCAxPjuyUNZ2pu3pJJxkBAP//IgAgpNU5narWobUpPXWnrzjilYnd9C6DVcafO/ZLc3vdrMgAVklWpVXVRQr7cidImXn8E9nqCAxPjuyUNZ2pu3pJJxkBFeE3d36c7ThjtioG6XUJjkISr2jfgpa99wHwhZ6neSQB/rQkVklWpVXVRQr7cidImXn8E9nqCAxPjuyUNZ2pu3pJJxkBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=="
      in
      let expected_hash =
        "5JuhZ8sR6gQZQCUMpZJpacn9XrXTksSj6zRWHQQXZtZzjiQZ5dNb"
      in
      run_test ~transaction_id ~expected_hash

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
      let expected_hash =
        "5JurwoAuED1yCWbKbf7JuieFd9Wmfv81d1v3XfFQ57q5v2yj2EDK"
      in
      run_test ~transaction_id ~expected_hash
  end )

[%%endif]
