(**  Low-level dependency make graphql_query.ml compile less often, which takes a long time **)
open Core

open Mina_base

module type Num_input = sig
  type t

  val of_string : string -> t

  val to_string : t -> string

  val of_int : int -> t
end

module type Numeric = sig
  type t

  val serialize : t -> Yojson.Basic.t

  val parse : Yojson.Basic.t -> t
end

module Make_numeric (Input : Num_input) : Numeric with type t = Input.t = struct
  open Input

  type nonrec t = t

  let serialize (t : t) = `String (to_string t)

  let parse = function
    | `String (value : string) ->
        of_string value
    | `Int (value : int) ->
        of_int value
    | _ ->
        failwith "Expected Yojson string"
end

module User_command_type = struct
  type t = [ `Payment | `Delegation ]

  let serialize = function
    | `Payment ->
        `String "payment"
    | `Delegation ->
        `String "delegation"

  let parse = function
    | `String "payment" ->
        `Payment
    | `String "delegation" ->
        `Delegation
    | _ ->
        raise (Invalid_argument "Unexpected input to decode user command type")
end

module Fee = Make_numeric (struct
  include Currency.Fee

  let of_int = of_nanomina_int_exn
end)

module Amount = Make_numeric (struct
  include Currency.Amount

  let of_int = of_nanomina_int_exn
end)

module Nonce = Make_numeric (Account.Nonce)
module Length = Make_numeric (Mina_numbers.Length)

module Block_time = Make_numeric (struct
  type t = Block_time.t

  let to_string = Block_time.to_string_exn

  let of_string = Block_time.of_string_exn

  let of_int = Fn.compose Block_time.of_int64 Int64.of_int
end)

module Optional_block_time = Graphql_lib.Serializing.Optional (Block_time)
