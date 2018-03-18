open Core
open Snark_params
open Snarky
open Tick
open Let_syntax

module Signature = Tick.Signature

module Amount = Currency.T64
module Fee = Currency.T32

let depth = Snark_params.ledger_depth

(* Right now nothing to stop transactions from being applied repeatedly *)
let apply ({ sender; signature; payload } : Transaction.var) root =
  let { Transaction.Payload.receiver; amount; fee } = payload in
  let%bind () =
    let%bind bs = Transaction.Payload.var_to_bits payload in
    Signature.Checked.assert_verifies signature sender bs
  in
  let%bind root =
    Ledger.modify_account root (Public_key.compress_var sender) ~f:(fun account ->
      let%map balance = Amount.(account.balance - amount) in (* TODO: Fee *)
      { account with balance })
  in
  Ledger.modify_account root receiver ~f:(fun account ->
    let%map balance = Amount.(account.balance + amount) in
    { account with balance })

let apply_many ts root =
  let rec go acc = function
    | [] -> return acc
    | t :: ts ->
      let%bind acc = apply t root in
      go acc ts
  in
  go root ts

let bundle_length = 1

module Prover_state = struct
  type t = 
    { transactions : Transaction.t list
    ; state1 : Ledger.t
    ; state2 : Ledger.t
    }
  [@@deriving fields]
end

let provide_witness' typ ~f = provide_witness typ As_prover.(map get_state ~f)

let transition_base top_hash =
  let%bind l1 = provide_witness' Ledger.typ ~f:Prover_state.state1 in
  let%bind l2 = provide_witness' Ledger.typ ~f:Prover_state.state2 in
  let%bind () =
    let%bind b1 = Ledger.var_to_bits l1
    and b2 = Ledger.var_to_bits l2
    in
    hash_digest (b1 @ b2) >>= assert_equal top_hash
  in
  let%bind ts =
    provide_witness' (Typ.list ~length:bundle_length Transaction.typ)
      ~f:Prover_state.transactions
  in
  apply_many ts l1 >>= Ledger.assert_equal l2

(* Staging:
   first make tick base.
   then make tick merge (which top_hashes in the tock merge)
   then make tock merge (tock branches on the vk) *)

let tick_input () = Data_spec.([ Field.typ ])
let tick_input_size = Tick.Data_spec.size (tick_input ())
let wrap_input () = Tock.Data_spec.([ Tock.Field.typ ])

let base_keypair =
  generate_keypair transition_base ~exposing:(tick_input ())

let base_pk = Keypair.pk base_keypair
let base_vk = Keypair.vk base_keypair

module Merge = struct
  type proof_type = Base | Merge

  module Prover_state = struct
    type t =
      { tock_vk : Tock_curve.Verification_key.t
      ; input1  : bool list
      ; proof12 : proof_type * Tock_curve.Proof.t
      ; input2  : bool list
      ; proof23 : proof_type * Tock_curve.Proof.t
      ; input3  : bool list
      }
    [@@deriving fields]
  end

  let input = tick_input

  let wrap_input_size = Tock.Data_spec.size (wrap_input ())

  let tock_vk_length = 11324
  let tock_vk_typ = Typ.list ~length:tock_vk_length Boolean.typ

  let wrap_input_typ = Typ.list ~length:Tock.Field.size_in_bits Boolean.typ

  module Verifier =
    Snarky.Verifier_gadget.Make(Tick)(Tick_curve)(Tock_curve)
      (struct let input_size = wrap_input_size end)

  let verify_transition tock_vk proof_field s1 s2 =
    let open Let_syntax in
    let get_proof s = let (_t, proof) = proof_field s in proof in
    let get_type s = let (t, _proof) = proof_field s in t in
    let%bind states_hash = 
      Pedersen_hash.hash (s1 @ s2)
        ~params:Pedersen.params
        ~init:(0, Hash_curve.Checked.identity)
    in
    let%bind states_and_vk_hash =
      Pedersen_hash.hash tock_vk
        ~params:Pedersen.params
        ~init:(2 * Tock.Field.size_in_bits, states_hash)
    in
    let%bind is_base =
      provide_witness' Boolean.typ ~f:(fun s ->
        match get_type s with
        | Base -> true
        | Merge -> false)
    in
    let%bind input =
      Checked.if_ is_base
        ~then_:(Pedersen_hash.digest states_hash)
        ~else_:(Pedersen_hash.digest states_and_vk_hash)
      >>= Pedersen.Digest.choose_preimage_var
      >>| Pedersen.Digest.Unpacked.var_to_bits
    in
    Verifier.All_in_one.create ~verification_key:tock_vk ~input
      As_prover.(map get_state ~f:(fun s ->
        { Verifier.All_in_one.
          verification_key = s.Prover_state.tock_vk
        ; proof            = get_proof s
        }))
    >>| Verifier.All_in_one.result
  ;;

  let main (top_hash : Pedersen.Digest.Packed.var) =
    let%bind tock_vk =
      provide_witness' tock_vk_typ ~f:(fun { Prover_state.tock_vk } ->
        Verifier.Verification_key.to_bool_list tock_vk)
    and s1 = provide_witness' wrap_input_typ ~f:Prover_state.input1
    and s2 = provide_witness' wrap_input_typ ~f:Prover_state.input2
    and s3 = provide_witness' wrap_input_typ ~f:Prover_state.input3
    in
    let%bind () = hash_digest (s1 @ s3 @ tock_vk) >>= assert_equal top_hash
    and verify_12 = verify_transition tock_vk Prover_state.proof12 s1 s2
    and verify_23 = verify_transition tock_vk Prover_state.proof23 s2 s3
    in
    Boolean.Assert.all [ verify_12; verify_23 ]

  let keypair =
    generate_keypair ~exposing:(input ()) main

  let vk = Keypair.vk keypair
  let pk = Keypair.pk keypair
end

module Wrap = struct
  open Tock

  module Verifier =
    Snarky.Verifier_gadget.Make(Tock)(Tock_curve)(Tick_curve)
      (struct let input_size = tick_input_size end)

  let merge_vk = Merge.vk
  let merge_vk_bits : bool list =
    Verifier.Verification_key.to_bool_list merge_vk
  let base_vk_bits : bool list =
    Verifier.Verification_key.to_bool_list base_vk

  let if_ (choice : Boolean.var) ~then_ ~else_ =
    List.map2_exn then_ else_ ~f:(fun t e ->
      match t, e with
      | true, true -> Boolean.true_
      | false, false -> Boolean.false_
      | true, false -> choice
      | false, true -> Boolean.not choice)

  module Prover_state = struct
    type t =
      { is_base : bool
      ; input   : bool list
      ; proof   : Tick_curve.Proof.t
      }
    [@@deriving fields]
  end

  let provide_witness' typ ~f = provide_witness typ As_prover.(map get_state ~f)

  let main input =
    let open Let_syntax in
    let%bind input =
      Checked.choose_preimage input
        ~length:Tick_curve.Field.size_in_bits
    in
    let%bind is_base = provide_witness' Boolean.typ ~f:Prover_state.is_base in
    let verification_key = if_ is_base ~then_:base_vk_bits ~else_:merge_vk_bits in
    let%bind v =
      (* TODO: Probably an opportunity for optimization here since
          we are passing in one of two known verification keys. *)
      Verifier.All_in_one.create ~verification_key ~input
        As_prover.(map get_state ~f:(fun { Prover_state.is_base; proof } ->
          let verification_key = if is_base then base_vk else merge_vk in
          { Verifier.All_in_one.verification_key; proof }))
    in
    Boolean.Assert.is_true (Verifier.All_in_one.result v)

  let keypair =
    generate_keypair ~exposing:(wrap_input ()) main

  let vk = Keypair.vk keypair
  let pk = Keypair.pk keypair
end

let wrap ~is_base proof input =
  Tock.prove Wrap.pk (wrap_input ())
    { Wrap.Prover_state.proof; is_base; input }
    Wrap.main

let top_hash s1 s2 =
  let wrap_vk_bits = Merge.Verifier.Verification_key.to_bool_list Wrap.vk in
  fun h ->
    let open Pedersen.State in
    update_fold (create Pedersen.params)
      (fun ~init ~f ->
         let init = List.fold ~init ~f s1 in
         let init = List.fold ~init ~f s2 in
         List.fold ~init ~f wrap_vk_bits)

let merge input1 input2 input3 proof12 proof23 =
  Tick.prove Merge.pk (tick_input ())
    { Merge.Prover_state.input1
    ; input2
    ; input3
    ; proof12
    ; proof23
    ; tock_vk = Wrap.vk
    }

type wallet = { private_key : Private_key.t ; account : Account.t }

let bundle start transactions =
  let fold_field_bits_todo = Public_key.Compressed.fold in
  let random_wallet () : wallet =
    let private_key = Private_key.create () in
    { private_key
    ; account =
        { public_key = fst (Public_key.of_private_key private_key)
        ; balance = Unsigned.UInt64.of_int (10 + Random.int 100)
        }
    }
  in
  let n = Int.pow 2 ledger_depth in
  let wallets = Array.init n ~f:(fun _ -> random_wallet ()) in
  let ledger =
    Merkle_tree.create
      ~hash:(function
        | None -> Pedersen.zero_hash
        | Some account ->
          Pedersen.hash_fold Pedersen.params (Account.fold_bits account))
      ~compress:(fun x y ->
        Pedersen.hash_fold Pedersen.params
          (fun ~init ~f ->
             let init = fold_field_bits_todo ~init ~f x in
             fold_field_bits_todo ~init ~f y))
      wallets.(0).account
    |> ref
  in
  ledger :=
    Merkle_tree.add_many !ledger
      (List.init (n - 1) ~f:(fun i -> wallets.(i + 1).account));
  let index_to_bool_list idx =
    List.init ledger_depth ~f:(fun i -> (idx lsr i) land 1 = 1)
  in
  let find_index pk =
    let (i, _) =
      Array.findi_exn wallets ~f:(fun _ w ->
        Field.equal w.account.public_key pk)
    in
    i
  in
  let transaction : Transaction.t = failwith "TODO" in
  let apply_transaction tree (transaction : Transaction.t) =
    let receiver = index_to_bool_list (find_index transaction.payload.receiver) in
    let sender = index_to_bool_list (find_index (fst transaction.sender)) in
    let modify addr tree ~f =
      let x = Merkle_tree.get_exn tree addr in
      Merkle_tree.update tree addr (f x)
    in
    modify sender tree ~f:(fun (acct : Account.t) ->
      { acct with
        balance = Unsigned.UInt64.sub acct.balance transaction.payload.amount
      })
    |> modify receiver ~f:(fun (acct : Account.t) ->
      { acct with
        balance = Unsigned.UInt64.add acct.balance transaction.payload.amount
      })
  in
  let state1 = Ledger.of_hash (Merkle_tree.root !ledger) in
  let state2 = Ledger.of_hash (Merkle_tree.root (apply_transaction !ledger transaction)) in
  let main top_hash =
    handle (transition_base top_hash)
      (fun (With { request; respond }) ->
         match request with
         | Ledger.Get_path idx ->
           respond (Provide (Merkle_tree.get_path !ledger (index_to_bool_list idx)))
         | Ledger.Set (idx, account) ->
           ledger := Merkle_tree.update !ledger (index_to_bool_list idx) account;
           respond (Provide ())
         | Ledger.Empty_entry -> unhandled
         | Ledger.Find_index pk ->
           respond (Provide (find_index pk))
         | _ -> unhandled)
  in
  let prover_state : Prover_state.t =
    { state1; state2; transactions = [ transaction ] }
  in
  prove base_pk (tick_input ()) prover_state main

