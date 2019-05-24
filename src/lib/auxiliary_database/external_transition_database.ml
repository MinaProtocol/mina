open Core
open Coda_base
open Coda_transition
module Time = Block_time

module Database = struct
  module Value = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type t = External_transition.Validated.Stable.V1.t * Time.Stable.V1.t
          [@@deriving bin_io, version {unnumbered}]
        end

        include T
      end
    end
  end

  include Rocksdb.Serializable.Make (State_hash.Stable.V1) (Value.Stable.V1)
end

module Pagination = Pagination.Make (State_hash.Stable.V1) (Time.Stable.V1)

let get_participants (transaction : Transaction.t) =
  match transaction with
  | Fee_transfer (One (pk, _)) ->
      [pk]
  | Fee_transfer (Two ((pk1, _), (pk2, _))) ->
      [pk1; pk2]
  | Coinbase {Coinbase.proposer; fee_transfer; _} ->
      Option.value_map fee_transfer ~default:[proposer] ~f:(fun (pk, _) ->
          [proposer; pk] )
  | User_command checked_user_command ->
      let user_command = User_command.forget_check checked_user_command in
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

type t = {pagination: Pagination.t; database: Database.t; logger: Logger.t}

let add_user_blocks ~logger (pagination : Pagination.t)
    ({With_hash.data= external_transition; hash= state_hash}, time) =
  Hashtbl.set pagination.all_values ~key:state_hash ~data:time ;
  let staged_ledger_diff =
    External_transition.Validated.staged_ledger_diff external_transition
  in
  match Staged_ledger.Pre_diff_info.get_transactions staged_ledger_diff with
  | Error staged_ledger_error ->
      Logger.error logger
        !"Could not extract transactions from external_transition \
          $state_hash: %s"
        ~module_:__MODULE__ ~location:__LOC__
        ( Error.to_string_hum
        @@ Protocols.Coda_pow.Pre_diff_error.to_error User_command.sexp_of_t
             staged_ledger_error )
        ~metadata:[("state_hash", State_hash.to_yojson state_hash)]
  | Ok transactions ->
      List.iter transactions ~f:(fun transaction ->
          let participants = get_participants transaction in
          Pagination.add_involved_participants pagination participants
            (state_hash, time) )

let create ~logger directory =
  let database = Database.create ~directory in
  let pagination = Pagination.create () in
  List.iter (Database.to_alist database)
    ~f:(fun (state_hash, (external_transition, time)) ->
      add_user_blocks ~logger pagination
        (With_hash.{data= external_transition; hash= state_hash}, time) ) ;
  { database= Database.create ~directory
  ; pagination= Pagination.create ()
  ; logger }

let add {database; pagination; logger}
    ( {With_hash.hash= state_hash; data= external_transition} as
    external_transition_with_date ) date =
  match Hashtbl.find pagination.all_values state_hash with
  | Some _ ->
      Logger.trace logger
        !"Not adding transition into external transition database since it \
          already exists: $transaction"
        ~module_:__MODULE__ ~location:__LOC__
        ~metadata:[("transaction", State_hash.to_yojson state_hash)]
  | None ->
      Database.set database ~key:state_hash ~data:(external_transition, date) ;
      add_user_blocks ~logger pagination (external_transition_with_date, date)

let get_total_values {pagination; _} = Pagination.get_total_values pagination

let get_values {pagination; _} = Pagination.get_values pagination

let get_earlier_values {pagination; _} =
  Pagination.get_earlier_values pagination

let get_later_values {pagination; _} = Pagination.get_later_values pagination

let close {database; _} = Database.close database
