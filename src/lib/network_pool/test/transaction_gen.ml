open Core_kernel
open Currency
open Mina_base
open Mina_numbers
open Mina_transaction
open Network_pool
open Signature_lib

let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

let constraint_constants = precomputed_values.constraint_constants

let consensus_constants = precomputed_values.consensus_constants

let test_keys = Array.init 10 ~f:(fun _ -> Keypair.create ())

let gen_cmd ?(keys = test_keys) ?sign_type ?nonce () =
  User_command.Valid.Gen.payment_with_random_participants ~keys ~max_amount:1000
    ~fee_range:100 ?sign_type ?nonce ()
  |> Quickcheck.Generator.map
       ~f:Transaction_hash.User_command_with_valid_signature.create

let txn_nonce txn =
  let unchecked =
    Transaction_hash.User_command_with_valid_signature.forget_check txn
  in
  match unchecked.data with
  | Signed_command cmd ->
      cmd.payload.common.nonce
  | Zkapp_command cmd ->
      cmd.fee_payer.body.nonce

let sender_pk txn =
  let unchecked =
    Transaction_hash.User_command_with_valid_signature.forget_check txn
  in
  match unchecked.data with
  | Signed_command cmd ->
      cmd.payload.common.fee_payer_pk
  | Zkapp_command cmd ->
      cmd.fee_payer.body.public_key

let rec rem_lowest_fee count pool =
  if count > 0 then
    rem_lowest_fee (count - 1) (Indexed_pool.remove_lowest_fee pool |> snd)
  else pool

module Stateful_gen = Monad_lib.State.Trans (Quickcheck.Generator)
module Stateful_gen_ext = Monad_lib.Make_ext2 (Stateful_gen)
module Result_ext = Monad_lib.Make_ext2 (Result)

let sgn_cmd_to_txn cmd =
  Signed_command cmd
  |> Transaction_hash.User_command_with_valid_signature.create

let gen_amount : (uint64, Account.t) Stateful_gen.t =
  let open Stateful_gen in
  let open Let_syntax in
  let open Account.Poly in
  let%bind balance = getf (fun a -> a.balance) in
  let%bind amt = lift @@ Amount.(gen_incl zero @@ Balance.to_amount balance) in
  let%map () =
    modify ~f:(fun a ->
        { a with balance = Option.value_exn @@ Balance.sub_amount balance amt } )
  in
  Amount.to_uint64 amt

let accounts_map accounts =
  List.map accounts ~f:Account.Poly.(fun a -> (a.public_key, a))
  |> Public_key.Compressed.Map.of_alist_exn

let with_accounts ~f ~account_map ~init txns =
  Result_ext.fold_m txns ~init:(account_map, init)
    ~f:(fun (accounts, accum) t ->
      let open Result.Let_syntax in
      let pk = sender_pk t in
      let a = Public_key.Compressed.Map.find_exn accounts pk in
      let%map accum' = f accum a t in
      let accounts' =
        Public_key.Compressed.Map.set accounts ~key:pk
          ~data:Account.Poly.{ a with nonce = Account_nonce.succ a.nonce }
      in
      (accounts', accum') )
  |> Result.map ~f:snd

let pool_of_transactions ~init ~account_map txns =
  Result_ext.fold_m
    (List.map txns ~f:(fun t ->
         Transaction_hash.User_command_with_valid_signature.create
           (Signed_command t) ) )
    ~init
    ~f:(fun p t ->
      let open Account.Poly in
      Indexed_pool.For_tests.assert_invariants p ;
      let a = Public_key.Compressed.Map.find_exn account_map (sender_pk t) in
      Indexed_pool.add_from_gossip_exn p t a.nonce (Balance.to_amount a.balance)
      |> Result.map ~f:Tuple3.get2 )
  |> Result.map_error ~f:(fun e -> Sexp.to_string @@ Command_error.sexp_of_t e)
  |> Result.ok_or_failwith

let rec gen_txns_from_single_sender_to receiver_public_key =
  let open Stateful_gen in
  let open Let_syntax in
  let open Account.Poly in
  let%bind sender = get in
  if Balance.(sender.balance = zero) then return []
  else
    let%bind () =
      modify ~f:(fun a -> { a with nonce = Account_nonce.succ a.nonce })
    in
    let%bind txn_amt = map ~f:Amount.of_uint64 gen_amount in
    let%bind txn_fee = map ~f:Fee.of_uint64 gen_amount in
    let cmd =
      let open Signed_command.Payload in
      Signed_command.Poly.
        { payload =
            Poly.
              { common =
                  Common.Poly.
                    { fee = txn_fee
                    ; fee_payer_pk = sender.public_key
                    ; nonce = sender.nonce
                    ; valid_until = Global_slot_since_genesis.max_value
                    ; memo = Signed_command_memo.dummy
                    }
              ; body =
                  Body.Payment
                    Payment_payload.Poly.
                      { receiver_pk = receiver_public_key; amount = txn_amt }
              }
        ; signer = Option.value_exn @@ Public_key.decompress sender.public_key
        ; signature = Signature.dummy
        }
    in
    let%map more = gen_txns_from_single_sender_to receiver_public_key in
    (* Signatures don't matter in these tests. *)
    let (`If_this_is_used_it_should_have_a_comment_justifying_it valid_cmd) =
      Signed_command.to_valid_unsafe cmd
    in
    valid_cmd :: more
