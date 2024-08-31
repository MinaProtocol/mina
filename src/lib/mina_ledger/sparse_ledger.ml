open Core_kernel
open Mina_base
include Sparse_ledger_base
module GS = Global_state

let of_ledger_root ledger =
  of_root ~depth:(Ledger.depth ledger) (Ledger.merkle_root ledger)

(*** [iterate_n ~f init n] returns [[f init, f (f init), ..]] of size [n] *)
let iterate_n ~f =
  let rec impl prev = function
    | 0 ->
        []
    | n ->
        let r = f prev in
        r :: impl r (n - 1)
  in
  impl

let of_ledger_subset_exn_impl ~path_query ~path_add (oledger : Ledger.t) keys =
  let locations = Ledger.location_of_account_batch oledger keys in
  let non_empty_locations = List.filter_map locations ~f:snd in
  let num_new_accounts =
    List.length locations - List.length non_empty_locations
  in
  let accounts = Ledger.get_batch oledger non_empty_locations in
  let empty_paths, non_empty_paths =
    let next_location_exn loc = Option.value_exn (Ledger.Location.next loc) in
    let empty_address =
      Ledger.Addr.of_directions
      @@ List.init (Ledger.depth oledger) ~f:(Fn.const Direction.Left)
    in
    let empty_locations =
      if num_new_accounts = 0 then []
      else
        let first_loc =
          Option.value_map ~f:next_location_exn
            ~default:(Ledger.Location.Account empty_address)
            (Ledger.last_filled oledger)
        in
        first_loc
        :: iterate_n ~f:next_location_exn first_loc (num_new_accounts - 1)
    in
    let paths = path_query oledger (empty_locations @ non_empty_locations) in
    List.split_n paths num_new_accounts
  in
  let process_location sl key = function
    | Some _, (_, Some account) :: accs, path :: ne_paths, epaths ->
        (path_add sl path key account, accs, ne_paths, epaths)
    | None, accs, ne_paths, path :: epaths ->
        (path_add sl path key Account.empty, accs, ne_paths, epaths)
    | Some _, (_, None) :: _, _, _ ->
        failwith
          "of_ledger_subset_exn: account not found for location returned by \
           location_of_account_batch"
    | _ ->
        failwith "of_ledger_subset_exn: mismatched lengths"
  in
  let sl, _, _, _ =
    List.fold locations
      ~init:(of_ledger_root oledger, accounts, non_empty_paths, empty_paths)
      ~f:(fun (sl, accs, ne_paths, epaths) (key, mloc) ->
        process_location sl key (mloc, accs, ne_paths, epaths) )
  in
  Debug_assert.debug_assert (fun () ->
      [%test_eq: Ledger_hash.t]
        (Ledger.merkle_root oledger)
        ((merkle_root sl :> Random_oracle.Digest.t) |> Ledger_hash.of_hash) ) ;
  sl

let of_ledger_subset_exn =
  of_ledger_subset_exn_impl ~path_query:Ledger.wide_merkle_path_batch
    ~path_add:add_wide_path_unsafe

let of_ledger_index_subset_exn (ledger : Ledger.Any_ledger.witness) indexes =
  List.fold indexes
    ~init:
      (of_root
         ~depth:(Ledger.Any_ledger.M.depth ledger)
         (Ledger.Any_ledger.M.merkle_root ledger) )
    ~f:(fun acc i ->
      let account = Ledger.Any_ledger.M.get_at_index_exn ledger i in
      add_path acc
        (Ledger.Any_ledger.M.merkle_path_at_index_exn ledger i)
        (Account.identifier account)
        account )

let%test_unit "of_ledger_subset_exn with keys that don't exist works" =
  let keygen () =
    let privkey = Signature_lib.Private_key.create () in
    ( privkey
    , Signature_lib.Public_key.of_private_key_exn privkey
      |> Signature_lib.Public_key.compress )
  in
  Ledger.with_ledger
    ~depth:Genesis_constants.For_unit_tests.Constraint_constants.t.ledger_depth
    ~f:(fun ledger ->
      let _, pub1 = keygen () in
      let _, pub2 = keygen () in
      let aid1 = Account_id.create pub1 Token_id.default in
      let aid2 = Account_id.create pub2 Token_id.default in
      let sl = of_ledger_subset_exn ledger [ aid1; aid2 ] in
      [%test_eq: Ledger_hash.t]
        (Ledger.merkle_root ledger)
        ((merkle_root sl :> Random_oracle.Digest.t) |> Ledger_hash.of_hash) )

module T = Mina_transaction_logic.Make (L)

let apply_transaction_logic f t x =
  let t' = ref t in
  let%map.Or_error app = f t' x in
  (!t', app)

let apply_user_command ~constraint_constants ~txn_global_slot =
  apply_transaction_logic
    (T.apply_user_command ~constraint_constants ~txn_global_slot)

let apply_transaction_first_pass ~constraint_constants ~global_slot
    ~txn_state_view =
  apply_transaction_logic
    (T.apply_transaction_first_pass ~constraint_constants ~global_slot
       ~txn_state_view )

let apply_transaction_second_pass =
  apply_transaction_logic T.apply_transaction_second_pass

let apply_transactions ~constraint_constants ~global_slot ~txn_state_view =
  apply_transaction_logic
    (T.apply_transactions ~constraint_constants ~global_slot ~txn_state_view)

let apply_zkapp_first_pass_unchecked_with_states ~constraint_constants
    ~global_slot ~state_view ~fee_excess ~supply_increase ~first_pass_ledger
    ~second_pass_ledger c =
  T.apply_zkapp_command_first_pass_aux ~constraint_constants ~global_slot
    ~state_view ~fee_excess ~supply_increase (ref first_pass_ledger) c ~init:[]
    ~f:(fun
         acc
         ( { first_pass_ledger
           ; second_pass_ledger = _ (*expected to be empty*)
           ; fee_excess
           ; supply_increase
           ; protocol_state
           ; block_global_slot
           }
         , local_state )
       ->
      ( { GS.first_pass_ledger = !first_pass_ledger
        ; second_pass_ledger
        ; fee_excess
        ; supply_increase
        ; protocol_state
        ; block_global_slot
        }
      , { local_state with ledger = !(local_state.ledger) } )
      :: acc )

let apply_zkapp_second_pass_unchecked_with_states ~init ledger c =
  T.apply_zkapp_command_second_pass_aux (ref ledger) c ~init
    ~f:(fun
         acc
         ( { first_pass_ledger
           ; second_pass_ledger
           ; fee_excess
           ; supply_increase
           ; protocol_state
           ; block_global_slot
           }
         , local_state )
       ->
      ( { GS.first_pass_ledger = !first_pass_ledger
        ; second_pass_ledger = !second_pass_ledger
        ; fee_excess
        ; supply_increase
        ; protocol_state
        ; block_global_slot
        }
      , { local_state with ledger = !(local_state.ledger) } )
      :: acc )
  |> Result.map ~f:(fun (account_update_applied, rev_states) ->
         let module LS = Mina_transaction_logic.Zkapp_command_logic.Local_state
         in
         let module Applied = T.Transaction_applied.Zkapp_command_applied in
         let states =
           match rev_states with
           | [] ->
               []
           | final_state :: rev_states ->
               (* Update the [will_succeed] of all *intermediate* states.
                  Note that the first and final states will always have
                  [will_succeed = true], so we must leave them unchanged.
               *)
               let will_succeed =
                 match account_update_applied.Applied.command.status with
                 | Applied ->
                     true
                 | Failed _ ->
                     false
               in
               (* We perform a manual [List.rev] here to ensure that the states
                  are in order wrt. the zkapp_command that generated the states.
               *)
               let rec go states rev_states =
                 match rev_states with
                 | [] ->
                     states
                 | [ initial_state ] ->
                     (* Skip the initial state *)
                     initial_state :: states
                 | (global_state, local_state) :: rev_states ->
                     go
                       ( (global_state, { local_state with LS.will_succeed })
                       :: states )
                       rev_states
               in
               go [ final_state ] rev_states
         in
         (account_update_applied, states) )
