open Core
open Coda_base
open Coda_transition
open Signature_lib
module Time = Block_time

(** Block_data is the external_transition data that GraphQL needs *)
module Block_data = struct
  module Transactions = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type t =
            { user_commands: User_command.Stable.V1.t list
            ; fee_transfers: Fee_transfer.Single.Stable.V1.t list
            ; coinbase: Currency.Amount.Stable.V1.t }
          [@@deriving bin_io, version {unnumbered}]
        end

        include T
      end

      module Latest = V1
    end

    type t = Stable.Latest.t =
      { user_commands: User_command.t list
      ; fee_transfers: Fee_transfer.Single.t list
      ; coinbase: Currency.Amount.t }
  end

  module Protocol_state = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type t =
            { previous_state_hash: State_hash.Stable.V1.t
            ; blockchain_state: Coda_state.Blockchain_state.Value.Stable.V1.t
            }
          [@@deriving bin_io, version {unnumbered}]
        end

        include T
      end

      module Latest = V1
    end

    type t = Stable.Latest.t =
      { previous_state_hash: State_hash.t
      ; blockchain_state: Coda_state.Blockchain_state.Value.t }
  end

  module Stable = struct
    module V1 = struct
      module T = struct
        type t =
          { creator: Public_key.Compressed.Stable.V1.t
          ; protocol_state: Protocol_state.Stable.V1.t
          ; transactions: Transactions.Stable.V1.t }
        [@@deriving bin_io, version {unnumbered}]
      end

      include T
    end

    module Latest = V1
  end

  type t = Stable.Latest.t =
    { creator: Public_key.Compressed.t
    ; protocol_state: Protocol_state.t
    ; transactions: Transactions.t }

  let of_transition external_transition =
    let open External_transition.Validated in
    let creator = proposer external_transition in
    let protocol_state =
      { Protocol_state.previous_state_hash= parent_hash external_transition
      ; blockchain_state=
          Coda_state.Protocol_state.blockchain_state
          @@ protocol_state external_transition }
    in
    let open Result.Let_syntax in
    let%map calculated_transactions =
      Staged_ledger.Pre_diff_info.get_transactions
      @@ staged_ledger_diff external_transition
    in
    let transactions =
      List.fold calculated_transactions
        ~init:
          { Transactions.user_commands= []
          ; fee_transfers= []
          ; coinbase= Currency.Amount.zero } ~f:(fun acc_transactions ->
        function
        | User_command user_command ->
            { acc_transactions with
              user_commands=
                User_command.forget_check user_command
                :: acc_transactions.user_commands }
        | Fee_transfer fee_transfer ->
            let fee_transfers =
              match fee_transfer with
              | One fee_transfer1 ->
                  [fee_transfer1]
              | Two (fee_transfer1, fee_transfer2) ->
                  [fee_transfer1; fee_transfer2]
            in
            { acc_transactions with
              fee_transfers= fee_transfers @ acc_transactions.fee_transfers }
        | Coinbase {Coinbase.amount; _} ->
            { acc_transactions with
              coinbase=
                Currency.Amount.(
                  Option.value_exn (add amount acc_transactions.coinbase)) } )
    in
    {creator; protocol_state; transactions}
end

module Database = struct
  module Value = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type t = Block_data.Stable.V1.t * Time.Stable.V1.t
          [@@deriving bin_io, version {unnumbered}]
        end

        include T
      end
    end
  end

  include Rocksdb.Serializable.Make (State_hash.Stable.V1) (Value.Stable.V1)
end

module Pagination = Pagination.Make (State_hash.Stable.V1) (Time.Stable.V1)

let user_command_participants user_command =
  let sender = User_command.sender user_command in
  let payload = User_command.payload user_command in
  let receiver =
    match User_command_payload.body payload with
    | Stake_delegation (Set_delegate {new_delegate}) ->
        new_delegate
    | Payment {receiver; _} ->
        receiver
  in
  [receiver; sender]

let fee_transfer_participants (pk, _) = [pk]

type t = {pagination: Pagination.t; database: Database.t; logger: Logger.t}

let add_user_blocks (pagination : Pagination.t)
    ( {With_hash.hash= state_hash; data= {Block_data.transactions; creator; _}}
    , time ) =
  Hashtbl.set pagination.all_values ~key:state_hash ~data:time ;
  List.iter transactions.fee_transfers ~f:(fun fee_transfer ->
      let participants = fee_transfer_participants fee_transfer in
      Pagination.add_involved_participants pagination participants
        (state_hash, time) ) ;
  List.iter transactions.user_commands ~f:(fun user_command ->
      let participants = user_command_participants user_command in
      Pagination.add_involved_participants pagination participants
        (state_hash, time) ) ;
  Pagination.add_involved_participants pagination [creator] (state_hash, time)

let create ~logger directory =
  let database = Database.create ~directory in
  let pagination = Pagination.create () in
  List.iter (Database.to_alist database) ~f:(fun (hash, (block_data, time)) ->
      add_user_blocks pagination ({With_hash.hash; data= block_data}, time) ) ;
  { database= Database.create ~directory
  ; pagination= Pagination.create ()
  ; logger }

let add {database; pagination; logger}
    {With_hash.hash= state_hash; data= external_transition} date =
  match Hashtbl.find pagination.all_values state_hash with
  | Some _ ->
      Logger.trace logger
        !"Not adding transition into external transition database since it \
          already exists: $transaction"
        ~module_:__MODULE__ ~location:__LOC__
        ~metadata:[("transaction", State_hash.to_yojson state_hash)]
  | None -> (
    match Block_data.of_transition external_transition with
    | Ok block ->
        Database.set database ~key:state_hash ~data:(block, date) ;
        add_user_blocks pagination
          ({With_hash.hash= state_hash; data= block}, date)
    | Error error ->
        Logger.error logger
          !"Could not extract transactions from external_transition \
            $state_hash: %s"
          ~module_:__MODULE__ ~location:__LOC__
          ( Error.to_string_hum
          @@ Protocols.Coda_pow.Pre_diff_error.to_error User_command.sexp_of_t
               error )
          ~metadata:[("state_hash", State_hash.to_yojson state_hash)] )

let get_total_values {pagination; _} = Pagination.get_total_values pagination

let get_values {pagination; _} = Pagination.get_values pagination

let get_earlier_values {pagination; _} =
  Pagination.get_earlier_values pagination

let get_later_values {pagination; _} = Pagination.get_later_values pagination

let close {database; _} = Database.close database
