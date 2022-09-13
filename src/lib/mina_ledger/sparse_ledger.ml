open Core_kernel
open Mina_base
include Sparse_ledger_base
module GS = Global_state

let of_ledger_root ledger =
  of_root ~depth:(Ledger.depth ledger) (Ledger.merkle_root ledger)

let of_any_ledger (ledger : Ledger.Any_ledger.witness) =
  Ledger.Any_ledger.M.foldi ledger
    ~init:
      (of_root
         ~depth:(Ledger.Any_ledger.M.depth ledger)
         (Ledger.Any_ledger.M.merkle_root ledger) )
    ~f:(fun _addr sparse_ledger account ->
      let loc =
        Option.value_exn
          (Ledger.Any_ledger.M.location_of_account ledger
             (Account.identifier account) )
      in
      add_path sparse_ledger
        (Ledger.Any_ledger.M.merkle_path ledger loc)
        (Account.identifier account)
        (Option.value_exn (Ledger.Any_ledger.M.get ledger loc)) )

let of_ledger_subset_exn (oledger : Ledger.t) keys =
  let ledger = Ledger.copy oledger in
  let _, sparse =
    List.fold keys
      ~f:(fun (new_keys, sl) key ->
        match Ledger.location_of_account ledger key with
        | Some loc ->
            ( new_keys
            , add_path sl
                (Ledger.merkle_path ledger loc)
                key
                ( Ledger.get ledger loc
                |> Option.value_exn ?here:None ?error:None ?message:None ) )
        | None ->
            let path, acct = Ledger.create_empty_exn ledger key in
            (key :: new_keys, add_path sl path key acct) )
      ~init:([], of_ledger_root ledger)
  in
  Debug_assert.debug_assert (fun () ->
      [%test_eq: Ledger_hash.t]
        (Ledger.merkle_root ledger)
        ((merkle_root sparse :> Random_oracle.Digest.t) |> Ledger_hash.of_hash) ) ;
  sparse

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
    ~depth:Genesis_constants.Constraint_constants.for_unit_tests.ledger_depth
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

let apply_parties_unchecked_with_states ~constraint_constants ~state_view
    ~fee_excess ledger c =
  let open T in
  (* TODO *)
  apply_parties_unchecked_aux ~constraint_constants ~state_view ~fee_excess
    (ref ledger) c ~init:[]
    ~f:(fun
         acc
         ( { first_pass_ledger; second_pass_ledger; fee_excess; protocol_state }
         , local_state )
       ->
      ( { GS.first_pass_ledger = !first_pass_ledger
        ; second_pass_ledger = !second_pass_ledger
        ; fee_excess
        ; protocol_state
        }
      , { local_state with ledger = !(local_state.ledger) } )
      :: acc )
  |> Result.map ~f:(fun (party_applied, states) ->
         (* We perform a [List.rev] here to ensure that the states are in order
            wrt. the parties that generated the states.
         *)
         (party_applied, List.rev states) )

let apply_transaction_logic f t x =
  let open Or_error.Let_syntax in
  let t' = ref t in
  let%map app = f t' x in
  (!t', app)

let apply_user_command ~constraint_constants ~txn_global_slot =
  apply_transaction_logic
    (T.apply_user_command ~constraint_constants ~txn_global_slot)

let apply_transaction' ~constraint_constants ~txn_state_view l t =
  O1trace.sync_thread "apply_transaction" (fun () ->
      T.apply_transaction ~constraint_constants ~txn_state_view l t )

let apply_transaction ~constraint_constants ~txn_state_view =
  apply_transaction_logic
    (apply_transaction' ~constraint_constants ~txn_state_view)
