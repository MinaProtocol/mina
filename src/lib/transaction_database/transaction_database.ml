open Coda_base
open Core
open Async
open Signature_lib

module Make (Time : sig
  type t [@@deriving bin_io, compare, sexp]
end) =
struct
  module Database = Rocksdb.Serializable.Make (Transaction.Stable.V1) (Time)

  module Txn_with_date = struct
    module T = struct
      type t = Transaction.t * Time.t [@@deriving sexp]

      let compare (txn1, time1) (txn2, time2) =
        match Time.compare time1 time2 with
        | 0 ->
            Transaction.compare txn1 txn2
        | x ->
            x
    end

    include T
    include Comparable.Make (T)
  end

  type cache =
    { user_transactions: Txn_with_date.Set.t Public_key.Compressed.Table.t
    ; all_transactions: Time.t Transaction.Table.t }

  type t = {database: Database.t; cache: cache; logger: Logger.t}

  let create logger directory =
    { database= Database.create ~directory
    ; cache=
        { user_transactions= Public_key.Compressed.Table.create ()
        ; all_transactions= Transaction.Table.create () }
    ; logger }

  (* TODO: make load function #2333 *)

  let close {database; _} = Database.close database

  let get_participants (transaction : Transaction.t) =
    match transaction with
    | Fee_transfer (One (pk, _)) ->
        [pk]
    | Fee_transfer (Two ((pk1, _), (pk2, _))) ->
        [pk1; pk2]
    | Coinbase {Coinbase.proposer; fee_transfer; _} ->
        Option.value_map fee_transfer ~default:[proposer] ~f:(fun (pk, _) ->
            [proposer; pk] )
    | User_command checked_user_command -> (
        let user_command = User_command.forget_check checked_user_command in
        let sender = User_command.sender user_command in
        let payload = User_command.payload user_command in
        match User_command_payload.body payload with
        | Stake_delegation (Set_delegate {new_delegate}) ->
            [sender; new_delegate]
        | Payment {receiver; _} ->
            [sender; receiver]
        | Chain_voting _ ->
            [sender] )

  let add {database; cache= {all_transactions; user_transactions}; logger}
      transaction date =
    match Hashtbl.find all_transactions transaction with
    | Some _retrieved_transaction ->
        Logger.trace logger
          !"Not adding transaction into transaction database since it already \
            exists: $transaction"
          ~module_:__MODULE__ ~location:__LOC__
          ~metadata:[("transaction", Transaction.to_yojson transaction)]
    | None ->
        Database.set database ~key:transaction ~data:date ;
        Hashtbl.add_exn all_transactions ~key:transaction ~data:date ;
        List.iter (get_participants transaction) ~f:(fun pk ->
            let user_txns =
              Option.value
                (Hashtbl.find user_transactions pk)
                ~default:Txn_with_date.Set.empty
            in
            let user_txns' =
              Txn_with_date.Set.add user_txns (transaction, date)
            in
            Hashtbl.set user_transactions ~key:pk ~data:user_txns' )

  let get_transactions {cache= {user_transactions; _}; _} public_key =
    let queried_transactions =
      let open Option.Let_syntax in
      let%map transactions_with_dates_set =
        Hashtbl.find user_transactions public_key
      in
      List.map (Txn_with_date.Set.to_list transactions_with_dates_set)
        ~f:(fun (txn, _) -> txn)
    in
    Option.value queried_transactions ~default:[]

  let get_pagination_query ~f t public_key transaction =
    let queried_transactions =
      let open Option.Let_syntax in
      let%bind transactions_with_dates =
        Hashtbl.find t.cache.user_transactions public_key
      in
      let%map date = Hashtbl.find t.cache.all_transactions transaction in
      let earlier, transaction_opt, later =
        Set.split transactions_with_dates (transaction, date)
      in
      [%test_pred: Txn_with_date.t option]
        ~message:
          "Transaction should be in-memory cache database for public key"
        Option.is_some transaction_opt ;
      f earlier later
    in
    Option.value_map queried_transactions
      ~default:([], `Has_earlier_page false, `Has_later_page false)
      ~f:(fun (transactions_with_dates, has_previous, has_next) ->
        (List.map transactions_with_dates ~f:fst, has_previous, has_next) )

  let has_neighboring_page = Fn.compose not Set.is_empty

  let get_earlier_transactions t public_key transaction n =
    get_pagination_query t public_key transaction ~f:(fun earlier later ->
        let has_later = `Has_later_page (has_neighboring_page later) in
        match Set.nth earlier (Set.length earlier - n) with
        | None ->
            (Set.to_list earlier, `Has_earlier_page false, has_later)
        | Some earliest_transaction ->
            let more_early_transactions, _, next_page_transactions =
              Set.split earlier earliest_transaction
            in
            ( Set.to_list @@ Set.add next_page_transactions earliest_transaction
            , `Has_earlier_page (has_neighboring_page more_early_transactions)
            , has_later ) )

  let get_later_transactions t public_key transaction n =
    get_pagination_query t public_key transaction ~f:(fun earlier later ->
        let has_earlier = `Has_earlier_page (has_neighboring_page earlier) in
        match Set.nth later n with
        | None ->
            (Set.to_list later, has_earlier, `Has_later_page false)
        | Some latest_transaction ->
            let next_page_transactions, _, _ =
              Set.split later latest_transaction
            in
            ( Set.to_list next_page_transactions
            , has_earlier
            , `Has_later_page true ) )
end

let%test_module "Transaction_database" =
  ( module struct
    module Database = Make (Int)

    let assert_transactions expected_transactions transactions =
      Transaction.Set.(
        [%test_eq: t] (of_list expected_transactions) (of_list transactions))

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

    let extract_transactions transactions_with_dates =
      List.map transactions_with_dates ~f:(fun (txn, _) -> txn)

    let%test_unit "We can get all the transactions associated with a public key"
        =
      let trials = 10 in
      let time = 1 in
      with_database ~trials
        Quickcheck.Generator.(
          list
          @@ User_command.With_valid_signature.gen_with_random_participants
               ~keys:(Array.of_list [keypair1; keypair2])
               ~max_amount:10000 ~max_fee:1000 ())
        ~f:(fun user_commands database ->
          let transactions =
            List.map user_commands ~f:(fun user_command ->
                Transaction.User_command user_command )
          in
          add_all_transactions database
            (List.map transactions ~f:(fun txn -> (txn, time))) ;
          let pk1_expected_transactions =
            List.filter transactions ~f:(fun transaction ->
                let participants = Database.get_participants transaction in
                List.mem participants pk1 ~equal:Public_key.Compressed.equal )
          in
          let pk1_queried_transactions =
            Database.get_transactions database pk1
          in
          assert_transactions pk1_expected_transactions
            pk1_queried_transactions ;
          Deferred.unit )

    module Pagination_test = struct
      module Gen = struct
        let gen_key_as_sender_or_receiver keypair1 keypair2 =
          let open Quickcheck.Generator.Let_syntax in
          if%map Bool.quickcheck_generator then (keypair1, keypair2)
          else (keypair2, keypair1)

        let key = gen_key_as_sender_or_receiver keypair1 keypair2

        let user_command =
          let open Quickcheck.Generator.Let_syntax in
          let%map user_command =
            User_command.With_valid_signature.gen ~key_gen:key
              ~max_amount:10000 ~max_fee:1000 ()
          in
          Transaction.User_command user_command

        let user_command_with_time lower_bound_incl upper_bound_incl =
          Quickcheck.Generator.tuple2 user_command
            (Int.gen_incl lower_bound_incl upper_bound_incl)

        let max_number_txns_in_page = Int.gen_incl 1 10

        let non_empty_list gen =
          let open Quickcheck.Generator in
          let open Let_syntax in
          let%map x = gen and xs = list gen in
          x :: xs

        let transaction_test_input =
          let time = 50 in
          let earliest_time_in_next_page = time - 10 in
          let max_time = 2 * time in
          let open Quickcheck.Generator in
          let open Let_syntax in
          let%bind transactions_per_page = max_number_txns_in_page in
          tuple4
            ( non_empty_list
            @@ user_command_with_time 0 (earliest_time_in_next_page - 1) )
            ( list_with_length transactions_per_page
            @@ user_command_with_time earliest_time_in_next_page (time - 1) )
            (user_command_with_time time time)
            (non_empty_list @@ user_command_with_time (time + 1) max_time)

        let transaction_test_cutoff_input =
          let time = 50 in
          let open Quickcheck.Generator in
          let open Let_syntax in
          let%bind transactions_per_page = max_number_txns_in_page in
          tuple4
            ( list_with_length transactions_per_page
            @@ user_command_with_time 0 (time - 1) )
            (user_command_with_time time time)
            (non_empty_list @@ user_command_with_time (time + 1) Int.max_value)
            (Int.gen_incl 0 10)
      end

      let test ~trials gen ~query_next_page =
        with_database gen ~trials
          ~f:(fun ( earlier_transactions_with_dates
                  , next_page_transactions_with_dates
                  , ((query_transaction, _) as query_transaction_with_time)
                  , later_transactions_with_dates )
             database
             ->
            let all_transactions_with_dates =
              earlier_transactions_with_dates
              @ next_page_transactions_with_dates
              @ (query_transaction_with_time :: later_transactions_with_dates)
            in
            add_all_transactions database all_transactions_with_dates ;
            let expected_next_page_transactions =
              List.map next_page_transactions_with_dates ~f:(fun (txn, _) ->
                  txn )
            in
            let ( next_page_transactions
                , `Has_earlier_page has_earlier
                , `Has_later_page has_later ) =
              query_next_page database pk1 query_transaction
              @@ List.length next_page_transactions_with_dates
            in
            assert_transactions expected_next_page_transactions
              next_page_transactions ;
            assert has_earlier ;
            assert has_later ;
            Deferred.unit )

      let test_with_cutoff ~trials ~query_next_page gen ~check_pages =
        with_database ~trials gen
          ~f:(fun ( earlier_transactions_with_dates
                  , ( (querying_transaction, _) as
                    querying_transaction_with_date )
                  , later_transactions_with_dates
                  , offset )
             database
             ->
            let all_transactions_with_dates =
              earlier_transactions_with_dates
              @ querying_transaction_with_date :: later_transactions_with_dates
            in
            add_all_transactions database all_transactions_with_dates ;
            let expected_next_page_transactions =
              extract_transactions earlier_transactions_with_dates
            in
            let amount_to_query =
              List.length expected_next_page_transactions + offset
            in
            let ( next_page_transactions
                , `Has_earlier_page has_earlier
                , `Has_later_page has_later ) =
              query_next_page database pk1 querying_transaction amount_to_query
            in
            assert_transactions expected_next_page_transactions
              next_page_transactions ;
            check_pages has_earlier has_later ;
            Deferred.unit )

      let%test_unit "Get n transactions that were added before an arbitrary \
                     transaction" =
        test ~trials:10 Gen.transaction_test_input
          ~query_next_page:Database.get_earlier_transactions

      let%test_unit "Trying to query n transactions that occurred before \
                     another transaction can give you less than n transactions"
          =
        test_with_cutoff ~trials:5 Gen.transaction_test_cutoff_input
          ~query_next_page:Database.get_earlier_transactions
          ~check_pages:(fun has_earlier has_later ->
            [%test_result: bool]
              ~message:
                "We should not have anymore earlier transactions to query"
              ~equal:Bool.equal ~expect:false has_earlier ;
            [%test_result: bool]
              ~message:"We should have at least one later transaction"
              ~equal:Bool.equal ~expect:true has_later )

      let invert_transaction_time =
        List.map ~f:(fun (txn, date) -> (txn, -1 * date))

      let%test_unit "Get n transactions that were added after an arbitrary \
                     transaction" =
        let later_pagination_transaction_gen =
          let open Quickcheck.Generator.Let_syntax in
          let%map ( earlier_transactions_with_dates
                  , next_page_transactions_with_dates
                  , (query_transaction, time)
                  , later_transactions_with_dates ) =
            Gen.transaction_test_input
          in
          ( invert_transaction_time earlier_transactions_with_dates
          , invert_transaction_time next_page_transactions_with_dates
          , (query_transaction, -1 * time)
          , invert_transaction_time later_transactions_with_dates )
        in
        test ~trials:10 later_pagination_transaction_gen
          ~query_next_page:Database.get_later_transactions

      let%test_unit "Trying to query n transactions that occurred after \
                     another transaction can give you less than n transactions"
          =
        let later_pagination_transaction_gen =
          let open Quickcheck.Generator.Let_syntax in
          let%map ( earlier_transactions_with_dates
                  , (querying_transaction, time)
                  , later_transactions_with_dates
                  , offsets ) =
            Gen.transaction_test_cutoff_input
          in
          ( invert_transaction_time earlier_transactions_with_dates
          , (querying_transaction, -1 * time)
          , invert_transaction_time later_transactions_with_dates
          , offsets )
        in
        test_with_cutoff ~trials:5 later_pagination_transaction_gen
          ~query_next_page:Database.get_later_transactions
          ~check_pages:(fun has_earlier has_later ->
            [%test_result: bool]
              ~message:
                "We should have at least one earlier transactions to query"
              ~equal:Bool.equal ~expect:true has_earlier ;
            [%test_result: bool]
              ~message:"We should not be able to query any more later queries"
              ~equal:Bool.equal ~expect:false has_later )
    end
  end )

module T = Make (Block_time.Time.Stable.V1)
include T
