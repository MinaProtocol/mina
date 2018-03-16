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
      let%map balance = Amount.(account.balance - amount) in
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
let tock_input () = Tock.Data_spec.([ Tock.Field.typ ])

let base_keypair =
  generate_keypair transition_base ~exposing:(tick_input ())

module Merge = struct
  module Tick = struct
    module Prover_state = struct
      type t =
        { tock_vk : Tock_curve.Verification_key.t
        ; input1  : bool list
        ; proof12 : Tock_curve.Proof.t
        ; input2  : bool list
        ; proof23 : Tock_curve.Proof.t
        ; input3  : bool list
        }
      [@@deriving fields]
    end

    let input = tick_input

    let tock_input_size = Tock.Data_spec.size (tock_input ())

    let tock_vk_length = 11324
    let tock_vk_typ = Typ.list ~length:tock_vk_length Boolean.typ

    let tock_input_typ = Typ.list ~length:Tock.Field.size_in_bits Boolean.typ

    module Verifier =
      Snarky.Verifier_gadget.Make(Tick)(Tick_curve)(Tock_curve)
        (struct let input_size = tock_input_size end)

    let main (top_hash : Pedersen.Digest.Packed.var) =
      let%bind tock_vk =
        provide_witness' tock_vk_typ ~f:(fun { Prover_state.tock_vk } ->
          Verifier.Verification_key.to_bool_list tock_vk)
      and s1 = provide_witness' tock_input_typ ~f:Prover_state.input1
      and s2 = provide_witness' tock_input_typ ~f:Prover_state.input2
      and s3 = provide_witness' tock_input_typ ~f:Prover_state.input3
      in
      let%bind () =
        hash_digest (tock_vk @ s1 @ s3) >>= assert_equal top_hash
      in
      let%bind v12 =
        let%bind input =
          hash_digest (tock_vk @ s1 @ s2)
          >>= Pedersen.Digest.choose_preimage_var
          >>| Pedersen.Digest.Unpacked.var_to_bits
        in
        Verifier.All_in_one.create ~verification_key:tock_vk ~input
          As_prover.(map get_state ~f:(fun { Prover_state.tock_vk; proof12 } ->
            { Verifier.All_in_one.verification_key=tock_vk; proof=proof12 }))
      in
      let%bind v23 =
        let%bind input =
          hash_digest (tock_vk @ s2 @ s3)
          >>= Pedersen.Digest.choose_preimage_var
          >>| Pedersen.Digest.Unpacked.var_to_bits
        in
        Verifier.All_in_one.create ~verification_key:tock_vk ~input
          As_prover.(map get_state ~f:(fun { Prover_state.tock_vk; proof23 } ->
            { Verifier.All_in_one.verification_key=tock_vk; proof=proof23 }))
      in
      Boolean.Assert.all
        [ Verifier.All_in_one.result v12
        ; Verifier.All_in_one.result v23
        ]

    let keypair =
      generate_keypair ~exposing:(input ()) main

    let vk = Keypair.vk keypair
  end

  module Tock = struct
    open Tock

    module Verifier =
      Snarky.Verifier_gadget.Make(Tock)(Tock_curve)(Tick_curve)
        (struct let input_size = tick_input_size end)

    let base_vk = Tick0.Keypair.vk base_keypair
    let merge_vk = Tick.vk
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
        { tock_vk : Tick_curve.Verification_key.t
        ; is_base    : bool
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
  end
end
