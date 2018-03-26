open Core
open Nanobit_base
open Snark_params
open Snarky
open Tick
open Let_syntax

module Signature = Tick.Signature

let depth = Snark_params.ledger_depth

let bundle_length = 1

let tick_input () = Data_spec.([ Field.typ ])
let tick_input_size = Tick.Data_spec.size (tick_input ())
let wrap_input () = Tock.Data_spec.([ Tock.Field.typ ])

let provide_witness' typ ~f = provide_witness typ As_prover.(map get_state ~f)

(* Staging:
   first make tick base.
   then make tick merge (which top_hashes in the tock wrap vk)
   then make tock wrap (which branches on the tick vk) *)

module Base = struct
  let apply_transaction root ({ sender; signature; payload } : Transaction.var) =
    (if not Insecure.transaction_replay
     then failwith "Insecure.transaction_replay false");
    let { Transaction.Payload.receiver; amount; fee } = payload in
    let%bind () =
      let%bind bs = Transaction.Payload.var_to_bits payload in
      Signature.Checked.assert_verifies signature sender bs
    in
    let%bind root =
      let%bind sender_compressed = Public_key.compress_var sender in
      Ledger_hash.modify_account root sender_compressed ~f:(fun account ->
        let%map balance = Transaction.Amount.(account.balance - amount) in (* TODO: Fee *)
        { account with balance })
    in
    Ledger_hash.modify_account root receiver ~f:(fun account ->
      let%map balance = Transaction.Amount.(account.balance + amount) in
      { account with balance })

  let apply_transactions root ts =
    Checked.List.fold ~init:root ~f:apply_transaction ts

  module Prover_state = struct
    type t =
      { transactions : Transaction.t list
      ; state1 : Ledger_hash.t
      ; state2 : Ledger_hash.t
      }
    [@@deriving fields]
  end

  let main top_hash =
    let%bind l1 = provide_witness' Ledger_hash.typ ~f:Prover_state.state1 in
    let%bind l2 = provide_witness' Ledger_hash.typ ~f:Prover_state.state2 in
    let%bind () =
      let%bind b1 = Ledger_hash.var_to_bits l1
      and b2 = Ledger_hash.var_to_bits l2
      in
      hash_digest (b1 @ b2) >>= assert_equal top_hash
    in
    let%bind ts =
      provide_witness' (Typ.list ~length:bundle_length Transaction.typ)
        ~f:Prover_state.transactions
    in
    apply_transactions l1 ts >>= Ledger_hash.assert_equal l2

  let keypair = generate_keypair main ~exposing:(tick_input ())
  let pk = Keypair.pk keypair
  let vk = Keypair.vk keypair

  let root_after_transaction ledger
        (transaction : Transaction.t) =
    let get_exn pk = Option.value_exn (Ledger.get ledger pk) in
    let sender = Public_key.compress transaction.sender in
    let receiver = transaction.payload.receiver in
    let sender_pre = get_exn sender in
    let receiver_pre = get_exn receiver in
    Ledger.update ledger sender
      { sender_pre with
        balance = Unsigned.UInt64.sub sender_pre.balance transaction.payload.amount
      };
    Ledger.update ledger transaction.payload.receiver
      { receiver_pre with
        balance = Unsigned.UInt64.add receiver_pre.balance transaction.payload.amount
      };
    let root = Ledger.merkle_root ledger in
    Ledger.update ledger sender sender_pre;
    Ledger.update ledger receiver receiver_pre;
    root

  let bundle ledger transaction
    =
    let state1 = Ledger_hash.of_hash (Ledger.merkle_root ledger) in
    let state2 = Ledger_hash.of_hash (root_after_transaction ledger transaction) in
    let prover_state : Prover_state.t =
      { state1; state2; transactions = [ transaction ] }
    in
    let top_hash =
      Pedersen.hash_fold Pedersen.params
        (List.fold (Ledger_hash.to_bits state1 @ Ledger_hash.to_bits state2))
    in
    state1, state2,
    top_hash,
    prove pk (tick_input ()) prover_state main top_hash
end

module Proof_type = struct
  type t = Base | Merge

  let is_base = function
    | Base -> true
    | Merge -> false
end

module Merge = struct

  module Prover_state = struct
    type t =
      { tock_vk : Tock_curve.Verification_key.t
      ; input1  : bool list
      ; proof12 : Proof_type.t * Tock_curve.Proof.t
      ; input2  : bool list
      ; proof23 : Proof_type.t * Tock_curve.Proof.t
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
        Proof_type.is_base (get_type s))
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

  let merge_vk_bits : bool list =
    Verifier.Verification_key.to_bool_list Merge.vk

  let base_vk_bits : bool list =
    Verifier.Verification_key.to_bool_list Base.vk

  let if_ (choice : Boolean.var) ~then_ ~else_ =
    List.map2_exn then_ else_ ~f:(fun t e ->
      match t, e with
      | true, true -> Boolean.true_
      | false, false -> Boolean.false_
      | true, false -> choice
      | false, true -> Boolean.not choice)

  module Prover_state = struct
    type t =
      { proof_type : Proof_type.t
      ; proof      : Tick_curve.Proof.t
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
    let%bind is_base =
      provide_witness' Boolean.typ ~f:(fun {Prover_state.proof_type} ->
        Proof_type.is_base proof_type)
    in
    let verification_key = if_ is_base ~then_:base_vk_bits ~else_:merge_vk_bits in
    let%bind v =
      (* someday: Probably an opportunity for optimization here since
          we are passing in one of two known verification keys. *)
      Verifier.All_in_one.create ~verification_key ~input
        As_prover.(map get_state ~f:(fun { Prover_state.proof_type; proof } ->
          let verification_key =
            match proof_type with
            | Base -> Base.vk
            | Merge -> Merge.vk
          in
          { Verifier.All_in_one.verification_key; proof }))
    in
    Boolean.Assert.is_true (Verifier.All_in_one.result v)

  let keypair =
    generate_keypair ~exposing:(wrap_input ()) main

  let vk = Keypair.vk keypair
  let pk = Keypair.pk keypair
end

let embed (x : Tick.Field.t) : Tock.Field.t =
  Tock.Field.project (Tick.Field.unpack x)

let wrap proof_type proof input =
  Tock.prove Wrap.pk (wrap_input ())
    { Wrap.Prover_state.proof; proof_type }
    Wrap.main
    (embed input)

let top_hash s1 s2 =
  let wrap_vk_bits = Merge.Verifier.Verification_key.to_bool_list Wrap.vk in
  Pedersen.hash_fold Pedersen.params
    (fun ~init ~f ->
       let init = Ledger_hash.fold ~init ~f s1 in
       let init = Ledger_hash.fold ~init ~f s2 in
       List.fold ~init ~f wrap_vk_bits)

let merge_proof input1 input2 input3 proof12 proof23 =
  let top_hash = top_hash input1 input3 in
  let to_bits = Ledger_hash.to_bits in
  top_hash,
  Tick.prove Merge.pk (tick_input ())
    { Merge.Prover_state.input1 = to_bits input1
    ; input2 = to_bits input2
    ; input3 = to_bits input3
    ; proof12
    ; proof23
    ; tock_vk = Wrap.vk
    }
    Merge.main
    top_hash

type t =
  { source     : Ledger_hash.t
  ; target     : Ledger_hash.t
  ; proof      : Tock.Proof.t
  ; proof_type : Proof_type.t
  }
[@@deriving fields]

let of_transaction ledger transaction =
  let source, target, top_hash, proof =
    Base.bundle ledger transaction
  in
  let proof_type = Proof_type.Base in
  { source
  ; target
  ; proof_type
  ; proof = wrap proof_type proof top_hash
  }

let merge t1 t2 =
  (if not (Ledger_hash.(=) t1.target t2.source)
   then
     failwithf
       !"Transaction_snark.merge: t1.target <> t2.source (%{sexp:Ledger_hash.t} vs %{sexp:Ledger_hash.t})"
       t1.target
       t2.source ());
  let input, proof =
    merge_proof t1.source t1.target t2.source
      (t1.proof_type, t1.proof)
      (t2.proof_type, t2.proof)
  in
  let proof_type = Proof_type.Merge in
  { source = t1.source
  ; target = t2.target
  ; proof_type
  ; proof = wrap proof_type proof input
  }

let%test_module "transaction_snark" =
  (module struct
    type wallet = { private_key : Private_key.t ; account : Account.t }

    let random_wallets () =
      let random_wallet () : wallet =
        let private_key = Private_key.create () in
        { private_key
        ; account =
            { public_key = Public_key.compress (Public_key.of_private_key private_key)
            ; balance = Unsigned.UInt64.of_int (10 + Random.int 100)
            }
        }
      in
      let n = Int.pow 2 ledger_depth in
      Array.init n ~f:(fun _ -> random_wallet ())
    ;;

    let transaction wallets i j amt =
      let sender = wallets.(i) in
      let receiver = wallets.(j) in
      let payload : Transaction.Payload.t =
        { receiver = receiver.account.public_key
        ; fee = Unsigned.UInt32.zero
        ; amount = Unsigned.UInt64.of_int amt
        }
      in
      let signature =
        Signature.sign sender.private_key
          (Transaction.Payload.to_bits payload)
      in
      assert (Signature.verify signature (Public_key.of_private_key sender.private_key) (Transaction.Payload.to_bits payload));
      { Transaction.payload
      ; sender = Public_key.of_private_key sender.private_key
      ; signature
      }

    let find_index xs x =
      fst (Array.findi_exn xs ~f:(fun _ y -> Field.equal y x))

    let%test "base_and_merge" =
      let wallets = random_wallets () in
      let ledger =
        Ledger.create ~depth:ledger_depth
      in
      Array.iter wallets ~f:(fun { account } ->
        Ledger.update ledger account.public_key account);
      let t1 = transaction wallets 0 1 8 in
      let t2 = transaction wallets 1 2 3 in
      let state1 = Ledger_hash.of_hash (Ledger.merkle_root ledger) in
      let proof12 = of_transaction ledger t1 in
      let proof23 = of_transaction ledger t2 in
      let state3 = Ledger_hash.of_hash (Ledger.merkle_root ledger) in
      let proof13 = merge proof12 proof23 in
      Tock.verify proof13.proof Wrap.vk (wrap_input ())
        (embed (top_hash state1 state3))
  end)
