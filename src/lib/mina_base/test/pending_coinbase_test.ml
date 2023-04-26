(** Testing
    -------
    Component:  Mina base
    Invocation: dune exec src/lib/mina_base/test/main.exe -- test '^pending coinbase$'
    Subject:    Test pending coinbase.
 *)

open Core_kernel
open Currency
open Signature_lib
open Mina_base
open Pending_coinbase
open For_tests

let run_and_check = Snark_params.Tick.run_and_check

let add_stack_plus_remove_stack_equals_initial_tree () =
  let constraint_constants =
    Genesis_constants.Constraint_constants.for_unit_tests
  in
  let depth = constraint_constants.pending_coinbase_depth in
  let coinbases_gen =
    Quickcheck.Generator.list_non_empty (Coinbase.Gen.gen ~constraint_constants)
  in
  let pending_coinbases = ref (create ~depth () |> Or_error.ok_exn) in
  Quickcheck.test coinbases_gen ~trials:50 ~f:(fun cbs ->
      Run_in_thread.block_on_async_exn (fun () ->
          let is_new_stack = ref true in
          let init = merkle_root !pending_coinbases in
          let after_adding =
            List.fold cbs ~init:!pending_coinbases ~f:(fun acc (coinbase, _) ->
                let t =
                  add_coinbase ~depth acc ~coinbase ~is_new_stack:!is_new_stack
                  |> Or_error.ok_exn
                in
                is_new_stack := false ;
                t )
          in
          let _, after_del =
            remove_coinbase_stack ~depth after_adding |> Or_error.ok_exn
          in
          pending_coinbases := after_del ;
          [%test_eq: Hash.t] (merkle_root after_del) init ;
          Async_kernel.Deferred.return () ) )

let checked_stack_equals_unchecked_stack () =
  let open Quickcheck in
  let constraint_constants =
    Genesis_constants.Constraint_constants.for_unit_tests
  in
  test ~trials:20
    (Generator.tuple2 Stack.gen (Coinbase.Gen.gen ~constraint_constants))
    ~f:(fun (base, (cb, _supercharged_coinbase)) ->
      let coinbase_data = Coinbase_data.of_coinbase cb in
      let unchecked = Stack.push_coinbase cb base in
      let checked =
        let comp =
          let open Snark_params.Tick in
          let cb_var = Coinbase_data.(var_of_t coinbase_data) in
          let%map res =
            Stack.Checked.push_coinbase cb_var (Stack.var_of_t base)
          in
          As_prover.read Stack.typ res
        in
        Or_error.ok_exn (run_and_check comp)
      in
      [%test_eq: Stack.t] unchecked checked )

let checked_tree_equals_unchecked_tree () =
  let open Quickcheck in
  let constraint_constants =
    Genesis_constants.Constraint_constants.for_unit_tests
  in
  let depth = constraint_constants.pending_coinbase_depth in
  let pending_coinbases = create ~depth () |> Or_error.ok_exn in
  test ~trials:20
    (Generator.tuple3
       (Coinbase.Gen.gen ~constraint_constants)
       State_body_hash.gen Mina_numbers.Global_slot.gen )
    ~f:(fun ( (coinbase, `Supercharged_coinbase supercharged_coinbase)
            , state_body_hash
            , global_slot ) ->
      let amount = coinbase.amount in
      let is_new_stack, action =
        Currency.Amount.(
          if equal coinbase.amount zero then (true, Update.Action.Update_none)
          else (true, Update_one))
      in
      let unchecked =
        add_coinbase_with_zero_checks ~constraint_constants pending_coinbases
          ~coinbase ~is_new_stack ~state_body_hash ~global_slot
          ~supercharged_coinbase
      in
      (* inside the `open' below, Checked means something else, so define this function *)
      let f_add_coinbase = Checked.add_coinbase ~constraint_constants in
      let checked_merkle_root =
        let comp =
          let open Snark_params.Tick in
          let amount_var = Amount.var_of_t amount in
          let action_var = Update.Action.var_of_t action in
          let coinbase_receiver_var =
            Public_key.Compressed.var_of_t coinbase.receiver
          in
          let supercharge_coinbase_var =
            Boolean.var_of_value supercharged_coinbase
          in
          let state_body_hash_var = State_body_hash.var_of_t state_body_hash in
          let global_slot_var =
            Mina_numbers.Global_slot.Checked.constant global_slot
          in
          let%map result =
            handle
              (fun () ->
                f_add_coinbase
                  (Hash.var_of_t (merkle_root pending_coinbases))
                  { Update.Poly.action = action_var
                  ; coinbase_amount = amount_var
                  }
                  ~coinbase_receiver:coinbase_receiver_var
                  ~supercharge_coinbase:supercharge_coinbase_var
                  state_body_hash_var global_slot_var )
              (unstage (handler ~depth pending_coinbases ~is_new_stack))
          in
          As_prover.read Hash.typ result
        in
        Or_error.ok_exn (run_and_check comp)
      in
      [%test_eq: Hash.t] (merkle_root unchecked) checked_merkle_root )

let checked_tree_equals_unchecked_tree_after_pop () =
  let open Quickcheck in
  let constraint_constants =
    Genesis_constants.Constraint_constants.for_unit_tests
  in
  let depth = constraint_constants.pending_coinbase_depth in
  test ~trials:20
    (Generator.tuple3
       (Coinbase.Gen.gen ~constraint_constants)
       State_body_hash.gen Mina_numbers.Global_slot.gen )
    ~f:(fun ( (coinbase, `Supercharged_coinbase supercharged_coinbase)
            , state_body_hash
            , global_slot ) ->
      let pending_coinbases = create ~depth () |> Or_error.ok_exn in
      let amount = coinbase.amount in
      let action =
        Currency.Amount.(
          if equal coinbase.amount zero then Update.Action.Update_none
          else Update_one)
      in
      let unchecked =
        add_coinbase_with_zero_checks ~constraint_constants pending_coinbases
          ~coinbase ~is_new_stack:true ~state_body_hash ~global_slot
          ~supercharged_coinbase
      in
      (* inside the `open' below, Checked means something else, so define these functions *)
      let f_add_coinbase = Checked.add_coinbase ~constraint_constants in
      let f_pop_coinbase = Checked.pop_coinbases ~constraint_constants in
      let checked_merkle_root =
        let comp =
          let open Snark_params.Tick in
          let amount_var = Amount.var_of_t amount in
          let action_var = Update.Action.(var_of_t action) in
          let coinbase_receiver_var =
            Public_key.Compressed.var_of_t coinbase.receiver
          in
          let supercharge_coinbase_var =
            Boolean.var_of_value supercharged_coinbase
          in
          let state_body_hash_var = State_body_hash.var_of_t state_body_hash in
          let global_slot_var =
            Mina_numbers.Global_slot.Checked.constant global_slot
          in
          let%map result =
            handle
              (fun () ->
                f_add_coinbase
                  (Hash.var_of_t (merkle_root pending_coinbases))
                  { Update.Poly.action = action_var
                  ; coinbase_amount = amount_var
                  }
                  ~coinbase_receiver:coinbase_receiver_var
                  ~supercharge_coinbase:supercharge_coinbase_var
                  state_body_hash_var global_slot_var )
              (unstage (handler ~depth pending_coinbases ~is_new_stack:true))
          in
          As_prover.read Hash.typ result
        in
        Or_error.ok_exn (run_and_check comp)
      in
      [%test_eq: Hash.t] (merkle_root unchecked) checked_merkle_root ;
      (* deleting the coinbase stack we just created. therefore if there
         was no update then don't try to delete *)
      let proof_emitted = not Update.Action.(equal action Update_none) in
      let unchecked_after_pop =
        if proof_emitted then
          remove_coinbase_stack ~depth unchecked |> Or_error.ok_exn |> snd
        else unchecked
      in
      let checked_merkle_root_after_pop =
        let comp =
          let open Snark_params.Tick in
          let%map current, _previous =
            handle
              (fun () ->
                f_pop_coinbase ~proof_emitted:Boolean.true_
                  (Hash.var_of_t checked_merkle_root) )
              (unstage (handler ~depth unchecked ~is_new_stack:false))
          in
          As_prover.read Hash.typ current
        in
        Or_error.ok_exn (run_and_check comp)
      in
      [%test_eq: Hash.t]
        (merkle_root unchecked_after_pop)
        checked_merkle_root_after_pop )

let push_and_pop_multiple_stacks () =
  let open Quickcheck in
  let constraint_constants =
    { Genesis_constants.Constraint_constants.for_unit_tests with
      pending_coinbase_depth = 3
    }
  in
  let depth = constraint_constants.pending_coinbase_depth in
  let t_of_coinbases t = function
    | [] ->
        let t' = incr_index ~depth t ~is_new_stack:true |> Or_error.ok_exn in
        (Stack.empty, t')
    | ((initial_coinbase, _supercharged_coinbase), state_body_hash, global_slot)
      :: coinbases ->
        let t' =
          add_state ~depth t state_body_hash global_slot ~is_new_stack:true
          |> Or_error.ok_exn
          |> add_coinbase ~depth ~coinbase:initial_coinbase ~is_new_stack:false
          |> Or_error.ok_exn
        in
        let updated =
          List.fold coinbases ~init:t'
            ~f:(fun
                 pending_coinbases
                 ( (coinbase, `Supercharged_coinbase supercharged_coinbase)
                 , state_body_hash
                 , global_slot )
               ->
              add_coinbase_with_zero_checks ~constraint_constants
                pending_coinbases ~coinbase ~is_new_stack:false ~state_body_hash
                ~global_slot ~supercharged_coinbase )
        in
        let new_stack =
          Or_error.ok_exn @@ latest_stack updated ~is_new_stack:false
        in
        (new_stack, updated)
  in
  (* Create pending coinbase stacks from coinbase lists and add it to the pending coinbase merkle tree *)
  let add coinbase_lists pending_coinbases =
    List.fold ~init:([], pending_coinbases) coinbase_lists
      ~f:(fun (stacks, pc) coinbases ->
        let new_stack, pc = t_of_coinbases pc coinbases in
        (new_stack :: stacks, pc) )
  in
  (* remove the oldest stack and check if that's the expected one *)
  let remove_check t expected_stack =
    let popped_stack, updated_pending_coinbases =
      remove_coinbase_stack ~depth t |> Or_error.ok_exn
    in
    [%test_eq: Stack.t] ~equal:Stack.equal_data popped_stack expected_stack ;
    updated_pending_coinbases
  in
  let add_remove_check coinbase_lists =
    let max_coinbase_stack_count = max_coinbase_stack_count ~depth in
    let pending_coinbases = create_exn ~depth () in
    let rec go coinbase_lists pc =
      if List.is_empty coinbase_lists then ()
      else
        let coinbase_lists' =
          List.take coinbase_lists max_coinbase_stack_count
        in
        let added_stacks, pending_coinbases_updated = add coinbase_lists' pc in
        let pending_coinbases' =
          List.fold ~init:pending_coinbases_updated (List.rev added_stacks)
            ~f:(fun pc expected_stack -> remove_check pc expected_stack)
        in
        let remaining_lists =
          List.drop coinbase_lists max_coinbase_stack_count
        in
        go remaining_lists pending_coinbases'
    in
    go coinbase_lists pending_coinbases
  in
  let coinbase_lists_gen =
    Quickcheck.Generator.(
      list
        (list
           (Generator.tuple3
              (Coinbase.Gen.gen ~constraint_constants)
              State_body_hash.gen Mina_numbers.Global_slot.gen ) ))
  in
  test ~trials:100 coinbase_lists_gen ~f:add_remove_check
