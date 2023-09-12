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
    let b = cmd |> Binable.to_string (module M) in
    digest_string b
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
        "5Jv9H3FWr4Uepj8FWhpMQErTaxuXUuk6zGeVziMSCZM5rdaTvY3B"
      in
      run_test ~transaction_id ~expected_hash

    let%test "hash of zkapp txn with proof" =
      let gcloud_txn_json =
        Yojson.Safe.from_string
          {json|
          [
            "Zkapp_command",
            {
              "fee_payer": {
                "body": {
                  "nonce": "1",
                  "public_key": "B62qpYiNarxLiQRydW2bspXEQbXWoUfmHyexq1Lq5DgfDcHuu1UAF5P",
                  "fee": "0.02",
                  "valid_until": null
                },
                "authorization": "7mXJzKj43kmiSquNH7HDKBGnHuD1A8PGySkU8BvCgvXccrzeeYGPVfdMiJrv3c2rdLaod2tX8faV96dXhMi461hfS1P6F9UA"
              },
              "account_updates": [
                {
                  "stack_hash": "0x2E09974624315111F4B243E6DF459AC57A5184A72FEC52F01F837710FA4714FD",
                  "elt": {
                    "account_update": {
                      "body": {
                        "actions": [],
                        "implicit_account_creation_fee": true,
                        "public_key": "B62qpYiNarxLiQRydW2bspXEQbXWoUfmHyexq1Lq5DgfDcHuu1UAF5P",
                        "authorization_kind": [
                          "Signature"
                        ],
                        "token_id": "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf",
                        "update": {
                          "voting_for": [
                            "Keep"
                          ],
                          "timing": [
                            "Keep"
                          ],
                          "app_state": [
                            [
                              "Keep"
                            ],
                            [
                              "Keep"
                            ],
                            [
                              "Keep"
                            ],
                            [
                              "Keep"
                            ],
                            [
                              "Keep"
                            ],
                            [
                              "Keep"
                            ],
                            [
                              "Keep"
                            ],
                            [
                              "Keep"
                            ]
                          ],
                          "verification_key": [
                            "Set",
                            {
                              "data": "zBpF7K9KgsbYdaZMLnyid1ZGm1cbNfbnDk19kcxPs1mpT9oF6ZP7buu48xV6XmcZGckFSCmK3pWAdkB4xBLyBz7H45PRzf2NK9YZuci4pJFBnmCxa55qCEUSZPkk8BXdxAdZrPJa6zGwTH227ecD2MFp4oxG8jJw2uUNHY8pirE5ZFt9i99haSqbCv6HWwifdta4CfgM2qvZi9ZHizKUFKvoF2N9VSatrGKNxSKhqSigigiwH3EVe5Hitf4uCSXSyd7znzEbUgGzg8iTNibdMZZP3fR9ner1T178ZxyDTD9SyyDr1pX7zDwbs9VJRFrVxmkCouATPD74D2zFNuXKJZvNfnWbMvWspHUDJ2deJRzaqVHk29eCaxcMgoRCDZ515W1j4KgSk1JC7FmpCm7DSKqZ4ZqcbFk2MFNECzKcz4TNQyUkUxxYaSrEpPHWDpeu5b451im5zi8YLtzBzSKHEZYmLX9bVbmGG2QfBSFE7XZFvWkrKiB3mVRRAWpB9qHBQ7QyR4j32Pqex93eJ2sCucWfqQmy14zDhQzzTJLonqF5LaXvJGVVKe6uAY9nevsUHyvDTP6sk3EHg1bGh3ZNefoGmaaTUobivtfF89epjudZbk5WxcBNoFCPMKKfJbbcvv4rbQSq3V2duWHvH3xvsBLCGrHF4H9WCTSGeRUJmtLxw8hnWXr7AyrSZog32BScKFAZrMNg6RJvFhz9nEREFjtuYZjnw57jpr99D2Ua8xtp2SN7cAGWp5v4DFMJmr6HZfjsQdZXwpaXyVSg7qTMQu22vYAeKc8rZhH4fLcXkNhuPxFXbWgcHEfpaijeLRcK7sDT7CgQ5JMUxUaoU8J8vyX7b9HRT1umW23HmGA1zD8gWwMNNP67g7FCfBa4UpZB6U4fexQjpEjPLdVK1gBHRKhGxD6TZde4cejsME8aVfUXmsWRUpDZDHu7n4MohEfmVZNvJjv2TYjSa4EXm49VytFMchhzS9DLVQMu7V5qk6vkY22fEq1hBYPJQaMC6URmPyfi1fCo3SR84nDVJehJx9raWZudvmLcHVDyeQw4VEuPuaEcw7EfQ7SL2R6HN3ZLnqEMYuRNx8sPmKx631WYvNqxuEdqdeZan9dFmTvPSWGTJ7MWtFiuJ3TkjhNNiTDNDG28vrXnvkDKN6rGP5ZZ9bWxmZ1GvVpNHALZUcV3g9ZxyK3q1GXWPuPygVkMMH4xpehgJbDrGvwxKzpq2jswsjWKBMkX9rRWUSFaY2mMbmyn2JnkHf91NSZXP72BsnWDgeR3rmAXU9TE3iAMmGv2JJNUjrv4neSQBSHEQkgxrfDZaESBtgQho7BkSwwQvtJwi4cW13YwN5Yp8wTtbATVowGvYqyhLqrwupyd2PMF9v8cEYwihR2JTqEqJ4ny4yCuJjX2Lppkuy4Y7YeP748TaeFVW9i4TxEaYgRTqmnyUJ2Ua1ehwyt1Uaia7gPjfYfdcwrCMDkDyJZRL4inhAruLEPZGUh5LZArEpTBByXKpugaDdBn9xVcQpovvGtYqwAa2bjSGKicrSgqUMfh1sFurvu5emuuG6bk69QTNzaxYRbeBCXo32rGxrgjNUCkHSzWyHApwnTZ8eLFCrbPhtnJE57fse6JGNoheq7En3ywkBRnVNg1LsPuu7DkVDqtSKsu2QMQqsY3Lyha8pqeGZFuyYPwGPU3NgxTp5MFaQ5pb8QgRvYTuTV7juEJMYhZpemLUTHXQjaB7xDvbHtzKXkwyg4Z8sUjM3XVtFaKRGsgptEs754Eq2A1Q4a7oHoW7PpX7STy6kHixkXc96KNVZpWwFH2pF5Jm2nxYsmWJRYLkph9Cpud7ggwxSPRGsQtBsMbafHxVW716h2jVBF5txVUVeU8E7PkyS7tBKLhJT9qGgxwWNJeMxXCLjHPrpy1dCKof7YTrfxhSq6bUpQdShHgiAtgQRVuPJZW4dy89xejt8XjZbu2HL6EWmu7uv13TAe7ytQwMbfC4Li4YQDcvHxNGH2h79iJ31dD6evi2myWNSazZD8q4nXxAzwEAMM9D15NfbDm5rS3zaCnWRjMv7hgmXMWmkjUEh9yG6T5eyHTKnJyoBsaMDowBaFhy4gNX5FQGp2A8QD7kd5ax7rpxDgCPVSwK6Q5xonzmuow3CJXk9Ha8fxWZkYNpMmmywcHzyLZGGTid1JmFq5HopyuzrSCbdeAftMLmMjRCujQADotVmDf5qkpVdohnEs8p74HMQVDoSsE4ctemC77Vy185YvQAkxezPAU5YdSKvf9sUt7CsZfirrcGBNoHJVRDQtSqxMBqvdwbdHKuF6HjViw5juKaraR5nuJzkPeFyXs1oomEAZhxhzDsgZVBM1uRxtbY6xPC3Gq6iu6F4qX8kzA9J8S7qiPsyTv6HmMXLj6TU1Dxqh4SEdA6Q9DezBt6KhtTs15YZaZnXrcumcCNRpBFuM5ksXaCmM",
                              "hash": "0x21DD1295012AB95CA4A7145437A08EFD58FE7E8FBD7CB29CC2920A03F10E31B5"
                            }
                          ],
                          "permissions": [
                            "Set",
                            {
                              "set_voting_for": [
                                "Proof"
                              ],
                              "set_verification_key": [
                                "Signature"
                              ],
                              "increment_nonce": [
                                "Signature"
                              ],
                              "access": [
                                "None"
                              ],
                              "set_timing": [
                                "Signature"
                              ],
                              "send": [
                                "Signature"
                              ],
                              "edit_action_state": [
                                "Proof"
                              ],
                              "receive": [
                                "Proof"
                              ],
                              "set_zkapp_uri": [
                                "Proof"
                              ],
                              "set_delegate": [
                                "Proof"
                              ],
                              "set_permissions": [
                                "Signature"
                              ],
                              "set_token_symbol": [
                                "Proof"
                              ],
                              "edit_state": [
                                "Proof"
                              ]
                            }
                          ],
                          "token_symbol": [
                            "Keep"
                          ],
                          "delegate": [
                            "Keep"
                          ],
                          "zkapp_uri": [
                            "Keep"
                          ]
                        },
                        "use_full_commitment": true,
                        "increment_nonce": false,
                        "balance_change": {
                          "magnitude": "0",
                          "sgn": [
                            "Pos"
                          ]
                        },
                        "call_data": "0x0000000000000000000000000000000000000000000000000000000000000000",
                        "may_use_token": [
                          "No"
                        ],
                        "events": [],
                        "preconditions": {
                          "network": {
                            "blockchain_length": [
                              "Ignore"
                            ],
                            "snarked_ledger_hash": [
                              "Ignore"
                            ],
                            "next_epoch_data": {
                              "epoch_length": [
                                "Ignore"
                              ],
                              "ledger": {
                                "total_currency": [
                                  "Ignore"
                                ],
                                "hash": [
                                  "Ignore"
                                ]
                              },
                              "start_checkpoint": [
                                "Ignore"
                              ],
                              "seed": [
                                "Ignore"
                              ],
                              "lock_checkpoint": [
                                "Ignore"
                              ]
                            },
                            "min_window_density": [
                              "Ignore"
                            ],
                            "total_currency": [
                              "Ignore"
                            ],
                            "global_slot_since_genesis": [
                              "Ignore"
                            ],
                            "staking_epoch_data": {
                              "start_checkpoint": [
                                "Ignore"
                              ],
                              "seed": [
                                "Ignore"
                              ],
                              "ledger": {
                                "hash": [
                                  "Ignore"
                                ],
                                "total_currency": [
                                  "Ignore"
                                ]
                              },
                              "epoch_length": [
                                "Ignore"
                              ],
                              "lock_checkpoint": [
                                "Ignore"
                              ]
                            }
                          },
                          "valid_while": [
                            "Ignore"
                          ],
                          "account": [
                            "Accept"
                          ]
                        }
                      },
                      "authorization": [
                        "Signature",
                        "7mXJzKj43kmiSquNH7HDKBGnHuD1A8PGySkU8BvCgvXccrzeeYGPVfdMiJrv3c2rdLaod2tX8faV96dXhMi461hfS1P6F9UA"
                      ]
                    },
                    "account_update_digest": "0x33ADF6751F5F851B76D1FCF9CF55259801B8AD353215B783E0519B17DAF7CCBC",
                    "calls": []
                  }
                },
                {
                  "elt": {
                    "account_update": {
                      "authorization": [
                        "Proof",
                        "KChzdGF0ZW1lbnQoKHByb29mX3N0YXRlKChkZWZlcnJlZF92YWx1ZXMoKHBsb25rKChhbHBoYSgoaW5uZXIoNTkzYmIxM2Y2YjFiMWExYSBlZDA3OTAzYjRjY2JiMjdmKSkpKShiZXRhKDRiMjYzZmI0OTRmNmE1YjIgYWM2NmE5OWIzYTc2YzBlNykpKGdhbW1hKDI4MGI0MDU3NmRjMDE2YTAgY2YzNGY2MGRjMjdkNTJmOSkpKHpldGEoKGlubmVyKDExOWFkYjc3OWRmYzE2ZjYgYjEzYjQ0NjdlYTgyMDAxMSkpKSkoam9pbnRfY29tYmluZXIoKSkoZmVhdHVyZV9mbGFncygocmFuZ2VfY2hlY2swIGZhbHNlKShyYW5nZV9jaGVjazEgZmFsc2UpKGZvcmVpZ25fZmllbGRfYWRkIGZhbHNlKShmb3JlaWduX2ZpZWxkX211bCBmYWxzZSkoeG9yIGZhbHNlKShyb3QgZmFsc2UpKGxvb2t1cCBmYWxzZSkocnVudGltZV90YWJsZXMgZmFsc2UpKSkpKShidWxsZXRwcm9vZl9jaGFsbGVuZ2VzKCgocHJlY2hhbGxlbmdlKChpbm5lcihhMzZhYWQ5YTZlMjlmMWFjIDViZWQzMmRhM2YzY2VhMzkpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcihmNTdiYTAwYTY3YmM3ZTAwIGQ5MjQ0YzAyMDViZWNhYTgpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcig5MmY1ZTMxNDYzOTE5MDIxIGZlNDZhMWUxZTFmZWZiMDIpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcig2ODk4ZWNmMTY0ZjMwYjc5IDg2MzA2ZGEwODRiNzM5NmQpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcihkMWY5YTZkNzFmMDgxMWE2IDk5NzdlMTQ3MjdiYWRlMzQpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcihlYmJjZmM2M2NhZGI1NzNiIGJmNmUxMzQxMmQ0OTllODEpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcig0MTYzMTRiNmU1ZWIwNGVhIGRlMmMxMTI0OWJjZjllOTQpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcig1YWY3OWE2ZTkyNDk3OTFjIDRmZmNjNzBkZmUzNzNhOTYpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcihhMzI2YzZkN2NhODBlNGM4IDQ4NTU2OTIzNTVmYzAyYzIpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcig0YzJlMTY5ZTQzNjE0MzBmIDRjZWY2Njc4YjdkZjdhZjQpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcigzY2RhMWYxMDk2YzcwOTE4IGU1MzFhODVlOTY2YzAwM2YpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcihkZTRlOTkwNjA3NTA4ZDhkIDZjZGZjZjllMTk2MjI4YTYpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcig3ZTJmY2I1Nzg2MDlkYzZhIDg1NWUwMDNlNmY0MTZjNTUpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcigxYjU3NTZiMmNlYmQyOGU2IDFhNTUyMjc1NjUyZmI0ZDIpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcigzOTU2OGE1NWFmYTdjYWMzIDY4Y2IwOTZjYjFiNjcxMmMpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcigxMDRkZjBkNzM5NzA1NjZlIGI0N2Y2NjQ1MWQ2ODQ0NjUpKSkpKSkpKGJyYW5jaF9kYXRhKChwcm9vZnNfdmVyaWZpZWQgTjApKGRvbWFpbl9sb2cyIlxuIikpKSkpKHNwb25nZV9kaWdlc3RfYmVmb3JlX2V2YWx1YXRpb25zKDgwZTMxODY4ZDFhM2M0ZTYgMzE3MTIzM2EyZjRlOGU5NSA0N2RhYzQzYTY5ZDc1ZTYyIDE3YjA5M2Y0MGM5N2U1YzYpKShtZXNzYWdlc19mb3JfbmV4dF93cmFwX3Byb29mKChjaGFsbGVuZ2VfcG9seW5vbWlhbF9jb21taXRtZW50KDB4MkJGQTVERDFBNjk5MzhEQjY0N0NBQjhFNjdCNzNGQTM2QTk5NDNFNDY0QkNDQzgyMDJERkUyQzlBRTQ2OERGRSAweDIxM0M0NjZBQ0M5MjEyOEUxQjk3RTE1QUFBRjRFMDlEQTdCRTg1REJDRjY0NjA3RTAwMkVGRjlENDBFMzE5NDcpKShvbGRfYnVsbGV0cHJvb2ZfY2hhbGxlbmdlcygoKChwcmVjaGFsbGVuZ2UoKGlubmVyKDMzODJiM2M5YWNlNmJmNmYgNzk5NzQzNThmOTc2MTg2MykpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKGRkM2EyYjA2ZTk4ODg3OTcgZGQ3YWU2NDAyOTQ0YTFjNykpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKGM2ZThlNTMwZjQ5YzlmY2IgMDdkZGJiNjVjZGEwOWNkZCkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDUzMmM1OWEyODc2OTFhMTMgYTkyMWJjYjAyYTY1NmY3YikpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKGUyOWM3N2IxOGYxMDA3OGIgZjg1YzVmMDBkZjZiMGNlZSkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDFkYmRhNzJkMDdiMDljODcgNGQxYjk3ZTJlOTVmMjZhMCkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDljNzU3NDdjNTY4MDVmMTEgYTFmZTYzNjlmYWNlZjFlOCkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDVjMmI4YWRmZGJlOTYwNGQgNWE4YzcxOGNmMjEwZjc5YikpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDIyYzBiMzVjNTFlMDZiNDggYTY4ODhiNzM0MGE5NmRlZCkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDkwMDdkN2I1NWU3NjY0NmUgYzFjNjhiMzlkYjRlOGUxMikpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDQ0NDVlMzVlMzczZjJiYzkgOWQ0MGM3MTVmYzhjY2RlNSkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDQyOTg4Mjg0NGJiY2FhNGUgOTdhOTI3ZDdkMGFmYjdiYykpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDk5Y2EzZDViZmZmZDZlNzcgZWZlNjZhNTUxNTVjNDI5NCkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDRiN2RiMjcxMjE5Nzk5NTQgOTUxZmEyZTA2MTkzYzg0MCkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDJjZDFjY2JlYjIwNzQ3YjMgNWJkMWRlM2NmMjY0MDIxZCkpKSkpKSgoKHByZWNoYWxsZW5nZSgoaW5uZXIoMzM4MmIzYzlhY2U2YmY2ZiA3OTk3NDM1OGY5NzYxODYzKSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoZGQzYTJiMDZlOTg4ODc5NyBkZDdhZTY0MDI5NDRhMWM3KSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoYzZlOGU1MzBmNDljOWZjYiAwN2RkYmI2NWNkYTA5Y2RkKSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoNTMyYzU5YTI4NzY5MWExMyBhOTIxYmNiMDJhNjU2ZjdiKSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoZTI5Yzc3YjE4ZjEwMDc4YiBmODVjNWYwMGRmNmIwY2VlKSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoMWRiZGE3MmQwN2IwOWM4NyA0ZDFiOTdlMmU5NWYyNmEwKSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoOWM3NTc0N2M1NjgwNWYxMSBhMWZlNjM2OWZhY2VmMWU4KSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoNWMyYjhhZGZkYmU5NjA0ZCA1YThjNzE4Y2YyMTBmNzliKSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoMjJjMGIzNWM1MWUwNmI0OCBhNjg4OGI3MzQwYTk2ZGVkKSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoOTAwN2Q3YjU1ZTc2NjQ2ZSBjMWM2OGIzOWRiNGU4ZTEyKSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoNDQ0NWUzNWUzNzNmMmJjOSA5ZDQwYzcxNWZjOGNjZGU1KSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoNDI5ODgyODQ0YmJjYWE0ZSA5N2E5MjdkN2QwYWZiN2JjKSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoOTljYTNkNWJmZmZkNmU3NyBlZmU2NmE1NTE1NWM0Mjk0KSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoNGI3ZGIyNzEyMTk3OTk1NCA5NTFmYTJlMDYxOTNjODQwKSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoMmNkMWNjYmViMjA3NDdiMyA1YmQxZGUzY2YyNjQwMjFkKSkpKSkpKSkpKSkpKG1lc3NhZ2VzX2Zvcl9uZXh0X3N0ZXBfcHJvb2YoKGFwcF9zdGF0ZSgpKShjaGFsbGVuZ2VfcG9seW5vbWlhbF9jb21taXRtZW50cygpKShvbGRfYnVsbGV0cHJvb2ZfY2hhbGxlbmdlcygpKSkpKSkocHJldl9ldmFscygoZXZhbHMoKHB1YmxpY19pbnB1dCgweDE1RTI3QzYzN0JGMTZCQkM5OEE0OUZBRDc0MDRGRkI5MjBFNTdCRTI2RTY4RUE5MzdCMTJEQTg5M0VGQTk0NjYgMHgxOTM4RDM2OThEQzdCNjJDMzNBQTNFRjY0Q0EyMTU0NTc4Q0NCMjNBMEEwODU3OTI4RjJBNUEzOTFGM0U2MDhCKSkoZXZhbHMoKHcoKCgweDFDOTQwNUIyQkQ5M0Q3NURGMzY5OTRDNzdENzNFRUI5RDdBOTM4ODVDQTYyQ0NDRTM4OEY0MzM1QUU3ODcwOTMpKDB4MTZFRjY3MUZERTQ3N0IzQjY2QjM0Q0IxMTNGOTMzNUM2NjcxMUI5ODRBMTM0OTQ5NUNGQzA4NUNGNTAzNTBFOCkpKCgweDBDQjY1NUEwMDY4NTM2OEZBRTNDRTZBRjE1RTc2QjEzQ0M5QTAxNjY5RTNGQjgxREYzQTg2Qzc4QjczM0QwQzMpKDB4M0M1RDAzMzIyMDEzREIwMzVCM0E2MTRBOTMyODUyMUMxNDYwNEUxMDJCM0QzRkY5NTJGOTZGQTNBOEY4NEEzMCkpKCgweDM1ODU1NEYyOUI4OTUxN0U4MTU4NUE5QTExQjk3N0NEQkZGNDI2OTAyN0MxRTRGRjAwODMxNkRFNEVDNEZEMTQpKDB4MUY0NTFGNkRCNDIzMTM0MUYxQjBFNjBDMzM3NURDNjIxOTJERjdCMjQxQjk5ODkwNUFBRUNGNTQwQzYzQUREMikpKCgweDBENDFBQzZCOTI2QzM5RkExQzIyODFBMzgyMUZFREJERDczOTI4RkZDMkNFODI0NkI1NkJBMjJENTBBNDgxNEQpKDB4MDUwNDg3QTAxQ0QwMTMzOTlFMTQxQ0JDMUVDRDU5MTg3NzQ0MzI0MjBFMTAwODU2N0VGOEM4NDIzNEE5NDlBMSkpKCgweDA5NjE3RTIwNDNDMjZGQTBDNjdCNUMyOUIyMzc5QTlEQTI3MzlFMDczN0ZBMERBMEQxOTQzMTE2M0IwMjMwRDUpKDB4MzM4QjA2QUUzRTMxOTYxMjI2NDJBRTM4NDE2MDU4NzRENjU0RkY4QUE2OUUwNDA5REQyMTYwRTg0RTdGNDI5OCkpKCgweDMyMkUzMUYwODI1QkVGQjgyMUNEMTdCQkUyQzIxNjJDQjhCNkZGQjczNUJENEYzQTc1RDc0NUYzNDkxQ0Y3Q0IpKDB4M0ExNEIzQTYzNzA0RUMyNkIxNTNEQ0UxMjQ3ODE2OTIwQjhFMjk5MUYzRjRFMTIxMkRBQUZEOTA4Nzk4MEJEMCkpKCgweDE1NTZDQzhCMUZBMDI3MDhBMDE2REVENzM2NTM5M0RCQzE3NkJDQUU1Q0I0OUM2RkJFN0RERUI0RDY0MEY0QzYpKDB4MzAzREVGNTVCOTQxRjAyMjQ4REI3NUQ3RDAwRTgzMTMwOTA3RUVCM0ZBNzlFMEUzMDI1QTNGRDdGRkQ3QTlDOSkpKCgweDIwRDA5N0VDRjkzRjg0MUVCMEIyN0JEOEU0ODMxMzczRTg5RjU0MjlFRUExNzQxN0E5Qjc3ODFCQTk4NTA0QUUpKDB4MzU1NURDOEFDNzJFOTI2MjBFRjE4RjYzNkE4N0FFNERDNzk0N0MxQjhGQkVDNUE4QTA1RURCNzlFMzkwRTA3RCkpKCgweDAxODY2NkNGQzgyOTU1MjM3NDAwRTFEQjBBMTk0ODE5MUUwQ0U4NTk2MDEyNzU5QUE4RjIwOTBEMkI2MkQ2NzgpKDB4MzA4MzE1RkUzRUQwMUFCMTY5NTAwMjg3NjdEOTBBOEM4MjM3RDZBNTJCNDU2OUI1QUFDODlGQzlFM0IwOUE4RCkpKCgweDI0MkQxOTRFNzkyQkNDQzcyQjUzOTE0NjIzM0YwOTRDMjM4NTNBQ0NEMEMyQkU1MjdEMDg0NDU4M0FFNTdEMzApKDB4MUIyMEIzRTExODc4RjI4OEYwRjQ4MkJGMDVFRTMwQ0E0REIwODEwNjcwMTg2QzQ1RTRBMDA1Rjc4NUM3NzgxRCkpKCgweDIzRUEyMTVBQUQ4OERERjQ4NTI4RTI4NjZFQ0UxQTYwM0M1M0I4RkFBNzU1NEI3MjE3MTlBQzdDOEYzQkE1NDkpKDB4M0NCRjk5QzZEOERBQkMxRTFGQTlGODlFNTA3QUY5QkQ1Q0EzQ0VDODMwRkU2MzFCRjg4NTE4RjUyMzVGRDhEMSkpKCgweDBBOTg1OTFBOThGQkExNTRDQ0Q0NkREODFGQ0M0NzVDRjk2NjIxOEI5MTM4MDU2N0I0OUMxNTQ1QzYxRTQwMzIpKDB4MjdCNDNENUE3NzMxQkY3MzE3QkMxMERBODVFNURGNDJGNTJCOUQ5OUJFMEEyNzk1OTQ3RkZGMUZDMEQwNzE3OSkpKCgweDJGMjhDNDMyQ0FFM0FCOTY0MkE3NzdDQkJCRDkxNjg3MTg3MDVCNERGODQ5MDEzMjZCQ0M2QTY0MjE2RjlBQzApKDB4MDMzMUY2RkJENTA5Q0I5QkZENjk2NTU5NUVERDc3RTE5MUFCQkYxMzkyNzc5NUYyMzY2NTAwMDkwOUE3NThBOSkpKCgweDAyN0I3NzIxNkU0MzYyRjhGMTRERTQzNTI2MjQxNEI2QUNGODlGRjA3OEI3NjExQTRGOUQ1MTdEMjAyMzQwQTIpKDB4M0REQzgwMTRENTQ2REVFMzY1MkREMjgwMUU5NEVERjk5QjhBNkE5OUFEQkJDN0I0NDU1MzMxREZCRDE4M0UwRCkpKCgweDAyODBDRUEwOUZDMTI5RDVBN0VBN0NGNTIzRkYyQTNCNTE4NkQ4NEY2ODdDQjBCQjUyODJCRTAxQjg5RTAxQUQpKDB4MDhEQjQzMjg3MjAyNzJBNkEzOUU2RUYxNzgyQTA1MzlEQ0Q5Q0FDNjE3NzNBRjkwQzg2OThFRkY1RDBBM0VCRSkpKSkoY29lZmZpY2llbnRzKCgoMHgwNUY0RjcyNjNEQ0RFMENGQjdFOEZDQTFGOUVCMzIwRThCODBCNDA3MUZBMDE3RDA3NDdENUNGQjUyQ0JGMTEzKSgweDJFQjNDRUM0RDRENzU0QUZDREEwQzI0MTc2MDU3QzMzNjU3MTAwMTc2MDIwQkNBODhBQzZDM0M5QkQyQkM5RDUpKSgoMHgxNTg5NkNGM0UyOEJDRkM0QUMwNEVCNEEwMzc3RTZBOERERDZBODVFMzA2ODhCNEQ5NkRGMTRCQ0JDMkQ0NTkwKSgweDA4MkRCQUU5OTI0MzFDRjlGOUZDQkMwRTdFOUI3NDBGQzk0MDdEQjIyMEQ2NkI2N0YyM0M0NkFBQzJDNjVERTIpKSgoMHgwRjI0MDY0MTQ4REMzQ0Y2MkM5RTk5RUIwOTc0QTMwNTUyN0EzNDM0OTAwMkE1MUU2NkFERTU1NUYyQTE0QkQzKSgweDNDMTcyRUY2MTIxRDk5OEQwMjM1OTA2ODAxNDEyNzE2MDRFMUMzRDBFQzRGQTc0RTBCQTczQzI1Qzk4M0Y3QzYpKSgoMHgxNDFFOTRFMkIxMzY0MDA5MTYzMjY3MjNGQ0FCNDhGMkM4RUY3Nzc1NERBQ0ZEODczNDYyNDYxMjkyNjJCMEE3KSgweDI4MjMyNTE4MDRCMDMzQzlGRDc2QTY4OEU4QkVCOEFCM0EyMDYwQUFFOEVBQ0QwOTY1NEFGQTlGN0M5RTc2RjUpKSgoMHgzQ0NEQTA4RDE1NTA3RkFGQjU0MkYzN0M1QzlEQUY4NzM2MkNEOEM1RDZBODc4NzQ0QjZFMUYyNTk2RUFFMTkyKSgweDIwQUFCQjA5N0ExNUI0NzcwMjhCMEMyREREREVBNTZFNUMzQTZBMzIyRDMyQ0ZDNENCN0I5OThBODlEODJDNTUpKSgoMHgxQjk5M0UxODExMjNERkE5Q0JBOUJERkI2RTRGOTg0Q0M1M0RFMTMyMkQxMTg0N0YxNzM0NUMwQTI5Njg1QkZBKSgweDFCNkE0NUMyRkNBQkEwRUMxRkNBNDc3MzA1NDIzQjYzQzhBRUZGM0VFNzcyMjA2QUE3N0M2NkMxQzNCMEI5MzEpKSgoMHgyRTM4OUM3M0MzNTY5Qjc2ODhBQzdBODI3NkY4NEI0Q0UzQUE0MkJFNTMxNzA4OUE4OUZCNjE2QTRDMkMzRjg2KSgweDM5OTE2NzY1MTFGMjlGRTE0NTdFM0JEQUZGMTU0NzdGMTA0MjVDNzdEMzZDOTNBNjRBQzYyRDVGRUJERDFBNEUpKSgoMHgxMEM2NTQ0NzY2RUY5QjBCRTc5NEExMjQ5MTYwRDFDMjRENzUyMkZGQUY4QTNEMTk0NTkzQzk1NzQ2Mzc0MEY1KSgweDBGREM3MzYzQ0VDMEQzQTlFODg0RTNEMzA5OUQ2OUU2ODIwREM4NjFBQTlCNzNGNTRGMEJBNEY3MUI2QTI0RDgpKSgoMHgyQjQ2OUFERTI1NEE3MkM4MEM1NDYyNjQ1MjQyM0IwNDM5NDZDNTQ4QTc0RTQ0RjAxMkE2MTlDMTAwQjhBNUE1KSgweDFCQjQ1OTg0NjBGMDY1RTkwQ0VCMzk5RDJFQzFDNTlBRDQyRTA2MEUzNjZENUFFQzJGOEMyREM1M0RCNTI4M0MpKSgoMHgzRDg5OTFEMUQxREQ4Q0NEMTJGMzk1OUNBQURERUJDMzU2MkQ5NEU3MEExRTU4MTA2N0VGNzJGRDAzMzZBQTFDKSgweDJBNDNENjUzRkNERjdDQTNFNTU1QUY1QTY4NEVFMUMwMzdEQURGREEwOTg2MTJFQTMzNjQzRDI0ODIwQzE1QzUpKSgoMHgxM0YxNzU2RTY2NzVFMkM0QTZFN0RDQjg4NzBDQzdCNTE1MzY0RjJBQTZENzlFRTRFM0RGRTY2NzVDRDNBQzhCKSgweDAxQTM5RUI1REVEMTRENTZGNUVFRjdGQ0FENDZDRjQxN0M4NTg4REEyNkQxQTg5MjAzMkQ0MzE3MDJBQzM3RkEpKSgoMHgxN0U3NjlBNzY0QTJCQzhGODg4NjgxRjdDQTE0MzZGMTQ4OEVBMUIzMzcyNkQ5OEI0NzM5RDBFOTgyRTA4ODVFKSgweDJFOEZERjNDNjk1OUQxMDhERUVEQkFENEVDQUEwMkUxREYxRDEwMzY2NzM3OTZENDNERjkzMTAyNDE3NjcyQTkpKSgoMHgyQkUwQ0ZCQkVBNkRGMzEyOEFERjdBMURGMzg2ODIxNjFENTdEMUYxOTg3Q0VCNjEzNkI3ODdGMjY5QUY1QTc5KSgweDAzMDI0Q0YwNDJFQTI5OENBQzc1QkIyMTlENzc5RjIwNkVEQ0M1OUI1MTIxNzAwOThCOThDRTZDQTZFRUNCQ0QpKSgoMHgwRjIxREI5MDQ0RjgzMTkyQkQwMDI0ODk1MDhBQjI0Qzc3MjU5RjRCMEYxM0M5MjVDMTYwNDYwREY5RDNEOTNFKSgweDA4QkJCMzM3RDNFRjE5RUI5M0M2OEU5ODNFNDc1RTQ5OTI4QjRFQTNFNkVFMDZDM0Y0MjY1NTNEMUQyNDM4OUIpKSgoMHgyQkE5QzNEMjAyNzQ3Nzg4RDJFNjkxRjJDMzJEN0IwQjY1MUQ1Q0FGMjZEOTBGQUZBNzRCRUYzNzE4RTIxNUNGKSgweDBBQUY3MzY1OUEwNDJFNzM0MzE3NDEyNDA2RjRFRDZCNzhBMzQzQzBFMTEwREZDRjlBRUM5NjM0NDc3N0Q0MEUpKSkpKHooKDB4MEIxRDMyRjk5Qjg5OTEwMUM0RDhGNjI0RjcxMzQ1MEU2NUU0MjU1MzkwRUVBQjBBODBGNDNDMzk5N0Y2NEQ5QikoMHgwOTNGNzM1NENBRTBFREY1NDZDMzFGNzM3MDRFNTdCNDRFN0EwRUY1NTg0REQ0MjYwMUJBRUMxMEYzRTVGMTQ3KSkpKHMoKCgweDNEMjQ5RTlGNDdEQTk2MzcxQjVGQzJDRUUzRjQyQkM3QkExOTI1MTgyQTAwQTlBOUIyQzJDNzU3MzgzNjk0RDQpKDB4Mjg4NkY1Q0FBNjQ3Q0M2RjdFQ0ZCRjc4ODdDQUVEMEJERTc0NkI5QjVGMkJGQkRCREM2QjU1N0Q1MjM1NjA2NCkpKCgweDE2MjUwQ0NCNkYxODRDMzIyRTQ5NEYzNjhGQUUwNUFDRkNEQzlENkJFRkQ1QUI1N0RCREQ3ODRGMkYwQjMyNTEpKDB4MjU4RTRGRDAwNjZBM0NEODJDQ0ZBRjYwMTUyQjhBQTA3RTFDODVFMEY1NkE2MDc3NkEyRTA5NDVCODU0MEVBMikpKCgweDEzNTVFMDJFRDZBOTkwOEM4NkRFODg3MEQ4NEUzRDE5Q0U0OThCMzY2QkNENzNEMThGOEYyREU3QTM2MzIzRTkpKDB4MjI0Nzk5MDIxMjc2OTQyQTEzOTgzQzYxNDM0MzUzRThCOThBMUFGMERGQTg3ODRBMjc5QzhDQzFFNjMwRkM3QikpKCgweDA2N0Y3MjVFQkQwQzFERjc5QURERUUyMTk1NjEyQTk2M0VBQTE5RkM3RTEzRDFFQTYxOEYzMEUwRUE3NkNFNkEpKDB4MUVFQkE2NjlBMDA1NEM5RkUzOTEzN0RFNjUwRDgyQTRFNUQwQTNDRDFDQzY5OTAwN0Q0REQ4MEI1OTdGRjFERikpKCgweDE3NjU4NEY2RjI1MTZEQzNDMUVENzQ5MTZCNkE0REJDMDFBMjc3NTc1NDVBQUExOTBBQTkzRDhENEFGRTVDNDgpKDB4MUUzNTBCQ0I1NEUyNUU2QUQwQjBCRDVBOTcyRkJBQ0Q4QTVBOTM4MjlEQTYyNzgzQjU1MDExREE1M0FGOTlGOSkpKCgweDE1NTFEN0NBM0E0RURDNTgyMjNCNDlFQjMxM0UyQjczQzEzRDg4NkQyOTIxQTg2MjUxMjBENEIxNkI4RjVENUEpKDB4MEU3RTYwOUQyNTE0ODVEQjExM0U2NkIwMUY3M0FENDdEOEFGQ0UzNjlFQjU1M0Y4MjBBNkMxMjA2NjVDQzYxNikpKSkoZ2VuZXJpY19zZWxlY3RvcigoMHgyNzk5NDRBQzU2QUJGODk1RDI4OTBFMEIxREY2RjM0MzhDOTRGMEQxQTg5RjlGRTJENjgzMjI3NjhFQ0MzMTEwKSgweDBENjBFNUM4MzYzM0Q1OEE3MEZCQTE3M0EyRjMzMzY5NDg1NEVBQjUyMTI4QTBENDY0NkQyMDg5REU5ODU4RkUpKSkocG9zZWlkb25fc2VsZWN0b3IoKDB4MEMyRDY1NUNCNzQxOTMxNkE4NDdFQjk5MEI2ODlDRjdBNUU2ODI5M0VBMjQwMzQ2QjBEODFCRDVEMEE2NzA5QikoMHgzNDg3REYyMUYxMUU2Qzc5NjdDNTZGMzBCRUYwNkMwNTY3NDlGQjdENEI4RDhCQzA3RTJDNTZCRjQzODZGRkE5KSkpKGNvbXBsZXRlX2FkZF9zZWxlY3RvcigoMHgzQ0RERjMxODBFMTcxRUQxQjVDRDdDNzk1NzVERTUyOTJDRkMzOUVEMzdBOURBMEFCMzc0ODVCM0ZGRjk5RDE2KSgweDM2MjE1NkVFQkY5N0QwNjZFMUNEQTcxNkE0QUIxQTM2MTJERjhCRTQ5MTZGMUYyNUQxQ0EzODc3QjNFN0ZBN0QpKSkobXVsX3NlbGVjdG9yKCgweDFGQzdENjlERjM4Qzk1QjY2NDBBNjgwMzJFNjk5ODUzQ0MxOUI4MUEzMUY4NTRBRTdDMzM5NjAyN0Y0OEQyMUIpKDB4MEZENTc3QzRGQTRBREY1M0M0NjU3RjIxMkY3NTNGM0RBRkY2RUE3QTg5MjE0MEZGRTAxQTVBQTYyRUNGMzAyNCkpKShlbXVsX3NlbGVjdG9yKCgweDAzMTZGQUMxRUNCNjQ3OEZDMDRDRjExNDM1RkM2OTdDREJCMjAwNUFGMkIyQThFNEMwNTE2QjNDOTUxOTcyOEIpKDB4MTJFODQxOUZFOTM5RTEwODQ5MEVERURENUFFMzZDQUMyNjY2NEIwMzQxNjk2OEYzNzgxMUE3RjgyMjRGNUE4QikpKShlbmRvbXVsX3NjYWxhcl9zZWxlY3RvcigoMHgzQUU4ODZDMzQ4RkZBQTE3REZERTBGQzBFQUE2M0ZBMkE1QjhEMkM1ODFFQTdBNEUxQkExRjIxOUQ2NEJBQjQ5KSgweDBCMEI1QzhENEY0QkYzQTU5Nzk4RkE4MjQyNjQ0REU0MURERjM3OENDODU0RkZGMEJDQjMzQTA1M0RENjI4M0EpKSkocmFuZ2VfY2hlY2swX3NlbGVjdG9yKCkpKHJhbmdlX2NoZWNrMV9zZWxlY3RvcigpKShmb3JlaWduX2ZpZWxkX2FkZF9zZWxlY3RvcigpKShmb3JlaWduX2ZpZWxkX211bF9zZWxlY3RvcigpKSh4b3Jfc2VsZWN0b3IoKSkocm90X3NlbGVjdG9yKCkpKGxvb2t1cF9hZ2dyZWdhdGlvbigpKShsb29rdXBfdGFibGUoKSkobG9va3VwX3NvcnRlZCgoKSgpKCkoKSgpKSkocnVudGltZV9sb29rdXBfdGFibGUoKSkocnVudGltZV9sb29rdXBfdGFibGVfc2VsZWN0b3IoKSkoeG9yX2xvb2t1cF9zZWxlY3RvcigpKShsb29rdXBfZ2F0ZV9sb29rdXBfc2VsZWN0b3IoKSkocmFuZ2VfY2hlY2tfbG9va3VwX3NlbGVjdG9yKCkpKGZvcmVpZ25fZmllbGRfbXVsX2xvb2t1cF9zZWxlY3RvcigpKSkpKSkoZnRfZXZhbDEgMHgxMEQ1RjM3Qzc2NUIwQzcxMzAzMEEwNjFENzdGQ0I0N0U2RTFCOERCNEI5QUUwREY2MDE2MEEwQUEzRDBCMkE0KSkpKHByb29mKChjb21taXRtZW50cygod19jb21tKCgweDFDQUNDNDU0NzAwOTNEN0VBRkUyN0I4MkMzODlGNUQzOUY2NkUzQ0ExRUZCNDBENEU2NDk2MDQ5RjAwM0Q2MTEgMHgwMDk0QUM5REZGQ0NGODhFRkYxQ0ZDOTQ4OEYwMDg4N0I5ODZFRDFFNTE5QkUxQ0M1MzUyNDM3M0RFQjY0MDk3KSgweDM5NTVEOTQyODNDMDk4Q0RFMUMxNDhGNTY5QzJCOEUxQkE3RUUxRUM2NTU1QjM2REQyODRFRTNEOTM1MzkwQTcgMHgzNEMyM0NFRENGNUYwN0YyRkYyODM2OEEyNkIzQkIxMTBBRDdBRTI4RkUyMEZDMzg0QzM0OTVBMDBBMTA5RDRDKSgweDI1OUVFNjczMjg3Njc0RkM4QzU1MENBRjIxNzg0Q0I5OTA4MDc0QkJCNjYyOURCQzk1OTY1OEVDNzZDRUU3RjMgMHgxNTgzMUZGRkU3NDIyOEVCRUVGQzU2NUVDMENCQkUzRDQ1RDE4QjZFREUzOUREODM2QzNGQzFGRDU4RENBRkMxKSgweDAwNEFFRUU1NTZDREQ3MTMyNzdBREYxODc0MUE3RUFEQ0NFQzdFMjNBMTE0N0QwOTczNDc5NjAyMkU0MDEwNzAgMHgxQUFFNzdDQURCREZCMTg0OTY3NkY1MjkyODhBNjVDNEQ2RTA4REU1NDgzQUIwQzFDMEM5N0Q5NjBDM0JFRjczKSgweDBEMUU4RkFGOTA4Q0QzMTdGNDREREQ4RDVEOUZCRDY0MzYyOEUzQ0Q3NTQ1N0U5QjdBMDBEOTAxM0IzRjkxQjEgMHgzQjE1Q0Y0NUQxQUJCREZGRERFNTM1OUQ1NzZBMzFDMEQxRTg5NDQ2ODM5QTlEQTMxMEEwRjEzOEM1RUJEODkxKSgweDM3RjNDNjc2QjY4N0VDRTVEOTY3MkE4NjNEMzRBQjYyMDc1MzdDN0VENUJCMkY4OEYzMEQyMkY0RTVDMjA1QzMgMHgyNUE5NjM5RDUzQzQ0QTQ1NTczRTU5QUJCNDc0QkJGRjQzNTk1REUwNjVERTMyRDRBQkE0NkEyNkExMjlBRDgzKSgweDM1Qjc5RUUwNzQ0NkQ2Q0RDODk1OTMxNEEwREQ0ODUyQzRDRkQ1MTFDOUQyRDQ1QjI4QkMyMUI4ODE5QkVCNUYgMHgzMjEyMDkzOEQwMDczNTVGRTgwOTVBQzgyNzM0ODJDRTRBRTQxOTAwOTA1MUQzQzNGNzBCNTQzOUYyMkY2MzZDKSgweDJFMjJGMDdBODdGMDU2M0M5QTlCQjY1NzQ3MEY4MzY0NjZEQzFGRjk5RTcwQTlFQTU1NzdGN0MwMzAyNUU2MEIgMHgxOTQxMjY4NjEyREY3RjhDRDFCN0M4M0FBMTZBMUYwNTE5QjlEODJDQ0U5M0VGNjA5Mjc2N0M5RDBGM0I2OTgxKSgweDAzRDIzQjNBQTQ4RTBDRUFCMkIxMjZGNDJCOEMwRDg3MEJFNkYwOTU2OTZDM0NCNEI1MkM3NTkwMzRENUM2MjggMHgwOUJGMDM2NEVGRjI0RjU5NjE3MUY3QUY2RDdFQkZEMjg5N0VBRjQ3QjhBRjBCMkZEQjI0NTdCNTE4M0Q0Rjk5KSgweDI3RTRGNEIxNzM3RjE2OTkyRjU1QjY4QzRFMjNDRjMyQjQxNEUwQ0NENzFCNTFBQzQ4RTVGMzRCRTk5MUZGM0EgMHgxQTM2QTQ1Nzk2NTE3MDYwM0Y1Nzk4QjAxRjM1NkQ0M0M1MUYxNDM5Qzg2MTRGMDdGQ0RBQTlGRTlFMDVBREE1KSgweDI0MUNDNDVGNDRDNjgyQTNEREFEMUExMzhDMjdFQjY0RTYyQUNFQ0M0QzkxRTUxOUNEMjNBNzAyRDNBNTIzOUMgMHgwQ0JBMzc0REFEMzZGM0YxQTU2OUI0MzZBMjExMjAwODEwNzM1QTczNjA5ODU2N0YxQUM2MzM5RkVCNEMzODM2KSgweDNFNEFCQUM3QThDRDhFODQyODY0QUZEMkVCODJEODZBQTRGRkY1M0FDRjEzOEMyQkVFMUU0QTBGQkE4MDI2OUUgMHgxNEJERTQzMEQzOTFEQjgxN0VGNzc3MzNFQjdBNERCRTRCM0U2NEFFNjlBMTdBOTI3ODVFNEM0NzBEQkVGQUEwKSgweDJFODlGOTI4MTNCQUIyOEQ5NDk0OTI1Qjc4OTgwN0QxRTQyODM5NkUxMTU2QTBBNUNFMTJDNjRCNjE3MTkxNzIgMHgyQTIxRUY4MDQxQTRCM0E3RDA4RTBFMTAyNDZCRjVENzI0ODA1RkM0MDQxQUEwNTVDOEU1ODNCNDA2RUNEOEE4KSgweDMwNzIzRjA2NDE3QjRCMEQ5N0U4QjhBQzdEREMxNTI2RUM1QzdFRDI4RDQ2RkI1Njk0MEJCNkE4ODBDRTdBMTcgMHgxNUE5NjgyNEFBOTg3OUEwRTI1OTVEMjU4REEwNkJFMUIyNEZEOTQ0MTg1RkUzRUVBMDVCODZEMkExNjhCOEJFKSgweDM5M0I5ODIyQTdCQTQ0QTIwNDQ5OUFBMTQ1RUY0QkFCMEFFOEVENjc3MjdBQzFDODI1NjAxMzQ3MUI4RTFDMTcgMHgxNDQ2RkE0NEY5NzAyQzdBMTUwMjg2MjNDM0EzQjNBNkJDNzA5QzdGREQzNTdCODRBRjRBQTYwNDZERkM3QUE0KSkpKHpfY29tbSgweDAyMkYxNDY5RUU3MkFCRjAwRDg5RjA1MzA1MkIxMzY2NTE3RDdDNUZBNjgzNkM3RTA2QUY5RTkyQTAwMTk4Q0EgMHgyQUU3NjM2N0VGQ0U0Q0Q5Mjg0NzQ0MkMxNDY3MkVGQUIyNTFBMjk2NjU1ODg3ODU3QUFDRTJEMzZFOTUzNTc5KSkodF9jb21tKCgweDFDMTAzQUJGNjc5QUFFMzIzRTY3NTZDMUZBNDVFQjdGQzlDMEY0QkQ5MjcwMTBEM0E0OENCRUZCMDlGODRFODkgMHgxQzAzOEUyRkQwNjQ4RjcyMDdFNTcyMkJFMDMxQzczQzFGOEI3QUZCRkFCMjA3RkU2M0EwN0NEMUE4N0RFMjBGKSgweDBBRDQ1M0RDOTUyMjA3NDhEMkRGN0UyOThCNjBGOEYyNjE4MzRDQUY0RDZEQjBGMzQzNzY2MTBCNzczMjlCODggMHgyNjg2RTNENTM2MkNDNTQxMjI2OTFFM0EwODcyMUFDQTZEMkIzNDJCOThBRDNGOTRBOUY5MEE5OTcyQ0EwOTU5KSgweDM4N0MyNUNEQ0NCNjU3RDMzREQ4MkM4Mzg0RTdGMDIyOThGRkQ2MDJBQjYzNEJCQTRGRUI4NDM2RUIyNjAwQUEgMHgyRjU4MDRCQjBCNTlDNjVCNEQ2OEI2RUY5MDdFRDJBOTE4NzMxRjE0N0YzMTVDOTcwRjI2RTNFMjM3QUUzN0Q5KSgweDI5RjUxMDVENDVGOTNCMEZBQ0Q4MERDQTg5MzZFREE4OUEwNTUyRjM0RTkyMzRGMTkwNzA3REM4NTZFRUZCQ0UgMHgxNjhFRTU1RTZENDVFRENGNkI2RkFDNDY4N0IyNENBNEIyQzFFMUVDNDlBNjVCQzg4RjM4NDBFMkUwMUU0MkVCKSgweDI4NEEzRTIzREE5NDBBQTIwOTBBQjM1RjBDRDU1NkU5MzI3MUYwNUI2OUY1QTFGNEY4MDYwMzM4RkNCQkE2ODUgMHgxMkFFRDYxMEQ0QjAxMUQ1REEyRjcxNUUyNjVEN0MzRDY1MDgxODc3RDUzRjJBNUI0MTU2Rjc5NTM1MTJBRkY3KSgweDJFRjJFMUZEMjQ1NEVGQUMzQTA4REQxNUFFMzg1MEVDMThFQjJENTMyNzBEMEUwNDlGQTRFNTkyNThDMjE2MDYgMHgzRUU5MzExMENFNjhBRjRCMTI2OUJCOTY2OEQ4NkM1MDlCQTgwQjE3QjVDNzA5QTdENjJENkJEQjhERDgyODdGKSgweDJDN0Y2RUM2ODMxOUVEMDVGNTM5NThGRTExODQyOEMzMjVDQ0RFQUUwNEQ3RDBFNkZDNDBBMDQ4MjkxMTg1N0MgMHgwMDdFMEY5QjRGRDdERkJERUMzMkNGMkNFRDExMTI0MTQ5NDg0MzFCRUU5NEFDRTM3MTNCQkU5RDFBQzAzM0ZFKSkpKSkoZXZhbHVhdGlvbnMoKHcoKDB4MzQ2Q0I0NDBBMkM5NENEQkVGOEEyRDA0M0NFNjYxQjRFOUVDMzAxMjg0NjNDMzgwM0MwQzdEN0VCNTYwRDA0MSAweDFFMDU4QjlCODM4MDE2MjQ2MTg4NEIwM0RBNTQyQ0U3RkQ2NzkzRjUyREMwNjZDRjdEMDcxNjM5QjlDREMwNTkpKDB4MTc4N0U0M0U0NTZERjkzOTJGRDk4M0FBQzlFOEM3OTQ3MzMyRUM0RDU2MjY0MUVBMEYxQTVCNTZGOUUyQURCRCAweDM1NDk4MEJEREM3MUE2Qjg3Nzc0QUQ1RUQxOEQ1NUQ2RjQyOUMxMDc2QzFFRTBFQjZEMDNGMTA4NEJCNDREQTMpKDB4MzdCMjI5NTAzNzExNUVFMzZEQUI5MUYwRDM3QTc0RTRDMzExRDg1MzE1QkJENzM3NUI3QkI0QzFFQTEzMUI2MSAweDEzMkZEQTQ4NEFENkM0RjhFQUE2RThFNzI2NzY0MDZEOTgwOEMxQTdFRjU2MkU5NTlBQzkxQjI1RTg0QjNBMUYpKDB4MEJENzY2MjIzMDc0RjlERDNEOTk2NTk4MTMwMTU0MkIyMUIzN0JDRTY0NzdGOTdEMzg0NDc4RDE0Q0ZDMzUwRSAweDIyMEJCQURGNDEyNzQ3RUI3NTkzRkYyOTAxNjA2OTg5QjFFRjAyRTg1MjAxREExMUM0ODlCMjkwNUVEMjk5NjIpKDB4MDUwMEM5MEJFRjZGNjA4RTQwRUU1MDgzQjRDNzQ1NjRCNzMyOTVERDQ0NThBQThFMDk3QzUzMDRGMTlFODVBNiAweDJBREU2NDA4MDY4N0Y5Mzg2QjkwMjZGMUVBNjU3NDc0NUU5N0ZCRDU5QjAxOEY3Qzg5MTMxNUYxMjY4QTM0MjUpKDB4MjdCQzlEMUIxRDQwRUE5NUU3Q0QzMTRENkVGQUQ1RENBOTE5MjA2ODBFOEEzMDg4MUQ1QThFNjczNDA1OUJENiAweDA2NDQ4NTgwQjUxQTZFQTc5REI2NDhDM0Q3MjVGRDhFNEVGN0UwMzBGMzdCNDczMEY3RTU2MTMxNjYyNjEyRTUpKDB4MjM5MDBDNjk4ODBGREMwNzk0QzgxMzE3NTg5NEQ4QzkzQTY1NjlDMDdFNzA0REI1OTc1QUQxMEI1MUU3NDQ2OSAweDFCOTZCODZEM0I3RkU4MDk5OTA2RTU4Q0JENDhDNUExMjE2RUZDQjI3NzQ5MDg4ODFFOURBOUIwMjFDNTY4NDEpKDB4MjIyMjk5OTE4MTkzOEJCNDNBMUNDOTAyMUE3NEYwQTM2QzQyNDdBNkRGNzZGQzlBMDM4NzE3NjI5MzNBMDhDMCAweDI0Q0JCNkEyM0FBNDA2N0U3RTlBODEyN0QwRjgwNUU1MjBGMUNGNENFMDNBMUYyN0I1MEE5ODk5OEY3Q0RDOTApKDB4Mzk3Njc4NThEOEVFODVFOTk4RDg4NEREQzA1RUM2RjBBQkU4NzY4NDQ5NjUwRDIzQ0NENTY2Q0VCMEE4OTE4MCAweDNCRTc3NzVFQjNDODlFRkU1MkU5REZCRTY4NjBFQUE3RUExRDYwREU2NDA2MUU5QUFDRjcwRUY2MzZGRDdCMzgpKDB4MDEyOEU5REU4RUIyMUFENzFBRENFRTQ2MTYyNDRCQ0VDM0JBRTlEMTgxMTIzOTZEMzgwNTRBREE2QzlDMzM5MSAweDBCNzdEMDE0QjBFQkM2OTAxNEE3NTkyRUEyQjhDQUI3NzcxRTM4MUYzNjhDM0QwQTNBNkM2NzU5ODkxOTcyOTMpKDB4MkY4NTI2QkU0QUJCNDQ1ODUxOEY5NTQyMURDMkNCRjJCOUVDQzU4NjVFMDA5QTg5RUEzMDkxMzBFNkE3MjhCQSAweDA0Q0Y5NjI3OUE4MDVCRDA2RkZFNDFEQzFDQjNGNTA2NUQyOUQyMUIyRkRDRDM3NTQxMzg1QUJDODhGRjdGRDgpKDB4MURFNTU1NjAzQzhGM0U5MzY4MTQ3MTAyMDBBMDc2MTRBQ0MxRDc0MDM4Q0JCQjFDNjJDRUQ2QTAzRjM2OUNCMCAweDFDOUI3NUQyNTZGMzYxQ0Q2MUExMTY0ODgyREMxODI2M0YyMjgzRUMyNDQyNTZBNjI1N0UxOUE3RDZCRTI3NDApKDB4MTg3MjA2QjI1NDA1QjEzQjM2M0QyQUQ4NDMwRUE3OEVEMkU3NjRCQzdGMUVERDhBQjE0NjBBMzAxMjk0Qjc2MyAweDA4QUUyQzU5QkJCRTg2OTBCQ0IwQjE5QzQ2QkMyMkM4MTJCMkQxODlFOTA4MjdDNENGMDc3NzZGQTY5NDg4RTQpKDB4MkM4MDQwRkJDOERGNDMyRDYzQTRGOTY3OUY2MEYzNjdFNEM1OTM0OEJBMjVDM0ZCNzVGRDgxMUVGOEY5MEExQyAweDA0NzVCMEI5Mzc0QjE2MjU1NTc4ODBEQUFGQ0NBN0VCRkFGMzYwRjI1QjVBQ0RBQTg5OUM4NzU1QUVFRTUxMEMpKDB4MTU2OEFCRDBBREExOTM0QTRFRjRDQzUzNkE3NzVCOUE0QjYyMjY0MUExODkxQUI4NERFNDdERTAxMjIzRDdFRCAweDMxREFBMTI0QTE4M0UxQjZCNjgzNDBDRTQ2OTU3RENEQkE2NkMyNTUxOUI0ODJEQkUxMDIzNUJERUY4RkI3QjApKSkoY29lZmZpY2llbnRzKCgweDE5NzNDMUEzQkMwOTk0MURBNzRBRjZGNEE0NkNFN0Y5NDEzMDlFMzkxRTZFODUxMTJGNUQ5NTdDMjEzNDlEQzAgMHgxMDhDMTlFQTg2MUQ1RTQ2Mzk4QUNDOUI1MEEwQzVEODUyMzEwMkRDRjU0MTUxOTA4RTYwRDBFRDdFOTdEQ0FGKSgweDEyOTdEOUUyRDJDNzMxRDZGQjg1RkJBMDBGNTYyODFFNEYwRThGNUIzQjgxRkQ5RDg4RjQwRUI5QzQ2OEIwNUQgMHgyNDFGNUQ2MUQwOEI4RjE4RjdCQUNCNkQzMThERUU4RjcyOERGRDEwODhFNTE0RjY0Njk3NUY1MjkxNjE1MDNGKSgweDMwRTNCNEMyRENFNTcwQjU3NjczOTZDMkZEQUU5QzdFNUQ5QTREMkUwREY0QTE3Q0Q2Mjk0MUU3QUQyMjI0MTcgMHgxM0NDNThFM0I4OUUzOEVEQzVCQjkyMjYzNjg3RTE0MjhGNjJBODRDNkYwNzI0NzUxQTg1OTQ1Q0Y2Q0M1QTVGKSgweDFGODQyMDZBOEIzMTJCRDRDQTNEQkExNTUxOTQ5QzFFQzlBRTM3QjNBOUIzNEIwQTdDNUZGQUM4MUE5MEUyNDkgMHgzMTFDNkJCNEZFODVFODI4OUEzMzY2MDE5OUI1OEVFMTg0NUZBNjQ1MDRFNzE0MUMyNEFBNzg5NzE3RDgyMUQ2KSgweDJDRDhEOTUxNDU1MTFGMzlFNDk4RUEzNzBBOUU4MEE3QTk3QUYxN0Y4OUZCRUQ0RDVCMDQ4RUI5OUY1OUZENzUgMHgyMUNCOEUxQThCNzlCMEMzRDMyNTQxRjU2QjI1OERFMTVCNzA1MkQ5QzJGRkNFRDRBRjdERkIxRTI4NUEwMTI0KSgweDE3NTczNjY0MzZGQ0UzMzc4NDREMEVDMjg1RDk5OTQyRkRBNDc2NDJBRDQxMzdFNDE1RENBNTc3NDM5OTgwMTYgMHgwNEMwRjRFQkQxRUZFNzI5RDEzQzY1MTk3MkMyODAxRTAxRTQwREQzNEVDNzA4REVERDY1MzQzNzQ1NEY4N0M2KSgweDFCQjU5RDlDRTZEOTZBRjlEMTc0OTM0NjgyMkI0RkMxRkM3MUQ1RDE4Mjc4MDAxM0JEQTJCMDgzQzM5OTE0QzMgMHgwRTA2NkRERDc4MjRFMTMwODIzMDkwQ0IwRTZBNUM4OERGNTc3OTYwRTlFMzI4RDYxRUExNkZEMkRDOTQxOEEyKSgweDI5MDY1ODMwODM0OTQ4NEYyNURENDg1MkI0M0U2MTMzNEQyRUJGRTVFRTI1NDhGQ0I4NjE4REM2OEZBQTk3MDkgMHgzMzhEQjU0NzY0NTMxRUE0N0U2RDEwOUE3MTI5MTlFQ0I4NEMzMzI5QUZGMUJDQzAyNzExOEEzMDZCNENGQzlGKSgweDA4NUQ3NDhDQUYzMDk5NjU0MjJGNTFFMUI5OTk4QTQ0MzVDMjBBOURCOTBERkVEMjEzQkZFREZBRDU4NDlCNDcgMHgwREY2MTA4MDAwN0MwMTA5NEM4MEExMzQwQTQ3NDEzODhDQjgwMkU4QzJCNzkzMkE4REVFRTc4OTZERERBMkUyKSgweDAwRUI5MTMwQTkyNEVCRUE1OUE1QTc5OEQ3QkM0QTA2ODAwNjRFQUFFMjFFRjBDNUQ5MjBGODdCRDk5OEM1QUYgMHgxMTNENjY3RDZDMzRFQzM2ODU2NEQ2QUM0QzRFRDczNUJFN0YzMDM0OTU3MDRBN0QxRTYwQzZDODEyRjE3QjFDKSgweDNFOUFFREU0M0NGMjA2NEIyQkIxNzU1NTlDOUZGQjUwNDhBN0Y4NURGOTVBMTI0NjNFQkE3MEM0OEFCRjkzQTkgMHgxNEIzNDYzRTNFMkJFODVCRjUwQjNFMzMxRjA4OTgyOUJFMkI4REYzODNGOTcwQ0E3RTRGMEFCNTY0MkQ0NDkxKSgweDNGQkQ1MEUyOUQ4REU3RDcxMzc3QkM2MUFEQjlDMDNDQUE0QzJFRDNFQzBBN0U4QURFOEJENzI1MzVEN0JFOTMgMHgwQTE3N0U0MEI2NjMyNDFEOUEyNjFCN0E4Q0RDNzIwMjM0RDBGNjU5OUM3OENGQjgxMDFBQzZENEM3MUNBNzc2KSgweDA0NzdCOTMwQjM0NDJEMUI1QUQyRjJDRkIzREVBQkEzODNFRjExN0FCM0Q1NDhDN0U3RDgyMkZBQ0Q5MDQ0QUMgMHgwNjJDN0JCMjFCRTAyMTdEQzk2NEVFRjc4MEFDRjE2RjIzMTFERDIzRTc2NTA3OUY3OTFCREZENzQ5MTUwRjBDKSgweDE1NTNFNkY0MzFDOUZBNjdCREExQzU1NUQwNTMxMDk5OUIxRjRFNEJEOEJCOUUzREEwNzIxOTVCMkJCMzhGN0IgMHgxOUFDMTZFRDNCMjU1RkJEMkJFRTk0MUNDOTY1MjZDRTBDQTk1OTIxQ0U0NkY5QzQwQzg5NDQxMTA1MjAwRjIyKSgweDJEMEUyQzI3QUE2MDJDNkIwODZDODVDODI2MkMzNUM4RjAxM0M0NTREMjUxM0E1QUE0OEY5MjczNzA0MzY2Q0UgMHgyRkQxREI0MUU5RTE2MkUwMDQzNURDNUZGMjU3Rjg0OTgzQzlFNkRENkREMTJERDE5NjVDRjA4MTdEMENCREJDKSkpKHooMHgyMDhENjYwRDczMEJGN0IyMTg2MEVCQURBQkUyNUQ1MjNFOTc4RjUyMjM0QjM0OEZGRDIzNEIwRDg3RUU0NDdEIDB4MjY4RTMzNzYzMjRBOTFDMUExQ0E5NUU4QUQwQjM4MkJGN0E0OTg4Njc0NTJBNjEyMURFQTRFQzUwMEZGNDc3QykpKHMoKDB4MUY1REM4NjUyMERCMEMxQ0UwNEIyNzYwNkE0NEQ4QTkzRDJBMkYzODMxQTYzODBBNThCRjU4OUZDOTU0QzA0MSAweDIwMTNCNEVEMDc4MjEzNEYxQUZCRUUwOEYwRUI1RkU2MjgxNkMxRjUyRUFFQkMxRDczNUZFMjg0N0Q3RjlDREMpKDB4MzgxMjdBRDQ2NTg3RkNDMkFGNThEQzAwODdBQjQxQjY4NjVENDE4NzY4QTVBOEFBRTc5MzlFNjMxNkQwNkIzQSAweDI0NDkxMEUzNzRGOEY3OTUzRkEzNkU1MzgzNEMzQkFCQUY1NUZEQjdDRUYyQjE3QzFGQUFGOEMyMzZCMzZEMzIpKDB4MjRFRUY4NjYzOUI0QjkxQjI4NzkyQ0I1RDYzNUFFRDg1QTM4NTU1NEU3RjI1QzFENEIzRUU1NjE5NEQ2MjMxRCAweDJFRTUxRDIwQkJBQTZBNzFCMUVBRDBBNkJCMkZDQTI2MUU3N0I0ODkzNUFDQzIwQ0IyOUQ2RERBRkIzOTIxMDIpKDB4MUI5RTIyMTdEQzBFMTdBNkU5N0IwREU5RjU4MEREOUJDMjkxNkEzRUQ1QUJBRUM1QUNFNkY0RkU0QzM1RjA0MCAweDAxREI1RjA4NDFCRThEOTlDMTFCRUM0OTIxM0E3QkU2Mjc3MTZGRDREQUI0Nzk2MUFGNjE3NzMxMENDOTg5Q0QpKDB4MzNCRjMxRkNFQkFCRjQ3QzQ5MDlDMTYxREQ4QzRFNjQ4NjI4QUFDOTYxRkM3NTRDQUQ3MTdBNUQyRTVCMEUxNyAweDMyMEE4QzY2NDE4NEFDOUQ2NEE0OTkwRTMyRDc2QzlEQUY3QUU1QTE1RkFCRkYwRTE4RjZGMEIzRURDRERDOUEpKDB4MTUyQzk0MjM5RjRGOUMwMURBQjc3Q0MzN0EyNEQ5QjFEMENCN0Y0OEM4QTE3NjY2MTEwODgwOEUxN0I1QTUxNSAweDNCNkY5MDY4RDU5NURBMjZBMzE2QTM5M0QxODRFQjNCREEzMDY3MkYzMjZGODJDMTdBRUQxNEEzMEYxMUY2MTEpKSkoZ2VuZXJpY19zZWxlY3RvcigweDMyNzMyRUZDRTQ3RkRBNDAyODJGRDc0NTg3QjlEQzJBM0QyOTM2RTdBQjY4ODFEOUJCQzgzRjdGOUQzM0NBQjYgMHgyRTc2REUyNkJEQ0M0ODRCOTIwREU1QUZBMDZCNkNENkE2MjBBRERFRjA0MDJFNzVENzEwRTBFMDBDMjU4OEQxKSkocG9zZWlkb25fc2VsZWN0b3IoMHgzNjBGQkY5NTAyRjBCRDQ5OTdBOTI0RTg3NEQzNUUzRjEyMEFBQzY3NjRGRDg0NkIwODM2NkQyMURFOTA4QTMzIDB4MjdGQjkzOUJDRTlCOEUxMUNCMTI3M0Q3RDNERTdBNDlFNUNDM0UwMjJERDA0RjBEMkIwMjVBQzRBRUQ1OEVEOCkpKGNvbXBsZXRlX2FkZF9zZWxlY3RvcigweDNGREU0MzY3MEFEQ0QzMjkxNEMxRkYxNzJENEZDMDVCMzM5RUFCOUZBRkNDNTExMEUzOUQwMDY0NEY1MzNGRUIgMHgxNUVERUNFN0Q0RjkzNzFBRjE3REFEREQ0QzNCMzRBQ0M4MEMxN0M1MkE4MEI0QTgxRDkxOUQ4RDI3MUQzMkE4KSkobXVsX3NlbGVjdG9yKDB4MzY4NzVDQzIwMzM4REI2NTE3QUNGNzYyMkE5MUY3QjMzQTJGMDhDQzIyNEEzNjM5QUIwMkNGMjVDMjIzQkFFOSAweDJEQUVGMTk5OEU5Q0NCMjQ1Rjg2NkI1QkI4MEM2M0NFQzM4MkMzOEQ4QkVGRDIzN0YwMURDOTE4N0ZBNjBEQ0QpKShlbXVsX3NlbGVjdG9yKDB4M0EzODJBNDNENjE1RjdFNjI5QjhCNEFEMTlDNDcwQUEzMjdGNUIyMzZFODc4Qzk3MENFNUEwNDVBRUJGMTIzQyAweDJDM0FENjA2N0NGNUU2OUYxQTA0MDQ1Nzc0OTc4OTQxNTY4NTI4MDA1NjMyNUQ2RDNGMzIxNzhFRDY4OEY4QjQpKShlbmRvbXVsX3NjYWxhcl9zZWxlY3RvcigweDBFRTk4RDM1OTQ2M0NCNTMzQTY4QzZBNzZENDlGOTY3QURGNUUxQTQxRDUyOEM0MzNGNTZERTBFOTE3NjQzRDcgMHgxNkQ0QTQwOTIxNDNEMENFNzA2NkU1QzVBMjAxMkQwNzE5MDM4Nzc3NzE1OUNBOEFDMzVBQTJFMDk0RTE4OEFDKSkpKShmdF9ldmFsMSAweDAzNzExNTBBOEI0OTdGRTFCODZFNjhGRTM3N0IwQUQzOTBCRTE1QzU5NkE2MDU5MDdDNjg0QTM0Qzg5NzU5RTUpKGJ1bGxldHByb29mKChscigoKDB4MDgzQTdFMzMwNzIxNTFEMTg2MDYyNDVFQTg5OEQ5MUZBQ0Q1N0U4RjZCQ0RDNDhBOEFEQzNBMEE2M0NCMUM1NCAweDM5NjJFNjlFN0Y5QzNDQkIxNDJGQUFCN0U0QTBERUFGMjUyN0IzRTM5MzZGNzQ4QThBREM4OEE3ODE2MEQ2OEUpKDB4MTU0Q0VENUExMDhCNTBDMzM4NTA3QTFERTU1MjE2QjM0MzdFQTg5NENBMzhFM0E2RDRCNjQ2MUZBQUE0QTdCRiAweDA4RjUwNzc5OThCODcwREFGRjA2Q0ZEQTY1NkYyRTY0RURERkI4N0E0MjA5NDNCNTg4MDA1MUM5QzZCQTQzNjIpKSgoMHgzMUMxOEFBOEE2NDNGNjJEODNDNEE3NEI5NjZEMjJDOEI2MkJERkFBN0ZDQzU5MDVENjJFMkM2NTRCOUI4QUEzIDB4M0YxMTNDQUMzRDg0NzZDOTQ4MzVDRDY2OTg3QTJCQTg5MTU2MDEyNTc5QzgzMEQ5NDU5NjBGREM3MkY4QzM4MSkoMHgzODc3NDYyM0JERjIwNzUzNEVGRkNCQjk5RjEzRjQxMTgwN0EzMDA2MENCRkQxMUI3Qzg3RTU0MDMxMUQyMDc4IDB4M0ZCMDYxRTg5QzAzMTkyN0Y1NTgxMUNENDlFMUJBRjVEQzMyNkJCRjFEQzY3NjQ5OTc2RjZEODIwOUEyOTAyMSkpKCgweDFCNkE2QTNENzY5OEIxODlDQkZCNUU4RkEyNEU5QUU2NkQxMzk3ODIwODQ2NjNCMkUwQUY1MDQxMDdFMTcwNDcgMHgyRkU0NjkxNkYyNzYwNjg5Q0NDNUVFRDY0MDAzODEwMUE3MTJCRDA1OThBMDk4MEVGM0FFRDlBOURGRTc0NThBKSgweDI5NzQwMjNCQzZBQzgyQ0VGN0U5RTI2NjRFRkQxNUYzMzE2NzlBMTIzOTE3RUE4OTM4QUI4NEM0REM2QjBGRjEgMHgyMTc2MTAxRkVFMjk1NTREMUEwNTgwOERBRkVEMTI2RkRBNDUwMDc0NDdCNzQ4MjUyMDg4QzYwRDA2NzcwNkY3KSkoKDB4MUI5QkZBRUUxRTZFQjBDMkVFMUE2ODZBRkQ1ODY3OUYzRThFQjlFMDAwOUFBNTA1NDUwQkIxRUNCRDdDQjlGNSAweDBENjU1QUQ3QjUyMjNCODlDNTg1RjNBMTU0MEU2MEE5QUFBMTlCODE4MjY0OEUwRUY2RUY3Qzg0NjVERjFDNUMpKDB4MDM1NzJGOTE5MDJEMzA2NDk2NTE0MUE4M0M2MTlEQzg5N0VDM0E3QkZERjNBODdFODRFNUNBMDQ2NkQxMUIxRCAweDM1OTZCRTBFNkUwMkFFOTc1OUVCNjc0QTc0NjYyNEY0Q0U0QTU2RjZDOTYyNkI4ODE3RUE1MUU5NTdDREIzRDUpKSgoMHgxNDcyRDQwMzBBNEVBMEM1MjQ4NkI3RDExRjM5M0VEOEJENEY3NkE3MkM4NUFCOTkyMzlBMEREREE0OTAwNDg5IDB4MzNCNzRGQTM0QTQzNTcxOUNDNzQxRUY1QTE3QUFBQ0EwQzk4MjdDNTU4Q0U0NUFEOTUzRUYzRkIzMzk5NzQ3MikoMHgxOUQwRDFCQ0VGREExMkJGRUQ4QThDMjhDNkIxQzY1ODg5NTc1MjEyMUIyODk3NkZGNjUxN0RFNDgxRDNCMERBIDB4MjNCRjRGQkFGRTJGQjcyNEFEMTQ4RDk2RDQzM0YxMzFDQ0Y2MzAzNDY2NTlBNUE1REE1Q0IwQThCNzdGMjdFNCkpKCgweDE5ODUyMTEzQzVFNTU1MkY1RUQ2MjAyREZGREJCMEQ2OTQyMDBFNDJCOUNGNzQwMjdFQTcwMkNFOTUzMzBCRUYgMHgyMTZCRTk5MjU3Qzg5QzNCODhCQkY2Nzk4RjFFRThFRUMxQzg1M0UzMjhFNkJFNDVCQkExQUVGQUFFQ0NERThFKSgweDMwQTZFOEEwNzUwMjc5MEI0MzE4RjNBNjA3NUJCRjg3OUMyNDdGNzZBODc1MjBDNkM4QUIzNkI4NDJCMTgyNTcgMHgyOEUzMTkwRUQwNEQ5Rjg4N0NGREVCQzQ1M0U2QkEzMDZBMjg2NzBCOUQzQjg5NEM2QTA2NTlBQTU5QzE2QjBDKSkoKDB4MzJENjVFMThFMURFRDg5RUQxRDYyMTZCMEZGQzRCRDRDMzA2OTVBNEIzRTRENTkzNjA2RUMzN0MwRjU4RTlDMyAweDI3NkYyRUZENzkyMjhGQzk4NUE4M0M3RkRDRUY5Q0E3OTdGODFCQzMyMEE5NzkzOEVGRjMxNjdCQjUwQzkzNkIpKDB4MjYyMDg2MEMyNTU3OEZFMUZCNTAwNzY3Q0NDMkFCN0REQkM1NkE2MThCREZGQjlGNERGRjRCQTNGQ0RGM0ExMSAweDBGQ0I5RjE2QjVEODE5MTkwQzA2MEREQ0E1RjZFRjVBMTU1QUUxN0Y1Qjg1QzhFOEE3NzZENzREQkU3MzMwMTgpKSgoMHgwODEwNDcxQzRCMjk1RjlDODA0MzZBNUI0QzYwRTFEMzFGQ0EwNzM3NUY5NUYyQzMwMEYyQThDRUExNTZFNUIyIDB4MkE4NkQ3MkY2MTAwQTA3NDc4QTkzOTE5MEExOUE0RTBDMjc4RUM0RjQxQUZGQTI5RkMyNEUyN0JGNTFBMjMwOSkoMHgyNTNDMkU0MTc0NzJBNkU3MDlEQkNBNDAzRUI1MDVERjZFMEYxQzFEODY3N0RBNThENDU0MEY4RjY3RjQxREQxIDB4MEY1QkJEQTdFOTYyRUI0RUE5QUVDQ0VERDgxRTBFNjY3NTgyQTMxNjRBRTYwRjczNjMwN0IyQUUxMkFGREFGNSkpKCgweDE3RkU4RTJGRTYxMjlBRUFFQkZFODFGOUYzMEYyMTM2NzBENkE1MzQzNUUyNTEwRjNCNkU3MjAwNjQ4ODJFNDMgMHgzMkEwOEIwOTQ3QURFREFFQjQxNURCNURENTE5QTZCMkVGMDczMkVGM0M2NTY4NTJGRDdFQ0FGRTVFMjhDOTNGKSgweDM0RDRCMzQxQjlGRUI3NjI4Q0JCRERBN0IwMUNFQjQyRUVGRTg4MzNEOUM4MjJGMDI1NUNBNzAwRkExMDhCODcgMHgyQUUzRjhFNUU4RjA4OTQ5ODYxMTY0MjUyNDVBMTgyN0ExNDcxRDU4MzBFMTVGOTdFMjU1MkM4NzdEMUUzNjcyKSkoKDB4MEZDODA4MjdGOUY4M0JCODJEMkU4RUI4OTQyQjIzRDM1Rjc0NTg3NTYzRDE4MkU1RjJFMDAyODIwQzU0RTkwOCAweDJEOTg2QjQyMjY1RjU4NEE1QTA3NEE0MDA5QTAwN0UxQ0ZEMENBMjM5NDk4NjdCQzk0RkQ1RDhENkUyNkI0RTQpKDB4MkUyQ0NDODQxMkYwNEMxNjlBMDg3N0VCOTMyQUQzQTg1MEMwRDcyRDA2MjAyNzA4QjAxRjkxQzAzMTYxMTY0MSAweDEyMjlCNzMyRUNBNzlEOEEwRTFEMEY2ODk2ODg3MDA1RTk1NDA3OEMxN0M0OUE4RTdCQTlFREIxREFFRjYyQTApKSgoMHgwRUFDQjY0OURGMTk2M0VGNDhFNkIwMDBBNkM0QzU0M0E4NThCMzRCMDZGRUU2QjJBQjgxRDE2RERFQzhDM0E5IDB4MTNDRTZBRTg2NDkzNzVDOUVCMzkwQUY3MTIxODA3ODQzQkZERDc0NjQzNDM3OTk5RkYwRjk1N0JEMUJDOTUyRikoMHgxRkZBN0NFMzlDRTdEQTNEQTZCNkI1Qzk3RjE2RDRGMUEyNDA0MjMxN0FFODZGRjIxQkVBNkY4OTk0NzZFMkNEIDB4MUE5QUE3MDFBNDVFNEE5MTQwMUIyQTc0NDI2NzEyMjAzQTEzRDhFNDkwREZCQzM3QjA1QUU2OTUyQUM3OTI3MSkpKCgweDEzQzE4QUM4RkNBQzUyOUNBQkU3OThFQjk0OEQ2RTVGNjFENzlGRkU2RjgzREVFMTczNEUwRjFDQzY4Rjk0MzggMHgyNDk1RTQ1RkVEODhFMkU0NzEyQTg0MTYwQzlGNDdFMUQwQUZDNThEMzg4QjhFQTlEOEREOTIxRTA2RjcwNzFEKSgweDEzOEJBNEYzRTcxNTM4QjEzRjNFOEM4NDIwOTI1REMxQzMyODFCRjdGOEVFMUI1ODEwNkVFNDNCODRGNUFBQjUgMHgzQzVGQkZFRDRGOTQwQjk0MDgzODA0NUExRTRFMUU5RTA4QUE3RjI3OUQyRDEwMDNEMjRERjBCQTNCNDYwOEVCKSkoKDB4MzQ2OEVGNUQ0ODNERjg1MjU0QTI1MDQwNTEzODlCNEY2NzA2MzkzMEI4MEQ3NEQ1NUNDMDEwQzFFRDVCNDFEOCAweDAyM0Q0RDdCRjc0REY0RDUzQTZFQzU2MDA5NDNEM0Y5NzVFREYzNkI5OEYyRTlGRTI0NjY4ODE4NkIxNjA1NjQpKDB4MTJFRkVBQUNEQzBDMDQ0N0Q4RTYwNTI1MzUxMUNFODRGRTRFRTczNzI3MzBENENGMkM5QzcyRDc0MTdCRkYwMSAweDA2ODRGNkY0M0UzQkI5MUJCMzlEMzExQjg3QkVGODU3QUI2REQzREFFNzEzODkwQTk2Q0ExODYwQTVGMzdCRTYpKSgoMHgxRTQwRkNERjlDRTk2MENDNTExMEVEMDBERjE0NzhGN0VDNDJENjQ1OUVFNUIxOUI2NjJGNjE3NjVDNzlERjUyIDB4MkVDRjIzQTRCRDhEODJGNTFDM0MxMDZBQjE4MEMwMThEOEQxOUNDOUVFQUE2MzkxQTRFNkZFM0E2MjcxQTBFQikoMHgyQzEyQjVDQjEyQzkxRUI1MjYyNTY4MUExNzg2MjVFM0Q1NjNGODEyQTQ4QjYxQjgwQkM4OTRBRUZEQjUwQkRCIDB4MTAzQzYxQzNGNjVEQzI0RjlDMjkzMzY4NzFEREUyNDJERDdFNDI1QkNCMEZEN0M3QURBQ0QwQkEzQzY1RDQwNCkpKCgweDM4OUFFMzAyMTJDMzM5RjJGNjZCRkVDRDNFQTQyNTk1RDMwNkFEQjE1MUZDNUI3QjZDMzhDNDYxMjBDMEU0QzUgMHgwMTNFQUQ2RDUxOUZBN0UwQUE4NDlFMTUyQTMwNTBDMzM5NjIyNjU4NUYyQzVCQjJDOUU0QUY1MUY2MEQzMEU1KSgweDA0NjE2MjM4RjI4MjNERDQ0NEMwQzZBMjY1Mjg1MjQxOEIwMTE5MTc4REYxNkIwQkEwOEZGRjNEOEQwMUE2QzYgMHgwQjY4MUU0NThGNkJGNTMzRTQ5RjQ3NjExNDRCQjFBNTczNkQ2NjZFQjQ4NDY5QTBBQzdGNDE1RkFFNzNGNUM3KSkpKSh6XzEgMHgwQzlBMzEwN0JDRjNGRDJBQTY1MzQyNTA3NTEyNkFDODlCRTkxN0ZFMDNGMjEzMzAwRTdDOTQ0RUFBOTFDNTAyKSh6XzIgMHgzRkM5Qjc4MTRERTNBOTNEMkFFQ0VCNDFCNDcyNjJCNkRCQ0I4OEFDMzRBMUIyRUVCMDk1N0REMkQxMjA5OTgwKShkZWx0YSgweDBFMzU2MDk3REQ0NDgzN0YwOTZCRTUzNkRCMkMwODlEODgyQzg5M0RBOUNDNDlGMUE1QzlBQTg5OUE1QUUwMjEgMHgyMzUzRkNGNUIzRDU5QTY4NzQxQURCQ0ExMzgyMjFDODM0MTM0OEU3MUYzRUVDM0Y3ODk4OUJCNzkwQzcwQUQ4KSkoY2hhbGxlbmdlX3BvbHlub21pYWxfY29tbWl0bWVudCgweDE3RTBFMDBFNjRBQTk1M0E2NTdCNTExM0FBOEFFOTg1MkY4NkVCN0JCMDE5RENGN0U1M0VFOTk5ODkxOEY1NEMgMHgwNTdDOEQ5RUI2RjM2MTJFRjU3OTQ3N0VCRkMwMDdGM0IwNkMxOUQzQkZGMkEyMDczNDFBMkRDRUQ3MzhDRDU3KSkpKSkpKQ=="
                      ],
                      "body": {
                        "increment_nonce": false,
                        "may_use_token": [
                          "No"
                        ],
                        "use_full_commitment": false,
                        "public_key": "B62qpYiNarxLiQRydW2bspXEQbXWoUfmHyexq1Lq5DgfDcHuu1UAF5P",
                        "call_data": "0x0000000000000000000000000000000000000000000000000000000000000000",
                        "preconditions": {
                          "valid_while": [
                            "Ignore"
                          ],
                          "account":["Accept"],
                          "network": {
                            "snarked_ledger_hash": [
                              "Ignore"
                            ],
                            "global_slot_since_genesis": [
                              "Ignore"
                            ],
                            "next_epoch_data": {
                              "seed": [
                                "Ignore"
                              ],
                              "ledger": {
                                "hash": [
                                  "Ignore"
                                ],
                                "total_currency": [
                                  "Ignore"
                                ]
                              },
                              "epoch_length": [
                                "Ignore"
                              ],
                              "lock_checkpoint": [
                                "Ignore"
                              ],
                              "start_checkpoint": [
                                "Ignore"
                              ]
                            },
                            "total_currency": [
                              "Ignore"
                            ],
                            "blockchain_length": [
                              "Ignore"
                            ],
                            "staking_epoch_data": {
                              "ledger": {
                                "total_currency": [
                                  "Ignore"
                                ],
                                "hash": [
                                  "Ignore"
                                ]
                              },
                              "seed": [
                                "Ignore"
                              ],
                              "lock_checkpoint": [
                                "Ignore"
                              ],
                              "epoch_length": [
                                "Ignore"
                              ],
                              "start_checkpoint": [
                                "Ignore"
                              ]
                            },
                            "min_window_density": [
                              "Ignore"
                            ]
                          }
                        },
                        "authorization_kind": [
                          "Proof",
                          "15316925453152997343340358011259256123163419923523856454720461417962839880117"
                        ],
                        "events": [],
                        "token_id": "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf",
                        "balance_change": {
                          "sgn": [
                            "Pos"
                          ],
                          "magnitude": "0"
                        },
                        "actions": [],
                        "implicit_account_creation_fee": true,
                        "update": {
                          "voting_for": [
                            "Keep"
                          ],
                          "delegate": [
                            "Keep"
                          ],
                          "app_state": [
                            [
                              "Set",
                              "0x0000000000000000000000000000000000000000000000000000000000000002"
                            ],
                            [
                              "Keep"
                            ],
                            [
                              "Keep"
                            ],
                            [
                              "Keep"
                            ],
                            [
                              "Keep"
                            ],
                            [
                              "Keep"
                            ],
                            [
                              "Keep"
                            ],
                            [
                              "Keep"
                            ]
                          ],
                          "zkapp_uri": [
                            "Keep"
                          ],
                          "timing": [
                            "Keep"
                          ],
                          "verification_key": [
                            "Keep"
                          ],
                          "token_symbol": [
                            "Keep"
                          ],
                          "permissions": [
                            "Keep"
                          ]
                        }
                      }
                    },
                    "account_update_digest": "0x1A81B18D90436C0A48EE28A8C2944A013829C1203FA877966FA17D79C693FCE5",
                    "calls": []
                  },
                  "stack_hash": "0x0EFF662EB75B6599D52F022DF13E0AC87D40F46138CE332D2F752F231C3CAAD5"
                }
              ],
              "memo": "E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH"
            }
          ]
        |json}
      in
      let gcloud_zkapp_txn =
        match Mina_base.User_command.of_yojson gcloud_txn_json with
        | Ok t ->
            t
        | Error s ->
            failwith s
      in
      printf "Hash of txn from node %s\n%!"
        (hash_command gcloud_zkapp_txn |> to_yojson |> Yojson.to_string) ;
      let ci_txn_json =
        Yojson.Safe.from_string
          {json|
        [
            "Zkapp_command",
              {"fee_payer":{"body":{"public_key":"B62qpYiNarxLiQRydW2bspXEQbXWoUfmHyexq1Lq5DgfDcHuu1UAF5P","fee":"0.02","valid_until":null,"nonce":"1"},"authorization":"7mXJzKj43kmiSquNH7HDKBGnHuD1A8PGySkU8BvCgvXccrzeeYGPVfdMiJrv3c2rdLaod2tX8faV96dXhMi461hfS1P6F9UA"},"account_updates":[{"elt":{"account_update":{"body":{"public_key":"B62qpYiNarxLiQRydW2bspXEQbXWoUfmHyexq1Lq5DgfDcHuu1UAF5P","token_id":"wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf","update":{"app_state":[["Keep"],["Keep"],["Keep"],["Keep"],["Keep"],["Keep"],["Keep"],["Keep"]],"delegate":["Keep"],"verification_key":["Set",{"data":"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","hash":"0x21DD1295012AB95CA4A7145437A08EFD58FE7E8FBD7CB29CC2920A03F10E31B5"}],"permissions":["Set",{"edit_state":["Proof"],"access":["None"],"send":["Signature"],"receive":["Proof"],"set_delegate":["Proof"],"set_permissions":["Signature"],"set_verification_key":["Signature"],"set_zkapp_uri":["Proof"],"edit_action_state":["Proof"],"set_token_symbol":["Proof"],"increment_nonce":["Signature"],"set_voting_for":["Proof"],"set_timing":["Signature"]}],"zkapp_uri":["Keep"],"token_symbol":["Keep"],"timing":["Keep"],"voting_for":["Keep"]},"balance_change":{"magnitude":"0","sgn":["Pos"]},"increment_nonce":false,"events":[],"actions":[],"call_data":"0x0000000000000000000000000000000000000000000000000000000000000000","preconditions":{"network":{"snarked_ledger_hash":["Ignore"],"blockchain_length":["Ignore"],"min_window_density":["Ignore"],"total_currency":["Ignore"],"global_slot_since_genesis":["Ignore"],"staking_epoch_data":{"ledger":{"hash":["Ignore"],"total_currency":["Ignore"]},"seed":["Ignore"],"start_checkpoint":["Ignore"],"lock_checkpoint":["Ignore"],"epoch_length":["Ignore"]},"next_epoch_data":{"ledger":{"hash":["Ignore"],"total_currency":["Ignore"]},"seed":["Ignore"],"start_checkpoint":["Ignore"],"lock_checkpoint":["Ignore"],"epoch_length":["Ignore"]}},"account":["Accept"],"valid_while":["Ignore"]},"use_full_commitment":true,"implicit_account_creation_fee":true,"may_use_token":["No"],"authorization_kind":["Signature"]},"authorization":["Signature","7mXJzKj43kmiSquNH7HDKBGnHuD1A8PGySkU8BvCgvXccrzeeYGPVfdMiJrv3c2rdLaod2tX8faV96dXhMi461hfS1P6F9UA"]},"account_update_digest":"0x33ADF6751F5F851B76D1FCF9CF55259801B8AD353215B783E0519B17DAF7CCBC","calls":[]},"stack_hash":"0x2E09974624315111F4B243E6DF459AC57A5184A72FEC52F01F837710FA4714FD"},{"elt":{"account_update":{"body":{"public_key":"B62qpYiNarxLiQRydW2bspXEQbXWoUfmHyexq1Lq5DgfDcHuu1UAF5P","token_id":"wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf","update":{"app_state":[["Set","0x0000000000000000000000000000000000000000000000000000000000000002"],["Keep"],["Keep"],["Keep"],["Keep"],["Keep"],["Keep"],["Keep"]],"delegate":["Keep"],"verification_key":["Keep"],"permissions":["Keep"],"zkapp_uri":["Keep"],"token_symbol":["Keep"],"timing":["Keep"],"voting_for":["Keep"]},"balance_change":{"magnitude":"0","sgn":["Pos"]},"increment_nonce":false,"events":[],"actions":[],"call_data":"0x0000000000000000000000000000000000000000000000000000000000000000","preconditions":{"network":{"snarked_ledger_hash":["Ignore"],"blockchain_length":["Ignore"],"min_window_density":["Ignore"],"total_currency":["Ignore"],"global_slot_since_genesis":["Ignore"],"staking_epoch_data":{"ledger":{"hash":["Ignore"],"total_currency":["Ignore"]},"seed":["Ignore"],"start_checkpoint":["Ignore"],"lock_checkpoint":["Ignore"],"epoch_length":["Ignore"]},"next_epoch_data":{"ledger":{"hash":["Ignore"],"total_currency":["Ignore"]},"seed":["Ignore"],"start_checkpoint":["Ignore"],"lock_checkpoint":["Ignore"],"epoch_length":["Ignore"]}},"account":["Full",{"balance":["Ignore"],"nonce":["Ignore"],"receipt_chain_hash":["Ignore"],"delegate":["Ignore"],"state":[["Ignore"],["Ignore"],["Ignore"],["Ignore"],["Ignore"],["Ignore"],["Ignore"],["Ignore"]],"action_state":["Ignore"],"proved_state":["Ignore"],"is_new":["Ignore"]}],"valid_while":["Ignore"]},"use_full_commitment":false,"implicit_account_creation_fee":true,"may_use_token":["No"],"authorization_kind":["Proof","15316925453152997343340358011259256123163419923523856454720461417962839880117"]},"authorization":["Proof","KChzdGF0ZW1lbnQoKHByb29mX3N0YXRlKChkZWZlcnJlZF92YWx1ZXMoKHBsb25rKChhbHBoYSgoaW5uZXIoNTkzYmIxM2Y2YjFiMWExYSBlZDA3OTAzYjRjY2JiMjdmKSkpKShiZXRhKDRiMjYzZmI0OTRmNmE1YjIgYWM2NmE5OWIzYTc2YzBlNykpKGdhbW1hKDI4MGI0MDU3NmRjMDE2YTAgY2YzNGY2MGRjMjdkNTJmOSkpKHpldGEoKGlubmVyKDExOWFkYjc3OWRmYzE2ZjYgYjEzYjQ0NjdlYTgyMDAxMSkpKSkoam9pbnRfY29tYmluZXIoKSkoZmVhdHVyZV9mbGFncygocmFuZ2VfY2hlY2swIGZhbHNlKShyYW5nZV9jaGVjazEgZmFsc2UpKGZvcmVpZ25fZmllbGRfYWRkIGZhbHNlKShmb3JlaWduX2ZpZWxkX211bCBmYWxzZSkoeG9yIGZhbHNlKShyb3QgZmFsc2UpKGxvb2t1cCBmYWxzZSkocnVudGltZV90YWJsZXMgZmFsc2UpKSkpKShidWxsZXRwcm9vZl9jaGFsbGVuZ2VzKCgocHJlY2hhbGxlbmdlKChpbm5lcihhMzZhYWQ5YTZlMjlmMWFjIDViZWQzMmRhM2YzY2VhMzkpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcihmNTdiYTAwYTY3YmM3ZTAwIGQ5MjQ0YzAyMDViZWNhYTgpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcig5MmY1ZTMxNDYzOTE5MDIxIGZlNDZhMWUxZTFmZWZiMDIpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcig2ODk4ZWNmMTY0ZjMwYjc5IDg2MzA2ZGEwODRiNzM5NmQpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcihkMWY5YTZkNzFmMDgxMWE2IDk5NzdlMTQ3MjdiYWRlMzQpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcihlYmJjZmM2M2NhZGI1NzNiIGJmNmUxMzQxMmQ0OTllODEpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcig0MTYzMTRiNmU1ZWIwNGVhIGRlMmMxMTI0OWJjZjllOTQpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcig1YWY3OWE2ZTkyNDk3OTFjIDRmZmNjNzBkZmUzNzNhOTYpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcihhMzI2YzZkN2NhODBlNGM4IDQ4NTU2OTIzNTVmYzAyYzIpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcig0YzJlMTY5ZTQzNjE0MzBmIDRjZWY2Njc4YjdkZjdhZjQpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcigzY2RhMWYxMDk2YzcwOTE4IGU1MzFhODVlOTY2YzAwM2YpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcihkZTRlOTkwNjA3NTA4ZDhkIDZjZGZjZjllMTk2MjI4YTYpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcig3ZTJmY2I1Nzg2MDlkYzZhIDg1NWUwMDNlNmY0MTZjNTUpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcigxYjU3NTZiMmNlYmQyOGU2IDFhNTUyMjc1NjUyZmI0ZDIpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcigzOTU2OGE1NWFmYTdjYWMzIDY4Y2IwOTZjYjFiNjcxMmMpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcigxMDRkZjBkNzM5NzA1NjZlIGI0N2Y2NjQ1MWQ2ODQ0NjUpKSkpKSkpKGJyYW5jaF9kYXRhKChwcm9vZnNfdmVyaWZpZWQgTjApKGRvbWFpbl9sb2cyIlxuIikpKSkpKHNwb25nZV9kaWdlc3RfYmVmb3JlX2V2YWx1YXRpb25zKDgwZTMxODY4ZDFhM2M0ZTYgMzE3MTIzM2EyZjRlOGU5NSA0N2RhYzQzYTY5ZDc1ZTYyIDE3YjA5M2Y0MGM5N2U1YzYpKShtZXNzYWdlc19mb3JfbmV4dF93cmFwX3Byb29mKChjaGFsbGVuZ2VfcG9seW5vbWlhbF9jb21taXRtZW50KDB4MkJGQTVERDFBNjk5MzhEQjY0N0NBQjhFNjdCNzNGQTM2QTk5NDNFNDY0QkNDQzgyMDJERkUyQzlBRTQ2OERGRSAweDIxM0M0NjZBQ0M5MjEyOEUxQjk3RTE1QUFBRjRFMDlEQTdCRTg1REJDRjY0NjA3RTAwMkVGRjlENDBFMzE5NDcpKShvbGRfYnVsbGV0cHJvb2ZfY2hhbGxlbmdlcygoKChwcmVjaGFsbGVuZ2UoKGlubmVyKDMzODJiM2M5YWNlNmJmNmYgNzk5NzQzNThmOTc2MTg2MykpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKGRkM2EyYjA2ZTk4ODg3OTcgZGQ3YWU2NDAyOTQ0YTFjNykpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKGM2ZThlNTMwZjQ5YzlmY2IgMDdkZGJiNjVjZGEwOWNkZCkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDUzMmM1OWEyODc2OTFhMTMgYTkyMWJjYjAyYTY1NmY3YikpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKGUyOWM3N2IxOGYxMDA3OGIgZjg1YzVmMDBkZjZiMGNlZSkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDFkYmRhNzJkMDdiMDljODcgNGQxYjk3ZTJlOTVmMjZhMCkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDljNzU3NDdjNTY4MDVmMTEgYTFmZTYzNjlmYWNlZjFlOCkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDVjMmI4YWRmZGJlOTYwNGQgNWE4YzcxOGNmMjEwZjc5YikpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDIyYzBiMzVjNTFlMDZiNDggYTY4ODhiNzM0MGE5NmRlZCkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDkwMDdkN2I1NWU3NjY0NmUgYzFjNjhiMzlkYjRlOGUxMikpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDQ0NDVlMzVlMzczZjJiYzkgOWQ0MGM3MTVmYzhjY2RlNSkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDQyOTg4Mjg0NGJiY2FhNGUgOTdhOTI3ZDdkMGFmYjdiYykpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDk5Y2EzZDViZmZmZDZlNzcgZWZlNjZhNTUxNTVjNDI5NCkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDRiN2RiMjcxMjE5Nzk5NTQgOTUxZmEyZTA2MTkzYzg0MCkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDJjZDFjY2JlYjIwNzQ3YjMgNWJkMWRlM2NmMjY0MDIxZCkpKSkpKSgoKHByZWNoYWxsZW5nZSgoaW5uZXIoMzM4MmIzYzlhY2U2YmY2ZiA3OTk3NDM1OGY5NzYxODYzKSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoZGQzYTJiMDZlOTg4ODc5NyBkZDdhZTY0MDI5NDRhMWM3KSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoYzZlOGU1MzBmNDljOWZjYiAwN2RkYmI2NWNkYTA5Y2RkKSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoNTMyYzU5YTI4NzY5MWExMyBhOTIxYmNiMDJhNjU2ZjdiKSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoZTI5Yzc3YjE4ZjEwMDc4YiBmODVjNWYwMGRmNmIwY2VlKSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoMWRiZGE3MmQwN2IwOWM4NyA0ZDFiOTdlMmU5NWYyNmEwKSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoOWM3NTc0N2M1NjgwNWYxMSBhMWZlNjM2OWZhY2VmMWU4KSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoNWMyYjhhZGZkYmU5NjA0ZCA1YThjNzE4Y2YyMTBmNzliKSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoMjJjMGIzNWM1MWUwNmI0OCBhNjg4OGI3MzQwYTk2ZGVkKSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoOTAwN2Q3YjU1ZTc2NjQ2ZSBjMWM2OGIzOWRiNGU4ZTEyKSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoNDQ0NWUzNWUzNzNmMmJjOSA5ZDQwYzcxNWZjOGNjZGU1KSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoNDI5ODgyODQ0YmJjYWE0ZSA5N2E5MjdkN2QwYWZiN2JjKSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoOTljYTNkNWJmZmZkNmU3NyBlZmU2NmE1NTE1NWM0Mjk0KSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoNGI3ZGIyNzEyMTk3OTk1NCA5NTFmYTJlMDYxOTNjODQwKSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoMmNkMWNjYmViMjA3NDdiMyA1YmQxZGUzY2YyNjQwMjFkKSkpKSkpKSkpKSkpKG1lc3NhZ2VzX2Zvcl9uZXh0X3N0ZXBfcHJvb2YoKGFwcF9zdGF0ZSgpKShjaGFsbGVuZ2VfcG9seW5vbWlhbF9jb21taXRtZW50cygpKShvbGRfYnVsbGV0cHJvb2ZfY2hhbGxlbmdlcygpKSkpKSkocHJldl9ldmFscygoZXZhbHMoKHB1YmxpY19pbnB1dCgweDE1RTI3QzYzN0JGMTZCQkM5OEE0OUZBRDc0MDRGRkI5MjBFNTdCRTI2RTY4RUE5MzdCMTJEQTg5M0VGQTk0NjYgMHgxOTM4RDM2OThEQzdCNjJDMzNBQTNFRjY0Q0EyMTU0NTc4Q0NCMjNBMEEwODU3OTI4RjJBNUEzOTFGM0U2MDhCKSkoZXZhbHMoKHcoKCgweDFDOTQwNUIyQkQ5M0Q3NURGMzY5OTRDNzdENzNFRUI5RDdBOTM4ODVDQTYyQ0NDRTM4OEY0MzM1QUU3ODcwOTMpKDB4MTZFRjY3MUZERTQ3N0IzQjY2QjM0Q0IxMTNGOTMzNUM2NjcxMUI5ODRBMTM0OTQ5NUNGQzA4NUNGNTAzNTBFOCkpKCgweDBDQjY1NUEwMDY4NTM2OEZBRTNDRTZBRjE1RTc2QjEzQ0M5QTAxNjY5RTNGQjgxREYzQTg2Qzc4QjczM0QwQzMpKDB4M0M1RDAzMzIyMDEzREIwMzVCM0E2MTRBOTMyODUyMUMxNDYwNEUxMDJCM0QzRkY5NTJGOTZGQTNBOEY4NEEzMCkpKCgweDM1ODU1NEYyOUI4OTUxN0U4MTU4NUE5QTExQjk3N0NEQkZGNDI2OTAyN0MxRTRGRjAwODMxNkRFNEVDNEZEMTQpKDB4MUY0NTFGNkRCNDIzMTM0MUYxQjBFNjBDMzM3NURDNjIxOTJERjdCMjQxQjk5ODkwNUFBRUNGNTQwQzYzQUREMikpKCgweDBENDFBQzZCOTI2QzM5RkExQzIyODFBMzgyMUZFREJERDczOTI4RkZDMkNFODI0NkI1NkJBMjJENTBBNDgxNEQpKDB4MDUwNDg3QTAxQ0QwMTMzOTlFMTQxQ0JDMUVDRDU5MTg3NzQ0MzI0MjBFMTAwODU2N0VGOEM4NDIzNEE5NDlBMSkpKCgweDA5NjE3RTIwNDNDMjZGQTBDNjdCNUMyOUIyMzc5QTlEQTI3MzlFMDczN0ZBMERBMEQxOTQzMTE2M0IwMjMwRDUpKDB4MzM4QjA2QUUzRTMxOTYxMjI2NDJBRTM4NDE2MDU4NzRENjU0RkY4QUE2OUUwNDA5REQyMTYwRTg0RTdGNDI5OCkpKCgweDMyMkUzMUYwODI1QkVGQjgyMUNEMTdCQkUyQzIxNjJDQjhCNkZGQjczNUJENEYzQTc1RDc0NUYzNDkxQ0Y3Q0IpKDB4M0ExNEIzQTYzNzA0RUMyNkIxNTNEQ0UxMjQ3ODE2OTIwQjhFMjk5MUYzRjRFMTIxMkRBQUZEOTA4Nzk4MEJEMCkpKCgweDE1NTZDQzhCMUZBMDI3MDhBMDE2REVENzM2NTM5M0RCQzE3NkJDQUU1Q0I0OUM2RkJFN0RERUI0RDY0MEY0QzYpKDB4MzAzREVGNTVCOTQxRjAyMjQ4REI3NUQ3RDAwRTgzMTMwOTA3RUVCM0ZBNzlFMEUzMDI1QTNGRDdGRkQ3QTlDOSkpKCgweDIwRDA5N0VDRjkzRjg0MUVCMEIyN0JEOEU0ODMxMzczRTg5RjU0MjlFRUExNzQxN0E5Qjc3ODFCQTk4NTA0QUUpKDB4MzU1NURDOEFDNzJFOTI2MjBFRjE4RjYzNkE4N0FFNERDNzk0N0MxQjhGQkVDNUE4QTA1RURCNzlFMzkwRTA3RCkpKCgweDAxODY2NkNGQzgyOTU1MjM3NDAwRTFEQjBBMTk0ODE5MUUwQ0U4NTk2MDEyNzU5QUE4RjIwOTBEMkI2MkQ2NzgpKDB4MzA4MzE1RkUzRUQwMUFCMTY5NTAwMjg3NjdEOTBBOEM4MjM3RDZBNTJCNDU2OUI1QUFDODlGQzlFM0IwOUE4RCkpKCgweDI0MkQxOTRFNzkyQkNDQzcyQjUzOTE0NjIzM0YwOTRDMjM4NTNBQ0NEMEMyQkU1MjdEMDg0NDU4M0FFNTdEMzApKDB4MUIyMEIzRTExODc4RjI4OEYwRjQ4MkJGMDVFRTMwQ0E0REIwODEwNjcwMTg2QzQ1RTRBMDA1Rjc4NUM3NzgxRCkpKCgweDIzRUEyMTVBQUQ4OERERjQ4NTI4RTI4NjZFQ0UxQTYwM0M1M0I4RkFBNzU1NEI3MjE3MTlBQzdDOEYzQkE1NDkpKDB4M0NCRjk5QzZEOERBQkMxRTFGQTlGODlFNTA3QUY5QkQ1Q0EzQ0VDODMwRkU2MzFCRjg4NTE4RjUyMzVGRDhEMSkpKCgweDBBOTg1OTFBOThGQkExNTRDQ0Q0NkREODFGQ0M0NzVDRjk2NjIxOEI5MTM4MDU2N0I0OUMxNTQ1QzYxRTQwMzIpKDB4MjdCNDNENUE3NzMxQkY3MzE3QkMxMERBODVFNURGNDJGNTJCOUQ5OUJFMEEyNzk1OTQ3RkZGMUZDMEQwNzE3OSkpKCgweDJGMjhDNDMyQ0FFM0FCOTY0MkE3NzdDQkJCRDkxNjg3MTg3MDVCNERGODQ5MDEzMjZCQ0M2QTY0MjE2RjlBQzApKDB4MDMzMUY2RkJENTA5Q0I5QkZENjk2NTU5NUVERDc3RTE5MUFCQkYxMzkyNzc5NUYyMzY2NTAwMDkwOUE3NThBOSkpKCgweDAyN0I3NzIxNkU0MzYyRjhGMTRERTQzNTI2MjQxNEI2QUNGODlGRjA3OEI3NjExQTRGOUQ1MTdEMjAyMzQwQTIpKDB4M0REQzgwMTRENTQ2REVFMzY1MkREMjgwMUU5NEVERjk5QjhBNkE5OUFEQkJDN0I0NDU1MzMxREZCRDE4M0UwRCkpKCgweDAyODBDRUEwOUZDMTI5RDVBN0VBN0NGNTIzRkYyQTNCNTE4NkQ4NEY2ODdDQjBCQjUyODJCRTAxQjg5RTAxQUQpKDB4MDhEQjQzMjg3MjAyNzJBNkEzOUU2RUYxNzgyQTA1MzlEQ0Q5Q0FDNjE3NzNBRjkwQzg2OThFRkY1RDBBM0VCRSkpKSkoY29lZmZpY2llbnRzKCgoMHgwNUY0RjcyNjNEQ0RFMENGQjdFOEZDQTFGOUVCMzIwRThCODBCNDA3MUZBMDE3RDA3NDdENUNGQjUyQ0JGMTEzKSgweDJFQjNDRUM0RDRENzU0QUZDREEwQzI0MTc2MDU3QzMzNjU3MTAwMTc2MDIwQkNBODhBQzZDM0M5QkQyQkM5RDUpKSgoMHgxNTg5NkNGM0UyOEJDRkM0QUMwNEVCNEEwMzc3RTZBOERERDZBODVFMzA2ODhCNEQ5NkRGMTRCQ0JDMkQ0NTkwKSgweDA4MkRCQUU5OTI0MzFDRjlGOUZDQkMwRTdFOUI3NDBGQzk0MDdEQjIyMEQ2NkI2N0YyM0M0NkFBQzJDNjVERTIpKSgoMHgwRjI0MDY0MTQ4REMzQ0Y2MkM5RTk5RUIwOTc0QTMwNTUyN0EzNDM0OTAwMkE1MUU2NkFERTU1NUYyQTE0QkQzKSgweDNDMTcyRUY2MTIxRDk5OEQwMjM1OTA2ODAxNDEyNzE2MDRFMUMzRDBFQzRGQTc0RTBCQTczQzI1Qzk4M0Y3QzYpKSgoMHgxNDFFOTRFMkIxMzY0MDA5MTYzMjY3MjNGQ0FCNDhGMkM4RUY3Nzc1NERBQ0ZEODczNDYyNDYxMjkyNjJCMEE3KSgweDI4MjMyNTE4MDRCMDMzQzlGRDc2QTY4OEU4QkVCOEFCM0EyMDYwQUFFOEVBQ0QwOTY1NEFGQTlGN0M5RTc2RjUpKSgoMHgzQ0NEQTA4RDE1NTA3RkFGQjU0MkYzN0M1QzlEQUY4NzM2MkNEOEM1RDZBODc4NzQ0QjZFMUYyNTk2RUFFMTkyKSgweDIwQUFCQjA5N0ExNUI0NzcwMjhCMEMyREREREVBNTZFNUMzQTZBMzIyRDMyQ0ZDNENCN0I5OThBODlEODJDNTUpKSgoMHgxQjk5M0UxODExMjNERkE5Q0JBOUJERkI2RTRGOTg0Q0M1M0RFMTMyMkQxMTg0N0YxNzM0NUMwQTI5Njg1QkZBKSgweDFCNkE0NUMyRkNBQkEwRUMxRkNBNDc3MzA1NDIzQjYzQzhBRUZGM0VFNzcyMjA2QUE3N0M2NkMxQzNCMEI5MzEpKSgoMHgyRTM4OUM3M0MzNTY5Qjc2ODhBQzdBODI3NkY4NEI0Q0UzQUE0MkJFNTMxNzA4OUE4OUZCNjE2QTRDMkMzRjg2KSgweDM5OTE2NzY1MTFGMjlGRTE0NTdFM0JEQUZGMTU0NzdGMTA0MjVDNzdEMzZDOTNBNjRBQzYyRDVGRUJERDFBNEUpKSgoMHgxMEM2NTQ0NzY2RUY5QjBCRTc5NEExMjQ5MTYwRDFDMjRENzUyMkZGQUY4QTNEMTk0NTkzQzk1NzQ2Mzc0MEY1KSgweDBGREM3MzYzQ0VDMEQzQTlFODg0RTNEMzA5OUQ2OUU2ODIwREM4NjFBQTlCNzNGNTRGMEJBNEY3MUI2QTI0RDgpKSgoMHgyQjQ2OUFERTI1NEE3MkM4MEM1NDYyNjQ1MjQyM0IwNDM5NDZDNTQ4QTc0RTQ0RjAxMkE2MTlDMTAwQjhBNUE1KSgweDFCQjQ1OTg0NjBGMDY1RTkwQ0VCMzk5RDJFQzFDNTlBRDQyRTA2MEUzNjZENUFFQzJGOEMyREM1M0RCNTI4M0MpKSgoMHgzRDg5OTFEMUQxREQ4Q0NEMTJGMzk1OUNBQURERUJDMzU2MkQ5NEU3MEExRTU4MTA2N0VGNzJGRDAzMzZBQTFDKSgweDJBNDNENjUzRkNERjdDQTNFNTU1QUY1QTY4NEVFMUMwMzdEQURGREEwOTg2MTJFQTMzNjQzRDI0ODIwQzE1QzUpKSgoMHgxM0YxNzU2RTY2NzVFMkM0QTZFN0RDQjg4NzBDQzdCNTE1MzY0RjJBQTZENzlFRTRFM0RGRTY2NzVDRDNBQzhCKSgweDAxQTM5RUI1REVEMTRENTZGNUVFRjdGQ0FENDZDRjQxN0M4NTg4REEyNkQxQTg5MjAzMkQ0MzE3MDJBQzM3RkEpKSgoMHgxN0U3NjlBNzY0QTJCQzhGODg4NjgxRjdDQTE0MzZGMTQ4OEVBMUIzMzcyNkQ5OEI0NzM5RDBFOTgyRTA4ODVFKSgweDJFOEZERjNDNjk1OUQxMDhERUVEQkFENEVDQUEwMkUxREYxRDEwMzY2NzM3OTZENDNERjkzMTAyNDE3NjcyQTkpKSgoMHgyQkUwQ0ZCQkVBNkRGMzEyOEFERjdBMURGMzg2ODIxNjFENTdEMUYxOTg3Q0VCNjEzNkI3ODdGMjY5QUY1QTc5KSgweDAzMDI0Q0YwNDJFQTI5OENBQzc1QkIyMTlENzc5RjIwNkVEQ0M1OUI1MTIxNzAwOThCOThDRTZDQTZFRUNCQ0QpKSgoMHgwRjIxREI5MDQ0RjgzMTkyQkQwMDI0ODk1MDhBQjI0Qzc3MjU5RjRCMEYxM0M5MjVDMTYwNDYwREY5RDNEOTNFKSgweDA4QkJCMzM3RDNFRjE5RUI5M0M2OEU5ODNFNDc1RTQ5OTI4QjRFQTNFNkVFMDZDM0Y0MjY1NTNEMUQyNDM4OUIpKSgoMHgyQkE5QzNEMjAyNzQ3Nzg4RDJFNjkxRjJDMzJEN0IwQjY1MUQ1Q0FGMjZEOTBGQUZBNzRCRUYzNzE4RTIxNUNGKSgweDBBQUY3MzY1OUEwNDJFNzM0MzE3NDEyNDA2RjRFRDZCNzhBMzQzQzBFMTEwREZDRjlBRUM5NjM0NDc3N0Q0MEUpKSkpKHooKDB4MEIxRDMyRjk5Qjg5OTEwMUM0RDhGNjI0RjcxMzQ1MEU2NUU0MjU1MzkwRUVBQjBBODBGNDNDMzk5N0Y2NEQ5QikoMHgwOTNGNzM1NENBRTBFREY1NDZDMzFGNzM3MDRFNTdCNDRFN0EwRUY1NTg0REQ0MjYwMUJBRUMxMEYzRTVGMTQ3KSkpKHMoKCgweDNEMjQ5RTlGNDdEQTk2MzcxQjVGQzJDRUUzRjQyQkM3QkExOTI1MTgyQTAwQTlBOUIyQzJDNzU3MzgzNjk0RDQpKDB4Mjg4NkY1Q0FBNjQ3Q0M2RjdFQ0ZCRjc4ODdDQUVEMEJERTc0NkI5QjVGMkJGQkRCREM2QjU1N0Q1MjM1NjA2NCkpKCgweDE2MjUwQ0NCNkYxODRDMzIyRTQ5NEYzNjhGQUUwNUFDRkNEQzlENkJFRkQ1QUI1N0RCREQ3ODRGMkYwQjMyNTEpKDB4MjU4RTRGRDAwNjZBM0NEODJDQ0ZBRjYwMTUyQjhBQTA3RTFDODVFMEY1NkE2MDc3NkEyRTA5NDVCODU0MEVBMikpKCgweDEzNTVFMDJFRDZBOTkwOEM4NkRFODg3MEQ4NEUzRDE5Q0U0OThCMzY2QkNENzNEMThGOEYyREU3QTM2MzIzRTkpKDB4MjI0Nzk5MDIxMjc2OTQyQTEzOTgzQzYxNDM0MzUzRThCOThBMUFGMERGQTg3ODRBMjc5QzhDQzFFNjMwRkM3QikpKCgweDA2N0Y3MjVFQkQwQzFERjc5QURERUUyMTk1NjEyQTk2M0VBQTE5RkM3RTEzRDFFQTYxOEYzMEUwRUE3NkNFNkEpKDB4MUVFQkE2NjlBMDA1NEM5RkUzOTEzN0RFNjUwRDgyQTRFNUQwQTNDRDFDQzY5OTAwN0Q0REQ4MEI1OTdGRjFERikpKCgweDE3NjU4NEY2RjI1MTZEQzNDMUVENzQ5MTZCNkE0REJDMDFBMjc3NTc1NDVBQUExOTBBQTkzRDhENEFGRTVDNDgpKDB4MUUzNTBCQ0I1NEUyNUU2QUQwQjBCRDVBOTcyRkJBQ0Q4QTVBOTM4MjlEQTYyNzgzQjU1MDExREE1M0FGOTlGOSkpKCgweDE1NTFEN0NBM0E0RURDNTgyMjNCNDlFQjMxM0UyQjczQzEzRDg4NkQyOTIxQTg2MjUxMjBENEIxNkI4RjVENUEpKDB4MEU3RTYwOUQyNTE0ODVEQjExM0U2NkIwMUY3M0FENDdEOEFGQ0UzNjlFQjU1M0Y4MjBBNkMxMjA2NjVDQzYxNikpKSkoZ2VuZXJpY19zZWxlY3RvcigoMHgyNzk5NDRBQzU2QUJGODk1RDI4OTBFMEIxREY2RjM0MzhDOTRGMEQxQTg5RjlGRTJENjgzMjI3NjhFQ0MzMTEwKSgweDBENjBFNUM4MzYzM0Q1OEE3MEZCQTE3M0EyRjMzMzY5NDg1NEVBQjUyMTI4QTBENDY0NkQyMDg5REU5ODU4RkUpKSkocG9zZWlkb25fc2VsZWN0b3IoKDB4MEMyRDY1NUNCNzQxOTMxNkE4NDdFQjk5MEI2ODlDRjdBNUU2ODI5M0VBMjQwMzQ2QjBEODFCRDVEMEE2NzA5QikoMHgzNDg3REYyMUYxMUU2Qzc5NjdDNTZGMzBCRUYwNkMwNTY3NDlGQjdENEI4RDhCQzA3RTJDNTZCRjQzODZGRkE5KSkpKGNvbXBsZXRlX2FkZF9zZWxlY3RvcigoMHgzQ0RERjMxODBFMTcxRUQxQjVDRDdDNzk1NzVERTUyOTJDRkMzOUVEMzdBOURBMEFCMzc0ODVCM0ZGRjk5RDE2KSgweDM2MjE1NkVFQkY5N0QwNjZFMUNEQTcxNkE0QUIxQTM2MTJERjhCRTQ5MTZGMUYyNUQxQ0EzODc3QjNFN0ZBN0QpKSkobXVsX3NlbGVjdG9yKCgweDFGQzdENjlERjM4Qzk1QjY2NDBBNjgwMzJFNjk5ODUzQ0MxOUI4MUEzMUY4NTRBRTdDMzM5NjAyN0Y0OEQyMUIpKDB4MEZENTc3QzRGQTRBREY1M0M0NjU3RjIxMkY3NTNGM0RBRkY2RUE3QTg5MjE0MEZGRTAxQTVBQTYyRUNGMzAyNCkpKShlbXVsX3NlbGVjdG9yKCgweDAzMTZGQUMxRUNCNjQ3OEZDMDRDRjExNDM1RkM2OTdDREJCMjAwNUFGMkIyQThFNEMwNTE2QjNDOTUxOTcyOEIpKDB4MTJFODQxOUZFOTM5RTEwODQ5MEVERURENUFFMzZDQUMyNjY2NEIwMzQxNjk2OEYzNzgxMUE3RjgyMjRGNUE4QikpKShlbmRvbXVsX3NjYWxhcl9zZWxlY3RvcigoMHgzQUU4ODZDMzQ4RkZBQTE3REZERTBGQzBFQUE2M0ZBMkE1QjhEMkM1ODFFQTdBNEUxQkExRjIxOUQ2NEJBQjQ5KSgweDBCMEI1QzhENEY0QkYzQTU5Nzk4RkE4MjQyNjQ0REU0MURERjM3OENDODU0RkZGMEJDQjMzQTA1M0RENjI4M0EpKSkocmFuZ2VfY2hlY2swX3NlbGVjdG9yKCkpKHJhbmdlX2NoZWNrMV9zZWxlY3RvcigpKShmb3JlaWduX2ZpZWxkX2FkZF9zZWxlY3RvcigpKShmb3JlaWduX2ZpZWxkX211bF9zZWxlY3RvcigpKSh4b3Jfc2VsZWN0b3IoKSkocm90X3NlbGVjdG9yKCkpKGxvb2t1cF9hZ2dyZWdhdGlvbigpKShsb29rdXBfdGFibGUoKSkobG9va3VwX3NvcnRlZCgoKSgpKCkoKSgpKSkocnVudGltZV9sb29rdXBfdGFibGUoKSkocnVudGltZV9sb29rdXBfdGFibGVfc2VsZWN0b3IoKSkoeG9yX2xvb2t1cF9zZWxlY3RvcigpKShsb29rdXBfZ2F0ZV9sb29rdXBfc2VsZWN0b3IoKSkocmFuZ2VfY2hlY2tfbG9va3VwX3NlbGVjdG9yKCkpKGZvcmVpZ25fZmllbGRfbXVsX2xvb2t1cF9zZWxlY3RvcigpKSkpKSkoZnRfZXZhbDEgMHgxMEQ1RjM3Qzc2NUIwQzcxMzAzMEEwNjFENzdGQ0I0N0U2RTFCOERCNEI5QUUwREY2MDE2MEEwQUEzRDBCMkE0KSkpKHByb29mKChjb21taXRtZW50cygod19jb21tKCgweDFDQUNDNDU0NzAwOTNEN0VBRkUyN0I4MkMzODlGNUQzOUY2NkUzQ0ExRUZCNDBENEU2NDk2MDQ5RjAwM0Q2MTEgMHgwMDk0QUM5REZGQ0NGODhFRkYxQ0ZDOTQ4OEYwMDg4N0I5ODZFRDFFNTE5QkUxQ0M1MzUyNDM3M0RFQjY0MDk3KSgweDM5NTVEOTQyODNDMDk4Q0RFMUMxNDhGNTY5QzJCOEUxQkE3RUUxRUM2NTU1QjM2REQyODRFRTNEOTM1MzkwQTcgMHgzNEMyM0NFRENGNUYwN0YyRkYyODM2OEEyNkIzQkIxMTBBRDdBRTI4RkUyMEZDMzg0QzM0OTVBMDBBMTA5RDRDKSgweDI1OUVFNjczMjg3Njc0RkM4QzU1MENBRjIxNzg0Q0I5OTA4MDc0QkJCNjYyOURCQzk1OTY1OEVDNzZDRUU3RjMgMHgxNTgzMUZGRkU3NDIyOEVCRUVGQzU2NUVDMENCQkUzRDQ1RDE4QjZFREUzOUREODM2QzNGQzFGRDU4RENBRkMxKSgweDAwNEFFRUU1NTZDREQ3MTMyNzdBREYxODc0MUE3RUFEQ0NFQzdFMjNBMTE0N0QwOTczNDc5NjAyMkU0MDEwNzAgMHgxQUFFNzdDQURCREZCMTg0OTY3NkY1MjkyODhBNjVDNEQ2RTA4REU1NDgzQUIwQzFDMEM5N0Q5NjBDM0JFRjczKSgweDBEMUU4RkFGOTA4Q0QzMTdGNDREREQ4RDVEOUZCRDY0MzYyOEUzQ0Q3NTQ1N0U5QjdBMDBEOTAxM0IzRjkxQjEgMHgzQjE1Q0Y0NUQxQUJCREZGRERFNTM1OUQ1NzZBMzFDMEQxRTg5NDQ2ODM5QTlEQTMxMEEwRjEzOEM1RUJEODkxKSgweDM3RjNDNjc2QjY4N0VDRTVEOTY3MkE4NjNEMzRBQjYyMDc1MzdDN0VENUJCMkY4OEYzMEQyMkY0RTVDMjA1QzMgMHgyNUE5NjM5RDUzQzQ0QTQ1NTczRTU5QUJCNDc0QkJGRjQzNTk1REUwNjVERTMyRDRBQkE0NkEyNkExMjlBRDgzKSgweDM1Qjc5RUUwNzQ0NkQ2Q0RDODk1OTMxNEEwREQ0ODUyQzRDRkQ1MTFDOUQyRDQ1QjI4QkMyMUI4ODE5QkVCNUYgMHgzMjEyMDkzOEQwMDczNTVGRTgwOTVBQzgyNzM0ODJDRTRBRTQxOTAwOTA1MUQzQzNGNzBCNTQzOUYyMkY2MzZDKSgweDJFMjJGMDdBODdGMDU2M0M5QTlCQjY1NzQ3MEY4MzY0NjZEQzFGRjk5RTcwQTlFQTU1NzdGN0MwMzAyNUU2MEIgMHgxOTQxMjY4NjEyREY3RjhDRDFCN0M4M0FBMTZBMUYwNTE5QjlEODJDQ0U5M0VGNjA5Mjc2N0M5RDBGM0I2OTgxKSgweDAzRDIzQjNBQTQ4RTBDRUFCMkIxMjZGNDJCOEMwRDg3MEJFNkYwOTU2OTZDM0NCNEI1MkM3NTkwMzRENUM2MjggMHgwOUJGMDM2NEVGRjI0RjU5NjE3MUY3QUY2RDdFQkZEMjg5N0VBRjQ3QjhBRjBCMkZEQjI0NTdCNTE4M0Q0Rjk5KSgweDI3RTRGNEIxNzM3RjE2OTkyRjU1QjY4QzRFMjNDRjMyQjQxNEUwQ0NENzFCNTFBQzQ4RTVGMzRCRTk5MUZGM0EgMHgxQTM2QTQ1Nzk2NTE3MDYwM0Y1Nzk4QjAxRjM1NkQ0M0M1MUYxNDM5Qzg2MTRGMDdGQ0RBQTlGRTlFMDVBREE1KSgweDI0MUNDNDVGNDRDNjgyQTNEREFEMUExMzhDMjdFQjY0RTYyQUNFQ0M0QzkxRTUxOUNEMjNBNzAyRDNBNTIzOUMgMHgwQ0JBMzc0REFEMzZGM0YxQTU2OUI0MzZBMjExMjAwODEwNzM1QTczNjA5ODU2N0YxQUM2MzM5RkVCNEMzODM2KSgweDNFNEFCQUM3QThDRDhFODQyODY0QUZEMkVCODJEODZBQTRGRkY1M0FDRjEzOEMyQkVFMUU0QTBGQkE4MDI2OUUgMHgxNEJERTQzMEQzOTFEQjgxN0VGNzc3MzNFQjdBNERCRTRCM0U2NEFFNjlBMTdBOTI3ODVFNEM0NzBEQkVGQUEwKSgweDJFODlGOTI4MTNCQUIyOEQ5NDk0OTI1Qjc4OTgwN0QxRTQyODM5NkUxMTU2QTBBNUNFMTJDNjRCNjE3MTkxNzIgMHgyQTIxRUY4MDQxQTRCM0E3RDA4RTBFMTAyNDZCRjVENzI0ODA1RkM0MDQxQUEwNTVDOEU1ODNCNDA2RUNEOEE4KSgweDMwNzIzRjA2NDE3QjRCMEQ5N0U4QjhBQzdEREMxNTI2RUM1QzdFRDI4RDQ2RkI1Njk0MEJCNkE4ODBDRTdBMTcgMHgxNUE5NjgyNEFBOTg3OUEwRTI1OTVEMjU4REEwNkJFMUIyNEZEOTQ0MTg1RkUzRUVBMDVCODZEMkExNjhCOEJFKSgweDM5M0I5ODIyQTdCQTQ0QTIwNDQ5OUFBMTQ1RUY0QkFCMEFFOEVENjc3MjdBQzFDODI1NjAxMzQ3MUI4RTFDMTcgMHgxNDQ2RkE0NEY5NzAyQzdBMTUwMjg2MjNDM0EzQjNBNkJDNzA5QzdGREQzNTdCODRBRjRBQTYwNDZERkM3QUE0KSkpKHpfY29tbSgweDAyMkYxNDY5RUU3MkFCRjAwRDg5RjA1MzA1MkIxMzY2NTE3RDdDNUZBNjgzNkM3RTA2QUY5RTkyQTAwMTk4Q0EgMHgyQUU3NjM2N0VGQ0U0Q0Q5Mjg0NzQ0MkMxNDY3MkVGQUIyNTFBMjk2NjU1ODg3ODU3QUFDRTJEMzZFOTUzNTc5KSkodF9jb21tKCgweDFDMTAzQUJGNjc5QUFFMzIzRTY3NTZDMUZBNDVFQjdGQzlDMEY0QkQ5MjcwMTBEM0E0OENCRUZCMDlGODRFODkgMHgxQzAzOEUyRkQwNjQ4RjcyMDdFNTcyMkJFMDMxQzczQzFGOEI3QUZCRkFCMjA3RkU2M0EwN0NEMUE4N0RFMjBGKSgweDBBRDQ1M0RDOTUyMjA3NDhEMkRGN0UyOThCNjBGOEYyNjE4MzRDQUY0RDZEQjBGMzQzNzY2MTBCNzczMjlCODggMHgyNjg2RTNENTM2MkNDNTQxMjI2OTFFM0EwODcyMUFDQTZEMkIzNDJCOThBRDNGOTRBOUY5MEE5OTcyQ0EwOTU5KSgweDM4N0MyNUNEQ0NCNjU3RDMzREQ4MkM4Mzg0RTdGMDIyOThGRkQ2MDJBQjYzNEJCQTRGRUI4NDM2RUIyNjAwQUEgMHgyRjU4MDRCQjBCNTlDNjVCNEQ2OEI2RUY5MDdFRDJBOTE4NzMxRjE0N0YzMTVDOTcwRjI2RTNFMjM3QUUzN0Q5KSgweDI5RjUxMDVENDVGOTNCMEZBQ0Q4MERDQTg5MzZFREE4OUEwNTUyRjM0RTkyMzRGMTkwNzA3REM4NTZFRUZCQ0UgMHgxNjhFRTU1RTZENDVFRENGNkI2RkFDNDY4N0IyNENBNEIyQzFFMUVDNDlBNjVCQzg4RjM4NDBFMkUwMUU0MkVCKSgweDI4NEEzRTIzREE5NDBBQTIwOTBBQjM1RjBDRDU1NkU5MzI3MUYwNUI2OUY1QTFGNEY4MDYwMzM4RkNCQkE2ODUgMHgxMkFFRDYxMEQ0QjAxMUQ1REEyRjcxNUUyNjVEN0MzRDY1MDgxODc3RDUzRjJBNUI0MTU2Rjc5NTM1MTJBRkY3KSgweDJFRjJFMUZEMjQ1NEVGQUMzQTA4REQxNUFFMzg1MEVDMThFQjJENTMyNzBEMEUwNDlGQTRFNTkyNThDMjE2MDYgMHgzRUU5MzExMENFNjhBRjRCMTI2OUJCOTY2OEQ4NkM1MDlCQTgwQjE3QjVDNzA5QTdENjJENkJEQjhERDgyODdGKSgweDJDN0Y2RUM2ODMxOUVEMDVGNTM5NThGRTExODQyOEMzMjVDQ0RFQUUwNEQ3RDBFNkZDNDBBMDQ4MjkxMTg1N0MgMHgwMDdFMEY5QjRGRDdERkJERUMzMkNGMkNFRDExMTI0MTQ5NDg0MzFCRUU5NEFDRTM3MTNCQkU5RDFBQzAzM0ZFKSkpKSkoZXZhbHVhdGlvbnMoKHcoKDB4MzQ2Q0I0NDBBMkM5NENEQkVGOEEyRDA0M0NFNjYxQjRFOUVDMzAxMjg0NjNDMzgwM0MwQzdEN0VCNTYwRDA0MSAweDFFMDU4QjlCODM4MDE2MjQ2MTg4NEIwM0RBNTQyQ0U3RkQ2NzkzRjUyREMwNjZDRjdEMDcxNjM5QjlDREMwNTkpKDB4MTc4N0U0M0U0NTZERjkzOTJGRDk4M0FBQzlFOEM3OTQ3MzMyRUM0RDU2MjY0MUVBMEYxQTVCNTZGOUUyQURCRCAweDM1NDk4MEJEREM3MUE2Qjg3Nzc0QUQ1RUQxOEQ1NUQ2RjQyOUMxMDc2QzFFRTBFQjZEMDNGMTA4NEJCNDREQTMpKDB4MzdCMjI5NTAzNzExNUVFMzZEQUI5MUYwRDM3QTc0RTRDMzExRDg1MzE1QkJENzM3NUI3QkI0QzFFQTEzMUI2MSAweDEzMkZEQTQ4NEFENkM0RjhFQUE2RThFNzI2NzY0MDZEOTgwOEMxQTdFRjU2MkU5NTlBQzkxQjI1RTg0QjNBMUYpKDB4MEJENzY2MjIzMDc0RjlERDNEOTk2NTk4MTMwMTU0MkIyMUIzN0JDRTY0NzdGOTdEMzg0NDc4RDE0Q0ZDMzUwRSAweDIyMEJCQURGNDEyNzQ3RUI3NTkzRkYyOTAxNjA2OTg5QjFFRjAyRTg1MjAxREExMUM0ODlCMjkwNUVEMjk5NjIpKDB4MDUwMEM5MEJFRjZGNjA4RTQwRUU1MDgzQjRDNzQ1NjRCNzMyOTVERDQ0NThBQThFMDk3QzUzMDRGMTlFODVBNiAweDJBREU2NDA4MDY4N0Y5Mzg2QjkwMjZGMUVBNjU3NDc0NUU5N0ZCRDU5QjAxOEY3Qzg5MTMxNUYxMjY4QTM0MjUpKDB4MjdCQzlEMUIxRDQwRUE5NUU3Q0QzMTRENkVGQUQ1RENBOTE5MjA2ODBFOEEzMDg4MUQ1QThFNjczNDA1OUJENiAweDA2NDQ4NTgwQjUxQTZFQTc5REI2NDhDM0Q3MjVGRDhFNEVGN0UwMzBGMzdCNDczMEY3RTU2MTMxNjYyNjEyRTUpKDB4MjM5MDBDNjk4ODBGREMwNzk0QzgxMzE3NTg5NEQ4QzkzQTY1NjlDMDdFNzA0REI1OTc1QUQxMEI1MUU3NDQ2OSAweDFCOTZCODZEM0I3RkU4MDk5OTA2RTU4Q0JENDhDNUExMjE2RUZDQjI3NzQ5MDg4ODFFOURBOUIwMjFDNTY4NDEpKDB4MjIyMjk5OTE4MTkzOEJCNDNBMUNDOTAyMUE3NEYwQTM2QzQyNDdBNkRGNzZGQzlBMDM4NzE3NjI5MzNBMDhDMCAweDI0Q0JCNkEyM0FBNDA2N0U3RTlBODEyN0QwRjgwNUU1MjBGMUNGNENFMDNBMUYyN0I1MEE5ODk5OEY3Q0RDOTApKDB4Mzk3Njc4NThEOEVFODVFOTk4RDg4NEREQzA1RUM2RjBBQkU4NzY4NDQ5NjUwRDIzQ0NENTY2Q0VCMEE4OTE4MCAweDNCRTc3NzVFQjNDODlFRkU1MkU5REZCRTY4NjBFQUE3RUExRDYwREU2NDA2MUU5QUFDRjcwRUY2MzZGRDdCMzgpKDB4MDEyOEU5REU4RUIyMUFENzFBRENFRTQ2MTYyNDRCQ0VDM0JBRTlEMTgxMTIzOTZEMzgwNTRBREE2QzlDMzM5MSAweDBCNzdEMDE0QjBFQkM2OTAxNEE3NTkyRUEyQjhDQUI3NzcxRTM4MUYzNjhDM0QwQTNBNkM2NzU5ODkxOTcyOTMpKDB4MkY4NTI2QkU0QUJCNDQ1ODUxOEY5NTQyMURDMkNCRjJCOUVDQzU4NjVFMDA5QTg5RUEzMDkxMzBFNkE3MjhCQSAweDA0Q0Y5NjI3OUE4MDVCRDA2RkZFNDFEQzFDQjNGNTA2NUQyOUQyMUIyRkRDRDM3NTQxMzg1QUJDODhGRjdGRDgpKDB4MURFNTU1NjAzQzhGM0U5MzY4MTQ3MTAyMDBBMDc2MTRBQ0MxRDc0MDM4Q0JCQjFDNjJDRUQ2QTAzRjM2OUNCMCAweDFDOUI3NUQyNTZGMzYxQ0Q2MUExMTY0ODgyREMxODI2M0YyMjgzRUMyNDQyNTZBNjI1N0UxOUE3RDZCRTI3NDApKDB4MTg3MjA2QjI1NDA1QjEzQjM2M0QyQUQ4NDMwRUE3OEVEMkU3NjRCQzdGMUVERDhBQjE0NjBBMzAxMjk0Qjc2MyAweDA4QUUyQzU5QkJCRTg2OTBCQ0IwQjE5QzQ2QkMyMkM4MTJCMkQxODlFOTA4MjdDNENGMDc3NzZGQTY5NDg4RTQpKDB4MkM4MDQwRkJDOERGNDMyRDYzQTRGOTY3OUY2MEYzNjdFNEM1OTM0OEJBMjVDM0ZCNzVGRDgxMUVGOEY5MEExQyAweDA0NzVCMEI5Mzc0QjE2MjU1NTc4ODBEQUFGQ0NBN0VCRkFGMzYwRjI1QjVBQ0RBQTg5OUM4NzU1QUVFRTUxMEMpKDB4MTU2OEFCRDBBREExOTM0QTRFRjRDQzUzNkE3NzVCOUE0QjYyMjY0MUExODkxQUI4NERFNDdERTAxMjIzRDdFRCAweDMxREFBMTI0QTE4M0UxQjZCNjgzNDBDRTQ2OTU3RENEQkE2NkMyNTUxOUI0ODJEQkUxMDIzNUJERUY4RkI3QjApKSkoY29lZmZpY2llbnRzKCgweDE5NzNDMUEzQkMwOTk0MURBNzRBRjZGNEE0NkNFN0Y5NDEzMDlFMzkxRTZFODUxMTJGNUQ5NTdDMjEzNDlEQzAgMHgxMDhDMTlFQTg2MUQ1RTQ2Mzk4QUNDOUI1MEEwQzVEODUyMzEwMkRDRjU0MTUxOTA4RTYwRDBFRDdFOTdEQ0FGKSgweDEyOTdEOUUyRDJDNzMxRDZGQjg1RkJBMDBGNTYyODFFNEYwRThGNUIzQjgxRkQ5RDg4RjQwRUI5QzQ2OEIwNUQgMHgyNDFGNUQ2MUQwOEI4RjE4RjdCQUNCNkQzMThERUU4RjcyOERGRDEwODhFNTE0RjY0Njk3NUY1MjkxNjE1MDNGKSgweDMwRTNCNEMyRENFNTcwQjU3NjczOTZDMkZEQUU5QzdFNUQ5QTREMkUwREY0QTE3Q0Q2Mjk0MUU3QUQyMjI0MTcgMHgxM0NDNThFM0I4OUUzOEVEQzVCQjkyMjYzNjg3RTE0MjhGNjJBODRDNkYwNzI0NzUxQTg1OTQ1Q0Y2Q0M1QTVGKSgweDFGODQyMDZBOEIzMTJCRDRDQTNEQkExNTUxOTQ5QzFFQzlBRTM3QjNBOUIzNEIwQTdDNUZGQUM4MUE5MEUyNDkgMHgzMTFDNkJCNEZFODVFODI4OUEzMzY2MDE5OUI1OEVFMTg0NUZBNjQ1MDRFNzE0MUMyNEFBNzg5NzE3RDgyMUQ2KSgweDJDRDhEOTUxNDU1MTFGMzlFNDk4RUEzNzBBOUU4MEE3QTk3QUYxN0Y4OUZCRUQ0RDVCMDQ4RUI5OUY1OUZENzUgMHgyMUNCOEUxQThCNzlCMEMzRDMyNTQxRjU2QjI1OERFMTVCNzA1MkQ5QzJGRkNFRDRBRjdERkIxRTI4NUEwMTI0KSgweDE3NTczNjY0MzZGQ0UzMzc4NDREMEVDMjg1RDk5OTQyRkRBNDc2NDJBRDQxMzdFNDE1RENBNTc3NDM5OTgwMTYgMHgwNEMwRjRFQkQxRUZFNzI5RDEzQzY1MTk3MkMyODAxRTAxRTQwREQzNEVDNzA4REVERDY1MzQzNzQ1NEY4N0M2KSgweDFCQjU5RDlDRTZEOTZBRjlEMTc0OTM0NjgyMkI0RkMxRkM3MUQ1RDE4Mjc4MDAxM0JEQTJCMDgzQzM5OTE0QzMgMHgwRTA2NkRERDc4MjRFMTMwODIzMDkwQ0IwRTZBNUM4OERGNTc3OTYwRTlFMzI4RDYxRUExNkZEMkRDOTQxOEEyKSgweDI5MDY1ODMwODM0OTQ4NEYyNURENDg1MkI0M0U2MTMzNEQyRUJGRTVFRTI1NDhGQ0I4NjE4REM2OEZBQTk3MDkgMHgzMzhEQjU0NzY0NTMxRUE0N0U2RDEwOUE3MTI5MTlFQ0I4NEMzMzI5QUZGMUJDQzAyNzExOEEzMDZCNENGQzlGKSgweDA4NUQ3NDhDQUYzMDk5NjU0MjJGNTFFMUI5OTk4QTQ0MzVDMjBBOURCOTBERkVEMjEzQkZFREZBRDU4NDlCNDcgMHgwREY2MTA4MDAwN0MwMTA5NEM4MEExMzQwQTQ3NDEzODhDQjgwMkU4QzJCNzkzMkE4REVFRTc4OTZERERBMkUyKSgweDAwRUI5MTMwQTkyNEVCRUE1OUE1QTc5OEQ3QkM0QTA2ODAwNjRFQUFFMjFFRjBDNUQ5MjBGODdCRDk5OEM1QUYgMHgxMTNENjY3RDZDMzRFQzM2ODU2NEQ2QUM0QzRFRDczNUJFN0YzMDM0OTU3MDRBN0QxRTYwQzZDODEyRjE3QjFDKSgweDNFOUFFREU0M0NGMjA2NEIyQkIxNzU1NTlDOUZGQjUwNDhBN0Y4NURGOTVBMTI0NjNFQkE3MEM0OEFCRjkzQTkgMHgxNEIzNDYzRTNFMkJFODVCRjUwQjNFMzMxRjA4OTgyOUJFMkI4REYzODNGOTcwQ0E3RTRGMEFCNTY0MkQ0NDkxKSgweDNGQkQ1MEUyOUQ4REU3RDcxMzc3QkM2MUFEQjlDMDNDQUE0QzJFRDNFQzBBN0U4QURFOEJENzI1MzVEN0JFOTMgMHgwQTE3N0U0MEI2NjMyNDFEOUEyNjFCN0E4Q0RDNzIwMjM0RDBGNjU5OUM3OENGQjgxMDFBQzZENEM3MUNBNzc2KSgweDA0NzdCOTMwQjM0NDJEMUI1QUQyRjJDRkIzREVBQkEzODNFRjExN0FCM0Q1NDhDN0U3RDgyMkZBQ0Q5MDQ0QUMgMHgwNjJDN0JCMjFCRTAyMTdEQzk2NEVFRjc4MEFDRjE2RjIzMTFERDIzRTc2NTA3OUY3OTFCREZENzQ5MTUwRjBDKSgweDE1NTNFNkY0MzFDOUZBNjdCREExQzU1NUQwNTMxMDk5OUIxRjRFNEJEOEJCOUUzREEwNzIxOTVCMkJCMzhGN0IgMHgxOUFDMTZFRDNCMjU1RkJEMkJFRTk0MUNDOTY1MjZDRTBDQTk1OTIxQ0U0NkY5QzQwQzg5NDQxMTA1MjAwRjIyKSgweDJEMEUyQzI3QUE2MDJDNkIwODZDODVDODI2MkMzNUM4RjAxM0M0NTREMjUxM0E1QUE0OEY5MjczNzA0MzY2Q0UgMHgyRkQxREI0MUU5RTE2MkUwMDQzNURDNUZGMjU3Rjg0OTgzQzlFNkRENkREMTJERDE5NjVDRjA4MTdEMENCREJDKSkpKHooMHgyMDhENjYwRDczMEJGN0IyMTg2MEVCQURBQkUyNUQ1MjNFOTc4RjUyMjM0QjM0OEZGRDIzNEIwRDg3RUU0NDdEIDB4MjY4RTMzNzYzMjRBOTFDMUExQ0E5NUU4QUQwQjM4MkJGN0E0OTg4Njc0NTJBNjEyMURFQTRFQzUwMEZGNDc3QykpKHMoKDB4MUY1REM4NjUyMERCMEMxQ0UwNEIyNzYwNkE0NEQ4QTkzRDJBMkYzODMxQTYzODBBNThCRjU4OUZDOTU0QzA0MSAweDIwMTNCNEVEMDc4MjEzNEYxQUZCRUUwOEYwRUI1RkU2MjgxNkMxRjUyRUFFQkMxRDczNUZFMjg0N0Q3RjlDREMpKDB4MzgxMjdBRDQ2NTg3RkNDMkFGNThEQzAwODdBQjQxQjY4NjVENDE4NzY4QTVBOEFBRTc5MzlFNjMxNkQwNkIzQSAweDI0NDkxMEUzNzRGOEY3OTUzRkEzNkU1MzgzNEMzQkFCQUY1NUZEQjdDRUYyQjE3QzFGQUFGOEMyMzZCMzZEMzIpKDB4MjRFRUY4NjYzOUI0QjkxQjI4NzkyQ0I1RDYzNUFFRDg1QTM4NTU1NEU3RjI1QzFENEIzRUU1NjE5NEQ2MjMxRCAweDJFRTUxRDIwQkJBQTZBNzFCMUVBRDBBNkJCMkZDQTI2MUU3N0I0ODkzNUFDQzIwQ0IyOUQ2RERBRkIzOTIxMDIpKDB4MUI5RTIyMTdEQzBFMTdBNkU5N0IwREU5RjU4MEREOUJDMjkxNkEzRUQ1QUJBRUM1QUNFNkY0RkU0QzM1RjA0MCAweDAxREI1RjA4NDFCRThEOTlDMTFCRUM0OTIxM0E3QkU2Mjc3MTZGRDREQUI0Nzk2MUFGNjE3NzMxMENDOTg5Q0QpKDB4MzNCRjMxRkNFQkFCRjQ3QzQ5MDlDMTYxREQ4QzRFNjQ4NjI4QUFDOTYxRkM3NTRDQUQ3MTdBNUQyRTVCMEUxNyAweDMyMEE4QzY2NDE4NEFDOUQ2NEE0OTkwRTMyRDc2QzlEQUY3QUU1QTE1RkFCRkYwRTE4RjZGMEIzRURDRERDOUEpKDB4MTUyQzk0MjM5RjRGOUMwMURBQjc3Q0MzN0EyNEQ5QjFEMENCN0Y0OEM4QTE3NjY2MTEwODgwOEUxN0I1QTUxNSAweDNCNkY5MDY4RDU5NURBMjZBMzE2QTM5M0QxODRFQjNCREEzMDY3MkYzMjZGODJDMTdBRUQxNEEzMEYxMUY2MTEpKSkoZ2VuZXJpY19zZWxlY3RvcigweDMyNzMyRUZDRTQ3RkRBNDAyODJGRDc0NTg3QjlEQzJBM0QyOTM2RTdBQjY4ODFEOUJCQzgzRjdGOUQzM0NBQjYgMHgyRTc2REUyNkJEQ0M0ODRCOTIwREU1QUZBMDZCNkNENkE2MjBBRERFRjA0MDJFNzVENzEwRTBFMDBDMjU4OEQxKSkocG9zZWlkb25fc2VsZWN0b3IoMHgzNjBGQkY5NTAyRjBCRDQ5OTdBOTI0RTg3NEQzNUUzRjEyMEFBQzY3NjRGRDg0NkIwODM2NkQyMURFOTA4QTMzIDB4MjdGQjkzOUJDRTlCOEUxMUNCMTI3M0Q3RDNERTdBNDlFNUNDM0UwMjJERDA0RjBEMkIwMjVBQzRBRUQ1OEVEOCkpKGNvbXBsZXRlX2FkZF9zZWxlY3RvcigweDNGREU0MzY3MEFEQ0QzMjkxNEMxRkYxNzJENEZDMDVCMzM5RUFCOUZBRkNDNTExMEUzOUQwMDY0NEY1MzNGRUIgMHgxNUVERUNFN0Q0RjkzNzFBRjE3REFEREQ0QzNCMzRBQ0M4MEMxN0M1MkE4MEI0QTgxRDkxOUQ4RDI3MUQzMkE4KSkobXVsX3NlbGVjdG9yKDB4MzY4NzVDQzIwMzM4REI2NTE3QUNGNzYyMkE5MUY3QjMzQTJGMDhDQzIyNEEzNjM5QUIwMkNGMjVDMjIzQkFFOSAweDJEQUVGMTk5OEU5Q0NCMjQ1Rjg2NkI1QkI4MEM2M0NFQzM4MkMzOEQ4QkVGRDIzN0YwMURDOTE4N0ZBNjBEQ0QpKShlbXVsX3NlbGVjdG9yKDB4M0EzODJBNDNENjE1RjdFNjI5QjhCNEFEMTlDNDcwQUEzMjdGNUIyMzZFODc4Qzk3MENFNUEwNDVBRUJGMTIzQyAweDJDM0FENjA2N0NGNUU2OUYxQTA0MDQ1Nzc0OTc4OTQxNTY4NTI4MDA1NjMyNUQ2RDNGMzIxNzhFRDY4OEY4QjQpKShlbmRvbXVsX3NjYWxhcl9zZWxlY3RvcigweDBFRTk4RDM1OTQ2M0NCNTMzQTY4QzZBNzZENDlGOTY3QURGNUUxQTQxRDUyOEM0MzNGNTZERTBFOTE3NjQzRDcgMHgxNkQ0QTQwOTIxNDNEMENFNzA2NkU1QzVBMjAxMkQwNzE5MDM4Nzc3NzE1OUNBOEFDMzVBQTJFMDk0RTE4OEFDKSkpKShmdF9ldmFsMSAweDAzNzExNTBBOEI0OTdGRTFCODZFNjhGRTM3N0IwQUQzOTBCRTE1QzU5NkE2MDU5MDdDNjg0QTM0Qzg5NzU5RTUpKGJ1bGxldHByb29mKChscigoKDB4MDgzQTdFMzMwNzIxNTFEMTg2MDYyNDVFQTg5OEQ5MUZBQ0Q1N0U4RjZCQ0RDNDhBOEFEQzNBMEE2M0NCMUM1NCAweDM5NjJFNjlFN0Y5QzNDQkIxNDJGQUFCN0U0QTBERUFGMjUyN0IzRTM5MzZGNzQ4QThBREM4OEE3ODE2MEQ2OEUpKDB4MTU0Q0VENUExMDhCNTBDMzM4NTA3QTFERTU1MjE2QjM0MzdFQTg5NENBMzhFM0E2RDRCNjQ2MUZBQUE0QTdCRiAweDA4RjUwNzc5OThCODcwREFGRjA2Q0ZEQTY1NkYyRTY0RURERkI4N0E0MjA5NDNCNTg4MDA1MUM5QzZCQTQzNjIpKSgoMHgzMUMxOEFBOEE2NDNGNjJEODNDNEE3NEI5NjZEMjJDOEI2MkJERkFBN0ZDQzU5MDVENjJFMkM2NTRCOUI4QUEzIDB4M0YxMTNDQUMzRDg0NzZDOTQ4MzVDRDY2OTg3QTJCQTg5MTU2MDEyNTc5QzgzMEQ5NDU5NjBGREM3MkY4QzM4MSkoMHgzODc3NDYyM0JERjIwNzUzNEVGRkNCQjk5RjEzRjQxMTgwN0EzMDA2MENCRkQxMUI3Qzg3RTU0MDMxMUQyMDc4IDB4M0ZCMDYxRTg5QzAzMTkyN0Y1NTgxMUNENDlFMUJBRjVEQzMyNkJCRjFEQzY3NjQ5OTc2RjZEODIwOUEyOTAyMSkpKCgweDFCNkE2QTNENzY5OEIxODlDQkZCNUU4RkEyNEU5QUU2NkQxMzk3ODIwODQ2NjNCMkUwQUY1MDQxMDdFMTcwNDcgMHgyRkU0NjkxNkYyNzYwNjg5Q0NDNUVFRDY0MDAzODEwMUE3MTJCRDA1OThBMDk4MEVGM0FFRDlBOURGRTc0NThBKSgweDI5NzQwMjNCQzZBQzgyQ0VGN0U5RTI2NjRFRkQxNUYzMzE2NzlBMTIzOTE3RUE4OTM4QUI4NEM0REM2QjBGRjEgMHgyMTc2MTAxRkVFMjk1NTREMUEwNTgwOERBRkVEMTI2RkRBNDUwMDc0NDdCNzQ4MjUyMDg4QzYwRDA2NzcwNkY3KSkoKDB4MUI5QkZBRUUxRTZFQjBDMkVFMUE2ODZBRkQ1ODY3OUYzRThFQjlFMDAwOUFBNTA1NDUwQkIxRUNCRDdDQjlGNSAweDBENjU1QUQ3QjUyMjNCODlDNTg1RjNBMTU0MEU2MEE5QUFBMTlCODE4MjY0OEUwRUY2RUY3Qzg0NjVERjFDNUMpKDB4MDM1NzJGOTE5MDJEMzA2NDk2NTE0MUE4M0M2MTlEQzg5N0VDM0E3QkZERjNBODdFODRFNUNBMDQ2NkQxMUIxRCAweDM1OTZCRTBFNkUwMkFFOTc1OUVCNjc0QTc0NjYyNEY0Q0U0QTU2RjZDOTYyNkI4ODE3RUE1MUU5NTdDREIzRDUpKSgoMHgxNDcyRDQwMzBBNEVBMEM1MjQ4NkI3RDExRjM5M0VEOEJENEY3NkE3MkM4NUFCOTkyMzlBMEREREE0OTAwNDg5IDB4MzNCNzRGQTM0QTQzNTcxOUNDNzQxRUY1QTE3QUFBQ0EwQzk4MjdDNTU4Q0U0NUFEOTUzRUYzRkIzMzk5NzQ3MikoMHgxOUQwRDFCQ0VGREExMkJGRUQ4QThDMjhDNkIxQzY1ODg5NTc1MjEyMUIyODk3NkZGNjUxN0RFNDgxRDNCMERBIDB4MjNCRjRGQkFGRTJGQjcyNEFEMTQ4RDk2RDQzM0YxMzFDQ0Y2MzAzNDY2NTlBNUE1REE1Q0IwQThCNzdGMjdFNCkpKCgweDE5ODUyMTEzQzVFNTU1MkY1RUQ2MjAyREZGREJCMEQ2OTQyMDBFNDJCOUNGNzQwMjdFQTcwMkNFOTUzMzBCRUYgMHgyMTZCRTk5MjU3Qzg5QzNCODhCQkY2Nzk4RjFFRThFRUMxQzg1M0UzMjhFNkJFNDVCQkExQUVGQUFFQ0NERThFKSgweDMwQTZFOEEwNzUwMjc5MEI0MzE4RjNBNjA3NUJCRjg3OUMyNDdGNzZBODc1MjBDNkM4QUIzNkI4NDJCMTgyNTcgMHgyOEUzMTkwRUQwNEQ5Rjg4N0NGREVCQzQ1M0U2QkEzMDZBMjg2NzBCOUQzQjg5NEM2QTA2NTlBQTU5QzE2QjBDKSkoKDB4MzJENjVFMThFMURFRDg5RUQxRDYyMTZCMEZGQzRCRDRDMzA2OTVBNEIzRTRENTkzNjA2RUMzN0MwRjU4RTlDMyAweDI3NkYyRUZENzkyMjhGQzk4NUE4M0M3RkRDRUY5Q0E3OTdGODFCQzMyMEE5NzkzOEVGRjMxNjdCQjUwQzkzNkIpKDB4MjYyMDg2MEMyNTU3OEZFMUZCNTAwNzY3Q0NDMkFCN0REQkM1NkE2MThCREZGQjlGNERGRjRCQTNGQ0RGM0ExMSAweDBGQ0I5RjE2QjVEODE5MTkwQzA2MEREQ0E1RjZFRjVBMTU1QUUxN0Y1Qjg1QzhFOEE3NzZENzREQkU3MzMwMTgpKSgoMHgwODEwNDcxQzRCMjk1RjlDODA0MzZBNUI0QzYwRTFEMzFGQ0EwNzM3NUY5NUYyQzMwMEYyQThDRUExNTZFNUIyIDB4MkE4NkQ3MkY2MTAwQTA3NDc4QTkzOTE5MEExOUE0RTBDMjc4RUM0RjQxQUZGQTI5RkMyNEUyN0JGNTFBMjMwOSkoMHgyNTNDMkU0MTc0NzJBNkU3MDlEQkNBNDAzRUI1MDVERjZFMEYxQzFEODY3N0RBNThENDU0MEY4RjY3RjQxREQxIDB4MEY1QkJEQTdFOTYyRUI0RUE5QUVDQ0VERDgxRTBFNjY3NTgyQTMxNjRBRTYwRjczNjMwN0IyQUUxMkFGREFGNSkpKCgweDE3RkU4RTJGRTYxMjlBRUFFQkZFODFGOUYzMEYyMTM2NzBENkE1MzQzNUUyNTEwRjNCNkU3MjAwNjQ4ODJFNDMgMHgzMkEwOEIwOTQ3QURFREFFQjQxNURCNURENTE5QTZCMkVGMDczMkVGM0M2NTY4NTJGRDdFQ0FGRTVFMjhDOTNGKSgweDM0RDRCMzQxQjlGRUI3NjI4Q0JCRERBN0IwMUNFQjQyRUVGRTg4MzNEOUM4MjJGMDI1NUNBNzAwRkExMDhCODcgMHgyQUUzRjhFNUU4RjA4OTQ5ODYxMTY0MjUyNDVBMTgyN0ExNDcxRDU4MzBFMTVGOTdFMjU1MkM4NzdEMUUzNjcyKSkoKDB4MEZDODA4MjdGOUY4M0JCODJEMkU4RUI4OTQyQjIzRDM1Rjc0NTg3NTYzRDE4MkU1RjJFMDAyODIwQzU0RTkwOCAweDJEOTg2QjQyMjY1RjU4NEE1QTA3NEE0MDA5QTAwN0UxQ0ZEMENBMjM5NDk4NjdCQzk0RkQ1RDhENkUyNkI0RTQpKDB4MkUyQ0NDODQxMkYwNEMxNjlBMDg3N0VCOTMyQUQzQTg1MEMwRDcyRDA2MjAyNzA4QjAxRjkxQzAzMTYxMTY0MSAweDEyMjlCNzMyRUNBNzlEOEEwRTFEMEY2ODk2ODg3MDA1RTk1NDA3OEMxN0M0OUE4RTdCQTlFREIxREFFRjYyQTApKSgoMHgwRUFDQjY0OURGMTk2M0VGNDhFNkIwMDBBNkM0QzU0M0E4NThCMzRCMDZGRUU2QjJBQjgxRDE2RERFQzhDM0E5IDB4MTNDRTZBRTg2NDkzNzVDOUVCMzkwQUY3MTIxODA3ODQzQkZERDc0NjQzNDM3OTk5RkYwRjk1N0JEMUJDOTUyRikoMHgxRkZBN0NFMzlDRTdEQTNEQTZCNkI1Qzk3RjE2RDRGMUEyNDA0MjMxN0FFODZGRjIxQkVBNkY4OTk0NzZFMkNEIDB4MUE5QUE3MDFBNDVFNEE5MTQwMUIyQTc0NDI2NzEyMjAzQTEzRDhFNDkwREZCQzM3QjA1QUU2OTUyQUM3OTI3MSkpKCgweDEzQzE4QUM4RkNBQzUyOUNBQkU3OThFQjk0OEQ2RTVGNjFENzlGRkU2RjgzREVFMTczNEUwRjFDQzY4Rjk0MzggMHgyNDk1RTQ1RkVEODhFMkU0NzEyQTg0MTYwQzlGNDdFMUQwQUZDNThEMzg4QjhFQTlEOEREOTIxRTA2RjcwNzFEKSgweDEzOEJBNEYzRTcxNTM4QjEzRjNFOEM4NDIwOTI1REMxQzMyODFCRjdGOEVFMUI1ODEwNkVFNDNCODRGNUFBQjUgMHgzQzVGQkZFRDRGOTQwQjk0MDgzODA0NUExRTRFMUU5RTA4QUE3RjI3OUQyRDEwMDNEMjRERjBCQTNCNDYwOEVCKSkoKDB4MzQ2OEVGNUQ0ODNERjg1MjU0QTI1MDQwNTEzODlCNEY2NzA2MzkzMEI4MEQ3NEQ1NUNDMDEwQzFFRDVCNDFEOCAweDAyM0Q0RDdCRjc0REY0RDUzQTZFQzU2MDA5NDNEM0Y5NzVFREYzNkI5OEYyRTlGRTI0NjY4ODE4NkIxNjA1NjQpKDB4MTJFRkVBQUNEQzBDMDQ0N0Q4RTYwNTI1MzUxMUNFODRGRTRFRTczNzI3MzBENENGMkM5QzcyRDc0MTdCRkYwMSAweDA2ODRGNkY0M0UzQkI5MUJCMzlEMzExQjg3QkVGODU3QUI2REQzREFFNzEzODkwQTk2Q0ExODYwQTVGMzdCRTYpKSgoMHgxRTQwRkNERjlDRTk2MENDNTExMEVEMDBERjE0NzhGN0VDNDJENjQ1OUVFNUIxOUI2NjJGNjE3NjVDNzlERjUyIDB4MkVDRjIzQTRCRDhEODJGNTFDM0MxMDZBQjE4MEMwMThEOEQxOUNDOUVFQUE2MzkxQTRFNkZFM0E2MjcxQTBFQikoMHgyQzEyQjVDQjEyQzkxRUI1MjYyNTY4MUExNzg2MjVFM0Q1NjNGODEyQTQ4QjYxQjgwQkM4OTRBRUZEQjUwQkRCIDB4MTAzQzYxQzNGNjVEQzI0RjlDMjkzMzY4NzFEREUyNDJERDdFNDI1QkNCMEZEN0M3QURBQ0QwQkEzQzY1RDQwNCkpKCgweDM4OUFFMzAyMTJDMzM5RjJGNjZCRkVDRDNFQTQyNTk1RDMwNkFEQjE1MUZDNUI3QjZDMzhDNDYxMjBDMEU0QzUgMHgwMTNFQUQ2RDUxOUZBN0UwQUE4NDlFMTUyQTMwNTBDMzM5NjIyNjU4NUYyQzVCQjJDOUU0QUY1MUY2MEQzMEU1KSgweDA0NjE2MjM4RjI4MjNERDQ0NEMwQzZBMjY1Mjg1MjQxOEIwMTE5MTc4REYxNkIwQkEwOEZGRjNEOEQwMUE2QzYgMHgwQjY4MUU0NThGNkJGNTMzRTQ5RjQ3NjExNDRCQjFBNTczNkQ2NjZFQjQ4NDY5QTBBQzdGNDE1RkFFNzNGNUM3KSkpKSh6XzEgMHgwQzlBMzEwN0JDRjNGRDJBQTY1MzQyNTA3NTEyNkFDODlCRTkxN0ZFMDNGMjEzMzAwRTdDOTQ0RUFBOTFDNTAyKSh6XzIgMHgzRkM5Qjc4MTRERTNBOTNEMkFFQ0VCNDFCNDcyNjJCNkRCQ0I4OEFDMzRBMUIyRUVCMDk1N0REMkQxMjA5OTgwKShkZWx0YSgweDBFMzU2MDk3REQ0NDgzN0YwOTZCRTUzNkRCMkMwODlEODgyQzg5M0RBOUNDNDlGMUE1QzlBQTg5OUE1QUUwMjEgMHgyMzUzRkNGNUIzRDU5QTY4NzQxQURCQ0ExMzgyMjFDODM0MTM0OEU3MUYzRUVDM0Y3ODk4OUJCNzkwQzcwQUQ4KSkoY2hhbGxlbmdlX3BvbHlub21pYWxfY29tbWl0bWVudCgweDE3RTBFMDBFNjRBQTk1M0E2NTdCNTExM0FBOEFFOTg1MkY4NkVCN0JCMDE5RENGN0U1M0VFOTk5ODkxOEY1NEMgMHgwNTdDOEQ5RUI2RjM2MTJFRjU3OTQ3N0VCRkMwMDdGM0IwNkMxOUQzQkZGMkEyMDczNDFBMkRDRUQ3MzhDRDU3KSkpKSkpKQ=="]},"account_update_digest":"0x1A81B18D90436C0A48EE28A8C2944A013829C1203FA877966FA17D79C693FCE5","calls":[]},"stack_hash":"0x0EFF662EB75B6599D52F022DF13E0AC87D40F46138CE332D2F752F231C3CAAD5"}],"memo":"E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH"}
            
          ]
        |json}
      in
      let ci_zkapp_txn =
        match Mina_base.User_command.of_yojson ci_txn_json with
        | Ok t ->
            t
        | Error s ->
            failwith s
      in
      printf "Hash of txn from CI %s\n%!"
        (hash_command ci_zkapp_txn |> to_yojson |> Yojson.to_string) ;
      if Mina_base.User_command.equal gcloud_zkapp_txn ci_zkapp_txn then
        printf "transactions equal\n"
      else printf "transactions not equal\n" ;
      let gcloud_json =
        Mina_base.User_command.to_yojson gcloud_zkapp_txn
        |> Yojson.Safe.to_string
      in
      let ci_json =
        Mina_base.User_command.to_yojson ci_zkapp_txn |> Yojson.Safe.to_string
      in
      if String.equal gcloud_json ci_json then
        printf "json transactions equal\n"
      else printf "json transactions not equal\n" ;
      printf "gcloud json  %s \n ci json  %s \n%!" gcloud_json ci_json ;
      printf "gcloud json hash %s \n ci json hash %s \n%!"
        (digest_string gcloud_json |> to_base58_check)
        (digest_string ci_json |> to_base58_check) ;
      true
  end )

[%%endif]
