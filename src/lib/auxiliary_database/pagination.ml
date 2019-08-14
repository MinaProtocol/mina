open Core
open Coda_base
open Signature_lib

let assert_same_set expected_transactions transactions =
  User_command.Set.(
    [%test_eq: t] (of_list expected_transactions) (of_list transactions))

module Make (Cursor : sig
  type t [@@deriving compare, sexp, hash]

  include Comparable.S with type t := t

  include Hashable.S with type t := t
end) (Value : sig
  type t
end) (Time : sig
  type t [@@deriving bin_io, compare, sexp]
end) =
struct
  module Cursor_with_date = struct
    module T = struct
      type t = Cursor.t * Time.t [@@deriving sexp]

      let compare =
        Comparable.lift
          ~f:(fun (value, date) -> (date, value))
          [%compare: Time.t * Cursor.t]
    end

    include T
    include Comparable.Make (T)
  end

  type t =
    { user_cursors: Cursor_with_date.Set.t Public_key.Compressed.Table.t
    ; all_values: (Time.t * Value.t) Cursor.Table.t }

  let create () =
    { user_cursors= Public_key.Compressed.Table.create ()
    ; all_values= Cursor.Table.create () }

  let get_value t cursor =
    let _, value = Hashtbl.find_exn t.all_values cursor in
    value

  let add (pagination : t) participants cursor value date =
    List.iter participants ~f:(fun pk ->
        let user_cursors =
          Option.value
            (Hashtbl.find pagination.user_cursors pk)
            ~default:Cursor_with_date.Set.empty
        in
        Hashtbl.set pagination.user_cursors ~key:pk
          ~data:(Set.add user_cursors (cursor, date)) ) ;
    Hashtbl.set pagination.all_values ~key:cursor ~data:(date, value)

  let get_all_values {all_values; _} =
    List.map (Hashtbl.data all_values) ~f:(fun (_, value) -> value)

  let get_total_values {user_cursors; _} public_key =
    let open Option.Let_syntax in
    let%map cursor_with_dates = Hashtbl.find user_cursors public_key in
    Set.length cursor_with_dates

  let get_values ({user_cursors; _} as t) public_key =
    let queried_values =
      let open Option.Let_syntax in
      let%map cursors_with_dates = Hashtbl.find user_cursors public_key in
      List.map (Cursor_with_date.Set.to_list cursors_with_dates)
        ~f:(fun (cursor, _) -> get_value t cursor)
    in
    Option.value queried_values ~default:[]

  module With_non_null_value = struct
    let get_pagination_query ~f t public_key cursor =
      let open Option.Let_syntax in
      let queried_values_opt =
        let%bind cursors_with_dates = Hashtbl.find t.user_cursors public_key in
        let%map cursor_with_date =
          let%map date, _value = Hashtbl.find t.all_values cursor in
          (cursor, date)
        in
        let earlier, value_opt, later =
          Set.split cursors_with_dates cursor_with_date
        in
        [%test_pred: Cursor_with_date.t option]
          ~message:
            "Transaction should be in-memory cache database for public key"
          Option.is_some value_opt ;
        f earlier later
      in
      let%map cursor_with_dates, has_previous, has_next = queried_values_opt in
      (List.map cursor_with_dates ~f:fst, has_previous, has_next)

    let has_neighboring_page = Fn.compose not Set.is_empty

    let get_earlier_values t public_key value amount_to_query_opt =
      get_pagination_query t public_key value ~f:(fun earlier later ->
          let has_later = `Has_later_page (has_neighboring_page later) in
          let get_all_earlier_values_result () =
            (Set.to_list earlier, `Has_earlier_page false, has_later)
          in
          match amount_to_query_opt with
          | None ->
              get_all_earlier_values_result ()
          | Some n -> (
            match Set.nth earlier (Set.length earlier - n) with
            | None ->
                get_all_earlier_values_result ()
            | Some earliest_value ->
                let more_early_values, _, next_page_values =
                  Set.split earlier earliest_value
                in
                ( Set.to_list @@ Set.add next_page_values earliest_value
                , `Has_earlier_page (has_neighboring_page more_early_values)
                , has_later ) ) )

    let get_later_values t public_key value amount_to_query_opt =
      get_pagination_query t public_key value ~f:(fun earlier later ->
          let has_earlier = `Has_earlier_page (has_neighboring_page earlier) in
          let get_all_later_values_result () =
            (Set.to_list later, has_earlier, `Has_later_page false)
          in
          match amount_to_query_opt with
          | None ->
              get_all_later_values_result ()
          | Some n -> (
            match Set.nth later n with
            | None ->
                get_all_later_values_result ()
            | Some latest_value ->
                let next_page_values, _, _ = Set.split later latest_value in
                ( Set.to_list next_page_values
                , has_earlier
                , `Has_later_page true ) ) )
  end

  let get_pagination_query ~get_default ~get_queries t public_key value_opt
      amount_to_query_opt =
    let query_opt =
      match value_opt with
      | None -> (
          let open Option.Let_syntax in
          let%bind user_cursors = Hashtbl.find t.user_cursors public_key in
          let%bind default_value, _ = get_default user_cursors in
          match amount_to_query_opt with
          | None ->
              let%map queries, has_earlier_page, has_later_page =
                get_queries t public_key default_value None
              in
              (default_value :: queries, has_earlier_page, has_later_page)
          | Some amount_to_query when amount_to_query = 1 ->
              Some
                ( [default_value]
                , `Has_earlier_page false
                , `Has_later_page false )
          | Some amount_to_query ->
              let%map queries, has_earlier_page, has_later_page =
                get_queries t public_key default_value
                  (Some (amount_to_query - 1))
              in
              (default_value :: queries, has_earlier_page, has_later_page) )
      | Some value ->
          get_queries t public_key value amount_to_query_opt
    in
    let cursors, has_earlier, has_later =
      Option.value query_opt
        ~default:([], `Has_earlier_page false, `Has_later_page false)
    in
    ( List.map cursors ~f:(fun cursor ->
          let _, value = Hashtbl.find_exn t.all_values cursor in
          value )
    , has_earlier
    , has_later )

  let get_earlier_values =
    get_pagination_query ~get_default:Set.max_elt
      ~get_queries:With_non_null_value.get_earlier_values

  let get_later_values =
    get_pagination_query ~get_default:Set.min_elt
      ~get_queries:With_non_null_value.get_later_values
end

let%test_module "Pagination" =
  ( module struct
    module Pagination =
      Make (User_command.Stable.V1) (User_command.Stable.V1) (Int)

    let ({Keypair.public_key= pk1; _} as keypair1) = Keypair.create ()

    let pk1 = Public_key.compress pk1

    let keypair2 = Keypair.create ()

    let extract_transactions transactions_with_dates =
      List.map transactions_with_dates ~f:(fun (txn, _) -> txn)

    let add_all_transactions (t : Pagination.t) transactions_with_dates =
      List.iter transactions_with_dates ~f:(fun (txn, time) ->
          if Option.is_none @@ Hashtbl.find t.all_values txn then
            Pagination.add t (User_command.accounts_accessed txn) txn txn time
      )

    let%test_unit "We can get all values associated with a public key" =
      let trials = 10 in
      let time = 1 in
      Quickcheck.test ~trials
        Quickcheck.Generator.(
          list
          @@ User_command.Gen.payment_with_random_participants
               ~keys:(Array.of_list [keypair1; keypair2])
               ~max_amount:10000 ~max_fee:1000 ())
        ~f:(fun user_commands ->
          let t = Pagination.create () in
          add_all_transactions t
            (List.map user_commands ~f:(fun txn -> (txn, time))) ;
          let pk1_expected_transactions =
            List.filter user_commands ~f:(fun user_command ->
                let participants =
                  User_command.accounts_accessed user_command
                in
                List.mem participants pk1 ~equal:Public_key.Compressed.equal )
          in
          let pk1_queried_transactions = Pagination.get_values t pk1 in
          assert_same_set pk1_expected_transactions pk1_queried_transactions )

    module Gen = struct
      let gen_key_as_sender_or_receiver keypair1 keypair2 =
        let open Quickcheck.Generator.Let_syntax in
        if%map Bool.quickcheck_generator then (keypair1, keypair2)
        else (keypair2, keypair1)

      let key = gen_key_as_sender_or_receiver keypair1 keypair2

      let payment =
        User_command.Gen.payment ~key_gen:key ~max_amount:10000 ~max_fee:1000
          ()

      let payment_with_time lower_bound_incl upper_bound_incl =
        Quickcheck.Generator.tuple2 payment
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
          @@ payment_with_time 0 (earliest_time_in_next_page - 1) )
          ( list_with_length transactions_per_page
          @@ payment_with_time earliest_time_in_next_page (time - 1) )
          (payment_with_time time time)
          (non_empty_list @@ payment_with_time (time + 1) max_time)

      let transaction_test_cutoff_input =
        let time = 50 in
        let open Quickcheck.Generator in
        let open Let_syntax in
        let%bind transactions_per_page = max_number_txns_in_page in
        tuple4
          ( list_with_length transactions_per_page
          @@ payment_with_time 0 (time - 1) )
          (payment_with_time time time)
          (non_empty_list @@ payment_with_time (time + 1) Int.max_value)
          (Int.gen_incl 0 10)

      let test_no_transaction_input =
        let open Quickcheck.Generator in
        let open Quickcheck.Generator.Let_syntax in
        let%bind num_transactions = Int.gen_incl 2 20 in
        let%bind transactions =
          list_with_length num_transactions
            (tuple2 payment Int.quickcheck_generator)
        in
        let%bind amount_to_query = Int.gen_incl 1 (num_transactions - 1) in
        tuple2
          (Quickcheck.Generator.of_list [None; Some amount_to_query])
          (return transactions)
    end

    type query_next_page =
         Pagination.t
      -> Public_key.Compressed.t
      -> User_command.t option
      -> int option
      -> User_command.t list
         * [`Has_earlier_page of bool]
         * [`Has_later_page of bool]

    let test ~trials gen ~(query_next_page : query_next_page) =
      Quickcheck.test gen ~trials
        ~f:(fun ( earlier_transactions_with_dates
                , next_page_transactions_with_dates
                , ((query_transaction, _) as query_transaction_with_time)
                , later_transactions_with_dates )
           ->
          let t = Pagination.create () in
          let all_transactions_with_dates =
            earlier_transactions_with_dates @ next_page_transactions_with_dates
            @ (query_transaction_with_time :: later_transactions_with_dates)
          in
          add_all_transactions t all_transactions_with_dates ;
          let expected_next_page_transactions =
            extract_transactions next_page_transactions_with_dates
          in
          let ( next_page_transactions
              , `Has_earlier_page has_earlier
              , `Has_later_page has_later ) =
            query_next_page t pk1 (Some query_transaction)
              (Some (List.length next_page_transactions_with_dates))
          in
          assert_same_set expected_next_page_transactions
            next_page_transactions ;
          assert has_earlier ;
          assert has_later )

    let test_no_amount_input ~trials gen ~(query_next_page : query_next_page)
        ~check_pages =
      Quickcheck.test gen ~trials
        ~f:(fun ( earlier_transactions_with_dates
                , next_page_transactions_with_dates
                , ((query_transaction, _) as query_transaction_with_time)
                , later_transactions_with_dates )
           ->
          let t = Pagination.create () in
          let all_transactions_with_dates =
            earlier_transactions_with_dates @ next_page_transactions_with_dates
            @ (query_transaction_with_time :: later_transactions_with_dates)
          in
          add_all_transactions t all_transactions_with_dates ;
          let expected_next_page_transactions =
            extract_transactions
              ( earlier_transactions_with_dates
              @ next_page_transactions_with_dates )
          in
          let ( next_page_transactions
              , `Has_earlier_page has_earlier
              , `Has_later_page has_later ) =
            query_next_page t pk1 (Some query_transaction) None
          in
          assert_same_set expected_next_page_transactions
            next_page_transactions ;
          check_pages has_earlier has_later )

    let test_no_transaction_input ~trials gen
        ~(query_next_page : query_next_page) ~check_pages ~compare =
      Quickcheck.test gen ~trials
        ~f:(fun (amount_to_query_opt, transactions_with_dates) ->
          Option.iter amount_to_query_opt ~f:(fun amount_to_query ->
              assert (List.length transactions_with_dates >= amount_to_query)
          ) ;
          let t = Pagination.create () in
          add_all_transactions t transactions_with_dates ;
          let expected_next_page_transactions =
            let sorted_transaction_with_dates =
              List.sort ~compare transactions_with_dates
            in
            let sorted_transactions =
              extract_transactions sorted_transaction_with_dates
            in
            Option.value_map amount_to_query_opt ~default:sorted_transactions
              ~f:(List.take sorted_transactions)
          in
          let ( next_page_transactions
              , `Has_earlier_page has_earlier
              , `Has_later_page has_later ) =
            query_next_page t pk1 None amount_to_query_opt
          in
          assert_same_set expected_next_page_transactions
            next_page_transactions ;
          check_pages has_earlier has_later )

    let test_with_cutoff ~trials ~(query_next_page : query_next_page) gen
        ~check_pages =
      Quickcheck.test ~trials gen
        ~f:(fun ( earlier_transactions_with_dates
                , ((querying_transaction, _) as querying_transaction_with_date)
                , later_transactions_with_dates
                , offset )
           ->
          let t = Pagination.create () in
          let all_transactions_with_dates =
            earlier_transactions_with_dates
            @ (querying_transaction_with_date :: later_transactions_with_dates)
          in
          add_all_transactions t all_transactions_with_dates ;
          let expected_next_page_transactions =
            extract_transactions earlier_transactions_with_dates
          in
          let amount_to_query =
            List.length expected_next_page_transactions + offset
          in
          let ( next_page_transactions
              , `Has_earlier_page has_earlier
              , `Has_later_page has_later ) =
            query_next_page t pk1 (Some querying_transaction)
              (Some amount_to_query)
          in
          assert_same_set expected_next_page_transactions
            next_page_transactions ;
          check_pages has_earlier has_later )

    let%test_unit "Get n transactions that were added before an arbitrary \
                   transaction" =
      test ~trials:10 Gen.transaction_test_input
        ~query_next_page:Pagination.get_earlier_values

    let%test_unit "Trying to query n transactions that occurred before \
                   another transaction can give you less than n transactions" =
      test_with_cutoff ~trials:5 Gen.transaction_test_cutoff_input
        ~query_next_page:Pagination.get_earlier_values
        ~check_pages:(fun has_earlier has_later ->
          [%test_result: bool]
            ~message:"We should not have anymore earlier transactions to query"
            ~equal:Bool.equal ~expect:false has_earlier ;
          [%test_result: bool]
            ~message:"We should have at least one later transaction"
            ~equal:Bool.equal ~expect:true has_later )

    let%test_unit "Get the n latest transactions if transactions are not \
                   provided" =
      test_no_transaction_input ~trials:5 Gen.test_no_transaction_input
        ~query_next_page:Pagination.get_earlier_values
        ~check_pages:(fun _has_earlier has_later -> assert (not has_later))
        ~compare:
          (Comparable.lift
             ~f:(fun (txn, date) -> (-1 * date, txn))
             [%compare: int * User_command.t])

    let%test_unit "Get all transactions that were added before an arbitrary \
                   transaction" =
      test_no_amount_input ~trials:5 Gen.transaction_test_input
        ~query_next_page:Pagination.get_earlier_values
        ~check_pages:(fun has_earlier has_later ->
          assert (not has_earlier) ;
          assert has_later )

    let invert_transaction_time =
      List.map ~f:(fun (txn, date) -> (txn, -1 * date))

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

    let%test_unit "Get n transactions that were added after an arbitrary \
                   transaction" =
      test ~trials:5 later_pagination_transaction_gen
        ~query_next_page:Pagination.get_later_values

    let%test_unit "Trying to query n transactions that occurred after another \
                   transaction can give you less than n transactions" =
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
        ~query_next_page:Pagination.get_later_values
        ~check_pages:(fun has_earlier has_later ->
          [%test_result: bool]
            ~message:
              "We should have at least one earlier transactions to query"
            ~equal:Bool.equal ~expect:true has_earlier ;
          [%test_result: bool]
            ~message:"We should not be able to query any more later queries"
            ~equal:Bool.equal ~expect:false has_later )

    let%test_unit "Get all transactions that were added after an arbitrary \
                   transaction" =
      test_no_amount_input ~trials:2 later_pagination_transaction_gen
        ~query_next_page:Pagination.get_later_values
        ~check_pages:(fun has_earlier has_later ->
          assert has_earlier ;
          assert (not has_later) )

    let compare_txns_with_dates =
      Comparable.lift
        ~f:(fun (txn, date) -> (date, txn))
        [%compare: int * User_command.t]

    let%test_unit "Get the n most earliest transactions if transactions are \
                   not provided" =
      test_no_transaction_input ~trials:5 Gen.test_no_transaction_input
        ~query_next_page:Pagination.get_later_values
        ~check_pages:(fun has_earlier _has_later -> assert (not has_earlier))
        ~compare:compare_txns_with_dates
  end )
