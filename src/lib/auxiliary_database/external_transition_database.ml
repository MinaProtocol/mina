open Core
open Coda_base
module Time = Block_time

module Database = struct
  module Value = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type t =
            Filtered_external_transition.Stable.V1.t * Block_time.Stable.V1.t
          [@@deriving bin_io, version {unnumbered}]
        end

        include T
      end
    end
  end

  include Rocksdb.Serializable.Make (State_hash.Stable.V1) (Value.Stable.V1)
end

module Pagination =
  Pagination.Make
    (State_hash.Stable.V1)
    (struct
      type t = (Filtered_external_transition.t, State_hash.t) With_hash.t
    end)
    (Block_time.Stable.V1)

let fee_transfer_participants (pk, _) = [pk]

type t = {pagination: Pagination.t; database: Database.t; logger: Logger.t}

let add_user_blocks (pagination : Pagination.t)
    ( ( { With_hash.hash= state_hash
        ; data= {Filtered_external_transition.transactions; creator; _} } as
      external_transition )
    , time ) =
  let fee_transfer_participants =
    List.concat_map transactions.fee_transfers ~f:fee_transfer_participants
  in
  let user_command_participants =
    List.concat_map transactions.user_commands
      ~f:User_command.accounts_accessed
  in
  Pagination.add pagination
    ((creator :: fee_transfer_participants) @ user_command_participants)
    state_hash external_transition time

let create ~logger directory =
  let database = Database.create ~directory in
  let pagination = Pagination.create () in
  List.iter (Database.to_alist database) ~f:(fun (hash, (block_data, time)) ->
      add_user_blocks pagination ({With_hash.hash; data= block_data}, time) ) ;
  {database; pagination; logger}

let add {database; pagination; logger}
    ( {With_hash.hash= state_hash; data= filtered_external_transition} as
    transition_with_hash ) date =
  match Hashtbl.find pagination.all_values state_hash with
  | Some _ ->
      Logger.trace logger
        !"Not adding transition into external transition database since it \
          already exists: $transaction"
        ~module_:__MODULE__ ~location:__LOC__
        ~metadata:[("transaction", State_hash.to_yojson state_hash)]
  | None ->
      Database.set database ~key:state_hash
        ~data:(filtered_external_transition, date) ;
      add_user_blocks pagination (transition_with_hash, date)

let get_total_values {pagination; _} = Pagination.get_total_values pagination

let get_values {pagination; _} = Pagination.get_values pagination

let get_all_values {pagination; _} = Pagination.get_all_values pagination

let get_earlier_values {pagination; _} =
  Pagination.get_earlier_values pagination

let get_later_values {pagination; _} = Pagination.get_later_values pagination

let close {database; _} = Database.close database
