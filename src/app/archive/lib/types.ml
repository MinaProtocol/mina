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

let encode_as_insert_input ~constraint_name ~updated_column data =
  object
    method data = Array.of_list [data]

    method on_conflict =
      Option.some
      @@ object
           method constraint_ = constraint_name

           method update_columns = Array.of_list [updated_column]
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

  let encode_as_insert_input user_command_with_hash first_seen =
    encode_as_insert_input ~constraint_name:`user_commands_hash_key
      ~updated_column:`first_seen
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

module Fee_transfer = struct
  let encode {With_hash.data: Fee_transfer.Single.t = (receiver, fee); hash}
      first_seen =
    let open Option in
    object
      method hash = some @@ Transaction_hash.to_base58_check hash

      method fee = some @@ Fee.serialize fee

      method first_seen = Option.map first_seen ~f:Block_time.serialize

      method public_key = None

      method receiver = some @@ Public_key.encode_as_insert_input receiver

      method blocks_fee_transfers = None
    end

  let encode_as_insert_input fee_transfer_with_hash first_seen =
    object
      method data = encode fee_transfer_with_hash first_seen

      method on_conflict =
        Option.some
        @@ object
             method constraint_ = `user_commands_hash_key

             method update_columns = Array.of_list [`first_seen]
           end
    end
end

module Receipt_chain_hash = struct
  let encode hash previous_hash =
    let open Option in
    object
      (* May have to cut id *)
      method blocks_user_commands = None

      method hash = some @@ Receipt.Chain_hash.to_bytes @@ hash

      method parent_id = None

      method receipt_chain_hash = None

      (* TODO: check if this is correct *)
      method receipt_chain_hashes =
        some
        @@ object
             method data =
               some
               @@ object
                    method blocks_user_commands = None

                    method hash =
                      some @@ Receipt.Chain_hash.to_bytes @@ previous_hash

                    method parent_id = None

                    method receipt_chain_hash = None

                    method receipt_chain_hashes = None
                  end

             method on_conflict =
               some
               @@ object
                    method constraint_ = `receipt_chain_hashes_hash_key

                    method update_columns = Array.of_list [`hash]
                  end
           end
      (* method receipt_chain_hash = object
        method data = object
          method blocks
        end
      end *)
    end
end

(* module Snark_job = struct
  let encode (snark_job_ids) =

end *)

module Blocks = struct
  let serialize
      (With_hash.{hash; data= external_transition} :
        (External_transition.t, State_hash.t) With_hash.t)
      (user_commands_with_hashes_and_time :
        ( (Coda_base.User_command.t, Transaction_hash.t) With_hash.t
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
    (* let staged_ledger_diff = External_transition.staged_ledger_diff external_transition in
    let snark_jobs =
        List.map
          (Staged_ledger_diff.completed_works staged_ledger_diff)
          ~f:Transaction_snark_work.info
    in *)
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

      method blocks_fee_transfers = None

      method blocks_snark_jobs = None

      (* some @@ User_command.encode_as_insert_input user_commands *)
      method blocks_user_commands =
        object
          method data =
            Array.of_list
            @@ List.map user_commands_with_hashes_and_time
                 ~f:(fun (user_command_with_hash, first_seen) ->
                   object
                     (* TODO: Might have to remove block *)
                     method block = None

                     method block_id = None

                     (* TODO: fill in the receipt chain hash *)
                     method receipt_chain_hash = None

                     method receipt_chain_hash_id = None

                     method user_command =
                       some
                       @@ User_command.encode_as_insert_input
                            user_command_with_hash first_seen

                     method user_command_id = None
                   end )

          method on_conflict =
            some
            @@ object
                 method constraint_ =
                   `blocks_user_commands_block_id_user_command_id_receipt_chain_has

                 method update_columns =
                   Array.of_list
                     [`block_id; `user_command_id; `receipt_chain_hash_id]
               end
        end
    end
end
