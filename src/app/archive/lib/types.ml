open Core
open Coda_base
open Coda_state
open Coda_transition
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

module Graphql_output = struct
  module With_first_seen = struct
    module Make (Hash : sig
      type t
    end) =
    struct
      type t = {id: int; hash: Hash.t; first_seen: Block_time.t option}
      [@@deriving fields]
    end

    module Transaction_hash = Make (Transaction_hash)
  end

  module Public_keys = struct
    type t = {id: int; value: Public_key.Compressed.t} [@@deriving fields]
  end

  module Blocks = struct
    type t = {id: int; state_hash: State_hash.t} [@@deriving fields]
  end
end

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

module Fee_transfer = struct
  type postgres =
    { fee: Bitstring.t
    ; first_seen: Bitstring.t option
    ; hash: string
    ; receiver: int }

  let serialize {With_hash.data= fee_transfer; hash} receiver_id first_seen =
    { first_seen= Option.map first_seen ~f:Block_time.serialize
    ; hash= Transaction_hash.to_base58_check hash
    ; receiver= receiver_id
    ; fee= Bitstring.to_bitstring (module Currency.Fee) (snd fee_transfer) }

  let to_graphql_obj {first_seen; hash; receiver; fee} =
    let open Option in
    object
      method hash = some hash

      method fee = some @@ Bitstring.to_yojson fee

      method first_seen = Option.map first_seen ~f:Bitstring.to_yojson

      method public_key = None

      method receiver = some receiver

      method blocks_fee_transfers = None
    end

  let encode fee_transfer_with_hash receiver block_time =
    to_graphql_obj
    @@ serialize fee_transfer_with_hash receiver (Some block_time)
end

(* module Blocks_user_commands = struct
  type postgres = {
    block_id: int;
    user_command_id: int
  }

  let serialize = Fn.id
end *)

module Blocks = struct
  type postgres =
    { state_hash: string
    ; creator: int
    ; parent_hash: string
    ; ledger_hash: string
    ; global_slot: int
    ; ledger_proof_nonce: int
    ; status: int (* Default is zero*)
    ; block_length: Bitstring.t
    ; block_time: Bitstring.t
    ; user_commands: int list }

  type graphql_output = {id: int; state_hash: State_hash.t}

  let serialize
      (With_hash.{hash; data= external_transition} :
        (External_transition.t, State_hash.t) With_hash.t) user_commands
      creator : postgres =
    let blockchain_state =
      External_transition.blockchain_state external_transition
    in
    let consensus_state =
      External_transition.consensus_state external_transition
    in
    let global_slot =
      Consensus.Data.Consensus_state.global_slot consensus_state
    in
    let block_length =
      Consensus.Data.Consensus_state.blockchain_length consensus_state
    in
    let block_length =
      Bitstring.to_bitstring (module Coda_numbers.Length) block_length
    in
    { state_hash= State_hash.to_base58_check hash
    ; creator
    ; parent_hash=
        State_hash.to_base58_check
        @@ External_transition.parent_hash external_transition
    ; ledger_hash=
        Ledger_hash.to_string @@ Staged_ledger_hash.ledger_hash
        @@ Blockchain_state.staged_ledger_hash blockchain_state
    ; global_slot
    ; ledger_proof_nonce= 0
    ; status= 0
    ; block_length
    ; block_time=
        Block_time.serialize
        @@ External_transition.timestamp external_transition
    ; user_commands }

  let to_graphql_obj
      { state_hash
      ; creator
      ; parent_hash
      ; ledger_hash
      ; global_slot
      ; ledger_proof_nonce
      ; status
      ; block_length
      ; block_time
      ; user_commands } =
    let open Option in
    object
      method state_hash = some state_hash

      method creator = some creator

      method parent_hash = some parent_hash

      method ledger_hash = some ledger_hash

      method global_slot = some global_slot

      method ledger_proof_nonce = some ledger_proof_nonce

      method status = some status

      method block_length = some @@ Bitstring.to_yojson block_length

      method block_time = some @@ Bitstring.to_yojson block_time

      method blocks_fee_transfers = None

      method blocks_snark_jobs = None

      method blocks_user_commands =
        some
        @@ object
             method data =
               Array.map (Array.of_list user_commands)
                 ~f:(fun user_command_id ->
                   object
                     method block = None

                     method block_id = None

                     method receipt_chain_hash = None

                     method receipt_chain_hash_id = None

                     method user_command = None

                     method user_command_id = some user_command_id
                   end )
           end

      method public_key = None
    end

  let encode external_transition user_command_ids creator =
    to_graphql_obj @@ serialize external_transition user_command_ids creator
end
