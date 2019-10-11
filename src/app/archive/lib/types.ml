open Core
open Coda_base
open Signature_lib

(** Library used to encode and decode types to a graphql format.

    Unfortunately, the graphql_ppx does not have an "encode" attribute that
    allows us to map an OCaml type into some graphql schema type in a clean
    way. Therefore, we have to make our own encode and decode functions. On top
    of this, the generated GraphQL schema constructed by Hasura creates insert
    methods where the fields for each argument are optional, even though the
    inputs are explicitly labeled as NOT NULL in Postgres.Therefore, we are
    forced to lift the option types to these nested types. Furthermore, some
    types that are in Postgres but are not GraphQL primitive types are treated
    as custom scalars. These types include `bigint`, `bit(n)` and enums.
    graphql_ppx treats custom scalars as Yojson.Basic.t types (usually they are
    encoded as Json string types).

    **)

module type Numeric_intf = sig
  type t

  val num_bits : int

  val zero : t

  val one : t

  val ( lsl ) : t -> int -> t

  val ( lsr ) : t -> int -> t

  val ( land ) : t -> t -> t

  val ( lor ) : t -> t -> t

  val ( = ) : t -> t -> bool
end

module type Binary_intf = sig
  type t

  val to_bits : t -> bool list

  val of_bits : bool list -> t
end

module Bitstring : sig
  type t = private string

  val of_numeric : (module Numeric_intf with type t = 'a) -> 'a -> t

  val to_numeric : (module Numeric_intf with type t = 'a) -> t -> 'a

  val to_bitstring : (module Binary_intf with type t = 'a) -> 'a -> t

  val of_bitstring : (module Binary_intf with type t = 'a) -> t -> 'a

  val to_yojson : t -> Yojson.Basic.json

  val of_yojson : Yojson.Basic.json -> t
end = struct
  type t = string

  let to_string =
    Fn.compose String.of_char_list
      (List.map ~f:(fun bit -> if bit then '1' else '0'))

  let of_string_exn : t -> bool list =
    Fn.compose
      (List.map ~f:(function
        | '1' ->
            true
        | '0' ->
            false
        | bad_char ->
            failwithf !"Unexpected char: %c" bad_char () ))
      String.to_list

  let to_bitstring (type t) (module Binary : Binary_intf with type t = t)
      (value : t) =
    to_string @@ Binary.to_bits value

  let of_bitstring (type t) (module Binary : Binary_intf with type t = t) bits
      =
    Binary.of_bits @@ of_string_exn bits

  let of_numeric (type t) (module Numeric : Numeric_intf with type t = t)
      (value : t) =
    let open Numeric in
    to_string @@ List.init num_bits ~f:(fun i -> (value lsr i) land one = one)

  let to_numeric (type num) (module Numeric : Numeric_intf with type t = num)
      (bitstring : t) =
    let open Numeric in
    of_string_exn bitstring
    |> List.fold_right ~init:Numeric.zero ~f:(fun bool acc_num ->
           (acc_num lsl 1) lor if bool then one else zero )

  let to_yojson t = `String t

  let of_yojson = function
    | `String value ->
        value
    | _ ->
        failwith "Expected Yojson string"
end

module User_command_type = struct
  type t = [`Payment | `Delegation]

  let encode = function
    | `Payment ->
        `String "payment"
    | `Delegation ->
        `String "delegation"

  let decode = function
    | `String "payment" ->
        `Payment
    | `String "delegation" ->
        `Delegation
    | _ ->
        raise (Invalid_argument "Unexpected input to decode user command type")
end

module Make_Bitstring_converters (Bit : Binary_intf) = struct
  open Bitstring

  let serialize amount = to_yojson @@ to_bitstring (module Bit) amount

  let deserialize yojson = of_bitstring (module Bit) @@ of_yojson yojson
end

module Fee = Make_Bitstring_converters (Currency.Fee)
module Amount = Make_Bitstring_converters (Currency.Amount)
module Nonce = Make_Bitstring_converters (Account.Nonce)

module Block_time = struct
  let serialize value =
    Bitstring.to_yojson
    @@ Bitstring.of_numeric (module Int64)
    @@ Block_time.to_int64 value

  let deserialize value =
    Block_time.of_int64
    @@ Bitstring.to_numeric (module Int64)
    @@ Bitstring.of_yojson value
end

module User_command = struct
  let receiver user_command =
    match (User_command.payload user_command).body with
    | Payment payment ->
        payment.receiver
    | Stake_delegation (Set_delegate delegation) ->
        delegation.new_delegate

  let create_public_key_obj public_key =
    object
      method data =
        object
          method blocks = None

          method fee_transfers = None

          method userCommandsByReceiver = None

          method user_commands = None

          method value = Some public_key
        end

      method on_conflict =
        Option.some
        @@ object
             method constraint_ = `public_keys_value_key

             method update_columns = Array.of_list [`value]
           end
    end

  let encode {With_hash.data= user_command; hash} first_seen =
    let payload = User_command.payload user_command in
    let body = payload.body in
    let sender =
      Public_key.Compressed.to_base58_check @@ User_command.sender user_command
    in
    let receiver =
      Public_key.Compressed.to_base58_check @@ receiver user_command
    in
    let open Option in
    object
      method hash = some @@ Transaction_hash.to_base58_check hash

      method blocks_user_commands = None

      method amount =
        some
        @@ Amount.serialize
             ( match body with
             | Payment payment ->
                 payment.amount
             | Stake_delegation _ ->
                 Currency.Amount.zero )

      method fee = some @@ Fee.serialize (User_command.fee user_command)

      method first_seen = Option.map first_seen ~f:Block_time.serialize

      method memo =
        some @@ User_command_memo.to_string
        @@ User_command_payload.memo payload

      method nonce =
        some @@ Nonce.serialize @@ User_command_payload.nonce payload

      method public_key = some @@ create_public_key_obj sender

      method publicKeyByReceiver = some @@ create_public_key_obj receiver

      method sender = None

      method receiver = None

      method typ =
        some
        @@ User_command_type.encode
             ( match body with
             | Payment _ ->
                 `Payment
             | Stake_delegation _ ->
                 `Delegation )
    end

  let decode obj =
    let receiver = (obj#publicKeyByReceiver)#value in
    let sender = (obj#public_key)#value in
    let body =
      let open User_command_payload.Body in
      match obj#typ with
      | `Delegation ->
          Stake_delegation (Set_delegate {new_delegate= receiver})
      | `Payment ->
          Payment {receiver; amount= obj#amount}
    in
    let payload =
      User_command_payload.create ~fee:obj#fee ~nonce:obj#nonce ~memo:obj#memo
        ~body
    in
    ( Coda_base.{User_command.Poly.Stable.V1.payload; sender; signature= ()}
    , obj#first_seen )
end
