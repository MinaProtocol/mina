open Core
open Nanobit_base
open Util
open Snark_params
open Snarky
open Currency

let bundle_length = 1

let tick_input () = Tick.(Data_spec.([ Field.typ ]))
let tick_input_size = Tick.Data_spec.size (tick_input ())
let wrap_input () = Tock.(Data_spec.([ Field.typ ]))

let provide_witness' typ ~f =
  Tick.(provide_witness typ As_prover.(map get_state ~f))

module Tag : sig
  open Tick

  type t =
    | Normal
    | Fee_transfer
  [@@deriving sexp]

  type var

  val typ : (var, t) Typ.t

  module Checked : sig
    val is_normal : var -> Boolean.var
    val is_fee_transfer : var -> Boolean.var
  end
end = struct
  open Tick

  type t =
    | Normal
    | Fee_transfer
  [@@deriving sexp]

  let is_normal = function
    | Normal -> true
    | Fee_transfer -> false

  type var = Boolean.var

  let typ =
    Typ.transport Boolean.typ ~there:is_normal
      ~back:(function true -> Normal | false -> Fee_transfer)

  module Checked = struct
    let is_normal = Fn.id
    let is_fee_transfer = Boolean.not
  end
end

module Tagged_transaction = struct
  open Tick

  type t = Tag.t * Transaction.t
  [@@deriving sexp]

  type var = Tag.var * Transaction.var
  let typ : (var, t) Typ.t = Typ.(Tag.typ * Transaction.typ)

  let excess ((tag, t) : t) =
    match tag with
    | Normal ->
      Amount.Signed.create ~sgn:Sgn.Pos
        ~magnitude:(Amount.of_fee t.payload.fee)
    | Fee_transfer ->
      let magnitude =
        Amount.add_fee t.payload.amount t.payload.fee
        |> Option.value_exn
      in
      Amount.Signed.create ~sgn:Sgn.Neg ~magnitude
end

module Fee_transfer = struct
  include Fee_transfer

  let dummy_signature =
    Schnorr.sign (Private_key.create ())
      (List.init 256 ~f:(fun _ -> true))

  let two (pk1, fee1) (pk2, fee2) : Tagged_transaction.t =
    ( Fee_transfer
    , { payload =
          { receiver = pk1
          ; amount = Amount.of_fee fee1 (* What "receiver" receives *)
          ; fee = fee2 (* What "sender" receives *)
          ; nonce = Account.Nonce.zero
          }
      ; sender = Public_key.decompress_exn pk2
      ; signature = dummy_signature
      }
    )

  let to_tagged_transaction = function
    | One (pk1, fee1) -> two (pk1, fee1) (pk1, Fee.zero)
    | Two (t1, t2) -> two t1 t2
end

module Transition = struct
  type t =
    | Transaction of Transaction.With_valid_signature.t
    | Fee_transfer of Fee_transfer.t
  [@@deriving bin_io, sexp]

  let to_tagged_transaction = function
    | Fee_transfer t -> Fee_transfer.to_tagged_transaction t
    | Transaction t -> (Normal, (t :> Transaction.t))
end

module Proof_type = struct
  type t = Base | Merge
  [@@deriving bin_io]

  let is_base = function
    | Base -> true
    | Merge -> false
end

type t =
  { source     : Ledger_hash.Stable.V1.t
  ; target     : Ledger_hash.Stable.V1.t
  ; proof_type : Proof_type.t
  ; fee_excess : Amount.Signed.t
  ; proof      : Proof.Stable.V1.t
  }
[@@deriving fields, bin_io]

let create = Fields.create

let base_top_hash s1 s2 excess =
  Tick.Pedersen.digest_fold Hash_prefix.base_snark
    (Ledger_hash.fold s1 +> Ledger_hash.fold s2 +> Amount.Signed.fold excess)

let merge_top_hash s1 s2 fee_excess wrap_vk_bits =
  Tick.Pedersen.digest_fold Hash_prefix.merge_snark
    (Ledger_hash.fold s1
     +> Ledger_hash.fold s2
     +> Amount.Signed.fold fee_excess
     +> List.fold wrap_vk_bits)

let embed (x : Tick.Field.t) : Tock.Field.t =
  Tock.Field.project (Tick.Field.unpack x)

module Keys0 = struct
  type t =
    { base : Tick.Keypair.t
    ; wrap : Tock.Keypair.t
    ; merge : Tick.Keypair.t
    }
  [@@deriving bin_io]

  let dummy () =
    let tick_keypair =
      let open Tick in
      generate_keypair ~exposing:(tick_input ()) (fun x -> assert_equal x x)
    in
    let tock_keypair =
      let open Tock in
      generate_keypair ~exposing:(wrap_input ()) (fun x -> assert_equal x x)
    in
    { base = tick_keypair
    ; wrap = tock_keypair
    ; merge = tick_keypair
    }
end

let handle_with_ledger (ledger : Ledger.t) =
  let open Tick in
  let path_at_index idx =
    List.map ~f:Ledger.Path.elem_hash (Ledger.merkle_path_at_index_exn ledger idx)
  in
  fun (With { request; respond }) ->
    let open Ledger_hash in
    match request with
    | Get_element idx ->
      let elt = Ledger.get_at_index_exn ledger idx in
      let path = path_at_index idx in
      respond (Provide (elt, path))
    | Get_path idx ->
      let path = path_at_index idx in
      respond (Provide path)
    | Set (idx, account) ->
      Ledger.set_at_index_exn ledger idx account;
      respond (Provide ())
    | Find_index pk ->
      let index = Ledger.index_of_key_exn ledger pk in
      respond (Provide index)
    | _ -> unhandled

(* Staging:
   first make tick base.
   then make tick merge (which top_hashes in the tock wrap vk)
   then make tock wrap (which branches on the tick vk) *)

module Base = struct
  open Tick
  open Let_syntax

  (* spec for
     [apply_tagged_transaction root (tag, { sender; signature; payload }]):
     - if tag = Normal:
        - check that [signature] is a signature by [sender] of payload
        - return:
          - merkle tree [root'] where the sender balance is decremented by
            [payload.amount] and the receiver balance is incremented by [payload.amount].
          - fee excess = +fee.

     - if tag = Fee_transfer
        - return:
          - merkle tree [root'] where the sender balance is incremented by
            fee and the receiver balance is incremented by amount
          - fee excess = -(amount + fee)
  *)
  (* Nonce should only be incremented if it is a "Normal" transaction. *)
  let apply_tagged_transaction root
        ((tag, { sender; signature; payload }) : Tagged_transaction.var) =
    with_label __LOC__ begin
      (if not Insecure.transaction_replay
       then failwith "Insecure.transaction_replay false");
      let { Transaction.Payload.receiver; amount; fee; nonce } = payload in
      let is_fee_transfer = Tag.Checked.is_fee_transfer tag in
      let is_normal = Tag.Checked.is_normal tag in
      let%bind () =
        let%bind bs = Transaction.Payload.var_to_bits payload in
        let%bind verifies =
          Schnorr.Checked.verifies signature sender bs
        in
        (* Should only assert_verifies if the tag is Normal *)
        Boolean.Assert.any [is_fee_transfer; verifies]
      in
      let%bind excess, sender_delta =
        let%bind amount_plus_fee = Amount.Checked.add_fee amount fee in
        let open Amount.Signed in
        let neg_amount_plus_fee = create ~sgn:Sgn.Neg ~magnitude:amount_plus_fee in
        let pos_fee = create ~sgn:Sgn.Pos ~magnitude:(Amount.Checked.of_fee fee) in
        (* If tag = Normal:
          sender gets -(amount + fee)
          excess is +fee

          If tag = Fee_transfer:
          "sender" gets +fee
          excess is -(amount + fee) (since "receiver" gets amount)
        *)
        Checked.cswap is_fee_transfer (pos_fee, neg_amount_plus_fee)
      in
      let%bind root =
        let%bind sender_compressed = Public_key.compress_var sender in
        Ledger_hash.modify_account root sender_compressed ~f:(fun account ->
          let%bind next_nonce = Account.Nonce.increment_if_var account.nonce is_normal in
          let%bind () =
            with_label __LOC__ begin
              let%bind nonce_matches = Account.Nonce.equal_var nonce account.nonce in
              Boolean.Assert.any [ is_fee_transfer; nonce_matches ]
            end
          in
          let%map balance =
            Balance.Checked.add_signed_amount account.balance sender_delta
          in
          { account with balance; nonce = next_nonce })
      in
      let%map root =
        Ledger_hash.modify_account root receiver ~f:(fun account ->
          let%map balance = Balance.Checked.(account.balance + amount) in
          { account with balance })
      in
      (root, excess)
    end

(* Someday:
   write the following soundness tests:
   - apply a transaction where the signature is incorrect
   - apply a transaction where the sender does not have enough money in their account
   - apply a transaction and stuff in the wrong target hash
*)

  module Prover_state = struct
    type t =
      { transaction : Tagged_transaction.t
      ; state1      : Ledger_hash.t
      ; state2      : Ledger_hash.t
      }
    [@@deriving fields]
  end

(* spec for [main top_hash]:
   constraints pass iff
   there exist
      l1 : Ledger_hash.t,
      l2 : Ledger_hash.t,
      fee_excess : Amount.Signed.t,
      t : Tagged_transaction.t
   such that
   H(l1, l2, fee_excess) = top_hash,
   applying [t] to ledger with merkle hash [l1] results in ledger with merkle hash [l2]. *)
  let main top_hash =
    with_label __LOC__ begin
      let open Let_syntax in
      let%bind root_before = provide_witness' Ledger_hash.typ ~f:Prover_state.state1 in
      let%bind t =
        with_label __LOC__
          (provide_witness' Tagged_transaction.typ ~f:Prover_state.transaction)
      in
      let%bind root_after, fee_excess = apply_tagged_transaction root_before t in
      let%map () =
        with_label __LOC__ begin
          let%bind b1 = Ledger_hash.var_to_bits root_before
          and b2 = Ledger_hash.var_to_bits root_after
          in
          let fee_excess_bits = Amount.Signed.Checked.to_bits fee_excess in
          digest_bits ~init:Hash_prefix.base_snark (b1 @ b2 @ fee_excess_bits)
          >>= assert_equal ~label:"equals-top_hash" top_hash
        end
      in
      ()
    end

  let create_keys () =
    generate_keypair main ~exposing:(tick_input ())

  let tagged_transaction_proof ~proving_key
        state1
        state2
        (transaction : Tagged_transaction.t)
        handler
    =
    let prover_state : Prover_state.t = { state1; state2; transaction } in
    let main top_hash = handle (main top_hash) handler in
    let top_hash = base_top_hash state1 state2 (Tagged_transaction.excess transaction) in
    top_hash,
    prove proving_key (tick_input ()) prover_state main top_hash

  let fee_transfer_proof ~proving_key state1 state2 transfer handler = 
    tagged_transaction_proof ~proving_key state1 state2
      (Fee_transfer.to_tagged_transaction transfer) handler

  let transaction_proof ~proving_key state1 state2 transaction handler =
    tagged_transaction_proof ~proving_key state1 state2
      (Normal, transaction) handler

  let cached () =
    Cached.create
      ~directory:Cache_dir.cache_dir
      ~digest_input:(Fn.compose Md5.to_hex R1CS_constraint_system.digest)
      ~bin_t:Keypair.bin_t
      R1CS_constraint_system.generate_keypair
      (constraint_system ~exposing:(tick_input ()) main)
end

module Merge = struct
  open Tick
  open Let_syntax

  module Prover_state = struct
    type t =
      { tock_vk      : Tock_curve.Verification_key.t
      ; ledger_hash1 : bool list

      ; ledger_hash2 : bool list
      ; proof12      : Proof_type.t * Tock_curve.Proof.t
      ; fee_excess12 : Amount.Signed.t

      ; ledger_hash3 : bool list
      ; proof23      : Proof_type.t * Tock_curve.Proof.t
      ; fee_excess23 : Amount.Signed.t
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

  (* spec for [verify_transition tock_vk proof_field s1 s2]:
     returns a bool which is true iff
     there is a snark proving making tock_vk
     accept on one of [ H(s1, s2, excess); H(s1, s2, excess, tock_vk) ] *)
  let verify_transition tock_vk proof_field s1 s2 fee_excess =
    let open Let_syntax in
    let get_proof s = let (_t, proof) = proof_field s in proof in
    let get_type s = let (t, _proof) = proof_field s in t in
    let input_bits = s1 @ s2 @ Amount.Signed.Checked.to_bits fee_excess in
    let input_bits_length = List.length input_bits in
    assert (input_bits_length = 2 * Tock.Field.size_in_bits + Amount.Signed.length);
    let%bind is_base =
      with_label __LOC__ begin
        provide_witness' Boolean.typ ~f:(fun s ->
          Proof_type.is_base (get_type s))
      end
    in
    let%bind states_and_excess_hash =
      let init =
        ( Hash_prefix.length_in_bits
        , Hash_curve.Checked.if_value is_base
            ~then_:Hash_prefix.base_snark.acc
            ~else_:Hash_prefix.merge_snark.acc
        )
      in
      with_label __LOC__
        (Pedersen_hash.hash ~init ~params:Pedersen.params input_bits)
    in
    let%bind states_and_excess_and_vk_hash =
      with_label __LOC__ begin
        Pedersen_hash.hash tock_vk
          ~params:Pedersen.params
          ~init:(input_bits_length + Hash_prefix.length_in_bits, states_and_excess_hash)
      end
    in
    let%bind input =
      with_label __LOC__ begin
        Checked.if_ is_base
          ~then_:(Pedersen_hash.digest states_and_excess_hash)
          ~else_:(Pedersen_hash.digest states_and_excess_and_vk_hash)
        >>= Pedersen.Digest.choose_preimage_var
        >>| Pedersen.Digest.Unpacked.var_to_bits
      end
    in
    with_label __LOC__ begin
      Verifier.All_in_one.create ~verification_key:tock_vk ~input
        As_prover.(map get_state ~f:(fun s ->
          { Verifier.All_in_one.
            verification_key = s.Prover_state.tock_vk
          ; proof            = get_proof s
          }))
      >>| Verifier.All_in_one.result
    end
  ;;

  (* spec for [main top_hash]:
     constraints pass iff
     there exist s1, s3, tock_vk such that
     H(s1, s3, tock_vk) = top_hash,
     verify_transition tock_vk _ s1 s2 is true
     verify_transition tock_vk _ s2 s3 is true
  *)
  let main (top_hash : Pedersen.Digest.Packed.var) =
    let%bind tock_vk =
      provide_witness' tock_vk_typ ~f:(fun { Prover_state.tock_vk } ->
        Verifier.Verification_key.to_bool_list tock_vk)
    and s1 = provide_witness' wrap_input_typ ~f:Prover_state.ledger_hash1
    and s2 = provide_witness' wrap_input_typ ~f:Prover_state.ledger_hash2
    and s3 = provide_witness' wrap_input_typ ~f:Prover_state.ledger_hash3
    and fee_excess12 = provide_witness' Amount.Signed.typ ~f:Prover_state.fee_excess12
    and fee_excess23 = provide_witness' Amount.Signed.typ ~f:Prover_state.fee_excess23
    in
    let%bind () =
      let%bind total_fees = Amount.Signed.Checked.add fee_excess12 fee_excess23 in
      digest_bits ~init:Hash_prefix.merge_snark (s1 @ s3 @ Amount.Signed.Checked.to_bits total_fees @ tock_vk)
      >>= assert_equal top_hash
    and verify_12 = verify_transition tock_vk Prover_state.proof12 s1 s2 fee_excess12
    and verify_23 = verify_transition tock_vk Prover_state.proof23 s2 s3 fee_excess23
    in
    Boolean.Assert.all [ verify_12; verify_23 ]


  let create_keys () =
    generate_keypair ~exposing:(input ()) main

  let cached () =
    Cached.create
      ~directory:Cache_dir.cache_dir
      ~digest_input:(Fn.compose Md5.to_hex R1CS_constraint_system.digest)
      ~bin_t:Keypair.bin_t
      R1CS_constraint_system.generate_keypair
      (constraint_system ~exposing:(input ()) main)
end

module Verification = struct
  module Keys = struct
    type t =
      { base : Tick.Verification_key.t
      ; wrap : Tock.Verification_key.t
      ; merge : Tick.Verification_key.t
      }
  end

  module type S = sig
    val verify : t -> bool

    val verify_complete_merge
      : Ledger_hash.var
      -> Ledger_hash.var
      -> (Tock.Proof.t, 's) Tick.As_prover.t
      -> (Tick.Boolean.var, 's) Tick.Checked.t
  end

  module Make (K : sig val keys : Keys.t end) = struct
    open K

    let wrap_vk_bits =
      Merge.Verifier.Verification_key.to_bool_list keys.wrap

    let verify { source; target; proof; proof_type; fee_excess } =
      let input =
        match proof_type with
        | Base ->
          base_top_hash source target fee_excess
        | Merge ->
          merge_top_hash source target fee_excess wrap_vk_bits
      in
      Tock.verify proof keys.wrap (wrap_input ()) (embed input)

    (* The curve pt corresponding to H(merge_prefix, _, _, Amount.Signed.zero, wrap_vk)
      (with starting point shifted over by 2 * digest_size so that
      this can then be used to compute H(merge_prefix, s1, s2, Amount.Signed.zero, wrap_vk) *)
    let merge_prefix_and_zero_and_vk_curve_pt =
      let open Tick in
      let s =
        { Hash_prefix.merge_snark
          with bits_consumed = Hash_prefix.merge_snark.bits_consumed
                              + Pedersen.Digest.size_in_bits * 2
        }
      in
      let s =
        Pedersen.State.update_fold s
          (fun ~init ~f ->
            let init = Amount.Signed.(fold zero ~init ~f) in
            List.fold wrap_vk_bits ~init ~f)
      in
      s.acc

    (* spec for [verify_merge s1 s2 _]:
      Returns a boolean which is true if there exists a tock proof proving
      (against the wrap verification key) H(s1, s2, Amount.Signed.zero, wrap_vk).
      This in turn should only happen if there exists a tick proof proving
      (against the merge verification key) H(s1, s2, Amount.Signed.zero, wrap_vk).

      We precompute the parts of the pedersen involving wrap_vk and
      Amount.Signed.zero outside the SNARK since this saves us many constraints.
    *)
    let verify_complete_merge s1 s2 get_proof =
      let open Tick in
      let open Let_syntax in
      let%bind s1 = Ledger_hash.var_to_bits s1
      and s2 = Ledger_hash.var_to_bits s2
      in
      let%bind top_hash =
        let (vx, vy) = merge_prefix_and_zero_and_vk_curve_pt in
        Pedersen_hash.hash ~params:Pedersen.params
          ~init:(Hash_prefix.length_in_bits, (Cvar.constant vx, Cvar.constant vy))
          (s1 @ s2)
        >>| Pedersen_hash.digest
        >>= Pedersen.Digest.choose_preimage_var
        >>| Pedersen.Digest.Unpacked.var_to_bits
      in
      Merge.Verifier.All_in_one.create ~input:top_hash
        ~verification_key:(List.map ~f:Boolean.var_of_value wrap_vk_bits)
        (As_prover.map get_proof ~f:(fun proof ->
          { Merge.Verifier.All_in_one.proof
          ; verification_key = keys.wrap
          }))
      >>| Merge.Verifier.All_in_one.result
    ;;
  end
end

module Wrap (Vk : sig
    val merge : Tick.Verification_key.t
    val base : Tick.Verification_key.t
  end)
= struct
  open Tock

  module Verifier =
    Snarky.Verifier_gadget.Make(Tock)(Tock_curve)(Tick_curve)
      (struct let input_size = tick_input_size end)

  let merge_vk_bits : bool list =
    Verifier.Verification_key.to_bool_list Vk.merge

  let base_vk_bits : bool list =
    Verifier.Verification_key.to_bool_list Vk.base

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

(* spec for [main input]:
   constraints pass iff
   (b1, b2, .., bn) = unpack input,
   there is a proof making one of [ base_vk; merge_vk ] accept (b1, b2, .., bn) *)
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
            | Base -> Vk.base
            | Merge -> Vk.merge
          in
          { Verifier.All_in_one.verification_key; proof }))
    in
    Boolean.Assert.is_true (Verifier.All_in_one.result v)

  let create_keys () =
    generate_keypair ~exposing:(wrap_input ()) main

  let cached () =
    Cached.create
      ~directory:Cache_dir.cache_dir
      ~digest_input:(Fn.compose Md5.to_hex R1CS_constraint_system.digest)
      ~bin_t:Keypair.bin_t
      R1CS_constraint_system.generate_keypair
      (constraint_system ~exposing:(wrap_input ()) main)
end

module type S = sig
  include Verification.S

  val of_transition
    :  Ledger_hash.t
    -> Ledger_hash.t
    -> Transition.t
    -> Tick.Handler.t
    -> t

  val of_transaction
    : Ledger_hash.t
    -> Ledger_hash.t
    -> Transaction.With_valid_signature.t
    -> Tick.Handler.t
    -> t

  val of_fee_transfer
    :  Ledger_hash.t
    -> Ledger_hash.t
    -> Fee_transfer.t
    -> Tick.Handler.t
    -> t

  val merge : t -> t -> t Or_error.t 
end

let check_tagged_transaction source target transaction handler =
  let prover_state : Base.Prover_state.t =
    { state1=source; state2=target; transaction }
  in
  let excess = Tagged_transaction.excess transaction in
  let top_hash = base_top_hash source target excess in
  let open Tick in
  let main = handle (Base.main (Cvar.constant top_hash)) handler in
  assert (check main prover_state)
;;

let check_transition source target (t : Transition.t) handler =
  check_tagged_transaction source target
    (Transition.to_tagged_transaction t) handler

let check_transaction source target t handler =
  check_transition source target (Transaction t) handler

let check_fee_transfer source target t handler =
  check_transition source target (Fee_transfer t) handler

let verification_keys_of_keys { Keys0.merge; wrap; base } =
  { Verification.Keys.merge = Tick.Keypair.vk merge
  ; wrap = Tock.Keypair.vk wrap
  ; base = Tick.Keypair.vk base
  }

module Make (K : sig val keys : Keys0.t end) = struct
  open K

  include Verification.Make(struct
      let keys = verification_keys_of_keys keys
    end)

  module Wrap = Wrap(struct
      let merge = Tick.Keypair.vk keys.merge
      let base = Tick.Keypair.vk keys.base
    end)

  let wrap proof_type proof input =
    Tock.prove (Tock.Keypair.pk keys.wrap) (wrap_input ())
      { Wrap.Prover_state.proof; proof_type }
      Wrap.main
      (embed input)

  let merge_proof
        ledger_hash1
        ledger_hash2
        ledger_hash3
        proof12
        proof23
        fee_excess12
        fee_excess23
    =
    let fee_excess =
      Amount.Signed.add fee_excess12 fee_excess23
      |> Option.value_exn
    in
    let top_hash = merge_top_hash ledger_hash1 ledger_hash3 fee_excess wrap_vk_bits in
    let to_bits = Ledger_hash.to_bits in
    top_hash,
    Tick.prove (Tick.Keypair.pk keys.merge) (tick_input ())
      { Merge.Prover_state.ledger_hash1 = to_bits ledger_hash1
      ; ledger_hash2 = to_bits ledger_hash2
      ; ledger_hash3 = to_bits ledger_hash3
      ; proof12
      ; proof23
      ; fee_excess12
      ; fee_excess23
      ; tock_vk = Tock.Keypair.vk keys.wrap
      }
      Merge.main
      top_hash

  let of_tagged_transaction source target transaction handler =
    let top_hash, proof =
      Base.tagged_transaction_proof
        ~proving_key:(Tick.Keypair.pk keys.base)
        source target transaction handler
    in
    { source
    ; target
    ; proof_type = Base
    ; fee_excess = Tagged_transaction.excess transaction
    ; proof = wrap Proof_type.Base proof top_hash
    }

  let of_transition source target transition handler =
    of_tagged_transaction source target (Transition.to_tagged_transaction transition) handler

  let of_transaction source target transaction handler =
    of_transition source target (Transaction transaction) handler

  let of_fee_transfer source target transfer handler =
    of_transition source target (Fee_transfer transfer) handler

  let merge t1 t2 =
    (if not (Ledger_hash.(=) t1.target t2.source)
    then
      failwithf
        !"Transaction_snark.merge: t1.target <> t2.source (%{sexp:Ledger_hash.t} vs %{sexp:Ledger_hash.t})"
        t1.target
        t2.source ());
    (*
    let t1_proof_type, t1_total_fees =
      Proof_type_with_fees.to_proof_type_and_amount t1.proof_type_with_fees
    in
    let t2_proof_type, t2_total_fees =
      Proof_type_with_fees.to_proof_type_and_amount t2.proof_type_with_fees
       in *)
    let input, proof =
      merge_proof
        t1.source t1.target t2.target
        (t1.proof_type, t1.proof)
        (t2.proof_type, t2.proof)
        t1.fee_excess
        t2.fee_excess
    in
    let open Or_error.Let_syntax in
    let%map fee_excess =
      Amount.Signed.add t1.fee_excess t2.fee_excess
      |> Option.value_map ~f:Or_error.return
           ~default:(Or_error.errorf "Transaction_snark.merge: Amount overflow")
    in
    { source = t1.source
    ; target = t2.target
    ; fee_excess
    ; proof_type = Merge
    ; proof = wrap Proof_type.Merge proof input
    }
end

module Keys = struct
  include Keys0

  let verification_keys = verification_keys_of_keys

  module Location = struct
    module T = struct
      type t =
        { base : string
        ; merge : string
        ; wrap : string
        }
      [@@deriving sexp]
    end
    include T
    include Sexpable.To_stringable(T)
  end

  let checksum ~base ~merge ~wrap =
    let open Cached in
    Md5.digest_string
      ("Transaction_snark"
        ^ Md5.to_hex base
        ^ Md5.to_hex merge
        ^ Md5.to_hex wrap)

  let cached () =
    let open Async in
    let get_vk (t : _ Cached.t) = { t with value = Tick.Keypair.vk t.value } in
    let%bind base = Base.cached () >>| get_vk
    and merge = Merge.cached () >>| get_vk
    in
    let%map wrap =
      let module Wrap =
        Wrap(struct
          let base = base.value
          let merge = merge.value
        end)
      in
      Wrap.cached ()
      >>| fun t -> { t with value = Tock.Keypair.vk t.value }
    in
    let t : Verification.Keys.t =
      { base = base.value
      ; merge = merge.value
      ; wrap = wrap.value
      }
    in
    let location : Location.t =
      { base = base.path
      ; merge = merge.path
      ; wrap = wrap.path
      }
    in
    let checksum = checksum ~base:base.checksum ~merge:merge.checksum ~wrap:wrap.checksum in
    (location, t, checksum)

  let load ({merge; base; wrap} : Location.t) =
    let open Storage.Disk in
    let parent_log = Logger.create () in
    let tick_controller =
      Controller.create ~parent_log Tick.Keypair.bin_t
    in
    let tock_controller =
      Controller.create ~parent_log Tock.Keypair.bin_t
    in
    let open Async in
    let load c p =
      match%map load_with_checksum c p with
      | Ok x -> x
      | Error e -> failwithf "Transaction_snark: load failed on %s" p ()
    in
    let%map base = load tick_controller base
    and merge = load tick_controller merge
    and wrap = load tock_controller wrap
    in
    let t =
      { base = base.data
      ; merge = merge.data
      ; wrap = wrap.data
      }
    in
    (t, checksum ~base:base.checksum ~merge:merge.checksum ~wrap:wrap.checksum)

  let create () =
    let base = Base.create_keys () in
    let merge = Merge.create_keys () in
    let wrap =
      let module Wrap =
        Wrap(struct
          let base = Tick.Keypair.vk base
          let merge = Tick.Keypair.vk merge
        end)
      in
      Wrap.create_keys ()
    in
    { base
    ; merge
    ; wrap
    }
end

let%test_module "transaction_snark" =
  (module struct
    type wallet = { private_key : Private_key.t ; account : Account.t }

    let random_wallets () =
      let random_wallet () : wallet =
        let private_key = Private_key.create () in
        { private_key
        ; account =
            { public_key = Public_key.compress (Public_key.of_private_key private_key)
            ; balance = Balance.of_int (10 + Random.int 100)
            ; nonce = Account.Nonce.zero
            }
        }
      in
      let n = Int.pow 2 ledger_depth in
      Array.init n ~f:(fun _ -> random_wallet ())
    ;;

    let transaction wallets i j amt fee nonce =
      let sender = wallets.(i) in
      let receiver = wallets.(j) in
      let payload : Transaction.Payload.t =
        { receiver = receiver.account.public_key
        ; fee
        ; amount = Amount.of_int amt
        ; nonce
        }
      in
      let signature =
        Schnorr.sign sender.private_key
          (Transaction.Payload.to_bits payload)
      in
      Transaction.check
        { Transaction.payload
        ; sender = Public_key.of_private_key sender.private_key
        ; signature
        }
      |> Option.value_exn

    let keys = Keys.create ()

    include Make(struct let keys = keys end)

    let of_transaction' ledger transaction =
      let source = Ledger.merkle_root ledger in
      let target = Ledger.merkle_root_after_transaction_exn ledger transaction in
      of_transaction source target transaction (handle_with_ledger ledger)

    let%test "base_and_merge" =
      Test_util.with_randomness 123456789 (fun () ->
        let wallets = random_wallets () in
        let ledger =
          Ledger.create ()
        in
        Array.iter wallets ~f:(fun { account } ->
          Ledger.set ledger account.public_key account);
        let t1 = transaction wallets 0 1 8 (Fee.of_int (Random.int 20)) Account.Nonce.zero in
        let t2 = transaction wallets 1 2 3 (Fee.of_int (Random.int 20)) Account.Nonce.zero in
        let state1 = Ledger.merkle_root ledger in
        let proof12 = of_transaction' ledger t1 in
        let proof23 = of_transaction' ledger t2 in
        let total_fees =
          let open Amount in
          let magnitude =
            of_fee ((t1 :> Transaction.t).payload.fee)
            + of_fee ((t2 :> Transaction.t).payload.fee)
            |> Option.value_exn
          in
          Signed.create ~magnitude ~sgn:Sgn.Pos
        in
        let state3 = Ledger.merkle_root ledger in
        let proof13 = merge proof12 proof23 |> Or_error.ok_exn in
        Tock.verify proof13.proof (Tock.Keypair.vk keys.Keys.wrap) (wrap_input ())
          (embed (merge_top_hash state1 state3 total_fees wrap_vk_bits)))
  end)
