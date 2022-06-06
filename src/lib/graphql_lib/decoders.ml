(* decoders.ml -- decode Yojson to internal types *)

open Core_kernel

let optional ~f = function `Null -> None | json -> Some (f json)

let public_key json =
  Yojson.Basic.Util.to_string json
  |> Signature_lib.Public_key.of_base58_check_decompress_exn

let public_key_array = Array.map ~f:public_key

let optional_public_key = Option.map ~f:public_key

let uint64 json = Yojson.Basic.Util.to_string json |> Unsigned.UInt64.of_string

let optional_uint64 json = Option.map json ~f:uint64

let uint32 json = Yojson.Basic.Util.to_string json |> Unsigned.UInt32.of_string

let balance json =
  Yojson.Basic.Util.to_string json |> Currency.Balance.of_string

let optional_balance = Option.map ~f:balance

let amount json = Yojson.Basic.Util.to_string json |> Currency.Amount.of_string

let optional_amount = Option.map ~f:amount

let fee json = Yojson.Basic.Util.to_string json |> Currency.Fee.of_string

let nonce json =
  Yojson.Basic.Util.to_string json |> Mina_base.Account.Nonce.of_string

let optional_nonce_from_string = Option.map ~f:Mina_base.Account.Nonce.of_string

let token json =
  Yojson.Basic.Util.to_string json |> Mina_base.Token_id.of_string

let timing json = Mina_base.Account_timing.of_yojson json |> Result.ok

let optional_account_id (json : Yojson.Basic.t option) =
  Option.bind
    (json :> Yojson.Safe.t option)
    ~f:(Fn.compose Result.ok Mina_base.Account_id.of_yojson)

let optional_receipt_chain_hash_from_string =
  Option.map ~f:Mina_base.Receipt.Chain_hash.of_base58_check_exn

let optional_global_slot (json : Yojson.Basic.t option) =
  Option.bind
    (json :> Yojson.Safe.t option)
    ~f:(Fn.compose Result.ok Mina_numbers.Global_slot.of_yojson)

let state_hash (json : Yojson.Basic.t option) =
  Option.bind
    (json :> Yojson.Safe.t option)
    ~f:(Fn.compose Result.ok Mina_base.State_hash.of_yojson)
