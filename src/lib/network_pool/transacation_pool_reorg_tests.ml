open Core
open Async
open Mina_base
open Mina_transaction
open Inline_test_quiet_logs
open Signature_lib
open Test_utils

let%test_module "transaction pool reorg tests" =
( module struct
  

module Account_spec = struct
  type t = {
    key_idx : int
    ; balance: int
    ; nonce: int
  } [@@deriving sexp]

  let rec find_in_test_keys ?(n=0) (x:Keypair.t) =
    if Keypair.equal test_keys.(n) x then n 
    else find_in_test_keys x ~n:(n+1)

  let create key_idx balance nonce = 
    {
      key_idx
      ; balance 
      ; nonce
    }

  let of_ledger_row ledger_row = 
    let (kp,balance,nonce,_)  = ledger_row in
    create 
       (find_in_test_keys kp) 
       (Currency.Amount.to_nanomina_int balance)
       (Unsigned.UInt32.to_int nonce)
  
  let apply_payment amount fee t = 
    create t.key_idx (t.balance - amount - fee) (t.nonce + 1)

  let apply_zkapp fee t = create t.key_idx (t.balance - fee) (t.nonce + 1)

  let to_key_and_nonce t = 
    (Public_key.compress test_keys.(t.key_idx).public_key, t.nonce)

end

module Command_spec = struct

  type t = 
    | Payment of { sender : Account_spec.t
      ; receiver_idx: int
      ; fee: int
      ; amount: int
    } 
    | Zkapp_blocking_send of { sender : Account_spec.t
      ; fee: int
    }
  [@@deriving sexp]

  let gen_zkapp_blocking_send (spec:Account_spec.t array)
   = 
    let open Quickcheck.Generator.Let_syntax in
    let%bind (random_idx, account_spec) = Array.mapi ~f:(fun i e -> (i,e)) spec |> Quickcheck_lib.of_array in
    let new_account_spec = Account_spec.apply_zkapp minimum_fee account_spec in 
    Array.set spec random_idx new_account_spec;
    return (Zkapp_blocking_send {
      sender = account_spec
      ; fee = minimum_fee
    }) 

  let gen_single_from (spec:Account_spec.t array) (idx,account_spec) = 
      let open Quickcheck.Generator.Let_syntax in
        let%bind receiver_idx = test_keys |> Array.mapi ~f:(fun i _-> i) |> Quickcheck_lib.of_array in
        let%bind amount = Int.gen_incl 5_000_000_000_000 10_000_000_000_000  in
        let new_account_spec = Account_spec.apply_payment amount minimum_fee account_spec in 
        Array.set spec idx new_account_spec;
        return (Payment {
            sender = account_spec
          ; fee = minimum_fee
          ; receiver_idx
          ; amount
          })
   
  let gen_sequence (spec:Account_spec.t array) ~length = 
    let open Quickcheck.Generator.Let_syntax in
    Quickcheck_lib.init_gen_array length ~f:(fun _ ->
      let%bind (random_idx, account_spec) = Array.mapi ~f:(fun i e -> (i,e)) spec |> Quickcheck_lib.of_array in
      gen_single_from spec (random_idx,account_spec)
    )
  
  let sender t = match t with
    | Payment {sender; _} ->  sender
    | Zkapp_blocking_send {sender; _} -> sender

  let total_cost t = match t with
    | Payment { amount; fee; _} ->  amount + fee
    | Zkapp_blocking_send {fee; _} -> fee
  
end

(** Main generator for prefix, minor and major sequences. This generator has a more firm grip
     on how data is generated than usual. It uses Command_spec and Account_spec modules for 
     user command definitions which then are carved into Signed_command list. By default generator
     fulfill standard use cases for ledger reorg, like merging transactions from minor and major sequences
     with preference for major sequence as well as 2 additional corner cases:

     ### Edge Case : Nonce Precedence

      - In major sequence, transactions update the account state to a point where the nonce of the account is smaller 
         than the first nonce in the sequence of removed transactions.
      - The mempool logic determines that if this condition is true, the entire minor sequence should be dropped.

     ### Edge Case : Nonce Intersection

      - Transactions using the same account appear in all three sequences (prefix, minor, major)
  
    On top of that one can enable/disable two special corner cases (permission change and limited capacity)
  *)
let gen_branches init_ledger_state ~permission_change ~limited_capacity ?(sequence_max_length=3) () = 
  let open Quickcheck.Generator.Let_syntax in
  let%bind prefix_length = Int.gen_incl 1 sequence_max_length in
  let%bind branch_length = Int.gen_incl 1 sequence_max_length in
    
  let spec = Array.map init_ledger_state ~f:Account_spec.of_ledger_row
  in
  
  let%bind prefix_command_spec = 
    Command_spec.gen_sequence spec ~length:prefix_length in
  
  let minor = Array.copy spec in
  let%bind minor_command_spec = 
    Command_spec.gen_sequence minor ~length:branch_length in
  
  let major = Array.copy spec in
  let%bind major_command_spec = 
    Command_spec.gen_sequence major ~length:branch_length in

  (* Optional Edge Case 1: Limited Account Capacity

    - In major sequence*, a transaction `T` from a specific account decreases its balance by amount `X`.
    - In minor sequence*, the same account decreases its balance in a similar transaction `T'`, but by an amount much smaller than `X`, followed by several other transactions using the same account.
    - The prefix ledger* contains just enough funds to process major sequence, with a small surplus.
    - When applying *minor sequence* without the transaction `T'` (of the same nonce as the large-amount transaction `T` in major sequence), 
        the sequence becomes partially applicable, forcing the mempool logic to drop some transactions at the end of *minor sequence*.
  *)

  (*find account in major and minor brnaches with the same nonces and similar balances (less than 100k mina diff)*)
  let minor_acc_opt = Array.find_map minor ~f:(fun minor_acc -> 
      Array.find major ~f:(fun major_acc -> 
            Int.equal minor_acc.nonce major_acc.nonce &&
            minor_acc.balance - major_acc.balance < 100_000_000_000
      ) |> Option.map ~f:(fun major_acc -> (major_acc,minor_acc))
  ) 
  in
  let%bind (major_command_spec, minor_command_spec) = match minor_acc_opt with 
    | Some (major_acc,minor_acc) when limited_capacity -> 
      
      let%bind receiver_idx = test_keys |> Array.filter_mapi ~f:(fun i _-> if Int.equal i major_acc.key_idx then None else Some i) |> Quickcheck_lib.of_array in
      let big_tx_amount = major_acc.balance / 2 in
      let small_tx_amount = major_acc.balance / 3 in
      let big_major_tx = Command_spec.Payment { sender = major_acc
          ; receiver_idx
          ; fee = minimum_fee
          ; amount = big_tx_amount
          } in
      let new_account_spec = Account_spec.apply_payment big_tx_amount minimum_fee major_acc in 
      Array.set major new_account_spec.key_idx new_account_spec;
      (* 3 smaller commands from which first and last one should be dropped *)
      let minor_txs = Array.init 3 ~f:(fun _ ->
          let sender = minor.(minor_acc.key_idx) in
          let small_minor_tx = Command_spec.Payment { sender
          ; receiver_idx
          ; fee = minimum_fee
          ; amount = small_tx_amount - 1_000_000
          } in
          let new_account_spec = Account_spec.apply_payment small_tx_amount minimum_fee sender in 
          Array.set minor minor_acc.key_idx new_account_spec;
          small_minor_tx
        )
         in
         return (Array.append major_command_spec [|big_major_tx|],
          Array.append minor_command_spec minor_txs) 
      
    | _ -> return (major_command_spec,minor_command_spec)
  in

  (* Optional Edge Case : Permission Changes:

    - In major sequence, a transaction modifies an account's permissions:
        1. It removes the permission to maintain the nonce.
        2. It removes the permission to send transactions.
    - In minor sequence, there is a regular transaction involving the same account, 
        but after the permission-modifying transaction in major sequence, 
        the new transaction becomes invalid and must be dropped.
  *)
  let%bind permission_change_cmd = Command_spec.gen_zkapp_blocking_send major in
  let sender = Command_spec.sender permission_change_cmd in
  (* We need to increase nonce so transaction has a chance to be placed in the pool.
    Otherwise it will be dropped as we already have transaction with the same nonce from major sequence
  *)
  let sender = major.(sender.key_idx) in
  let%bind aux_minor_cmd = Command_spec.gen_single_from minor (sender.key_idx,sender) in
  let major_command_spec = (  if permission_change then 
       Array.append major_command_spec [| permission_change_cmd |]
     else major_command_spec
  )
  in
  let minor_command_spec = (  if permission_change then 
    Array.append minor_command_spec [| aux_minor_cmd |]
    else minor_command_spec
  ) in

  return (prefix_command_spec,major_command_spec,minor_command_spec, minor, major )

let gen_commands_from_specs (sequence:Command_spec.t array) test : (User_command.Valid.t list) =
    let best_tip_ledger = Option.value_exn test.txn_pool.best_tip_ledger in 
    sequence |> Array.map ~f:(fun spec -> 
      match spec with 
      | Zkapp_blocking_send { sender; _ }-> 
        let zkapp = mk_basic_zkapp sender.nonce test_keys.(sender.key_idx) ~permissions:{ 
          Permissions.user_default with
          send = Permissions.Auth_required.Impossible
          ; increment_nonce = Permissions.Auth_required.Impossible
        } in
          Or_error.ok_exn
            (Zkapp_command.Valid.to_valid ~failed:false
               ~find_vk:
                 (Zkapp_command.Verifiable.load_vk_from_ledger
                    ~get:(Mina_ledger.Ledger.get best_tip_ledger)
                    ~location_of_account:
                      (Mina_ledger.Ledger.location_of_account best_tip_ledger) )
           zkapp) |> User_command.Zkapp_command 
      | Payment {sender;fee;amount;receiver_idx}->
        mk_payment ~sender_idx:sender.key_idx ~fee ~nonce:
        sender.nonce ~receiver_idx
        ~amount ()
    ) |> Array.to_list

let%test_unit "Handle transition frontier diff (permission send tx updated)" =
  (* 
    Testing strategy focuses specifically on the mempool layer, where we are given the following inputs:

      - A list of transactions that were **removed** due to the blockchain reorganization.
      - A list of transactions that were **added** in the new blocks.
      - The new **ledger** after the reorganization.

  This property-based test that generates three transaction sequences, 
  computes intermediate ledgers and verifies certain invariants after the call to `handle_transition_frontier_diff`.

  - Prefix sequence: a sequence of transactions originating from initial ledger
  - Major sequence: a sequence of transactions originating from prefix ledger
  - Major ledger: result of application of joint prefix and major sequences to prefix ledger
  - Minor sequence: a sequence of transactions originating from *prefix ledger
    -  It’s role in testing is that of a transaction sequence extracted from an “rolled back” chain
  *)
  Quickcheck.test ~trials:1 ~seed:(`Deterministic "")
    (let open Quickcheck.Generator.Let_syntax in
    let test = Thread_safe.block_on_async_exn (fun () -> setup_test ()) in
    let init_ledger_state = ledger_snapshot test in
    let%bind (prefix,major,minor,minor_account_spec,major_account_spec) = gen_branches init_ledger_state ~permission_change:true ~limited_capacity:true () in
    return (test,init_ledger_state,prefix,major,minor,major_account_spec,minor_account_spec))
    ~f:(fun (test,_init_ledger_state,prefix_specs,major_specs,minor_specs,major_account_spec,minor_account_spec) ->
      Thread_safe.block_on_async_exn (fun () ->
        let log_prefix = Array.map prefix_specs ~f:(fun cmd ->
          let sender = Command_spec.sender cmd in 
          let content = Printf.sprintf !"%{sexp: Public_key.t} %{sexp: Command_spec.t}" test_keys.(sender.key_idx).public_key cmd in
          `String content
        ) |> Array.to_list in

        let log_major = Array.map minor_specs ~f:(fun cmd ->
          let sender = Command_spec.sender cmd in 
          let content = Printf.sprintf !"%{sexp: Public_key.t} %{sexp: Command_spec.t}" test_keys.(sender.key_idx).public_key cmd in
          `String content
        ) |> Array.to_list in
        
        let log_minor = Array.map major_specs ~f:(fun cmd ->
          let sender = Command_spec.sender cmd in 
          let content = Printf.sprintf !"%{sexp: Public_key.t} %{sexp: Command_spec.t}" test_keys.(sender.key_idx).public_key cmd in
          `String content
        )|> Array.to_list in

        let log_minor_accounts_state = Array.map minor_account_spec ~f:(fun spec ->
          `String (Printf.sprintf !"%{sexp: Account_spec.t}\n" spec)
        ) |> Array.to_list in
        let log_major_accounts_state = Array.map major_account_spec ~f:(fun spec ->
          `String ( Printf.sprintf !"%{sexp: Account_spec.t}\n" spec)
        ) |> Array.to_list in
        
        [%log info] "Sequences" ~metadata:[
          ("prefix" , `List log_prefix)
          ; ("major" , `List log_major)
          ; ("minor" , `List log_minor)
          ; ("minor accounts state",`List log_minor_accounts_state )
          ; ("major accounts state", `List log_major_accounts_state)
        ];

        let prefix = gen_commands_from_specs (Array.concat [prefix_specs]) test in
        let minor = gen_commands_from_specs (Array.concat [minor_specs]) test in
        let major = gen_commands_from_specs (Array.concat [major_specs]) test in
        
        let%bind () = advance_chain test (prefix @ major) in

          Test.Resource_pool.handle_transition_frontier_diff_inner
            ~new_commands:(List.map ~f:mk_with_status (prefix @ major))
            ~removed_commands:(List.map ~f:mk_with_status (prefix @ minor))
            ~best_tip_ledger:(Option.value_exn test.txn_pool.best_tip_ledger) test.txn_pool ;

          Async.printf "Pool state: \n";
          let pool_state = Test.Resource_pool.get_all test.txn_pool |> 
           List.map ~f:(fun tx ->
            let data = Transaction_hash.User_command_with_valid_signature.data tx in
            let nonce = data |> User_command.forget_check
             |> User_command.applicable_at_nonce |> Unsigned.UInt32.to_int in 
             let fee_payer_pk = data |> User_command.forget_check
             |> User_command.fee_payer |> Account_id.public_key
             in
             (fee_payer_pk,nonce)
            ) in 

          let log_pool_content = List.map pool_state ~f:(fun (fee_payer_pk,nonce) -> 
            `String ( Printf.sprintf !"%{sexp: Public_key.Compressed.t} : %d" fee_payer_pk nonce )
          ) in
          
          [%log info] "Pool state" ~metadata:[
            ("pool state", `List log_pool_content )
          ];

          let assert_pool_contains pool_state (pk,nonce)= 
            let actual_opt = List.find pool_state ~f:(fun (fee_payer_pk, actual_nonce ) -> 
              Public_key.Compressed.equal pk fee_payer_pk &&
              Int.equal actual_nonce nonce
            ) in
          match actual_opt with 
            | Some actual -> [%test_eq: (Public_key.Compressed.t * int)] (pk,nonce) actual;
            | None -> failwithf !"Expected transaction from %{sexp: Public_key.Compressed.t} with nonce %d not found \n" pk nonce ();
          
          in

          let assert_pool_doesn't_contain pool_state (pk,nonce)= 
            let actual_opt = List.find pool_state ~f:(fun (fee_payer_pk, actual_nonce ) -> 
                Public_key.Compressed.equal pk fee_payer_pk &&
                Int.equal actual_nonce nonce
              ) in
              match actual_opt with 
              | Some _ -> failwithf !"Unexpected transaction from %{sexp: Public_key.Compressed.t} with nonce %d found \n" pk nonce ();
              | None -> () 
            
        in
        
        
        Array.iter minor_specs ~f:(fun (spec:Command_spec.t) ->
            let sender = Command_spec.sender spec in
            let (pk, nonce) = Account_spec.to_key_and_nonce sender in
           
            let find_owned (acc:Account_spec.t) (txs:Command_spec.t array) = 
              Array.filter txs ~f:(fun x -> 
                let sender = Command_spec.sender x in
                Int.equal acc.key_idx sender.key_idx && 
                Int.(>) acc.nonce sender.nonce)
            
            in  
            let account_spec = Array.find major_account_spec ~f:(fun spec -> 
                Int.equal sender.key_idx spec.key_idx && spec.nonce > 0
              )
            in
            match account_spec with
              | Some account_spec -> 
                if Int.(>=) sender.nonce account_spec.nonce then
                  (
                    let sent_blocking_zkapp (specs:Command_spec.t array) pk = 
                      Array.find specs ~f:(fun s -> 
                        match s with
                          | Payment _ -> false
                          | Zkapp_blocking_send {sender;_} ->  
                              let (cur_pk,_) = Account_spec.to_key_and_nonce sender in
                              Public_key.Compressed.equal pk cur_pk

                      ) |> Option.is_some
                    in
                    if sent_blocking_zkapp major_specs pk then 
                      (
                        [%log info] "major chain contains blocking zkapp. command should be dropped"
                        ~metadata: [
                          ("sent from", `String (Printf.sprintf !"%{sexp: Public_key.Compressed.t}" pk) )
                        ];
                        assert_pool_doesn't_contain pool_state (pk,nonce);
                      )
                    else
                      (
                        let total_cost = find_owned sender minor_specs |> Array.map ~f:Command_spec.total_cost |> Array.sum ~f:Fn.id (module Int) in
                        if (account_spec.balance - total_cost) > 0 then
                          (
                            [%log info] "sender nonce is greater than last major nonce. should be in the pool"
                            ~metadata: [
                              ("sent from", `String (Printf.sprintf !"%{sexp: Public_key.Compressed.t} -> %d}" pk nonce) )
                            ];  
                          assert_pool_contains pool_state (pk,nonce);
                          )
                        else
                          ( 
                            [%log info] "balance is negative. should be dropped from pool"
                            ~metadata: [
                              ("sent from", `String (Printf.sprintf !"%{sexp: Public_key.Compressed.t} -> %d" pk nonce) )
                            ];  
                          assert_pool_doesn't_contain pool_state (pk,nonce);
                          )
                      );
                    
                  )
                else 
                  (

                  [%log info] "sender nonce is smaller than last major nonce. command should be dropped"
                  ~metadata: [
                    ("sent from", `String (Printf.sprintf !"%{sexp: Public_key.Compressed.t} -> %d" pk nonce) )
                  ];
                  assert_pool_doesn't_contain pool_state (pk,nonce);)
              | None ->
                  (

                  [%log info] "sender didn't send any tx to major branch. command should be in the pool"
                  ~metadata: [
                    ("sent from", `String (Printf.sprintf !"%{sexp: Public_key.Compressed.t} -> %d" pk nonce) )
                  ];
                  assert_pool_contains pool_state (pk,nonce);)
            );
            Deferred.unit
           );
          
           )

end)