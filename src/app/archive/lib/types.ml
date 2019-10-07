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
module Length = Make_Bitstring_converters (Coda_numbers.Length)

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

let encode_as_insert_input ~constraint_name ~updated_columns data =
  object
    method data = data

    method on_conflict =
      Option.some
      @@ object
           method constraint_ = constraint_name

           method update_columns = Array.of_list updated_columns
         end
  end

module Public_key = struct
  let encode public_key =
    object
      method blocks = None

      method fee_transfers = None

      method userCommandsByReceiver = None

      method user_commands = None

      method value = Some public_key
    end

  let encode_as_insert_input public_key =
    object
      method data = encode public_key

      method on_conflict =
        Option.some
        @@ object
             method constraint_ = `public_keys_value_key

             method update_columns = Array.of_list [`value]
           end
    end
end

module User_command = struct
  let receiver user_command =
    match (User_command.payload user_command).body with
    | Payment payment ->
        payment.receiver
    | Stake_delegation (Set_delegate delegation) ->
        delegation.new_delegate

  let encode {With_hash.data= user_command; hash} first_seen =
    let payload = User_command.payload user_command in
    let body = payload.body in
    let sender =
      Signature_lib.Public_key.Compressed.to_base58_check
      @@ User_command.sender user_command
    in
    let receiver =
      Signature_lib.Public_key.Compressed.to_base58_check
      @@ receiver user_command
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

      method public_key = some @@ Public_key.encode_as_insert_input sender

      method publicKeyByReceiver =
        some @@ Public_key.encode_as_insert_input receiver

      method typ =
        some
        @@ User_command_type.encode
             ( match body with
             | Payment _ ->
                 `Payment
             | Stake_delegation _ ->
                 `Delegation )
    end

  let encode_as_insert_input user_command_with_hash first_seen =
    encode_as_insert_input ~constraint_name:`user_commands_hash_key
      ~updated_columns:[`first_seen]
      (encode user_command_with_hash first_seen)

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

module With_on_conflict = struct
  type ('constraint_, 'update_columns) on_conflict =
    < constraint_: 'constraint_ ; update_columns: 'update_columns array >

  type ('data, 'constraint_, 'update_columns) t =
    < data: 'data
    ; on_conflict: ('constraint_, 'update_columns) on_conflict option >

  type nonrec ('data, 'constraint_, 'update_columns) array =
    ('data array, 'constraint_, 'update_columns) t
end

module Fee_transfer = struct
  (* type ('block, 'm1, 'fee_transfer) t =
    (< data:
         < block:
             'block
             option
         ; block_id: int option
         ; fee_transfer:'fee_transfer array
     ; on_conflict:
         < constraint_: [< `blocks_fee_transfers_block_id_fee_transfer_id_key]
         ; update_columns: [< `block_id | `fee_transfer_id] array
         ; .. >
         option
     ; .. >
     )
    option *)

  type ('blocks_fee_transfer, 'public_key) insert_input =
    < blocks_fee_transfers: 'blocks_fee_transfer option
    ; fee: Yojson.Basic.json option
    ; first_seen: Yojson.Basic.json option
    ; hash: string option
    ; public_key: 'public_key option
    ; receiver: int option >

  type ('blocks_fee_transfer, 'public_key) rel_insert_input =
    ( ('blocks_fee_transfer, 'public_key) insert_input
    , [`fee_transfers_hash_key]
    , [`first_seen] )
    With_on_conflict.t

  let encode {With_hash.data: Fee_transfer.Single.t = (receiver, fee); hash}
      first_seen : ('blocks_fee_transfer, 'public_key) insert_input =
    let open Option in
    object
      method hash = some @@ Transaction_hash.to_base58_check hash

      method fee = some @@ Fee.serialize fee

      method first_seen = Option.map first_seen ~f:Block_time.serialize

      method public_key =
        some @@ Public_key.encode_as_insert_input
        @@ Signature_lib.Public_key.Compressed.to_base58_check receiver

      method receiver = None

      method blocks_fee_transfers = None
    end

  let encode_as_insert_input fee_transfer_with_hash first_seen :
      ('blocks_fee_transfer, 'public_key) rel_insert_input =
    encode_as_insert_input ~constraint_name:`fee_transfers_hash_key
      ~updated_columns:[`first_seen]
      (encode fee_transfer_with_hash first_seen)
end

module Receipt_chain_hash = struct
  type t = {value: Receipt.Chain_hash.t; parent: Receipt.Chain_hash.t}

  let to_obj value parent =
    object
      method blocks_user_commands = None

      method hash = value

      method receipt_chain_hash = None

      method receipt_chain_hashes = parent
    end

  (* HACK: An indication of what the type of receipt chain object input should be *)
  type ('f, 'g) obj_input =
    < data:
        (< blocks_user_commands: 'f option
         ; hash: string option
         ; receipt_chain_hash: 'g option
         ; receipt_chain_hashes:
             < data: 'h array
             ; on_conflict:
                 < constraint_:
                     [< `receipt_chain_hashes_hash_key
                     | `receipt_chain_hashes_pkey ]
                 ; update_columns: [< `hash | `parent_id] array >
                 option
             ; .. >
             option
         ; .. >
         as
         'h)
    ; on_conflict:
        < constraint_:
            [< `receipt_chain_hashes_hash_key | `receipt_chain_hashes_pkey]
        ; update_columns: [< `hash | `parent_id] array >
        option
    ; .. >
    as
    'g

  let encode t : ('f, 'g) obj_input =
    let open Option in
    let on_conflict =
      object
        method constraint_ = `receipt_chain_hashes_hash_key

        method update_columns = Array.of_list [`hash]
      end
    in
    let parent =
      to_obj (some @@ Receipt.Chain_hash.to_string @@ t.parent) None
    in
    object
      method data =
        to_obj
          (some @@ Receipt.Chain_hash.to_string @@ t.value)
          ( some
          @@ object
               method data = Array.of_list [parent]

               method on_conflict = some on_conflict
             end )

      method on_conflict = some on_conflict
    end
end

module Blocks_user_commands = struct
  let encode user_command_with_hash first_seen receipt_chain_opt =
    object
      method block = None

      method receipt_chain_hash =
        Option.map receipt_chain_opt ~f:Receipt_chain_hash.encode

      method user_command =
        Some
          (User_command.encode_as_insert_input user_command_with_hash
             first_seen)
    end

  let encode_as_insert_input user_commands =
    encode_as_insert_input
      ~constraint_name:
        `blocks_user_commands_block_id_user_command_id_receipt_chain_has
      ~updated_columns:[`block_id; `user_command_id; `receipt_chain_hash_id]
      ( Array.of_list
      @@ List.map user_commands
           ~f:(fun (user_command_with_hash, first_seen, receipt_chain) ->
             encode user_command_with_hash first_seen receipt_chain ) )
end

module Blocks_fee_transfers = struct
  (* blocks_fee_transfers_arr_rel_insert_input *)
  type ('block, 'fee_transfer) insert_input =
    < block: 'block option
    ; block_id: int option
    ; fee_transfer: 'fee_transfer option
    ; fee_transfer_id: int option >

  type ('block, 'fee_transfer) rel_insert_input =
    ( ('block, 'fee_transfer) insert_input
    , [`blocks_fee_transfers_block_id_fee_transfer_id_key]
    , [`block_id | `fee_transfer_id] )
    With_on_conflict.array

  let encode fee_transfer first_seen =
    object
      method block = None

      method block_id = None

      method fee_transfer =
        Some (Fee_transfer.encode_as_insert_input fee_transfer first_seen)

      method fee_transfer_id = None
    end

  let encode_as_insert_input fee_transfers :
      ('block, 'fee_transfer) rel_insert_input =
    encode_as_insert_input
      ~constraint_name:`blocks_fee_transfers_block_id_fee_transfer_id_key
      ~updated_columns:[`block_id; `fee_transfer_id]
      ( Array.of_list
      @@ List.map fee_transfers
           ~f:(fun (fee_transfers_with_hash, first_seen) ->
             encode fee_transfers_with_hash first_seen ) )
end

module Blocks = struct
  let serialize
      (With_hash.{hash; data= external_transition} :
        (External_transition.t, State_hash.t) With_hash.t)
      (user_commands :
        ( (Coda_base.User_command.t, Transaction_hash.t) With_hash.t
        * Coda_base.Block_time.t option
        * Receipt_chain_hash.t option )
        list)
      (fee_transfers :
        ( (Coda_base.Fee_transfer.Single.t, Transaction_hash.t) With_hash.t
        * Coda_base.Block_time.t option )
        list) =
    let blockchain_state =
      External_transition.blockchain_state external_transition
    in
    let consensus_state =
      External_transition.consensus_state external_transition
    in
    let global_slot =
      Consensus.Data.Consensus_state.global_slot consensus_state
    in
    let open Option in
    object
      method state_hash = some @@ State_hash.to_base58_check hash

      method creator = None

      method public_key =
        some @@ Public_key.encode_as_insert_input
        @@ Signature_lib.Public_key.Compressed.to_base58_check
        @@ External_transition.proposer external_transition

      method parent_hash =
        some @@ State_hash.to_base58_check
        @@ External_transition.parent_hash external_transition

      method ledger_hash =
        some @@ Ledger_hash.to_string @@ Staged_ledger_hash.ledger_hash
        @@ Blockchain_state.staged_ledger_hash blockchain_state

      method global_slot = some global_slot

      method ledger_proof_nonce = some 0

      method status = some 0

      method block_length =
        some @@ Length.serialize
        @@ Consensus.Data.Consensus_state.blockchain_length consensus_state

      method block_time =
        some @@ Block_time.serialize
        @@ External_transition.timestamp external_transition

      method blocks_fee_transfers =
        some @@ Blocks_fee_transfers.encode_as_insert_input fee_transfers

      method blocks_snark_jobs = None

      method blocks_user_commands =
        some @@ Blocks_user_commands.encode_as_insert_input user_commands
    end
end
