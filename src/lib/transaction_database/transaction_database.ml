open Core
open Async
open Signature_lib

(* TODO: Remove Transaction functor when we need to query transactions other
   than user_commands *)
module Make (Transaction : sig
  type t [@@deriving bin_io, compare, sexp, hash, to_yojson]

  include Comparable.S with type t := t

  include Hashable.S with type t := t

  val get_participants : t -> Public_key.Compressed.t list
end) (Time : sig
  type t [@@deriving bin_io, compare, sexp]
end) =
struct
  module Database = Rocksdb.Serializable.Make (Transaction) (Time)
  module Pagination = Pagination.Make (Transaction) (Time)

  type t = {database: Database.t; pagination: Pagination.t; logger: Logger.t}

  let add_user_transaction (pagination : Pagination.t) (transaction, date) =
    Hashtbl.add_exn pagination.all_values ~key:transaction ~data:date ;
    List.iter (Transaction.get_participants transaction) ~f:(fun pk ->
        let user_txns =
          Option.value
            (Hashtbl.find pagination.user_values pk)
            ~default:Pagination.Value_with_date.Set.empty
        in
        let user_txns' =
          Pagination.Value_with_date.Set.add user_txns (transaction, date)
        in
        Hashtbl.set pagination.user_values ~key:pk ~data:user_txns' )

  let create logger directory =
    let database = Database.create ~directory in
    let pagination = Pagination.create () in
    List.iter (Database.to_alist database) ~f:(add_user_transaction pagination) ;
    { database= Database.create ~directory
    ; pagination= failwith "Need to implement"
    ; logger }

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

  let get_total_transactions {pagination; _} =
    Pagination.get_total_values pagination

  let get_transactions {pagination; _} = Pagination.get_values pagination

  let get_earlier_transactions {pagination; _} =
    Pagination.get_earlier_values pagination

  let get_later_transactions {pagination; _} =
    Pagination.get_later_values pagination
end

let%test_module "Transaction_database" =
  ( module struct
    module Database = Make (User_command) (Int)

    let ({Keypair.public_key= pk1; _} as keypair1) = Keypair.create ()

    let pk1 = Public_key.compress pk1

    let keypair2 = Keypair.create ()

    let logger = Logger.create ()

    let with_database ~trials ~f gen =
      Async.Thread_safe.block_on_async_exn
      @@ fun () ->
      Quickcheck.async_test gen ~trials ~f:(fun input ->
          File_system.with_temp_dir "/tmp/coda-test" ~f:(fun directory_name ->
              let database = Database.create logger directory_name in
              f input database ) )

    let add_all_transactions database all_transactions_with_dates =
      List.iter all_transactions_with_dates ~f:(fun (txn, time) ->
          Database.add database txn time )

    let%test_unit "We can get all the transactions associated with a public key"
        =
      let trials = 10 in
      let time = 1 in
      with_database ~trials
        Quickcheck.Generator.(
          list
          @@ User_command.Gen.payment_with_random_participants
               ~keys:(Array.of_list [keypair1; keypair2])
               ~max_amount:10000 ~max_fee:1000 ())
        ~f:(fun user_commands database ->
          add_all_transactions database
            (List.map user_commands ~f:(fun txn -> (txn, time))) ;
          let pk1_expected_transactions =
            List.filter user_commands ~f:(fun user_command ->
                let participants =
                  User_command.get_participants user_command
                in
                List.mem participants pk1 ~equal:Public_key.Compressed.equal )
          in
          let pk1_queried_transactions =
            Database.get_transactions database pk1
          in
          User_command.assert_same_set pk1_expected_transactions
            pk1_queried_transactions ;
          Deferred.unit )
  end )

module Block_time = Coda_base.Block_time
module T = Make (User_command) (Block_time.Time.Stable.V1)
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
    let database = T.create logger (directory ^/ "transactions") in
    List.iter (Quickcheck.random_value ~seed:Quickcheck.default_seed gen)
      ~f:(fun (command, time) -> T.add database command time) ;
    ( database
    , compress_key_pairs local_wallet_keypairs
    , compress_key_pairs remote_user_keypairs )
end
