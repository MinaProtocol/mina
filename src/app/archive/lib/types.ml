open Core
open Coda_base
open Signature_lib

(** Library used to encode and decode types to a graphql format. 
    
    Unfortunately, the graphql_ppx does not have an "encode" attribute that allows us to map an OCaml type into some graphql schema type in a clean way. Therefore, we have to make our own encode and decode functions. On top of this, the generated GraphQL schema constructed by Hasura creates insert methods where the input fields are optional, even though the inputs are explicitly labeled as NOT NULL in Postgres. Additionally, graphql_ppx does not let us redefine a new type to make these optional inputs mandatory. Therefore, we are forced to lift the option types to some of our types. Furthermore, some types that are in Postgres but are not GraphQL primitive types are treated as custom scalars. These types include `bigint`, `bit(n)` and enums. graphql_ppx treats custom scalars as Yojson.Basic.t types (usually they are encoded as Json string types). 
    
    As a result, encoding a type to a Hasura input is broken into two phases: 
    1. Postgres phase: This phase converts OCaml type (such as blocks and transactions) to some intermediate representation that is very similar to their respective Postgres schema type. 
    2. Graphql object phase: The intermediate Postgres types are converted directly to some input that the Hasura Graphql schema would accept. This is essentially lifting types with the Option type and coercing Postgres custom scalar into Yojson types 
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

module Public_key = struct
  type postgres = {value: string}

  let serialize public_key =
    {value= Public_key.Compressed.to_base58_check public_key}

  let to_graphql_obj {value; _} =
    object
      method value = Some value

      method user_commands = None

      method userCommandsByReceiver = None

      method fee_transfers = None

      method blocks = None
    end

  let encode = Fn.compose to_graphql_obj serialize
end

module Block_time = struct
  let serialize value =
    Bitstring.of_numeric (module Int64) @@ Block_time.to_int64 value

  let deserialize value =
    Block_time.of_int64 @@ Bitstring.to_numeric (module Int64) value
end

module User_command = struct
  type postgres =
    { fee: Bitstring.t
    ; hash: string
    ; memo: string
    ; nonce: Bitstring.t
    ; receiver: int
    ; sender: int
    ; typ: [`Payment | `Delegation]
    ; amount: Bitstring.t
    ; first_seen: Bitstring.t option }

  let serialize {With_hash.data= user_command; hash} (`Receiver receiver_id)
      (`Sender sender_id) first_seen =
    let payload = User_command.payload user_command in
    let body = payload.body in
    let open Bitstring in
    { amount=
        to_bitstring
          (module Currency.Amount)
          ( match body with
          | Payment payment ->
              payment.amount
          | Stake_delegation _ ->
              Currency.Amount.zero )
    ; fee= to_bitstring (module Currency.Fee) (User_command.fee user_command)
    ; first_seen= Option.map first_seen ~f:Block_time.serialize
    ; hash= Transaction_hash.to_base58_check hash
    ; memo= User_command_memo.to_string @@ User_command_payload.memo payload
    ; nonce=
        to_bitstring (module Coda_numbers.Account_nonce)
        @@ User_command_payload.nonce payload
    ; sender= sender_id
    ; receiver= receiver_id
    ; typ=
        ( match body with
        | Payment _ ->
            `Payment
        | Stake_delegation _ ->
            `Delegation ) }

  let to_graphql_obj
      {fee; hash; memo; nonce; receiver; sender; typ; amount; first_seen} =
    let open Option in
    object
      method hash = some hash

      method blocks_user_commands = None

      method amount = some @@ Bitstring.to_yojson amount

      method fee = some @@ Bitstring.to_yojson fee

      method first_seen = Option.map first_seen ~f:Bitstring.to_yojson

      method memo = some @@ memo

      method nonce = some @@ Bitstring.to_yojson nonce

      method public_key = None

      method publicKeyByReceiver = None

      method sender = some sender

      method receiver = some receiver

      method typ = some @@ User_command_type.encode typ
    end

  let encode ~receiver ~sender user_command_with_hash block_time =
    to_graphql_obj
    @@ serialize user_command_with_hash (`Receiver receiver) (`Sender sender)
         (Some block_time)

  let decode
      {fee; hash= _; memo; nonce; receiver; sender; typ; amount; first_seen= _}
      public_keys_map =
    let receiver = Map.find_exn public_keys_map receiver in
    let sender = Map.find_exn public_keys_map sender in
    let body =
      let open User_command_payload.Body in
      match typ with
      | `Delegation ->
          Stake_delegation (Set_delegate {new_delegate= receiver})
      | `Payment ->
          Payment
            { receiver
            ; amount= Bitstring.of_bitstring (module Currency.Amount) amount }
    in
    let payload =
      User_command_payload.create
        ~fee:(Bitstring.of_bitstring (module Currency.Fee) fee)
        ~nonce:
          (Bitstring.of_bitstring (module Coda_numbers.Account_nonce) nonce)
        ~memo:(User_command_memo.of_string memo)
        ~body
    in
    Coda_base.{User_command.Poly.Stable.V1.payload; sender; signature= ()}
end
