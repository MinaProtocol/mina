open Core
open Async
open Signature_lib
open Coda_base

(* TODO: Remove Transaction functor when we need to query transactions other
   than user_commands *)
module Make (Transaction : sig
  type t [@@deriving bin_io, compare, sexp, hash, to_yojson]

  include Comparable.S with type t := t

  include Hashable.S with type t := t

  val accounts_accessed : t -> Public_key.Compressed.t list
end) (Time : sig
  type t [@@deriving bin_io, compare, sexp]
end) =
struct
  module Database = Rocksdb.Serializable.Make (Transaction) (Time)
  module Pagination = Pagination.Make (Transaction) (Transaction) (Time)

  type t = {database: Database.t; pagination: Pagination.t; logger: Logger.t}

  let add_user_transaction (pagination : Pagination.t) (transaction, date) =
    Pagination.add pagination
      (Transaction.accounts_accessed transaction)
      transaction transaction date

  let create ~logger directory =
    let database = Database.create ~directory in
    let pagination = Pagination.create () in
    List.iter (Database.to_alist database) ~f:(add_user_transaction pagination) ;
    {database; pagination; logger}

  let close {database; _} = Database.close database

  let add {database; pagination; logger} transaction date =
    match Hashtbl.find pagination.all_values transaction with
    | Some _retrieved_transaction ->
        Logger.trace logger
          !"Not adding transaction into transaction database since it already \
            exists: $transaction"
          ~module_:__MODULE__ ~location:__LOC__
          ~metadata:[("transaction", Transaction.to_yojson transaction)]
    | None ->
        Database.set database ~key:transaction ~data:date ;
        add_user_transaction pagination (transaction, date)

  let get_total_values {pagination; _} = Pagination.get_total_values pagination

  let get_values {pagination; _} = Pagination.get_values pagination

  let get_all_values {pagination; _} = Pagination.get_all_values pagination

  let get_earlier_values {pagination; _} =
    Pagination.get_earlier_values pagination

  let get_later_values {pagination; _} = Pagination.get_later_values pagination
end

module Block_time = Coda_base.Block_time
module T = Make (User_command.Stable.V1) (Block_time.Time.Stable.V1)
include T

module For_tests = struct
  open Quickcheck.Generator

  let of_year years = Int64.of_int (years * 365 * 24 * 60 * 60 * 1000)

  let compress_key_pairs =
    List.map ~f:(fun {Keypair.public_key; _} -> Public_key.compress public_key)

  let populate_database ~directory ~num_wallets ~num_foreign num_commands =
    let open Deferred.Let_syntax in
    let logger = Logger.create () in
    let%bind wallets = Secrets.Wallets.load ~logger ~disk_location:directory in
    let%map local_wallet_keypairs =
      Deferred.List.init num_wallets ~f:(fun _ ->
          let%map needle = Secrets.Wallets.generate_new wallets in
          Option.value_exn (Secrets.Wallets.find wallets ~needle) )
    in
    let remote_user_keypairs =
      List.init num_foreign ~f:(fun _ -> Keypair.create ())
    in
    let max_amount = 10_000 in
    let max_fee = 100 in
    let key_gen =
      let open Quickcheck.Generator.Let_syntax in
      match%map
        List.gen_permutations @@ local_wallet_keypairs @ remote_user_keypairs
      with
      | keypair1 :: keypair2 :: _ ->
          (keypair1, keypair2)
      | _ ->
          failwith
            "Need to select two elements from a list with at least two elements"
    in
    let payment_gen =
      User_command.Gen.payment ~key_gen ~max_amount ~max_fee ()
    in
    let delegation_gen =
      User_command.Gen.stake_delegation ~key_gen ~max_fee ()
    in
    let command_gen =
      Quickcheck.Generator.weighted_union
        [(0.90, payment_gen); (0.1, delegation_gen)]
    in
    let time_gen =
      let time_now =
        Block_time.Time.to_span_since_epoch
          (Block_time.Time.now Block_time.Time.Controller.basic)
      in
      let time_max = Block_time.Time.Span.to_ms time_now in
      let time_min = Int64.(time_max - of_year 5) in
      let open Quickcheck.Generator.Let_syntax in
      let%map time_span_gen = Int64.gen_incl time_min time_max in
      Block_time.Time.of_span_since_epoch
      @@ Block_time.Time.Span.of_ms time_span_gen
    in
    let gen =
      let open Quickcheck.Generator.Let_syntax in
      let%bind commands_with_time =
        list_with_length num_commands @@ tuple2 command_gen time_gen
      in
      let%map user_with_delegation_and_payments =
        let%bind wallet =
          List.gen_permutations local_wallet_keypairs >>| List.hd_exn
        in
        let key_gen =
          let%map remote_user =
            List.gen_permutations local_wallet_keypairs >>| List.hd_exn
          in
          (wallet, remote_user)
        in
        let%bind delegation_with_time =
          tuple2
            (User_command.Gen.stake_delegation ~key_gen ~max_fee ())
            time_gen
        in
        let%map payment_with_time =
          tuple2
            (User_command.Gen.payment ~key_gen ~max_amount ~max_fee ())
            time_gen
        in
        [payment_with_time; delegation_with_time]
      in
      user_with_delegation_and_payments @ commands_with_time
    in
    let database = T.create ~logger (directory ^/ "transactions") in
    List.iter (Quickcheck.random_value ~seed:Quickcheck.default_seed gen)
      ~f:(fun (command, time) -> T.add database command time) ;
    ( database
    , compress_key_pairs local_wallet_keypairs
    , compress_key_pairs remote_user_keypairs )
end
