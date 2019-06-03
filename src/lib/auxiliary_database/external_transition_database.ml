open Core
open Coda_base
module Time = Block_time

module Database = struct
  module Value = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type t =
            Filtered_external_transition.Stable.V1.t
            * Block_time.Time.Stable.V1.t
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
    (Block_time.Time.Stable.V1)

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
  {database; pagination= Pagination.create (); logger}

let add ~tracked_participants {database; pagination; logger}
    ({With_hash.hash= state_hash; _} as external_transition) date =
  match Hashtbl.find pagination.all_values state_hash with
  | Some _ ->
      Logger.trace logger
        !"Not adding transition into external transition database since it \
          already exists: $transaction"
        ~module_:__MODULE__ ~location:__LOC__
        ~metadata:[("transaction", State_hash.to_yojson state_hash)]
  | None -> (
    match
      Filtered_external_transition.of_transition ~tracked_participants
        external_transition
    with
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
          @@ Staged_ledger.Pre_diff_info.Error.to_error error )
          ~metadata:[("state_hash", State_hash.to_yojson state_hash)] )

let get_total_values {pagination; _} = Pagination.get_total_values pagination

let get_values {pagination; _} = Pagination.get_values pagination

let get_earlier_values {pagination; _} =
  Pagination.get_earlier_values pagination

let get_later_values {pagination; _} = Pagination.get_later_values pagination

let close {database; _} = Database.close database
