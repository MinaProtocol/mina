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

  val one : t

  val ( lsr ) : t -> int -> t

  val ( land ) : t -> t -> t

  val ( = ) : t -> t -> bool
end

module type Binary_intf = sig
  type t

  val to_bits : t -> bool list
end

module Bitstring : sig
  type t = private string

  val of_numeric : (module Numeric_intf with type t = 'a) -> 'a -> t

  val to_bitstring : (module Binary_intf with type t = 'a) -> 'a -> t

  val to_yojson : t -> Yojson.Basic.json
end = struct
  type t = string

  let to_string =
    Fn.compose String.of_char_list
      (List.map ~f:(fun bit -> if bit then '1' else '0'))

  let to_bitstring (type t) (module Binary : Binary_intf with type t = t)
      (value : t) =
    to_string @@ Binary.to_bits value

  let of_numeric (type t) (module Numeric : Numeric_intf with type t = t)
      (value : t) =
    let open Numeric in
    to_string @@ List.init num_bits ~f:(fun i -> (value lsr i) land one = one)

  let to_yojson t = `String t
end

module User_command_type = struct
  type t = [`Payment | `Delegation]

  let encode = function
    | `Payment ->
        `String "payment"
    | `Delegation ->
        `String "delegation"
end

module User_command = struct
  type postgres =
    { fee: Bitstring.t
    ; hash: string
    ; memo: string
    ; nonce: Bitstring.t
    ; receiver: string
    ; sender: string
    ; typ: [`Payment | `Delegation]
    ; amount: Bitstring.t
    ; first_seen: Bitstring.t option }

  let serialize {With_hash.data= user_command; hash} first_seen =
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
    ; first_seen=
        Option.map first_seen ~f:(fun value ->
            of_numeric (module Int64) @@ Block_time.to_int64 value )
    ; hash= Transaction_hash.to_base58_check hash
    ; memo= User_command_memo.to_string @@ User_command_payload.memo payload
    ; nonce=
        to_bitstring (module Coda_numbers.Account_nonce)
        @@ User_command_payload.nonce payload
    ; sender=
        Public_key.Compressed.to_base58_check @@ Public_key.compress
        @@ user_command.sender
    ; receiver=
        ( Public_key.Compressed.to_base58_check
        @@
        match payload.body with
        | Payment payment ->
            payment.receiver
        | Stake_delegation (Set_delegate delegation) ->
            delegation.new_delegate )
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
      method id = None

      method hash = some hash

      method blocks_user_commands = None

      method amount = some @@ Bitstring.to_yojson amount

      method fee = some @@ Bitstring.to_yojson fee

      method first_seen = Option.map first_seen ~f:Bitstring.to_yojson

      method memo = some @@ memo

      method nonce = some @@ Bitstring.to_yojson nonce

      method sender = some sender

      method receiver = some receiver

      method typ = some @@ User_command_type.encode typ
    end

  let encode user_command block_time =
    let user_command_with_hash =
      With_hash.of_data user_command
        ~hash_data:Transaction_hash.hash_user_command
    in
    to_graphql_obj @@ serialize user_command_with_hash (Some block_time)
end
