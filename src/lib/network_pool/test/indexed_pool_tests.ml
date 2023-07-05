(** Testing
    -------
    Component:  Network pool
    Invocation: dune exec src/lib/network_pool/test/main.exe -- \
                  test '^indexed pool$'
    Subject:    Test the indexed pool.
 *)

open Core_kernel
open Currency
open Mina_base
open Mina_numbers
open Mina_transaction
open Signature_lib
open Network_pool
open Indexed_pool
open For_tests
open Transaction_gen

let logger = Logger.null ()

let time_controller = Block_time.Controller.basic ~logger

let empty = empty ~constraint_constants ~consensus_constants ~time_controller

let empty_invariants () = assert_pool_consistency empty

let singleton_properties () =
  Quickcheck.test (gen_cmd ()) ~f:(fun cmd ->
      let pool = empty in
      let add_res =
        add_from_gossip_exn pool cmd Account_nonce.zero
          (Amount.of_nanomina_int_exn 500)
      in
      if
        Option.value_exn (currency_consumed ~constraint_constants cmd)
        |> Amount.to_nanomina_int > 500
      then
        match add_res with
        | Error (Insufficient_funds _) ->
            ()
        | _ ->
            failwith "should've returned insufficient_funds"
      else
        match add_res with
        | Ok (_, pool', dropped) ->
            assert_pool_consistency pool' ;
            assert (Sequence.is_empty dropped) ;
            [%test_eq: int] (size pool') 1 ;
            [%test_eq:
              Transaction_hash.User_command_with_valid_signature.t option]
              (get_highest_fee pool') (Some cmd) ;
            let dropped', pool'' = remove_lowest_fee pool' in
            [%test_eq:
              Transaction_hash.User_command_with_valid_signature.t Sequence.t]
              dropped' (Sequence.singleton cmd) ;
            [%test_eq: t] ~equal pool pool''
        | _ ->
            failwith "should've succeeded" )

let sequential_adds_all_valid () =
  let gen :
      ( Mina_ledger.Ledger.init_state
      * Transaction_hash.User_command_with_valid_signature.t list )
      Quickcheck.Generator.t =
    let open Quickcheck.Generator.Let_syntax in
    let%bind ledger_init = Mina_ledger.Ledger.gen_initial_ledger_state in
    let%map cmds = User_command.Valid.Gen.sequence ledger_init in
    ( ledger_init
    , List.map ~f:Transaction_hash.User_command_with_valid_signature.create cmds
    )
  in
  let shrinker :
      ( Mina_ledger.Ledger.init_state
      * Transaction_hash.User_command_with_valid_signature.t list )
      Quickcheck.Shrinker.t =
    Quickcheck.Shrinker.create (fun (init_state, cmds) ->
        Sequence.singleton (init_state, List.take cmds (List.length cmds - 1)) )
  in
  Quickcheck.test gen ~trials:1000
    ~sexp_of:
      [%sexp_of:
        Mina_ledger.Ledger.init_state
        * Transaction_hash.User_command_with_valid_signature.t list]
    ~shrinker ~shrink_attempts:`Exhaustive ~seed:(`Deterministic "d")
    ~sizes:(Sequence.repeat 10) ~f:(fun (ledger_init, cmds) ->
      let account_init_states_seq = Array.to_sequence ledger_init in
      let balances = Hashtbl.create (module Public_key.Compressed) in
      let nonces = Hashtbl.create (module Public_key.Compressed) in
      Sequence.iter account_init_states_seq ~f:(fun (kp, balance, nonce, _) ->
          let compressed = Public_key.compress kp.public_key in
          Hashtbl.add_exn balances ~key:compressed ~data:balance ;
          Hashtbl.add_exn nonces ~key:compressed ~data:nonce ) ;
      let pool = ref empty in
      let rec go cmds_acc =
        match cmds_acc with
        | [] ->
            ()
        | cmd :: rest -> (
            let unchecked =
              Transaction_hash.User_command_with_valid_signature.command cmd
            in
            let account_id = User_command.fee_payer unchecked in
            let pk = Account_id.public_key account_id in
            let add_res =
              add_from_gossip_exn !pool cmd
                (Hashtbl.find_exn nonces pk)
                (Hashtbl.find_exn balances pk)
            in
            match add_res with
            | Ok (_, pool', dropped) ->
                [%test_eq:
                  Transaction_hash.User_command_with_valid_signature.t
                  Sequence.t] dropped Sequence.empty ;
                assert_pool_consistency pool' ;
                pool := pool' ;
                go rest
            | Error (Invalid_nonce (`Expected want, got)) ->
                failwithf
                  !"Bad nonce. Expected: %{sexp: Account.Nonce.t}. Got: \
                    %{sexp: Account.Nonce.t}"
                  want got ()
            | Error (Invalid_nonce (`Between (low, high), got)) ->
                failwithf
                  !"Bad nonce. Expected between %{sexp: Account.Nonce.t} and \
                    %{sexp:Account.Nonce.t}. Got: %{sexp: Account.Nonce.t}"
                  low high got ()
            | Error (Insufficient_funds (`Balance bal, amt)) ->
                failwithf
                  !"Insufficient funds. Balance: %{sexp: Amount.t}. Amount: \
                    %{sexp: Amount.t}"
                  bal amt ()
            | Error (Insufficient_replace_fee (`Replace_fee rfee, fee)) ->
                failwithf
                  !"Insufficient fee for replacement. Needed at least %{sexp: \
                    Fee.t} but got %{sexp:Fee.t}."
                  rfee fee ()
            | Error Overflow ->
                failwith "Overflow."
            | Error Bad_token ->
                failwith "Token is incompatible with the command."
            | Error (Unwanted_fee_token fee_token) ->
                failwithf
                  !"Bad fee token. The fees are paid in token %{sexp: \
                    Token_id.t}, which we are not accepting fees in."
                  fee_token ()
            | Error
                (Expired
                  ( `Valid_until valid_until
                  , `Global_slot_since_genesis global_slot_since_genesis ) ) ->
                failwithf
                  !"Expired user command. Current global slot is \
                    %{sexp:Mina_numbers.Global_slot_since_genesis.t} but user \
                    command is only valid until \
                    %{sexp:Mina_numbers.Global_slot_since_genesis.t}"
                  global_slot_since_genesis valid_until () )
      in
      go cmds )

let replacement () =
  let modify_payment (c : User_command.t) ~sender ~common:fc ~body:fb =
    let modified_payload : Signed_command.Payload.t =
      match c with
      | Signed_command
          { payload = { body = Payment payment_payload; common }; _ } ->
          { common = fc common
          ; body = Signed_command.Payload.Body.Payment (fb payment_payload)
          }
      | _ ->
          failwith "generated user command that wasn't a payment"
    in
    Signed_command (Signed_command.For_tests.fake_sign sender modified_payload)
    |> Transaction_hash.User_command_with_valid_signature.create
  in
  let gen :
      ( Account_nonce.t
      * Amount.t
      * Transaction_hash.User_command_with_valid_signature.t list
      * Transaction_hash.User_command_with_valid_signature.t )
      Quickcheck.Generator.t =
    let open Quickcheck.Generator.Let_syntax in
    let%bind sender_index = Int.gen_incl 0 9 in
    let sender = test_keys.(sender_index) in
    let%bind init_nonce =
      Quickcheck.Generator.map ~f:Account_nonce.of_int @@ Int.gen_incl 0 1000
    in
    let init_balance = Amount.of_mina_int_exn 100_000 in
    let%bind size = Quickcheck.Generator.size in
    let%bind amounts =
      Quickcheck.Generator.map ~f:Array.of_list
      @@ Quickcheck_lib.gen_division_currency init_balance (size + 1)
    in
    let rec go current_nonce current_balance n =
      if n > 0 then
        let%bind cmd =
          let key_gen =
            Quickcheck.Generator.tuple2 (return sender)
              (Quickcheck_lib.of_array test_keys)
          in
          Mina_generators.User_command_generators.payment ~sign_type:`Fake
            ~key_gen ~nonce:current_nonce ~max_amount:1 ~fee_range:0 ()
        in
        let cmd_currency = amounts.(n - 1) in
        let%bind fee =
          Amount.(gen_incl zero (min (of_nanomina_int_exn 10) cmd_currency))
        in
        let amount = Option.value_exn Amount.(cmd_currency - fee) in
        let cmd' =
          modify_payment cmd ~sender
            ~common:(fun c -> { c with fee = Amount.to_fee fee })
            ~body:(fun b -> { b with amount })
        in
        let consumed =
          Option.value_exn (currency_consumed ~constraint_constants cmd')
        in
        let%map rest =
          go
            (Account_nonce.succ current_nonce)
            (Option.value_exn Amount.(current_balance - consumed))
            (n - 1)
        in
        cmd' :: rest
      else return []
    in
    let%bind setup_cmds = go init_nonce init_balance (size + 1) in
    let init_nonce_int = Account.Nonce.to_int init_nonce in
    let%bind replaced_nonce =
      Int.gen_incl init_nonce_int (init_nonce_int + List.length setup_cmds - 1)
    in
    let%map replace_cmd_skeleton =
      let key_gen =
        Quickcheck.Generator.tuple2 (return sender)
          (Quickcheck_lib.of_array test_keys)
      in
      Mina_generators.User_command_generators.payment ~sign_type:`Fake ~key_gen
        ~nonce:(Account_nonce.of_int replaced_nonce)
        ~max_amount:(Amount.to_nanomina_int init_balance)
        ~fee_range:0 ()
    in
    let replace_cmd =
      modify_payment replace_cmd_skeleton ~sender ~body:Fn.id ~common:(fun c ->
          { c with fee = Fee.of_mina_int_exn (10 + (5 * (size + 1))) } )
    in
    (init_nonce, init_balance, setup_cmds, replace_cmd)
  in
  Quickcheck.test ~trials:20 gen
    ~sexp_of:
      [%sexp_of:
        Account_nonce.t
        * Amount.t
        * Transaction_hash.User_command_with_valid_signature.t list
        * Transaction_hash.User_command_with_valid_signature.t]
    ~f:(fun (init_nonce, init_balance, setup_cmds, replace_cmd) ->
      let t =
        List.fold_left setup_cmds ~init:empty ~f:(fun t cmd ->
            match add_from_gossip_exn t cmd init_nonce init_balance with
            | Ok (_, t', removed) ->
                assert_pool_consistency t' ;
                [%test_eq:
                  Transaction_hash.User_command_with_valid_signature.t
                  Sequence.t] removed Sequence.empty ;
                t'
            | _ ->
                failwith
                @@ sprintf
                     !"adding command %{sexp: \
                       Transaction_hash.User_command_with_valid_signature.t} \
                       failed"
                     cmd )
      in
      let replaced_idx, _ =
        let replace_nonce =
          replace_cmd
          |> Transaction_hash.User_command_with_valid_signature.command
          |> User_command.applicable_at_nonce
        in
        List.findi setup_cmds ~f:(fun _i cmd ->
            let cmd_nonce =
              cmd |> Transaction_hash.User_command_with_valid_signature.command
              |> User_command.applicable_at_nonce
            in
            Account_nonce.compare replace_nonce cmd_nonce <= 0 )
        |> Option.value_exn
      in
      let currency_consumed_pre_replace =
        List.fold_left
          (List.take setup_cmds (replaced_idx + 1))
          ~init:Amount.zero
          ~f:(fun consumed_so_far cmd ->
            Option.value_exn
              Option.(
                currency_consumed ~constraint_constants cmd
                >>= fun consumed -> Amount.(consumed + consumed_so_far)) )
      in
      assert (Amount.(currency_consumed_pre_replace <= init_balance)) ;
      let currency_consumed_post_replace =
        Option.value_exn
          (let open Option.Let_syntax in
          let%bind replaced_currency_consumed =
            currency_consumed ~constraint_constants
            @@ List.nth_exn setup_cmds replaced_idx
          in
          let%bind replacer_currency_consumed =
            currency_consumed ~constraint_constants replace_cmd
          in
          let%bind a =
            Amount.(currency_consumed_pre_replace - replaced_currency_consumed)
          in
          Amount.(a + replacer_currency_consumed))
      in
      let add_res = add_from_gossip_exn t replace_cmd init_nonce init_balance in
      if Amount.(currency_consumed_post_replace <= init_balance) then
        match add_res with
        | Ok (_, t', dropped) ->
            assert (not (Sequence.is_empty dropped)) ;
            assert_pool_consistency t'
        | Error e ->
            Command_error.sexp_of_t e |> Sexp.to_string_hum |> failwith
      else
        match add_res with
        | Error (Insufficient_funds _) ->
            ()
        | _ ->
            failwith "should've returned insufficient_funds" )

let remove_lowest_fee () =
  let cmds =
    gen_cmd () |> Quickcheck.random_sequence |> Fn.flip Sequence.take 4
    |> Sequence.to_list
  in
  let compare cmd0 cmd1 : int =
    let open Transaction_hash.User_command_with_valid_signature in
    Fee_rate.compare
      (User_command.fee_per_wu @@ command cmd0)
      (User_command.fee_per_wu @@ command cmd1)
  in
  let cmds_sorted_by_fee_per_wu = List.sort ~compare cmds in
  let cmd_lowest_fee, commands_to_keep =
    ( List.hd_exn cmds_sorted_by_fee_per_wu
    , List.tl_exn cmds_sorted_by_fee_per_wu )
  in
  let insert_cmd pool cmd =
    add_from_gossip_exn pool cmd Account_nonce.zero (Amount.of_mina_int_exn 5)
    |> Result.ok |> Option.value_exn
    |> fun (_, pool, _) -> pool
  in
  let cmd_equal = Transaction_hash.User_command_with_valid_signature.equal in
  let removed, pool =
    List.fold_left cmds ~init:empty ~f:insert_cmd |> remove_lowest_fee
  in
  (* check that the lowest fee per wu command is returned *)
  assert (Sequence.(equal cmd_equal removed @@ return cmd_lowest_fee))
  |> fun () ->
  (* check that the lowest fee per wu command is removed from
     applicable_by_fee *)
  applicable_by_fee pool |> Map.data
  |> List.concat_map ~f:Set.to_list
  |> fun applicable_by_fee_cmds ->
  assert (List.(equal cmd_equal applicable_by_fee_cmds commands_to_keep))
  |> fun () ->
  (* check that the lowest fee per wu command is removed from
     all_by_fee *)
  applicable_by_fee pool |> Map.data
  |> List.concat_map ~f:Set.to_list
  |> fun all_by_fee_cmds ->
  assert (List.(equal cmd_equal all_by_fee_cmds commands_to_keep))

let insert_cmd pool cmd =
  add_from_gossip_exn pool cmd Account_nonce.zero (Amount.of_mina_int_exn 5)
  |> Result.map_error ~f:(fun e ->
         let sexp = Command_error.sexp_of_t e in
         Failure (Sexp.to_string sexp) )
  |> Result.ok_exn
  |> fun (_, pool, _) -> pool

(** Picking a transaction to include in a block, choose the one with
    highest fee. *)
let pick_highest_fee_for_application () =
  Quickcheck.test
    (* This should be replaced with a proper generator, but for the moment it
       generates inputs which fail the test. *)
    ( gen_cmd () |> Quickcheck.random_sequence |> Fn.flip Sequence.take 4
    |> Sequence.to_list |> Quickcheck.Generator.return )
    ~f:(fun cmds ->
      let compare cmd0 cmd1 : int =
        let open Transaction_hash.User_command_with_valid_signature in
        Fee_rate.compare
          (User_command.fee_per_wu @@ command cmd0)
          (User_command.fee_per_wu @@ command cmd1)
      in
      let pool = List.fold_left cmds ~init:empty ~f:insert_cmd in
      [%test_eq: Transaction_hash.User_command_with_valid_signature.t option]
        (get_highest_fee pool)
        (List.max_elt ~compare cmds) )

let command_nonce (txn : Transaction_hash.User_command_with_valid_signature.t) =
  let open Transaction_hash.User_command_with_valid_signature in
  match (forget_check txn).data with
  | Signed_command sc ->
      Signed_command.nonce sc
  | Zkapp_command zk ->
      zk.fee_payer.body.nonce

let dummy_state_view =
  let state_body =
    let consensus_constants =
      let genesis_constants = Genesis_constants.for_unit_tests in
      Consensus.Constants.create ~constraint_constants
        ~protocol_constants:genesis_constants.protocol
    in
    let compile_time_genesis =
      (*not using Precomputed_values.for_unit_test because of dependency cycle*)
      Mina_state.Genesis_protocol_state.t
        ~genesis_ledger:Genesis_ledger.(Packed.t for_unit_tests)
        ~genesis_epoch_data:Consensus.Genesis_epoch_data.for_unit_tests
        ~genesis_body_reference:Staged_ledger_diff.genesis_body_reference
        ~constraint_constants ~consensus_constants
    in
    compile_time_genesis.data |> Mina_state.Protocol_state.body
  in
  { (Mina_state.Protocol_state.Body.view state_body) with
    global_slot_since_genesis = Mina_numbers.Global_slot_since_genesis.zero
  }

let add_to_pool ~nonce ~balance pool cmd =
  let _, pool', dropped =
    add_from_gossip_exn pool cmd nonce balance
    |> Result.map_error ~f:(Fn.compose Sexp.to_string Command_error.sexp_of_t)
    |> Result.ok_or_failwith
  in
  [%test_eq: Transaction_hash.User_command_with_valid_signature.t Sequence.t]
    dropped Sequence.empty ;
  assert_pool_consistency pool' ;
  pool'

let init_permissionless_ledger ledger account_info =
  let open Mina_ledger.Ledger.Ledger_inner in
  List.iter account_info ~f:(fun (public_key, amount) ->
      let account_id =
        Account_id.create (Public_key.compress public_key) Token_id.default
      in
      let balance =
        Balance.of_nanomina_int_exn @@ Amount.to_nanomina_int amount
      in
      let _tag, account, location =
        Or_error.ok_exn (get_or_create ledger account_id)
      in
      set ledger location
        { account with balance; permissions = Permissions.empty } )

let apply_to_ledger ledger cmd =
  match Transaction_hash.User_command_with_valid_signature.command cmd with
  | User_command.Signed_command c ->
      let (`If_this_is_used_it_should_have_a_comment_justifying_it v) =
        Signed_command.to_valid_unsafe c
      in
      ignore
        ( Mina_ledger.Ledger.apply_user_command ~constraint_constants
            ~txn_global_slot:Mina_numbers.Global_slot_since_genesis.zero ledger
            v
          |> Or_error.ok_exn
          : Mina_transaction_logic.Transaction_applied.Signed_command_applied.t
          )
  | User_command.Zkapp_command p -> (
      let applied, _ =
        Mina_ledger.Ledger.apply_zkapp_command_unchecked ~constraint_constants
          ~global_slot:dummy_state_view.global_slot_since_genesis
          ~state_view:dummy_state_view ledger p
        |> Or_error.ok_exn
      in
      match With_status.status applied.command with
      | Transaction_status.Applied ->
          ()
      | Transaction_status.Failed failure ->
          failwithf "failed to apply zkapp_command transaction to ledger: [%s]"
            ( String.concat ~sep:", "
            @@ List.bind
                 ~f:(List.map ~f:Transaction_status.Failure.to_string)
                 failure )
            () )

let commit_to_pool ledger pool cmd expected_drops =
  apply_to_ledger ledger cmd ;
  let accounts_to_check =
    Transaction_hash.User_command_with_valid_signature.command cmd
    |> User_command.accounts_referenced |> Account_id.Set.of_list
  in
  let pool, dropped =
    revalidate pool ~logger (`Subset accounts_to_check) (fun sender ->
        match Mina_ledger.Ledger.location_of_account ledger sender with
        | None ->
            Account.empty
        | Some loc ->
            Option.value_exn
              ~message:"Somehow a public key has a location but no account"
              (Mina_ledger.Ledger.get ledger loc) )
  in
  let lower =
    List.map ~f:Transaction_hash.User_command_with_valid_signature.hash
  in
  [%test_eq: Transaction_hash.t list]
    (lower (Sequence.to_list dropped))
    (lower expected_drops) ;
  assert_pool_consistency pool ;
  pool

let make_zkapp_command_payment ~(sender : Keypair.t) ~(receiver : Keypair.t)
    ~double_increment_sender ~increment_receiver ~amount ~fee nonce_int =
  let nonce = Account.Nonce.of_int nonce_int in
  let sender_pk = Public_key.compress sender.public_key in
  let receiver_pk = Public_key.compress receiver.public_key in
  let zkapp_command_wire : Zkapp_command.Stable.Latest.Wire.t =
    { fee_payer =
        { Account_update.Fee_payer.body =
            { public_key = sender_pk; fee; nonce; valid_until = None }
            (* Real signature added in below *)
        ; authorization = Signature.dummy
        }
    ; account_updates =
        Zkapp_command.Call_forest.of_account_updates
          ~account_update_depth:(Fn.const 0)
          [ { Account_update.body =
                { public_key = sender_pk
                ; update = Account_update.Update.noop
                ; token_id = Token_id.default
                ; balance_change = Amount.Signed.(negate @@ of_unsigned amount)
                ; increment_nonce = double_increment_sender
                ; events = []
                ; actions = []
                ; call_data = Snark_params.Tick.Field.zero
                ; preconditions =
                    { Account_update.Preconditions.network =
                        Zkapp_precondition.Protocol_state.accept
                    ; account =
                        Account_update.Account_precondition.Nonce
                          (Account.Nonce.succ nonce)
                    ; valid_while = Ignore
                    }
                ; may_use_token = No
                ; use_full_commitment = not double_increment_sender
                ; implicit_account_creation_fee = false
                ; authorization_kind = None_given
                }
            ; authorization = None_given
            }
          ; { Account_update.body =
                { public_key = receiver_pk
                ; update = Account_update.Update.noop
                ; token_id = Token_id.default
                ; balance_change = Amount.Signed.of_unsigned amount
                ; increment_nonce = increment_receiver
                ; events = []
                ; actions = []
                ; call_data = Snark_params.Tick.Field.zero
                ; preconditions =
                    { Account_update.Preconditions.network =
                        Zkapp_precondition.Protocol_state.accept
                    ; account = Account_update.Account_precondition.Accept
                    ; valid_while = Ignore
                    }
                ; may_use_token = No
                ; implicit_account_creation_fee = false
                ; use_full_commitment = not increment_receiver
                ; authorization_kind = None_given
                }
            ; authorization = None_given
            }
          ]
    ; memo = Signed_command_memo.empty
    }
  in
  let zkapp_command = Zkapp_command.of_wire zkapp_command_wire in
  (* We skip signing the commitment and updating the authorization as it is not necessary to have a valid transaction for these tests. *)
  let (`If_this_is_used_it_should_have_a_comment_justifying_it cmd) =
    User_command.to_valid_unsafe (User_command.Zkapp_command zkapp_command)
  in
  Transaction_hash.User_command_with_valid_signature.create cmd

let support_for_zkapp_command_commands () =
  let fee = Fee.minimum_user_command_fee in
  let amount = Amount.of_nanomina_int_exn @@ Fee.to_nanomina_int fee in
  let balance = Option.value_exn (Amount.scale amount 100) in
  let kp1 =
    Quickcheck.random_value ~seed:(`Deterministic "apple") Keypair.gen
  in
  let kp2 =
    Quickcheck.random_value ~seed:(`Deterministic "orange") Keypair.gen
  in
  let add_cmd = add_to_pool ~nonce:Account_nonce.zero ~balance in
  let make_cmd =
    make_zkapp_command_payment ~sender:kp1 ~receiver:kp2
      ~increment_receiver:false ~amount ~fee
  in
  Mina_ledger.Ledger.with_ledger ~depth:4 ~f:(fun ledger ->
      init_permissionless_ledger ledger
        [ (kp1.public_key, balance); (kp2.public_key, Amount.zero) ] ;
      let commit = commit_to_pool ledger in
      let cmd1 = make_cmd ~double_increment_sender:false 0 in
      let cmd2 = make_cmd ~double_increment_sender:false 1 in
      let cmd3 = make_cmd ~double_increment_sender:false 2 in
      let cmd4 = make_cmd ~double_increment_sender:false 3 in
      (* used to break the sequence *)
      let cmd3' = make_cmd ~double_increment_sender:true 2 in
      let pool =
        List.fold_left [ cmd1; cmd2; cmd3; cmd4 ] ~init:empty ~f:add_cmd
      in
      let pool = commit pool cmd1 [ cmd1 ] in
      let pool = commit pool cmd2 [ cmd2 ] in
      let _pool = commit pool cmd3' [ cmd3; cmd4 ] in
      () )

let nonce_increment_side_effects () =
  let fee = Fee.minimum_user_command_fee in
  let amount = Amount.of_nanomina_int_exn @@ Fee.to_nanomina_int fee in
  let balance = Option.value_exn (Amount.scale amount 100) in
  let kp1 =
    Quickcheck.random_value ~seed:(`Deterministic "apple") Keypair.gen
  in
  let kp2 =
    Quickcheck.random_value ~seed:(`Deterministic "orange") Keypair.gen
  in
  let add_cmd = add_to_pool ~nonce:Account_nonce.zero ~balance in
  let make_cmd = make_zkapp_command_payment ~amount ~fee in
  Mina_ledger.Ledger.with_ledger ~depth:4 ~f:(fun ledger ->
      init_permissionless_ledger ledger
        [ (kp1.public_key, balance); (kp2.public_key, balance) ] ;
      let kp1_cmd1 =
        make_cmd ~sender:kp1 ~receiver:kp2 ~double_increment_sender:false
          ~increment_receiver:true 0
      in
      let kp2_cmd1 =
        make_cmd ~sender:kp2 ~receiver:kp1 ~double_increment_sender:false
          ~increment_receiver:false 0
      in
      let kp2_cmd2 =
        make_cmd ~sender:kp2 ~receiver:kp1 ~double_increment_sender:false
          ~increment_receiver:false 1
      in
      let pool =
        List.fold_left [ kp1_cmd1; kp2_cmd1; kp2_cmd2 ] ~init:empty ~f:add_cmd
      in
      let _pool = commit_to_pool ledger pool kp1_cmd1 [ kp2_cmd1; kp1_cmd1 ] in
      () )

let nonce_invariant_violation () =
  let fee = Fee.minimum_user_command_fee in
  let amount = Amount.of_nanomina_int_exn @@ Fee.to_nanomina_int fee in
  let balance = Option.value_exn (Amount.scale amount 100) in
  let kp1 =
    Quickcheck.random_value ~seed:(`Deterministic "apple") Keypair.gen
  in
  let kp2 =
    Quickcheck.random_value ~seed:(`Deterministic "orange") Keypair.gen
  in
  let add_cmd = add_to_pool ~nonce:Account_nonce.zero ~balance in
  let make_cmd =
    make_zkapp_command_payment ~sender:kp1 ~receiver:kp2
      ~double_increment_sender:false ~increment_receiver:false ~amount ~fee
  in
  Mina_ledger.Ledger.with_ledger ~depth:4 ~f:(fun ledger ->
      init_permissionless_ledger ledger
        [ (kp1.public_key, balance); (kp2.public_key, Amount.zero) ] ;
      let cmd1 = make_cmd 0 in
      let cmd2 = make_cmd 1 in
      let pool = List.fold_left [ cmd1; cmd2 ] ~init:empty ~f:add_cmd in
      apply_to_ledger ledger cmd1 ;
      let _pool = commit_to_pool ledger pool cmd2 [ cmd1; cmd2 ] in
      () )

(* Check that when commands from a single sender are added into the mempool
   and then lowest fee commands are dropped, remaining commands are returned
   for application in the order of increasing nonces without a gap. *)
let transactions_from_single_sender_ordered_by_nonce () =
  Quickcheck.test
    (let open Quickcheck.Generator.Let_syntax in
    let%bind sender = Account.gen in
    let%bind receiver = Account.gen in
    let%map txns =
      Stateful_gen.eval_state
        (gen_txns_from_single_sender_to receiver.public_key)
        sender
    in
    (sender, txns))
    ~f:(fun (sender, txns) ->
      let account_map = accounts_map [ sender ] in
      let pool =
        pool_of_transactions ~init:empty ~account_map txns |> rem_lowest_fee 5
      in
      assert_pool_consistency pool ;
      let txns = Sequence.to_list @@ Indexed_pool.transactions ~logger pool in
      with_accounts txns ~init:() ~account_map ~f:(fun () a t ->
          [%test_eq: Account_nonce.t] (txn_nonce t) a.nonce |> Result.return )
      |> Result.ok_or_failwith ;
      assert_pool_consistency pool )

let rec interleave_at_random queues =
  let open Quickcheck in
  let open Generator.Let_syntax in
  if Array.is_empty queues then return []
  else
    let%bind i = Int.gen_incl 0 (Array.length queues - 1) in
    match queues.(i) with
    | [] ->
        Array.filter queues ~f:(fun q -> not @@ List.is_empty q)
        |> interleave_at_random
    | t :: ts ->
        Array.set queues i ts ;
        let%map more = interleave_at_random queues in
        t :: more

let gen_accounts_and_transactions =
  let open Quickcheck.Generator.Let_syntax in
  let module Gen_ext = Monad_lib.Make_ext (Quickcheck.Generator) in
  let%bind senders = List.gen_non_empty Account.gen in
  let%bind receiver = Account.gen in
  let%bind txns =
    List.map senders
      ~f:
        (Stateful_gen.eval_state
           (gen_txns_from_single_sender_to receiver.public_key) )
    |> Gen_ext.sequence
  in
  let%map shuffled = interleave_at_random @@ Array.of_list txns in
  (accounts_map senders, shuffled)

let transactions_from_many_senders_no_nonce_gaps () =
  Quickcheck.test gen_accounts_and_transactions ~f:(fun (account_map, txns) ->
      let pool =
        pool_of_transactions ~init:empty ~account_map txns |> rem_lowest_fee 5
      in
      let txns = Sequence.to_list @@ Indexed_pool.transactions ~logger pool in
      with_accounts txns ~init:() ~account_map ~f:(fun () a t ->
          [%test_eq: Account_nonce.t] (txn_nonce t) a.nonce |> Result.return )
      |> Result.ok_or_failwith ;
      assert_pool_consistency pool )

let revalidation_drops_nothing_unless_ledger_changed () =
  Quickcheck.test gen_accounts_and_transactions ~f:(fun (account_map, txns) ->
      let pool = pool_of_transactions ~init:empty ~account_map txns in
      let pool', dropped =
        Indexed_pool.revalidate pool ~logger `Entire_pool (fun aid ->
            Public_key.Compressed.Map.find_exn account_map
              (Account_id.public_key aid) )
      in
      [%test_eq:
        Transaction_hash.User_command_with_valid_signature.t Sequence.t] dropped
        Sequence.empty ;
      [%test_eq: Indexed_pool.t] pool pool' ;
      let to_apply = Indexed_pool.transactions ~logger pool in
      let to_apply' = Indexed_pool.transactions ~logger pool' in
      assert_pool_consistency pool ;
      [%test_eq:
        Transaction_hash.User_command_with_valid_signature.t Sequence.t]
        to_apply to_apply' )

let apply_transactions txns accounts =
  List.fold txns ~init:accounts ~f:(fun m t ->
      let txn = Signed_command.forget_check t in
      let sender = Public_key.compress txn.signer in
      Public_key.Compressed.Map.update m sender ~f:(function
        | None ->
            failwith "sender not found"
        | Some a ->
            let open Account.Poly in
            let nonce = Account.Nonce.succ a.nonce in
            let balance =
              let amt =
                Signed_command.amount txn |> Option.value ~default:Amount.zero
              in
              Balance.(sub_amount a.balance amt)
              |> Option.value ~default:Balance.zero
            in
            { a with nonce; balance } ) )

let txn_hash = Transaction_hash.User_command_with_valid_signature.hash

let application_invalidates_applied_transactions () =
  Quickcheck.test
    (let open Quickcheck.Generator.Let_syntax in
    let%bind accounts, txns = gen_accounts_and_transactions in
    (* Simulate application of some transactions in order to invalidate them. *)
    let%map app_count = Int.gen_incl 0 (List.length txns) in
    let updated_accounts =
      apply_transactions (List.take txns app_count) accounts
    in
    (accounts, updated_accounts, txns, app_count))
    ~f:(fun (initial_accounts, updated_accounts, txns, app_count) ->
      let pool =
        pool_of_transactions ~init:empty ~account_map:initial_accounts txns
      in
      let _pool', dropped =
        Indexed_pool.revalidate ~logger pool `Entire_pool (fun aid ->
            Public_key.Compressed.Map.find_exn updated_accounts
              (Account_id.public_key aid) )
      in
      assert_pool_consistency pool ;
      [%test_eq: Transaction_hash.Set.t]
        ( Sequence.to_list dropped |> List.map ~f:txn_hash
        |> Transaction_hash.Set.of_list )
        ( List.take txns app_count
        |> List.map ~f:(Fn.compose txn_hash sgn_cmd_to_txn)
        |> Transaction_hash.Set.of_list ) )

let update_fee (txn : Signed_command.t) fee =
  { txn with
    payload = { txn.payload with common = { txn.payload.common with fee } }
  }

(* Generate a sequence of transactions, then choose one of them and replace
   it with the same transaction, just with a higher fee. *)
let transaction_replacement () =
  Quickcheck.test
    (let open Quickcheck in
    let open Generator.Let_syntax in
    (* Make sure we can increase the balance later. *)
    let high = Balance.(sub_amount max_int Amount.one) |> Option.value_exn in
    let%bind sender =
      Account.gen_with_constrained_balance ~low:Balance.one ~high
    in
    let%bind receiver = Account.gen in
    let%bind txns =
      Stateful_gen.eval_state
        (gen_txns_from_single_sender_to receiver.public_key)
        sender
    in
    let%map to_replace = Generator.of_list txns in
    (sender, txns, Signed_command.forget_check to_replace))
    ~f:(fun (sender, txns, to_replace) ->
      let account_map = accounts_map [ sender ] in
      let pool = pool_of_transactions ~init:empty ~account_map txns in
      let old_fee = to_replace.payload.common.fee in
      let fee = Currency.Fee.(old_fee + one) |> Option.value_exn in
      let cmd = update_fee to_replace fee in
      (* We don't care about signatures in these tests. *)
      let (`If_this_is_used_it_should_have_a_comment_justifying_it replacement)
          =
        Signed_command.to_valid_unsafe cmd
      in
      let t =
        User_command.Signed_command replacement
        |> Transaction_hash.User_command_with_valid_signature.create
      in
      let balance =
        Balance.to_amount sender.balance |> Amount.(add one) |> Option.value_exn
      in
      let _, pool', _ =
        Indexed_pool.add_from_gossip_exn pool t sender.nonce balance
        |> Result.map_error ~f:(fun e ->
               Sexp.to_string @@ Command_error.sexp_of_t e )
        |> Result.ok_or_failwith
      in
      assert_pool_consistency pool ;
      [%test_eq: int] (Indexed_pool.size pool) (Indexed_pool.size pool') ;
      [%test_eq: int]
        (Indexed_pool.transactions ~logger pool |> Sequence.length)
        (Indexed_pool.transactions ~logger pool' |> Sequence.length) )

let transaction_replacement_insufficient_balance () =
  Quickcheck.test
    (let open Quickcheck.Generator.Let_syntax in
    let%bind a = Account.gen in
    let sender = { a with balance = Balance.of_mina_int_exn 31 } in
    let%map recv = Account.gen in
    let cmds =
      List.init 3 ~f:(fun n ->
          let open Signed_command.Payload in
          let (`If_this_is_used_it_should_have_a_comment_justifying_it cmd) =
            Signed_command.Poly.
              { payload =
                  Poly.
                    { common =
                        Common.Poly.
                          { fee =
                              Fee.of_nanomina_int_exn 300_000_000 (* 0.3 Mina *)
                          ; fee_payer_pk = sender.public_key
                          ; nonce = Account_nonce.(add sender.nonce @@ of_int n)
                          ; valid_until = Global_slot_since_genesis.max_value
                          ; memo = Signed_command_memo.dummy
                          }
                    ; body =
                        Body.Payment
                          Payment_payload.Poly.
                            { receiver_pk = recv.public_key
                            ; amount = Amount.of_mina_int_exn 10
                            }
                    }
              ; signer =
                  Option.value_exn @@ Public_key.decompress sender.public_key
              ; signature = Signature.dummy
              }
            |> Signed_command.to_valid_unsafe
          in
          cmd )
    in
    (sender, cmds))
    ~f:(fun (sender, txns) ->
      let account_map = accounts_map [ sender ] in
      let pool = pool_of_transactions ~init:empty ~account_map txns in
      let t = List.nth_exn txns 1 |> Signed_command.forget_check in
      let updated =
        update_fee t (Currency.Fee.of_nanomina_int_exn 700_000_000)
        (* 0.7 Mina *)
      in
      let (`If_this_is_used_it_should_have_a_comment_justifying_it replacement)
          =
        Signed_command.to_valid_unsafe updated
      in
      let t =
        User_command.Signed_command replacement
        |> Transaction_hash.User_command_with_valid_signature.create
      in
      let balance = Balance.to_amount sender.balance in
      let _, pool', _ =
        Indexed_pool.add_from_gossip_exn pool t sender.nonce balance
        |> Result.map_error ~f:(fun e ->
               Sexp.to_string @@ Command_error.sexp_of_t e )
        |> Result.ok_or_failwith
      in
      (* The last transaction gets discarded, because after the replacement,
         the account can't afford it anymore. *)
      assert_pool_consistency pool ;
      [%test_eq: int] (Indexed_pool.size pool) 3 ;
      [%test_eq: int] (Indexed_pool.size pool') 2 )
