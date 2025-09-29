open Core_kernel
module Js = Js_of_ocaml.Js
module Impl = Pickles.Impls.Step
module Other_impl = Pickles.Impls.Wrap
module Field = Impl.Field
module Account_update = Mina_base.Account_update
module Zkapp_command = Mina_base.Zkapp_command
(*module Signed_command = Mina_base.Signed_command*)

(* Test - functions that have a ts implementation, exposed for ts-ml consistency tests *)

module Encoding = struct
  (* arbitrary base58_check encoding *)
  let binary_string_to_base58_check bin_string (version_byte : int) :
      Js.js_string Js.t =
    let module T = struct
      let version_byte = Char.of_int_exn version_byte

      let description = "any"
    end in
    let module B58 = Base58_check.Make (T) in
    bin_string |> B58.encode |> Js.string

  let binary_string_of_base58_check (base58 : Js.js_string Js.t)
      (version_byte : int) =
    let module T = struct
      let version_byte = Char.of_int_exn version_byte

      let description = "any"
    end in
    let module B58 = Base58_check.Make (T) in
    base58 |> Js.to_string |> B58.decode_exn

  (* base58 encoding of some transaction types *)
  let public_key_to_base58 (pk : Signature_lib.Public_key.Compressed.t) :
      Js.js_string Js.t =
    pk |> Signature_lib.Public_key.Compressed.to_base58_check |> Js.string

  let public_key_of_base58 (pk_base58 : Js.js_string Js.t) :
      Signature_lib.Public_key.Compressed.t =
    pk_base58 |> Js.to_string
    |> Signature_lib.Public_key.Compressed.of_base58_check_exn

  let private_key_to_base58 (sk : Other_impl.field) : Js.js_string Js.t =
    sk |> Signature_lib.Private_key.to_base58_check |> Js.string

  let private_key_of_base58 (sk_base58 : Js.js_string Js.t) : Other_impl.field =
    sk_base58 |> Js.to_string |> Signature_lib.Private_key.of_base58_check_exn

  let token_id_to_base58 (field : Impl.field) : Js.js_string Js.t =
    field |> Mina_base.Account_id.Digest.of_field
    |> Mina_base.Account_id.Digest.to_string |> Js.string

  let token_id_of_base58 (field : Js.js_string Js.t) : Impl.field =
    Mina_base.Account_id.Digest.to_field_unsafe
    @@ Mina_base.Account_id.Digest.of_string @@ Js.to_string field

  let memo_to_base58 (memo : Js.js_string Js.t) : Js.js_string Js.t =
    Js.string @@ Mina_base.Signed_command_memo.to_base58_check
    @@ Mina_base.Signed_command_memo.create_from_string_exn @@ Js.to_string memo

  let memo_hash_base58 (memo_base58 : Js.js_string Js.t) : Impl.field =
    memo_base58 |> Js.to_string
    |> Mina_base.Signed_command_memo.of_base58_check_exn
    |> Mina_base.Signed_command_memo.hash
end

module Token_id = struct
  let derive pk token =
    let account_id =
      Mina_base.Account_id.create pk (Mina_base.Token_id.of_field token)
    in
    Mina_base.Account_id.derive_token_id ~owner:account_id
    |> Mina_base.Token_id.to_field_unsafe

  let derive_checked pk token =
    let account_id =
      Mina_base.Account_id.Checked.create pk
        (Mina_base.Token_id.Checked.of_field token)
    in
    Mina_base.Account_id.Checked.derive_token_id ~owner:account_id
    |> Mina_base.Account_id.Digest.Checked.to_field_unsafe
end

(* deriver *)
let account_update_of_json, _account_update_to_json =
  let deriver =
    lazy
      ( Account_update.Graphql_repr.deriver
      @@ Fields_derivers_zkapps.Derivers.o () )
  in
  let account_update_of_json (account_update : Js.js_string Js.t) :
      Account_update.Stable.Latest.t =
    Fields_derivers_zkapps.of_json (Lazy.force deriver)
      (account_update |> Js.to_string |> Yojson.Safe.from_string)
    |> Account_update.of_graphql_repr
  in
  let account_update_to_json (account_update : Account_update.Stable.Latest.t) :
      Js.js_string Js.t =
    Fields_derivers_zkapps.to_json (Lazy.force deriver)
      (Account_update.to_graphql_repr account_update ~call_depth:0)
    |> Yojson.Safe.to_string |> Js.string
  in
  (account_update_of_json, account_update_to_json)

let body_of_json =
  let body_deriver =
    lazy
      ( Mina_base.Account_update.Body.Graphql_repr.deriver
      @@ Fields_derivers_zkapps.o () )
  in
  let body_of_json json =
    json
    |> Fields_derivers_zkapps.of_json (Lazy.force body_deriver)
    |> Account_update.Body.of_graphql_repr
  in
  body_of_json

let get_network_id_of_js_string (network : Js.js_string Js.t) =
  match Js.to_string network with
  | "mainnet" ->
      Mina_signature_kind.Mainnet
  | "testnet" | "devnet" ->
      Mina_signature_kind.Testnet
  | other ->
      Mina_signature_kind.(Other_network other)

module Poseidon = struct
  let hash_to_group (xs : Impl.field array) =
    let input = Random_oracle.hash xs in
    Snark_params.Group_map.to_group input
end

module Signature = struct
  let sign_field_element (x : Impl.field) (key : Other_impl.field)
      (network_id : Js.js_string Js.t) =
    Signature_lib.Schnorr.Chunked.sign
      ~signature_kind:(get_network_id_of_js_string network_id)
      key
      (Random_oracle.Input.Chunked.field x)
    |> Mina_base.Signature.to_base58_check |> Js.string

  let dummy_signature () =
    Mina_base.Signature.(dummy |> to_base58_check) |> Js.string
end

module To_fields = struct
  (* helper function to check whether the fields we produce from JS are correct *)
  let fields_of_json (typ : ('var, 'value) Impl.Internal_Basic.Typ.typ) of_json
      (json : Js.js_string Js.t) : Impl.field array =
    let json = json |> Js.to_string |> Yojson.Safe.from_string in
    let value = of_json json in
    let (Typ typ) = typ in
    let fields, _ = typ.value_to_fields value in
    fields

  let account_update =
    fields_of_json (Mina_base.Account_update.Body.typ ()) body_of_json
end

let proof_cache_db = Proof_cache_tag.For_tests.create_db ()

module Hash_from_json = struct
  let account_update (p : Js.js_string Js.t) (network_id : Js.js_string Js.t) =
    p |> account_update_of_json
    |> Account_update.digest
         ~signature_kind:(get_network_id_of_js_string network_id)

  let transaction_commitments (tx_json : Js.js_string Js.t)
      (network_id : Js.js_string Js.t) =
    let signature_kind = get_network_id_of_js_string network_id in
    let tx =
      Zkapp_command.write_all_proofs_to_disk ~signature_kind ~proof_cache_db
      @@ Zkapp_command.of_json @@ Yojson.Safe.from_string
      @@ Js.to_string tx_json
    in
    let get_account_updates_hash xs =
      let hash_account_update (p : Account_update.t) =
        Zkapp_command.Digest.Account_update.create ~signature_kind p
      in
      Zkapp_command.Call_forest.accumulate_hashes ~hash_account_update xs
    in
    let commitment =
      let account_updates_hash =
        Zkapp_command.Call_forest.hash
          (get_account_updates_hash tx.account_updates)
      in
      Zkapp_command.Transaction_commitment.create ~account_updates_hash
    in
    let fee_payer = Account_update.of_fee_payer tx.fee_payer in
    let fee_payer_hash =
      Zkapp_command.Digest.Account_update.create ~signature_kind fee_payer
    in
    let full_commitment =
      Zkapp_command.Transaction_commitment.create_complete commitment
        ~memo_hash:(Mina_base.Signed_command_memo.hash tx.memo)
        ~fee_payer_hash
    in
    object%js
      val commitment = commitment

      val fullCommitment = full_commitment

      val feePayerHash = (fee_payer_hash :> Impl.field)
    end

  let zkapp_public_input (tx_json : Js.js_string Js.t)
      (account_update_index : int) =
    let signature_kind = Mina_signature_kind_type.Testnet in
    let tx =
      Zkapp_command.write_all_proofs_to_disk ~signature_kind ~proof_cache_db
      @@ Zkapp_command.of_json @@ Yojson.Safe.from_string
      @@ Js.to_string tx_json
    in
    let account_update = List.nth_exn tx.account_updates account_update_index in
    object%js
      val accountUpdate =
        (account_update.elt.account_update_digest :> Impl.field)

      val calls =
        (Zkapp_command.Call_forest.hash account_update.elt.calls :> Impl.field)
    end
end

module Hash_input = struct
  type random_oracle_input = Impl.field Random_oracle_input.Chunked.t

  let pack_input (input : random_oracle_input) : Impl.field array =
    Random_oracle.pack_input input

  (* hash inputs for various account_update subtypes *)
  let timing_input (json : Js.js_string Js.t) : random_oracle_input =
    let deriver = Account_update.Update.Timing_info.deriver in
    let json = json |> Js.to_string |> Yojson.Safe.from_string in
    let value = Fields_derivers_zkapps.(of_json (deriver @@ o ()) json) in
    let input = Account_update.Update.Timing_info.to_input value in
    input

  let permissions_input (json : Js.js_string Js.t) : random_oracle_input =
    let deriver = Mina_base.Permissions.deriver in
    let json = json |> Js.to_string |> Yojson.Safe.from_string in
    let value = Fields_derivers_zkapps.(of_json (deriver @@ o ()) json) in
    let input = Mina_base.Permissions.to_input value in
    input

  let update_input (json : Js.js_string Js.t) : random_oracle_input =
    let deriver = Account_update.Update.deriver in
    let json = json |> Js.to_string |> Yojson.Safe.from_string in
    let value = Fields_derivers_zkapps.(of_json (deriver @@ o ()) json) in
    let input = Account_update.Update.to_input value in
    input

  let account_precondition_input (json : Js.js_string Js.t) :
      random_oracle_input =
    let deriver = Mina_base.Zkapp_precondition.Account.deriver in
    let json = json |> Js.to_string |> Yojson.Safe.from_string in
    let value = Fields_derivers_zkapps.(of_json (deriver @@ o ()) json) in
    let input = Mina_base.Zkapp_precondition.Account.to_input value in
    input

  let network_precondition_input (json : Js.js_string Js.t) :
      random_oracle_input =
    let deriver = Mina_base.Zkapp_precondition.Protocol_state.deriver in
    let json = json |> Js.to_string |> Yojson.Safe.from_string in
    let value = Fields_derivers_zkapps.(of_json (deriver @@ o ()) json) in
    let input = Mina_base.Zkapp_precondition.Protocol_state.to_input value in
    input

  let body_input (json : Js.js_string Js.t) : random_oracle_input =
    let json = json |> Js.to_string |> Yojson.Safe.from_string in
    let value = body_of_json json in
    let input = Account_update.Body.to_input value in
    input
end

module Transaction_hash = struct
  module Signed_command = Mina_base.Signed_command
  module Signed_command_payload = Mina_base.Signed_command_payload

  let ok_exn result =
    let open Ppx_deriving_yojson_runtime.Result in
    match result with Ok c -> c | Error e -> failwith ("not ok: " ^ e)

  let keypair () = Signature_lib.Keypair.create ()

  let hash_payment (command : Js.js_string Js.t) =
    let command : Signed_command.t =
      command |> Js.to_string |> Yojson.Safe.from_string
      |> Signed_command.of_yojson |> ok_exn
    in
    Mina_transaction.Transaction_hash.(
      command |> hash_signed_command |> to_base58_check |> Js.string)

  let hash_zkapp_command (command : Js.js_string Js.t) =
    let command : Zkapp_command.Stable.Latest.t =
      command |> Js.to_string |> Yojson.Safe.from_string
      |> Zkapp_command.of_json
    in
    Mina_transaction.Transaction_hash.(
      command |> hash_zkapp_command |> to_base58_check |> Js.string)

  let hash_payment_v1 (command : Js.js_string Js.t) =
    let command : Signed_command.Stable.V1.t =
      command |> Js.to_string |> Yojson.Safe.from_string
      |> Signed_command.Stable.V1.of_yojson |> ok_exn
    in
    let b58 = Signed_command.to_base58_check_v1 command in
    Mina_transaction.Transaction_hash.(b58 |> digest_string |> to_base58_check)
    |> Js.string

  let serialize_common (command : Js.js_string Js.t) =
    let command : Signed_command_payload.Common.t =
      command |> Js.to_string |> Yojson.Safe.from_string
      |> Signed_command_payload.Common.of_yojson |> ok_exn
    in
    Binable.to_bigstring
      (module Signed_command_payload.Common.Stable.Latest)
      command

  let serialize_payment (command : Js.js_string Js.t) =
    let command : Signed_command.t =
      command |> Js.to_string |> Yojson.Safe.from_string
      |> Signed_command.of_yojson |> ok_exn
    in
    Binable.to_bigstring (module Signed_command.Stable.Latest) command

  let serialize_payment_v1 (command : Js.js_string Js.t) =
    let command : Signed_command.Stable.V1.t =
      command |> Js.to_string |> Yojson.Safe.from_string
      |> Signed_command.Stable.V1.of_yojson |> ok_exn
    in
    Signed_command.to_base58_check_v1 command |> Js.string

  let example_payment () =
    let kp = keypair () in
    let payload : Signed_command_payload.t =
      { Signed_command_payload.dummy with
        common =
          { Signed_command_payload.dummy.common with
            fee_payer_pk = Signature_lib.Public_key.compress kp.public_key
          }
      }
    in
    let signature_kind = Mina_signature_kind.t_DEPRECATED in
    let payment = Signed_command.sign ~signature_kind kp payload in
    (payment :> Signed_command.t)
    |> Signed_command.to_yojson |> Yojson.Safe.to_string |> Js.string
end

let test =
  object%js
    val encoding =
      let open Encoding in
      object%js
        val toBase58 = binary_string_to_base58_check

        val ofBase58 = binary_string_of_base58_check

        method publicKeyToBase58 = public_key_to_base58

        method publicKeyOfBase58 = public_key_of_base58

        method privateKeyToBase58 = private_key_to_base58

        method privateKeyOfBase58 = private_key_of_base58

        method tokenIdToBase58 = token_id_to_base58

        method tokenIdOfBase58 = token_id_of_base58

        method memoToBase58 = memo_to_base58

        method memoHashBase58 = memo_hash_base58
      end

    val tokenId =
      object%js
        method derive = Token_id.derive

        method deriveChecked = Token_id.derive_checked
      end

    val poseidon =
      object%js
        val hashToGroup = Poseidon.hash_to_group
      end

    val signature =
      object%js
        method signFieldElement = Signature.sign_field_element

        val dummySignature = Signature.dummy_signature
      end

    val fieldsFromJson =
      object%js
        method accountUpdate = To_fields.account_update
      end

    val hashFromJson =
      object%js
        method accountUpdate = Hash_from_json.account_update

        method transactionCommitments = Hash_from_json.transaction_commitments

        method zkappPublicInput = Hash_from_json.zkapp_public_input
      end

    val hashInputFromJson =
      let open Hash_input in
      object%js
        val packInput = pack_input

        val timing = timing_input

        val permissions = permissions_input

        val accountPrecondition = account_precondition_input

        val networkPrecondition = network_precondition_input

        val update = update_input

        val body = body_input
      end

    val transactionHash =
      let open Transaction_hash in
      object%js
        method hashPayment = hash_payment

        method hashPaymentV1 = hash_payment_v1

        method serializeCommon = serialize_common

        method serializePayment = serialize_payment

        method serializePaymentV1 = serialize_payment_v1

        method hashZkAppCommand = hash_zkapp_command

        val examplePayment = example_payment
      end
  end
