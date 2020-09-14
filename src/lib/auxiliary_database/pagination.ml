open Core
open Coda_base
open Signature_lib

module Make (Cursor : sig
  type t [@@deriving compare, sexp, hash]

  include Comparable.S with type t := t

  include Hashable.S with type t := t
end) (Value : sig
  type t
end) (Time : sig
  type t [@@deriving bin_io, compare, sexp]

  include Hashable.S with type t := t
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

  type all_values =
    { table: (Time.t * Value.t) Cursor.Table.t
    ; mutable time_index: Cursor_with_date.Set.t }

  type t =
    { user_cursors: Cursor_with_date.Set.t Account_id.Table.t
    ; all_values: all_values }

  let create () =
    { user_cursors= Account_id.Table.create ()
    ; all_values=
        {table= Cursor.Table.create (); time_index= Cursor_with_date.Set.empty}
    }

  let get_value t cursor =
    let open Option.Let_syntax in
    let%map _, value = Hashtbl.find t.all_values.table cursor in
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
    Hashtbl.set pagination.all_values.table ~key:cursor ~data:(date, value) ;
    pagination.all_values.time_index
    <- Set.add pagination.all_values.time_index (cursor, date)

  let get_total_values {user_cursors; all_values} = function
    | None ->
        Some (Hashtbl.length all_values.table)
    | Some public_key ->
        let open Option.Let_syntax in
        let%map cursor_with_dates = Hashtbl.find user_cursors public_key in
        Set.length cursor_with_dates

  let split_user_values t cursor public_key =
    let open Option.Let_syntax in
    let%bind cursors_with_dates = Hashtbl.find t.user_cursors public_key in
    let%map cursor_with_date =
      let%map date, _value = Hashtbl.find t.all_values.table cursor in
      (cursor, date)
    in
    let earlier, value_opt, later =
      Set.split cursors_with_dates cursor_with_date
    in
    [%test_pred: Cursor_with_date.t option]
      ~message:"Transaction should be in-memory cache database for public key"
      Option.is_some value_opt ;
    (earlier, later)

  let split_all_values t cursor =
    let open Option.Let_syntax in
    let%map date, _value = Hashtbl.find t.all_values.table cursor in
    let earlier, value_opt, later =
      Set.split t.all_values.time_index (cursor, date)
    in
    [%test_pred: Cursor_with_date.t option]
      ~message:"Cursor should be in-memory cache database for all values"
      Option.is_some value_opt ;
    (earlier, later)

  let split t cursor_input = function
    | `All ->
        split_all_values t cursor_input
    | `User_only public_key ->
        split_user_values t cursor_input public_key

  let split_without_cursor ~value_filter_specification ~navigation t =
    let open Option.Let_syntax in
    let%map all_pages =
      match value_filter_specification with
      | `All ->
          Some t.all_values.time_index
      | `User_only public_key ->
          Hashtbl.find t.user_cursors public_key
    in
    match navigation with
    | `Earlier ->
        (all_pages, Cursor_with_date.Set.empty)
    | `Later ->
        (Cursor_with_date.Set.empty, all_pages)

  let get_all_paginations t = function
    | `All ->
        Some t.all_values.time_index
    | `User_only public_key ->
        Hashtbl.find t.user_cursors public_key

  let get_cursors = List.map ~f:fst

  let run_pagination ~f earlier later =
    let queried_values_opt = f earlier later in
    let cursor_with_dates, has_previous, has_next = queried_values_opt in
    (List.map cursor_with_dates ~f:fst, has_previous, has_next)

  let has_neighboring_page = Fn.compose not Set.is_empty

  let get_earlier_values earlier later amount_to_query_opt =
    let has_later = `Has_later_page (has_neighboring_page later) in
    let get_all_earlier_values_result () =
      (Set.to_list earlier, `Has_earlier_page false, has_later)
    in
    let cursor_with_dates, has_previous, has_next =
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
            , has_later ) )
    in
    (List.map cursor_with_dates ~f:fst, has_previous, has_next)

  let get_later_values earlier later amount_to_query_opt =
    let has_earlier = `Has_earlier_page (has_neighboring_page earlier) in
    let get_all_later_values_result () =
      (Set.to_list later, has_earlier, `Has_later_page false)
    in
    let cursor_with_dates, has_previous, has_next =
      match amount_to_query_opt with
      | None ->
          get_all_later_values_result ()
      | Some n -> (
        match Set.nth later n with
        | None ->
            get_all_later_values_result ()
        | Some latest_value ->
            let next_page_values, _, _ = Set.split later latest_value in
            (Set.to_list next_page_values, has_earlier, `Has_later_page true) )
    in
    (List.map cursor_with_dates ~f:fst, has_previous, has_next)

  let query t ~navigation ~cursor:cursor_opt ~value_filter_specification
      ~num_items:num_items_opt =
    let open Option.Let_syntax in
    let query_opt =
      let%map left, right =
        match cursor_opt with
        | Some cursor ->
            split t cursor value_filter_specification
        | None ->
            split_without_cursor ~value_filter_specification ~navigation t
      in
      match navigation with
      | `Earlier ->
          get_earlier_values left right num_items_opt
      | `Later ->
          get_later_values left right num_items_opt
    in
    let cursors, has_earlier, has_later =
      Option.value query_opt
        ~default:([], `Has_earlier_page false, `Has_later_page false)
    in
    ( List.map cursors ~f:(fun cursor ->
          let _, value = Hashtbl.find_exn t.all_values.table cursor in
          value )
    , has_earlier
    , has_later )

  let get_all_values t public_key_opt =
    let result, `Has_earlier_page _, `Has_later_page _ =
      query t ~navigation:`Earlier ~cursor:None
        ~value_filter_specification:
          (Option.value_map public_key_opt ~default:`All ~f:(fun public_key ->
               `User_only public_key ))
        ~num_items:None
    in
    result
end

(* TODO: The current tests test many different edge cases. This makes the tests
   quite verbose. To make the tests more expressive and concise, we can make a
   very simple pagination list data structure that implements the same `query`
   api as a source of correctness and compare it with the underlying pagination
   data structure. This would remove some nuances in the tests, like the
   `check_pages` parameter would not be needed for tests. *)
let%test_module "Pagination" =
  ( module struct
    let assert_same_set expected_values actual_values =
      Signed_command.Set.(
        [%test_eq: t] (of_list expected_values) (of_list actual_values))

    module Pagination = Make (Signed_command) (Signed_command) (Int)

    let ({Keypair.public_key= pk1; _} as keypair1) = Keypair.create ()

    let pk1 = Public_key.compress pk1

    let account_id1 = Account_id.create pk1 Token_id.default

    let keypair2 = Keypair.create ()

    let extract_transactions transactions_with_dates =
      List.map transactions_with_dates ~f:(fun (txn, _) -> txn)

    let add_all_transactions (t : Pagination.t) transactions_with_dates =
      ignore
      @@ List.fold
           ~init:Token_id.(next default)
           transactions_with_dates
           ~f:(fun next_available_token (txn, time) ->
             if Option.is_none @@ Hashtbl.find t.all_values.table txn then
               Pagination.add t
                 (Signed_command.accounts_accessed ~next_available_token txn)
                 txn txn time ;
             Signed_command.next_available_token txn next_available_token )

    let%test_unit "We can get all values associated with a public key" =
      let trials = 10 in
      let time = 1 in
      Quickcheck.test ~trials
        Quickcheck.Generator.(
          list
          @@ Signed_command.Gen.payment_with_random_participants
               ~keys:(Array.of_list [keypair1; keypair2])
               ~max_amount:10000 ~max_fee:1000 ())
        ~f:(fun user_commands ->
          let t = Pagination.create () in
          add_all_transactions t
            (List.map user_commands ~f:(fun txn -> (txn, time))) ;
          let next_available_token = ref Token_id.(next default) in
          let pk1_expected_transactions =
            List.filter user_commands ~f:(fun user_command ->
                let participants =
                  Signed_command.accounts_accessed
                    ~next_available_token:!next_available_token user_command
                in
                next_available_token :=
                  Signed_command.next_available_token user_command
                    !next_available_token ;
                List.mem participants account_id1 ~equal:Account_id.equal )
          in
          let pk1_queried_transactions =
            Pagination.get_all_values t (Some account_id1)
          in
          assert_same_set pk1_expected_transactions pk1_queried_transactions )

    module Gen = struct
      let key_as_sender_or_receiver keypair1 keypair2 =
        let open Quickcheck.Generator.Let_syntax in
        if%map Bool.quickcheck_generator then (keypair1, keypair2)
        else (keypair2, keypair1)

      let key = key_as_sender_or_receiver keypair1 keypair2

      module Payment = struct
        let same_sender_same_receiver =
          Signed_command.Gen.payment ~key_gen:key ~max_amount:10000 ~max_fee:1000
            ()

        let different_participants =
          let keys = Array.init 10 ~f:(fun _ -> Keypair.create ()) in
          Signed_command.Gen.payment_with_random_participants ~keys
            ~max_amount:10000 ~max_fee:1000 ()
      end

      let payment_with_time ~payment_gen lower_bound_incl upper_bound_incl =
        Quickcheck.Generator.tuple2 payment_gen
          (Int.gen_incl lower_bound_incl upper_bound_incl)

      let max_number_txns_in_page = Int.gen_incl 1 10

      let non_empty_list gen =
        let open Quickcheck.Generator in
        let open Let_syntax in
        let%map x = gen and xs = list gen in
        x :: xs

      let transaction_test_input ~payment_gen =
        let time = 50 in
        let earliest_time_in_next_page = time - 10 in
        let max_time = 2 * time in
        let open Quickcheck.Generator in
        let open Let_syntax in
        let%bind transactions_per_page = max_number_txns_in_page in
        tuple4
          ( non_empty_list
          @@ payment_with_time ~payment_gen 0 (earliest_time_in_next_page - 1)
          )
          ( list_with_length transactions_per_page
          @@ payment_with_time ~payment_gen earliest_time_in_next_page
               (time - 1) )
          (payment_with_time ~payment_gen time time)
          (non_empty_list @@ payment_with_time ~payment_gen (time + 1) max_time)

      let transaction_test_cutoff_input =
        let time = 50 in
        let open Quickcheck.Generator in
        let open Let_syntax in
        let%bind transactions_per_page = max_number_txns_in_page in
        tuple4
          ( list_with_length transactions_per_page
          @@ payment_with_time ~payment_gen:Payment.same_sender_same_receiver 0
               (time - 1) )
          (payment_with_time ~payment_gen:Payment.same_sender_same_receiver
             time time)
          ( non_empty_list
          @@ payment_with_time ~payment_gen:Payment.same_sender_same_receiver
               (time + 1) Int.max_value )
          (Int.gen_incl 0 10)

      let test_no_transaction_input =
        let open Quickcheck.Generator in
        let open Quickcheck.Generator.Let_syntax in
        let%bind num_transactions = Int.gen_incl 2 20 in
        let%bind transactions =
          list_with_length num_transactions
            (tuple2 Payment.same_sender_same_receiver Int.quickcheck_generator)
        in
        let%bind amount_to_query = Int.gen_incl 1 (num_transactions - 1) in
        tuple2
          (Quickcheck.Generator.of_list [None; Some amount_to_query])
          (return transactions)
    end

    let test ~trials gen ~query_next_page =
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
            query_next_page t ~cursor:(Some query_transaction)
              ~num_items:(Some (List.length next_page_transactions_with_dates))
          in
          assert_same_set expected_next_page_transactions
            next_page_transactions ;
          assert has_earlier ;
          assert has_later )

    let test_amount_input_omitted ~trials gen ~query_next_page ~check_pages =
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
            query_next_page t ~cursor:(Some query_transaction)
              ~value_filter_specification:(`User_only account_id1)
              ~num_items:None
          in
          assert_same_set expected_next_page_transactions
            next_page_transactions ;
          check_pages has_earlier has_later )

    let test_cursor_input_omitted ~trials gen ~query_next_page ~check_pages
        ~compare =
      Quickcheck.test gen ~trials
        ~f:(fun (num_items, transactions_with_dates) ->
          Option.iter num_items ~f:(fun amount_to_query ->
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
            Option.value_map num_items ~default:sorted_transactions
              ~f:(List.take sorted_transactions)
          in
          let ( next_page_transactions
              , `Has_earlier_page has_earlier
              , `Has_later_page has_later ) =
            query_next_page t ~cursor:None
              ~value_filter_specification:(`User_only account_id1) ~num_items
          in
          assert_same_set expected_next_page_transactions
            next_page_transactions ;
          check_pages has_earlier has_later )

    let test_with_cutoff ~trials ~query_next_page gen ~check_pages =
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
            query_next_page t ~cursor:(Some querying_transaction)
              ~value_filter_specification:(`User_only account_id1)
              ~num_items:(Some amount_to_query)
          in
          assert_same_set expected_next_page_transactions
            next_page_transactions ;
          check_pages has_earlier has_later )

    module Get_all_values = struct
      let%test_unit "Get n values that were added before an arbitrary value" =
        test ~trials:10
          (Gen.transaction_test_input
             ~payment_gen:Gen.Payment.different_participants)
          ~query_next_page:
            (Pagination.query ~navigation:`Earlier
               ~value_filter_specification:`All)
    end

    let%test_unit "Get n values that were added before an arbitrary value" =
      test ~trials:10
        (Gen.transaction_test_input
           ~payment_gen:Gen.Payment.same_sender_same_receiver)
        ~query_next_page:
          (Pagination.query ~navigation:`Earlier
             ~value_filter_specification:(`User_only account_id1))

    let%test_unit "Trying to query n transactions that occurred before \
                   another transaction can give you less than n transactions" =
      test_with_cutoff ~trials:5 Gen.transaction_test_cutoff_input
        ~query_next_page:(Pagination.query ~navigation:`Earlier)
        ~check_pages:(fun has_earlier has_later ->
          [%test_result: bool]
            ~message:"We should not have anymore earlier transactions to query"
            ~equal:Bool.equal ~expect:false has_earlier ;
          [%test_result: bool]
            ~message:"We should have at least one later transaction"
            ~equal:Bool.equal ~expect:true has_later )

    let%test_unit "Get the n latest values if values are not provided" =
      test_cursor_input_omitted ~trials:5 Gen.test_no_transaction_input
        ~query_next_page:(Pagination.query ~navigation:`Earlier)
        ~check_pages:(fun _has_earlier has_later -> assert (not has_later))
        ~compare:
          (Comparable.lift
             ~f:(fun (txn, date) -> (-1 * date, txn))
             [%compare: int * Signed_command.t])

    let%test_unit "Get all values that were added before an arbitrary value" =
      test_amount_input_omitted ~trials:5
        (Gen.transaction_test_input
           ~payment_gen:Gen.Payment.same_sender_same_receiver)
        ~query_next_page:(Pagination.query ~navigation:`Earlier)
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
          ~payment_gen:Gen.Payment.same_sender_same_receiver
      in
      ( invert_transaction_time earlier_transactions_with_dates
      , invert_transaction_time next_page_transactions_with_dates
      , (query_transaction, -1 * time)
      , invert_transaction_time later_transactions_with_dates )

    let%test_unit "Get n transactions that were added after an arbitrary \
                   transaction" =
      test ~trials:5 later_pagination_transaction_gen
        ~query_next_page:
          (Pagination.query ~navigation:`Later
             ~value_filter_specification:(`User_only account_id1))

    let%test_unit "Trying to query n values that occurred after another value \
                   can give you less than n values" =
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
        ~query_next_page:(Pagination.query ~navigation:`Later)
        ~check_pages:(fun has_earlier has_later ->
          [%test_result: bool]
            ~message:
              "We should have at least one earlier transactions to query"
            ~equal:Bool.equal ~expect:true has_earlier ;
          [%test_result: bool]
            ~message:"We should not be able to query any more later queries"
            ~equal:Bool.equal ~expect:false has_later )

    let%test_unit "Get all values that were after an arbitrary value" =
      test_amount_input_omitted ~trials:2 later_pagination_transaction_gen
        ~query_next_page:(Pagination.query ~navigation:`Later)
        ~check_pages:(fun has_earlier has_later ->
          assert has_earlier ;
          assert (not has_later) )

    let compare_txns_with_dates =
      Comparable.lift
        ~f:(fun (txn, date) -> (date, txn))
        [%compare: int * Signed_command.t]

    let%test_unit "Get the n most earliest values if a cursor is not provided"
        =
      test_cursor_input_omitted ~trials:5 Gen.test_no_transaction_input
        ~query_next_page:(Pagination.query ~navigation:`Later)
        ~check_pages:(fun has_earlier _has_later -> assert (not has_earlier))
        ~compare:compare_txns_with_dates
  end )
