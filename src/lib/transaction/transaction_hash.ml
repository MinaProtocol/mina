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

let mk_hasher (type a) (module M : Bin_prot.Binable.S with type t = a) (cmd : a)
    =
  cmd |> Binable.to_string (module M) |> digest_string

let signed_cmd_hasher_v1 =
  mk_hasher
    ( module struct
      include Signed_command.Stable.V1
    end )

let signed_cmd_hasher = mk_hasher (module Signed_command.Stable.Latest)

let zkapp_cmd_hasher = mk_hasher (module Zkapp_command.Stable.Latest)

(* replace actual signatures, proofs with dummies for hashing, so we can
   reproduce the transaction hashes if signatures, proofs omitted in
   archive db
*)
let hash_signed_command_v1 (cmd : Signed_command.Stable.V1.t) =
  let cmd_dummy_signature = { cmd with signature = Signature.dummy } in
  signed_cmd_hasher_v1 cmd_dummy_signature

let hash_signed_command (cmd : Signed_command.t) =
  let cmd_dummy_signature = { cmd with signature = Signature.dummy } in
  signed_cmd_hasher cmd_dummy_signature

let hash_zkapp_command (type p aux)
    ({ fee_payer; account_updates; memo } :
      ( ( Account_update.Body.t
        , (p, Signature.t) Control.Poly.t
        , aux )
        Account_update.Poly.t
      , unit
      , unit )
      Zkapp_command.with_forest ) =
  let cmd_dummy_signatures_and_proofs =
    { Zkapp_command.Poly.memo
    ; fee_payer = { fee_payer with authorization = Signature.dummy }
    ; account_updates =
        Zkapp_command.Call_forest.map account_updates
          ~f:(fun (acct_update : (_, _, _) Account_update.Poly.t) ->
            let dummy_auth =
              match acct_update.authorization with
              | Control.Poly.Proof _ ->
                  Control.Poly.Proof (Lazy.force Proof.transaction_dummy)
              | Control.Poly.Signature _ ->
                  Control.Poly.Signature Signature.dummy
              | Control.Poly.None_given ->
                  Control.Poly.None_given
            in
            Account_update.forget_aux
              { acct_update with authorization = dummy_auth } )
    }
  in
  zkapp_cmd_hasher cmd_dummy_signatures_and_proofs

(* no signatures to replace for internal commands *)
let hash_coinbase = mk_hasher (module Mina_base.Coinbase.Stable.Latest)

let hash_fee_transfer = mk_hasher (module Fee_transfer.Single.Stable.Latest)

let hash_zkapp_command_with_hashes
    ({ account_updates; _ } as cmd : (_, _, _) Zkapp_command.with_forest) =
  hash_zkapp_command
    { cmd with
      account_updates = Zkapp_command.Call_forest.forget_hashes account_updates
    }

let hash_command cmd =
  match cmd with
  | User_command.Signed_command s ->
      hash_signed_command s
  | User_command.Zkapp_command p ->
      hash_zkapp_command p

let hash_command_with_hashes cmd =
  match cmd with
  | User_command.Signed_command s ->
      hash_signed_command s
  | User_command.Zkapp_command p ->
      hash_zkapp_command_with_hashes p

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
  type hash = T.t [@@deriving equal, sexp, compare, hash]

  let hash_to_yojson = to_yojson

  let hash_of_yojson = of_yojson

  type t = (User_command.Valid.t, hash) With_hash.t
  [@@deriving sexp_of, to_yojson]

  let equal ({ hash = h1; _ } : t) ({ hash = h2; _ } : t) = T.equal h1 h2

  let create (c : User_command.Valid.t) : t =
    { data = c
    ; hash =
        hash_command
          (User_command.read_all_proofs_from_disk @@ User_command.forget_check c)
    }

  let data ({ data; _ } : t) = data

  let command ({ data; _ } : t) = User_command.forget_check data

  let transaction_hash ({ hash; _ } : t) = hash

  let forget_check ({ data; hash } : t) =
    { With_hash.data = User_command.forget_check data; hash }

  module Set = struct
    type el = t

    module Generic_set = With_hash.Set (T)
    include Generic_set

    type nonrec t = User_command.Valid.t Generic_set.t

    let sexp_of_t = Generic_set.sexp_of_t User_command.Valid.sexp_of_t
  end

  let make data hash : t = { data; hash }
end

module User_command = struct
  type hash = T.t [@@deriving sexp, compare, hash]

  let hash_to_yojson = to_yojson

  let hash_of_yojson = of_yojson

  [%%versioned
  module Stable = struct
    module V3 = struct
      type t =
        ( (User_command.Stable.V3.t[@hash.ignore])
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

  let create (c : User_command.Stable.Latest.t) : t =
    { data = c; hash = hash_command c }

  let data ({ data; _ } : t) = data

  let command ({ data; _ } : t) = data

  let hash ({ hash; _ } : t) = hash

  let of_checked ({ data; hash } : User_command_with_valid_signature.t) : t =
    { With_hash.data =
        User_command.(read_all_proofs_from_disk @@ forget_check data)
    ; hash
    }

  include Comparable.Make (Stable.Latest)
end

let%test_module "Transaction hashes" =
  ( module struct
    let new_zkapp_txn =
      let txn = Lazy.force (Zkapp_command.dummy ~signature_kind:Testnet) in
      { txn with
        account_updates =
          Zkapp_command.Call_forest.forget_hashes
          @@ Zkapp_command.Call_forest.map txn.account_updates ~f:(fun x ->
                 { (Account_update.forget_aux x) with
                   Account_update.Poly.authorization =
                     Mina_base.Control.Poly.Proof
                       (Lazy.force Proof.blockchain_dummy)
                 } )
      }

    let new_zkapp_transaction_id () =
      Binable.to_string
        (module Mina_base.User_command.Stable.Latest)
        (Zkapp_command new_zkapp_txn)
      |> Base64.encode_exn

    let new_zkapp_txn_hash () =
      hash_command (Zkapp_command new_zkapp_txn) |> to_base58_check

    let run_test ?regenerate_zkapp ~transaction_id ~expected_hash () =
      let hash =
        match hash_of_transaction_id transaction_id with
        | Ok hash ->
            to_base58_check hash
        | Error err ->
            (* Generate a new transaction_id and hash if the transaction_id fails to hash *)
            if
              Option.is_some regenerate_zkapp
              && Option.value_exn regenerate_zkapp
            then (
              Printf.printf "\nThere was an error hashing the transaction.\n" ;
              Printf.printf
                "If the encoding has changed you can update the values:\n" ;
              Printf.printf "Transaction ID:\n%s\n\n"
                (new_zkapp_transaction_id ()) ;
              Printf.printf "Expected hash:\n%s\n" (new_zkapp_txn_hash ()) ) ;
            failwithf "Error getting hash: %s\n" (Error.to_string_hum err) ()
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
      run_test ~transaction_id ~expected_hash ()

    let%test "signed command v2 hash from transaction id" =
      let transaction_id =
        "Av0IlDV3VklWpVXVRQr7cidImXn8E9nqCAxPjuyUNZ2pu3pJJxkBAAD//yIAIKTVOZ2q1qG1KT11p6844pWJ3fQug1XGnzv2S3N73azIABXhN3d+nO04Y7YqBul1CY5CEq9o34KWvfcB8IWep3kkAf60JFZJVqVV1UUK+3InSJl5/BPZ6ggMT47slDWdqbt6SScZAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
      in
      let expected_hash =
        "5JvBt4173K3t7gQSpFoMGtbtZuYWPSg29cWad5pnnRd9BnAowoqY"
      in
      run_test ~transaction_id ~expected_hash ()

    (* To regenerate: use the values provided in the error message *)
    let%test "zkApp v1 hash from transaction id" =
      let transaction_id =
        "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"
      in
      let expected_hash =
        "5JugPe4YYJuFv2LpBZVCqb6Tw3HYaEULeTjcpQ2eP4WWNTr5jzvH"
      in
      run_test ~regenerate_zkapp:true ~transaction_id ~expected_hash ()

    let%test "Hash fresh zkapp transaction" =
      match hash_of_transaction_id (new_zkapp_transaction_id ()) with
      | Ok _ ->
          true
          (* there's no point checking the hash is the same if it's freshly generated *)
      | Error err ->
          failwithf "Error hashing new transaction: %s\n"
            (Error.to_string_hum err) ()
  end )
