(**  Low-level dependency make graphql_query.ml compile less often, which takes a long time **)
open Core

open Coda_base

module Make_numeric (Input : sig
  type t

  val of_string : string -> t

  val to_string : t -> string

  val of_int : int -> t
end) : sig
  type t = Input.t

  val serialize : t -> Yojson.Basic.json

  val deserialize : Yojson.Basic.json -> t
end = struct
  open Input

  type nonrec t = t

  let serialize (t : t) = `String (to_string t)

  let deserialize = function
    | `String (value : string) ->
        of_string value
    | `Int (value : int) ->
        of_int value
    | _ ->
        failwith "Expected Yojson string"
end

module User_command_type = struct
  type t =
    [`Payment | `Delegation | `Mint | `Mint_new | `Blacklist | `Whitelist]

  let encode = function
    | `Payment ->
        `String "payment"
    | `Delegation ->
        `String "delegation"
    | `Mint ->
        `String "mint"
    | `Mint_new ->
        `String "mint new"
    | `Blacklist ->
        `String "blacklist"
    | `Whitelist ->
        `String "whitelist"

  let decode = function
    | `String "payment" ->
        `Payment
    | `String "delegation" ->
        `Delegation
    | `String "mint" ->
        `Mint
    | `String "mint new" ->
        `Mint_new
    | `String "blacklist" ->
        `Blacklist
    | `String "whitelist" ->
        `Whitelist
    | _ ->
        raise (Invalid_argument "Unexpected input to decode user command type")
end

module Fee = Make_numeric (Currency.Fee)
module Amount = Make_numeric (Currency.Amount)
module Nonce = Make_numeric (Account.Nonce)
module Length = Make_numeric (Coda_numbers.Length)

module Block_time = Make_numeric (struct
  type t = Block_time.t

  let to_string = Block_time.to_string

  let of_string = Block_time.of_string_exn

  let of_int = Fn.compose Block_time.of_int64 Int64.of_int
end)

let deserialize_optional_block_time = Option.map ~f:Block_time.deserialize
