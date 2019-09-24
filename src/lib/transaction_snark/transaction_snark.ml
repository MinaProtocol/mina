open Core
open Signature_lib
open Coda_base
open Snark_params
open Currency
open Fold_lib
open Module_version

let state_hash_size_in_triples = Tick.Field.size_in_triples

let tick_input () =
  let open Tick in
  Data_spec.[Field.typ]

let wrap_input = Tock.Data_spec.[Wrap_input.typ]

let exists' typ ~f = Tick.(exists typ ~compute:As_prover.(map get_state ~f))

module Proof_type = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = [`Base | `Merge]
        [@@deriving bin_io, compare, equal, hash, sexp, version, yojson]
      end

      include T
      include Registration.Make_latest_version (T)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "transaction_snark_proof_type"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  (* bin_io omitted *)
  type t = Stable.Latest.t [@@deriving sexp, hash, compare, yojson]

  let is_base = function `Base -> true | `Merge -> false
end

module Pending_coinbase_stack_state = struct
  (*State of the coinbase stack for the current transaction snark*)
  module Stable = struct
    module V1 = struct
      module T = struct
        type t =
          { source: Pending_coinbase.Stack.Stable.V1.t
          ; target: Pending_coinbase.Stack.Stable.V1.t }
        [@@deriving sexp, bin_io, hash, compare, eq, fields, yojson, version]
      end

      include T
      include Registration.Make_latest_version (T)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "transaction_snark_pending_coinbase_stack_state"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  type t = Stable.Latest.t =
    { source: Pending_coinbase.Stack.Stable.V1.t
    ; target: Pending_coinbase.Stack.Stable.V1.t }
  [@@deriving sexp, hash, compare, yojson]

  include Hashable.Make_binable (Stable.Latest)
  include Comparable.Make (Stable.Latest)
end

module Statement = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t =
          { source: Frozen_ledger_hash.Stable.V1.t
          ; target: Frozen_ledger_hash.Stable.V1.t
          ; supply_increase: Currency.Amount.Stable.V1.t
          ; pending_coinbase_stack_state:
              Pending_coinbase_stack_state.Stable.V1.t
          ; fee_excess: Currency.Fee.Signed.Stable.V1.t
          ; proof_type: Proof_type.Stable.V1.t }
        [@@deriving bin_io, compare, equal, hash, sexp, version, yojson]
      end

      include T
      include Registration.Make_latest_version (T)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "transaction_snark_statement"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  (* bin_io omitted *)
  type t = Stable.Latest.t =
    { source: Frozen_ledger_hash.Stable.V1.t
    ; target: Frozen_ledger_hash.Stable.V1.t
    ; supply_increase: Currency.Amount.Stable.V1.t
    ; pending_coinbase_stack_state: Pending_coinbase_stack_state.t
    ; fee_excess: Currency.Fee.Signed.Stable.V1.t
    ; proof_type: Proof_type.Stable.V1.t }
  [@@deriving sexp, hash, compare, yojson]

  let option lab =
    Option.value_map ~default:(Or_error.error_string lab) ~f:(fun x -> Ok x)

  let merge s1 s2 =
    let open Or_error.Let_syntax in
    let%map fee_excess =
      Currency.Fee.Signed.add s1.fee_excess s2.fee_excess
      |> option "Error adding fees"
    and supply_increase =
      Currency.Amount.add s1.supply_increase s2.supply_increase
      |> option "Error adding supply_increase"
    in
    { source= s1.source
    ; target= s2.target
    ; fee_excess
    ; proof_type= `Merge
    ; supply_increase
    ; pending_coinbase_stack_state=
        { source= s1.pending_coinbase_stack_state.source
        ; target= s2.pending_coinbase_stack_state.target } }

  include Hashable.Make_binable (Stable.Latest)
  include Comparable.Make (Stable.Latest)

  let gen =
    let open Quickcheck.Generator.Let_syntax in
    let%map source = Frozen_ledger_hash.gen
    and target = Frozen_ledger_hash.gen
    and fee_excess = Currency.Fee.Signed.gen
    and supply_increase = Currency.Amount.gen
    and pending_coinbase_before = Pending_coinbase.Stack.gen
    and pending_coinbase_after = Pending_coinbase.Stack.gen
    and proof_type =
      Bool.quickcheck_generator >>| fun b -> if b then `Merge else `Base
    in
    { source
    ; target
    ; fee_excess
    ; proof_type
    ; supply_increase
    ; pending_coinbase_stack_state=
        {source= pending_coinbase_before; target= pending_coinbase_after} }
end

module Stable = struct
  module V1 = struct
    module T = struct
      type t =
        { source: Frozen_ledger_hash.Stable.V1.t
        ; target: Frozen_ledger_hash.Stable.V1.t
        ; proof_type: Proof_type.Stable.V1.t
        ; supply_increase: Amount.Stable.V1.t
        ; pending_coinbase_stack_state:
            Pending_coinbase_stack_state.Stable.V1.t
        ; fee_excess: Amount.Signed.Stable.V1.t
        ; sok_digest: Sok_message.Digest.Stable.V1.t
        ; proof: Proof.Stable.V1.t }
      [@@deriving fields, sexp, bin_io, yojson, version]
    end

    include T
    include Registration.Make_latest_version (T)
  end

  module Latest = V1

  module Module_decl = struct
    let name = "transaction_snark"

    type latest = Latest.t
  end

  module Registrar = Registration.Make (Module_decl)
  module Registered_V1 = Registrar.Register (V1)
end

(* bin_io omitted *)
type t = Stable.Latest.t =
  { source: Frozen_ledger_hash.Stable.V1.t
  ; target: Frozen_ledger_hash.Stable.V1.t
  ; proof_type: Proof_type.Stable.V1.t
  ; supply_increase: Amount.Stable.V1.t
  ; pending_coinbase_stack_state: Pending_coinbase_stack_state.t
  ; fee_excess: Amount.Signed.Stable.V1.t
  ; sok_digest: Sok_message.Digest.Stable.V1.t
  ; proof: Proof.Stable.V1.t }
[@@deriving fields, sexp, yojson]

let statement
    ({ source
     ; target
     ; proof_type
     ; fee_excess
     ; supply_increase
     ; pending_coinbase_stack_state
     ; sok_digest= _
     ; proof= _ } :
      t) =
  { Statement.Stable.V1.source
  ; target
  ; proof_type
  ; supply_increase
  ; pending_coinbase_stack_state
  ; fee_excess=
      Currency.Fee.Signed.create
        ~magnitude:Currency.Amount.(to_fee (Signed.magnitude fee_excess))
        ~sgn:(Currency.Amount.Signed.sgn fee_excess) }

let create = Fields.create

let construct_input ~proof_type ~sok_digest ~state1 ~state2 ~supply_increase
    ~fee_excess
    ~(pending_coinbase_stack_state : Pending_coinbase_stack_state.t) =
  let fold =
    let open Fold in
    Sok_message.Digest.fold sok_digest
    +> Frozen_ledger_hash.fold state1
    +> Frozen_ledger_hash.fold state2
    +> Pending_coinbase.Stack.fold pending_coinbase_stack_state.source
    +> Pending_coinbase.Stack.fold pending_coinbase_stack_state.target
    +> Amount.fold supply_increase
    +> Amount.Signed.fold fee_excess
  in
  match proof_type with
  | `Base ->
      Tick.Pedersen.digest_fold Hash_prefix.base_snark fold
  | `Merge wrap_vk_bits ->
      Tick.Pedersen.digest_fold Hash_prefix.merge_snark
        Fold.(fold +> group3 ~default:false (of_list wrap_vk_bits))

let base_top_hash = construct_input ~proof_type:`Base

let merge_top_hash wrap_vk_bits =
  construct_input ~proof_type:(`Merge wrap_vk_bits)

module Verification_keys = struct
  type t =
    { base: Tick.Verification_key.t
    ; wrap: Tock.Verification_key.t
    ; merge: Tick.Verification_key.t }
  [@@deriving bin_io]

  let dummy : t =
    let groth16 =
      Tick_backend.Verification_key.dummy
        ~input_size:(Tick.Data_spec.size (tick_input ()))
    in
    { merge= groth16
    ; base= groth16
    ; wrap= Tock_backend.Verification_key.dummy ~input_size:Wrap_input.size }
end

module Keys0 = struct
  module Verification = Verification_keys

  module Proving = struct
    type t =
      { base: Tick.Proving_key.t
      ; wrap: Tock.Proving_key.t
      ; merge: Tick.Proving_key.t }

    let dummy =
      { merge= Dummy_values.Tick.Groth16.proving_key
      ; base= Dummy_values.Tick.Groth16.proving_key
      ; wrap= Dummy_values.Tock.Bowe_gabizon18.proving_key }
  end

  module T = struct
    type t = {proving: Proving.t; verification: Verification.t}
  end

  include T
end

(* Staging:
   first make tick base.
   then make tick merge (which top_hashes in the tock wrap vk)
   then make tock wrap (which branches on the tick vk) *)

module Base = struct
  open Tick
  open Let_syntax

  let%snarkydef check_signature shifted ~payload ~is_user_command ~sender
      ~signature =
    let%bind verifies =
      Schnorr.Checked.verifies shifted signature sender payload
    in
    Boolean.Assert.any [Boolean.not is_user_command; verifies]

  let chain if_ b ~then_ ~else_ =
    let%bind then_ = then_ and else_ = else_ in
    if_ b ~then_ ~else_

  (* spec for
     [apply_tagged_transaction root (tag, { sender; signature; payload }]):
     - if tag = Normal:
        - check that [signature] is a signature by [sender] of payload
        - return:
          - merkle tree [root'] where the sender balance is decremented by
            [payload.amount] and the receiver balance is incremented by [payload.amount].
          - fee excess = +fee.
          -if coinbase, then push it to the stack [pending_coinbase_stack_before]

     - if tag = Fee_transfer
        - return:
          - merkle tree [root'] where the sender balance is incremented by
            fee and the receiver balance is incremented by amount
          - fee excess = -(amount + fee)

  *)
  (* Nonce should only be incremented if it is a "Normal" transaction. *)
  let%snarkydef apply_tagged_transaction (type shifted)
      (shifted : (module Inner_curve.Checked.Shifted.S with type t = shifted))
      root pending_coinbase_stack_before
      ({sender; signature; payload} : Transaction_union.var) =
    let nonce = payload.common.nonce in
    let tag = payload.body.tag in
    let%bind payload_section = Schnorr.Message.var_of_payload payload in
    let%bind is_user_command =
      Transaction_union.Tag.Checked.is_user_command tag
    in
    let%bind () =
      check_signature shifted ~payload ~is_user_command ~sender ~signature
    in
    let%bind {excess; sender_delta; supply_increase; receiver_increase} =
      Transaction_union_payload.Changes.Checked.of_payload payload
    in
    let%bind is_stake_delegation =
      Transaction_union.Tag.Checked.is_stake_delegation tag
    in
    let%bind sender_compressed = Public_key.compress_var sender in
    let proposer = payload.body.public_key in
    let%bind is_coinbase = Transaction_union.Tag.Checked.is_coinbase tag in
    let%bind pending_coinbase_stack_after =
      let coinbase = (proposer, payload.body.amount) in
      let%bind stack' =
        Pending_coinbase.Stack.Checked.push pending_coinbase_stack_before
          coinbase
      in
      Pending_coinbase.Stack.Checked.if_ is_coinbase ~then_:stack'
        ~else_:pending_coinbase_stack_before
    in
    let%bind root =
      let%bind is_writeable =
        let%bind is_fee_transfer =
          Transaction_union.Tag.Checked.is_fee_transfer tag
        in
        Boolean.any [is_fee_transfer; is_coinbase]
      in
      Frozen_ledger_hash.modify_account_send root ~is_writeable
        sender_compressed ~f:(fun ~is_empty_and_writeable account ->
          with_label __LOC__
            (let%bind next_nonce =
               Account.Nonce.Checked.succ_if account.nonce is_user_command
             in
             let%bind () =
               with_label __LOC__
                 (let%bind nonce_matches =
                    Account.Nonce.Checked.equal nonce account.nonce
                  in
                  Boolean.Assert.any
                    [Boolean.not is_user_command; nonce_matches])
             in
             let%bind receipt_chain_hash =
               let current = account.receipt_chain_hash in
               let%bind r =
                 Receipt.Chain_hash.Checked.cons ~payload:payload_section
                   current
               in
               Receipt.Chain_hash.Checked.if_ is_user_command ~then_:r
                 ~else_:current
             in
             let%bind delegate =
               let if_ = chain Public_key.Compressed.Checked.if_ in
               if_ is_empty_and_writeable ~then_:(return sender_compressed)
                 ~else_:
                   (if_ is_stake_delegation
                      ~then_:(return payload.body.public_key)
                      ~else_:(return account.delegate))
             in
             let%map balance =
               Balance.Checked.add_signed_amount account.balance sender_delta
             in
             { Account.Poly.balance
             ; public_key= sender_compressed
             ; nonce= next_nonce
             ; receipt_chain_hash
             ; delegate
             ; voting_for= account.voting_for }) )
    in
    let%bind receiver =
      (* A stake delegation only uses the sender *)
      Public_key.Compressed.Checked.if_ is_stake_delegation
        ~then_:sender_compressed ~else_:payload.body.public_key
    in
    (* we explicitly set the public_key because it could be zero if the account is new *)
    let%map root =
      (* This update should be a no-op in the stake delegation case *)
      Frozen_ledger_hash.modify_account_recv root receiver
        ~f:(fun ~is_empty_and_writeable account ->
          let%map balance =
            (* receiver_increase will be zero in the stake delegation case *)
            Balance.Checked.(account.balance + receiver_increase)
          and delegate =
            Public_key.Compressed.Checked.if_ is_empty_and_writeable
              ~then_:receiver ~else_:account.delegate
          in
          {account with balance; delegate; public_key= receiver} )
    in
    (root, pending_coinbase_stack_after, excess, supply_increase)

  (* Someday:
   write the following soundness tests:
   - apply a transaction where the signature is incorrect
   - apply a transaction where the sender does not have enough money in their account
   - apply a transaction and stuff in the wrong target hash
    *)

  module Prover_state = struct
    type t =
      { transaction: Transaction_union.t
      ; state1: Frozen_ledger_hash.t
      ; state2: Frozen_ledger_hash.t
      ; pending_coinbase_stack_state: Pending_coinbase_stack_state.t
      ; sok_digest: Sok_message.Digest.t }
    [@@deriving fields]
  end

  (* spec for [main top_hash]:
   constraints pass iff
   there exist
      l1 : Frozen_ledger_hash.t,
      l2 : Frozen_ledger_hash.t,
      fee_excess : Amount.Signed.t,
      supply_increase : Amount.t
      pending_coinbase_stack_state: Pending_coinbase_stack_state.t
      t : Tagged_transaction.t
   such that
   H(l1, l2, pending_coinbase_stack_state.source, pending_coinbase_stack_state.target, fee_excess, supply_increase) = top_hash,
   applying [t] to ledger with merkle hash [l1] results in ledger with merkle hash [l2]. *)
  let%snarkydef main top_hash =
    let%bind (module Shifted) = Tick.Inner_curve.Checked.Shifted.create () in
    let%bind root_before =
      exists' Frozen_ledger_hash.typ ~f:Prover_state.state1
    in
    let%bind t =
      with_label __LOC__
        (exists' Transaction_union.typ ~f:Prover_state.transaction)
    in
    let%bind pending_coinbase_before =
      exists' Pending_coinbase.Stack.typ ~f:(fun s ->
          (Prover_state.pending_coinbase_stack_state s).source )
    in
    let%bind root_after, pending_coinbase_after, fee_excess, supply_increase =
      apply_tagged_transaction
        (module Shifted)
        root_before pending_coinbase_before t
    in
    let%map () =
      with_label __LOC__
        (let%bind b1 = Frozen_ledger_hash.var_to_triples root_before
         and b2 = Frozen_ledger_hash.var_to_triples root_after
         and sok_digest =
           exists' Sok_message.Digest.typ ~f:Prover_state.sok_digest
         and pending_coinbase_before =
           Pending_coinbase.Stack.var_to_triples pending_coinbase_before
         and pending_coinbase_after =
           Pending_coinbase.Stack.var_to_triples pending_coinbase_after
         in
         let fee_excess = Amount.Signed.Checked.to_triples fee_excess in
         let supply_increase = Amount.var_to_triples supply_increase in
         let triples =
           Sok_message.Digest.Checked.to_triples sok_digest
           @ b1 @ b2 @ pending_coinbase_before @ pending_coinbase_after
           @ supply_increase @ fee_excess
         in
         Pedersen.Checked.digest_triples ~init:Hash_prefix.base_snark triples
         >>= Field.Checked.Assert.equal top_hash)
    in
    ()

  let create_keys () = generate_keypair main ~exposing:(tick_input ())

  let transaction_union_proof ?(preeval = false) ~proving_key sok_digest state1
      state2 pending_coinbase_stack_state (transaction : Transaction_union.t)
      handler =
    let prover_state : Prover_state.t =
      {state1; state2; transaction; sok_digest; pending_coinbase_stack_state}
    in
    let main =
      if preeval then failwith "preeval currently disabled" else main
    in
    let main top_hash = handle (main top_hash) handler in
    let top_hash =
      base_top_hash ~sok_digest ~state1 ~state2
        ~fee_excess:(Transaction_union.excess transaction)
        ~supply_increase:(Transaction_union.supply_increase transaction)
        ~pending_coinbase_stack_state
    in
    (top_hash, prove proving_key (tick_input ()) prover_state main top_hash)

  let cached =
    let load =
      let open Cached.Let_syntax in
      let%map verification =
        Cached.component ~label:"verification" ~f:Keypair.vk
          (module Verification_key)
      and proving =
        Cached.component ~label:"proving" ~f:Keypair.pk (module Proving_key)
      in
      (verification, {proving with value= ()})
    in
    Cached.Spec.create ~load ~name:"transaction-snark base keys"
      ~autogen_path:Cache_dir.autogen_path
      ~manual_install_path:Cache_dir.manual_install_path
      ~brew_install_path:Cache_dir.brew_install_path
      ~digest_input:(fun x ->
        Md5.to_hex (R1CS_constraint_system.digest (Lazy.force x)) )
      ~input:(lazy (constraint_system ~exposing:(tick_input ()) main))
      ~create_env:(fun x -> Keypair.generate (Lazy.force x))
end

module Transition_data = struct
  type t =
    { proof: Proof_type.t * Tock_backend.Proof.t
    ; supply_increase: Amount.t
    ; fee_excess: Amount.Signed.t
    ; sok_digest: Sok_message.Digest.t
    ; pending_coinbase_stack_state: Pending_coinbase_stack_state.t }
  [@@deriving fields]
end

module Merge = struct
  open Tick
  open Let_syntax

  module Prover_state = struct
    type t =
      { tock_vk: Tock_backend.Verification_key.t
      ; sok_digest: Sok_message.Digest.t
      ; ledger_hash1: bool list
      ; ledger_hash2: bool list
      ; transition12: Transition_data.t
      ; ledger_hash3: bool list
      ; transition23: Transition_data.t
      ; pending_coinbase_stack1: bool list
      ; pending_coinbase_stack2: bool list
      ; pending_coinbase_stack3: bool list }
    [@@deriving fields]
  end

  let input = tick_input

  let wrap_input_size = Tock.Data_spec.size wrap_input

  let wrap_input_typ = Typ.list ~length:Tock.Field.size_in_bits Boolean.typ

  (* TODO: When we switch to the weierstrass curve use the shifted
   add-many function *)
  let disjoint_union_sections = function
    | [] ->
        failwith "empty list"
    | s :: ss ->
        Checked.List.fold
          ~f:(fun acc x -> Pedersen.Checked.Section.disjoint_union_exn acc x)
          ~init:s ss

  module Verifier = Tick.Verifier

  let vk_input_offset =
    Hash_prefix.length_in_triples + Sok_message.Digest.length_in_triples
    + (2 * state_hash_size_in_triples)
    + Amount.length_in_triples + Amount.Signed.length_in_triples
    + (2 * Pending_coinbase.Stack.length_in_triples)

  let construct_input_checked ~prefix
      ~(sok_digest : Sok_message.Digest.Checked.t) ~state1 ~state2
      ~pending_coinbase_stack1 ~pending_coinbase_stack2 ~supply_increase
      ~fee_excess ?tock_vk () =
    let prefix_section =
      Pedersen.Checked.Section.create ~acc:prefix
        ~support:
          (Interval_union.of_interval (0, Hash_prefix.length_in_triples))
    in
    let%bind prefix_and_sok_digest =
      Pedersen.Checked.Section.extend prefix_section
        (Sok_message.Digest.Checked.to_triples sok_digest)
        ~start:Hash_prefix.length_in_triples
    in
    let%bind prefix_and_sok_digest_and_supply_increase_and_fee =
      let open Pedersen.Checked.Section in
      extend prefix_and_sok_digest
        ~start:
          ( Hash_prefix.length_in_triples + Sok_message.Digest.length_in_triples
          + (2 * state_hash_size_in_triples)
          + (2 * Pending_coinbase.Stack.length_in_triples) )
        ( Amount.var_to_triples supply_increase
        @ Amount.Signed.Checked.to_triples fee_excess )
    in
    disjoint_union_sections
      ( [ prefix_and_sok_digest_and_supply_increase_and_fee
        ; state1
        ; state2
        ; pending_coinbase_stack1
        ; pending_coinbase_stack2 ]
      @ Option.to_list tock_vk )

  (* spec for [verify_transition tock_vk proof_field s1 s2]:
     returns a bool which is true iff
     there is a snark proving making tock_vk
     accept on one of [ H(s1, s2, excess); H(s1, s2, excess, tock_vk) ] *)
  let verify_transition tock_vk tock_vk_precomp tock_vk_section
      get_transition_data s1 s2 ~pending_coinbase_stack1
      ~pending_coinbase_stack2 supply_increase fee_excess =
    let%bind is_base =
      let get_type s = get_transition_data s |> Transition_data.proof |> fst in
      with_label __LOC__
        (exists' Boolean.typ ~f:(fun s -> Proof_type.is_base (get_type s)))
    in
    let%bind sok_digest =
      exists' Sok_message.Digest.typ
        ~f:(Fn.compose Transition_data.sok_digest get_transition_data)
    in
    let%bind all_but_vk_top_hash =
      let prefix =
        `Var
          (Inner_curve.Checked.if_value is_base
             ~then_:Hash_prefix.base_snark.acc
             ~else_:Hash_prefix.merge_snark.acc)
      in
      construct_input_checked ~prefix ~sok_digest ~state1:s1 ~state2:s2
        ~pending_coinbase_stack1 ~pending_coinbase_stack2 ~supply_increase
        ~fee_excess ()
    in
    let%bind with_vk_top_hash =
      with_label __LOC__
        (Pedersen.Checked.Section.disjoint_union_exn tock_vk_section
           all_but_vk_top_hash)
      >>| Pedersen.Checked.Section.to_initial_segment_digest_exn >>| fst
    in
    let%bind input =
      with_label __LOC__
        ( Field.Checked.if_ is_base
            ~then_:
              ( all_but_vk_top_hash
              |> Pedersen.Checked.Section.to_initial_segment_digest_exn |> fst
              )
            ~else_:with_vk_top_hash
        >>= Wrap_input.Checked.tick_field_to_scalars )
    in
    let%bind proof =
      exists Verifier.Proof.typ
        ~compute:
          As_prover.(
            map get_state ~f:(fun s ->
                get_transition_data s |> Transition_data.proof |> snd
                |> Verifier.proof_of_backend_proof ))
    in
    Verifier.verify tock_vk tock_vk_precomp input proof

  let state1_offset =
    Hash_prefix.length_in_triples + Sok_message.Digest.length_in_triples

  let state2_offset = state1_offset + state_hash_size_in_triples

  let state3_offset = state2_offset + state_hash_size_in_triples

  let state4_offset = state3_offset + state_hash_size_in_triples

  (* spec for [main top_hash]:
     constraints pass iff
     there exist digest, s1, s3, fee_excess, supply_increase pending_coinbase_stack12.source, pending_coinbase_stack23.target, tock_vk such that
     H(digest,s1, s3, pending_coinbase_stack12.source, pending_coinbase_stack23.target, fee_excess, supply_increase, tock_vk) = top_hash,
     verify_transition tock_vk _ s1 s2 pending_coinbase_stack12.source, pending_coinbase_stack12.target is true
     verify_transition tock_vk _ s2 s3 pending_coinbase_stack23.source, pending_coinbase_stack23.target is true
  *)
  let%snarkydef main (top_hash : Pedersen.Checked.Digest.var) =
    let%bind tock_vk =
      exists' (Verifier.Verification_key.typ ~input_size:wrap_input_size)
        ~f:(fun {Prover_state.tock_vk; _} -> Verifier.vk_of_backend_vk tock_vk
      )
    and s1 = exists' wrap_input_typ ~f:Prover_state.ledger_hash1
    and s2 = exists' wrap_input_typ ~f:Prover_state.ledger_hash2
    and s3 = exists' wrap_input_typ ~f:Prover_state.ledger_hash3
    and fee_excess12 =
      exists' Amount.Signed.typ
        ~f:(Fn.compose Transition_data.fee_excess Prover_state.transition12)
    and fee_excess23 =
      exists' Amount.Signed.typ
        ~f:(Fn.compose Transition_data.fee_excess Prover_state.transition23)
    and supply_increase12 =
      exists' Amount.typ
        ~f:
          (Fn.compose Transition_data.supply_increase Prover_state.transition12)
    and supply_increase23 =
      exists' Amount.typ
        ~f:
          (Fn.compose Transition_data.supply_increase Prover_state.transition23)
    and pending_coinbase1 =
      exists' wrap_input_typ ~f:Prover_state.pending_coinbase_stack1
    and pending_coinbase2 =
      exists' wrap_input_typ ~f:Prover_state.pending_coinbase_stack2
    and pending_coinbase3 =
      exists' wrap_input_typ ~f:Prover_state.pending_coinbase_stack3
    in
    let bits_to_triples bits =
      Fold.(to_list (group3 ~default:Boolean.false_ (of_list bits)))
    in
    let%bind s1_section =
      let open Pedersen.Checked.Section in
      extend empty ~start:state1_offset (bits_to_triples s1)
    in
    let%bind s3_section =
      let open Pedersen.Checked.Section in
      extend empty ~start:state2_offset (bits_to_triples s3)
    in
    let%bind coinbase_section1 =
      let open Pedersen.Checked.Section in
      extend empty ~start:state3_offset (bits_to_triples pending_coinbase1)
    in
    let%bind coinbase_section3 =
      let open Pedersen.Checked.Section in
      extend empty ~start:state4_offset (bits_to_triples pending_coinbase3)
    in
    let%bind tock_vk_section =
      let%bind bs =
        Verifier.Verification_key.(summary (summary_input tock_vk))
      in
      Pedersen.Checked.Section.extend Pedersen.Checked.Section.empty
        ~start:vk_input_offset (bits_to_triples bs)
    in
    let%bind tock_vk_precomp =
      Verifier.Verification_key.Precomputation.create tock_vk
    in
    let%bind () =
      let%bind total_fees =
        Amount.Signed.Checked.add fee_excess12 fee_excess23
      in
      let%bind supply_increase =
        Amount.Checked.add supply_increase12 supply_increase23
      in
      let%bind input =
        let%bind sok_digest =
          exists' Sok_message.Digest.typ ~f:Prover_state.sok_digest
        in
        construct_input_checked ~prefix:(`Value Hash_prefix.merge_snark.acc)
          ~sok_digest ~state1:s1_section ~state2:s3_section
          ~pending_coinbase_stack1:coinbase_section1
          ~pending_coinbase_stack2:coinbase_section3 ~supply_increase
          ~fee_excess:total_fees ~tock_vk:tock_vk_section ()
        >>| Pedersen.Checked.Section.to_initial_segment_digest_exn >>| fst
      in
      Field.Checked.Assert.equal top_hash input
    and verify_12 =
      let%bind s2_section =
        let open Pedersen.Checked.Section in
        extend empty ~start:state2_offset (bits_to_triples s2)
      in
      let%bind coinbase_section2 =
        let open Pedersen.Checked.Section in
        extend empty ~start:state4_offset (bits_to_triples pending_coinbase2)
      in
      verify_transition tock_vk tock_vk_precomp tock_vk_section
        Prover_state.transition12 s1_section s2_section
        ~pending_coinbase_stack1:coinbase_section1
        ~pending_coinbase_stack2:coinbase_section2 supply_increase12
        fee_excess12
    and verify_23 =
      let%bind s2_section =
        let open Pedersen.Checked.Section in
        extend empty ~start:state1_offset (bits_to_triples s2)
      in
      let%bind coinbase_section2 =
        let open Pedersen.Checked.Section in
        extend empty ~start:state3_offset (bits_to_triples pending_coinbase2)
      in
      verify_transition tock_vk tock_vk_precomp tock_vk_section
        Prover_state.transition23 s2_section s3_section
        ~pending_coinbase_stack1:coinbase_section2
        ~pending_coinbase_stack2:coinbase_section3 supply_increase23
        fee_excess23
    in
    Boolean.Assert.all [verify_12; verify_23]

  let create_keys () = generate_keypair ~exposing:(input ()) main

  let cached =
    let load =
      let open Cached.Let_syntax in
      let%map verification =
        Cached.component ~label:"verification" ~f:Keypair.vk
          (module Verification_key)
      and proving =
        Cached.component ~label:"proving" ~f:Keypair.pk (module Proving_key)
      in
      (verification, {proving with value= ()})
    in
    Cached.Spec.create ~load ~name:"transaction-snark merge keys"
      ~autogen_path:Cache_dir.autogen_path
      ~manual_install_path:Cache_dir.manual_install_path
      ~brew_install_path:Cache_dir.brew_install_path
      ~digest_input:(fun x ->
        Md5.to_hex (R1CS_constraint_system.digest (Lazy.force x)) )
      ~input:(lazy (constraint_system ~exposing:(input ()) main))
      ~create_env:(fun x -> Keypair.generate (Lazy.force x))
end

module Verification = struct
  module Keys = Verification_keys

  module type S = sig
    val verify : t -> message:Sok_message.t -> bool

    val verify_against_digest : t -> bool

    val verify_complete_merge :
         Sok_message.Digest.Checked.t
      -> Frozen_ledger_hash.var
      -> Frozen_ledger_hash.var
      -> Pending_coinbase.Stack.var
      -> Pending_coinbase.Stack.var
      -> Currency.Amount.var
      -> (Tock.Proof.t, 's) Tick.As_prover.t
      -> (Tick.Boolean.var, 's) Tick.Checked.t
  end

  module Make (K : sig
    val keys : Keys.t
  end) =
  struct
    open K

    let wrap_vk_bits = Snark_params.tock_vk_to_bool_list keys.wrap

    (* someday: Reorganize this module so that the inputs are separated from the proof. *)
    let verify_against_digest
        { source
        ; target
        ; proof
        ; proof_type
        ; fee_excess
        ; sok_digest
        ; supply_increase
        ; pending_coinbase_stack_state } =
      let input =
        match proof_type with
        | `Base ->
            base_top_hash ~sok_digest ~state1:source ~state2:target
              ~pending_coinbase_stack_state ~fee_excess ~supply_increase
        | `Merge ->
            merge_top_hash ~sok_digest wrap_vk_bits ~state1:source
              ~state2:target ~pending_coinbase_stack_state ~fee_excess
              ~supply_increase
      in
      Tock.verify proof keys.wrap wrap_input (Wrap_input.of_tick_field input)

    let verify t ~message =
      Sok_message.Digest.equal t.sok_digest (Sok_message.digest message)
      && verify_against_digest t

    (* The curve pt corresponding to
       H(merge_prefix, _digest, _, _, _, Amount.Signed.zero, wrap_vk)
    (with starting point shifted over by 2 * digest_size so that
    this can then be used to compute H(merge_prefix, digest, s1, s2, pending_coinbase_stack_state.source, pending_coinbase_stack_state.target, Amount.Signed.zero, wrap_vk) *)
    let merge_prefix_and_zero_and_vk_curve_pt =
      let open Tick in
      let excess_begin =
        Hash_prefix.length_in_triples + Sok_message.Digest.length_in_triples
        + (2 * state_hash_size_in_triples)
        + (2 * Pending_coinbase.Stack.length_in_triples)
        + Amount.length_in_triples
      in
      let s = {Hash_prefix.merge_snark with triples_consumed= excess_begin} in
      let s =
        Pedersen.State.update_fold s
          Fold.(
            Amount.Signed.(fold zero)
            +> group3 ~default:false (of_list wrap_vk_bits))
      in
      let prefix_interval = (0, Hash_prefix.length_in_triples) in
      let excess_end = excess_begin + Amount.Signed.length_in_triples in
      let excess_interval = (excess_begin, excess_end) in
      let vk_length_in_triples = (2 + List.length wrap_vk_bits) / 3 in
      let vk_interval = (excess_end, excess_end + vk_length_in_triples) in
      Tick.Pedersen.Checked.Section.create ~acc:(`Value s.acc)
        ~support:
          (Interval_union.of_intervals_exn
             [prefix_interval; excess_interval; vk_interval])

    (* spec for [verify_merge s1 s2 _]:
      Returns a boolean which is true if there exists a tock proof proving
      (against the wrap verification key) H(s1, s2, Amount.Signed.zero, wrap_vk).
      This in turn should only happen if there exists a tick proof proving
      (against the merge verification key) H(s1, s2, Amount.Signed.zero, wrap_vk).

      We precompute the parts of the pedersen involving wrap_vk and
      Amount.Signed.zero outside the SNARK since this saves us many constraints.
    *)

    let wrap_vk = Merge.Verifier.(constant_vk (vk_of_backend_vk keys.wrap))

    let wrap_precomp =
      Merge.Verifier.(
        Verification_key.Precomputation.create_constant
          (vk_of_backend_vk keys.wrap))

    let verify_complete_merge sok_digest s1 s2
        (pending_coinbase_stack1 : Pending_coinbase.Stack.var)
        (pending_coinbase_stack2 : Pending_coinbase.Stack.var) supply_increase
        get_proof =
      let open Tick in
      let%bind s1 = Frozen_ledger_hash.var_to_triples s1
      and s2 = Frozen_ledger_hash.var_to_triples s2
      and pending_coinbase_before =
        Pending_coinbase.Stack.var_to_triples pending_coinbase_stack1
      and pending_coinbase_after =
        Pending_coinbase.Stack.var_to_triples pending_coinbase_stack2
      in
      let%bind top_hash_section =
        Pedersen.Checked.Section.extend merge_prefix_and_zero_and_vk_curve_pt
          ~start:Hash_prefix.length_in_triples
          ( Sok_message.Digest.Checked.to_triples sok_digest
          @ s1 @ s2 @ pending_coinbase_before @ pending_coinbase_after
          @ Amount.var_to_triples supply_increase )
      in
      let digest =
        let digest, `Length_in_triples n =
          Pedersen.Checked.Section.to_initial_segment_digest_exn
            top_hash_section
        in
        let length =
          Hash_prefix.length_in_triples + Sok_message.Digest.length_in_triples
          + (2 * Frozen_ledger_hash.length_in_triples)
          + (2 * Pending_coinbase.Stack.length_in_triples)
          + Amount.length_in_triples + Amount.Signed.length_in_triples
          + Coda_base.Util.bit_length_to_triple_length
              (List.length wrap_vk_bits)
        in
        if n = length then digest
        else
          failwithf
            !"%d = Hash_prefix.length_in_triples aka %d\n\
             \            + Sok_message.Digest.length_in_triples aka %d\n\
              + (2 * Frozen_ledger_hash.length_in_triples) aka %d \n\
             \            + Amount.length aka %d + Amount.Signed.length aka \
              %d + List.length wrap_vk_triples aka %d + (2* \
              Pending_coinbase.Stack.length_in_triples) aka %d) aka %d"
            n Hash_prefix.length_in_triples
            Sok_message.Digest.length_in_triples
            (2 * Frozen_ledger_hash.length_in_triples)
            Amount.length_in_triples Amount.Signed.length_in_triples
            (Coda_base.Util.bit_length_to_triple_length
               (List.length wrap_vk_bits))
            (2 * Pending_coinbase.Stack.length_in_triples)
            length ()
      in
      let%bind input = Wrap_input.Checked.tick_field_to_scalars digest in
      let%map result =
        let%bind proof =
          exists Merge.Verifier.Proof.typ
            ~compute:
              (As_prover.map get_proof ~f:Merge.Verifier.proof_of_backend_proof)
        in
        Merge.Verifier.verify wrap_vk wrap_precomp input proof
      in
      result
  end
end

module Wrap (Vk : sig
  val merge : Tick.Verification_key.t

  val base : Tick.Verification_key.t
end) =
struct
  open Tock
  module Verifier = Tock.Groth_verifier

  let merge_vk = Verifier.vk_of_backend_vk Vk.merge

  let merge_vk_precomp =
    Verifier.Verification_key.Precomputation.create_constant merge_vk

  let base_vk = Verifier.vk_of_backend_vk Vk.base

  let base_vk_precomp =
    Verifier.Verification_key.Precomputation.create_constant base_vk

  module Prover_state = struct
    type t = {proof_type: Proof_type.t; proof: Tick.Proof.t}
    [@@deriving fields]
  end

  let exists' typ ~f = exists typ ~compute:As_prover.(map get_state ~f)

  (* spec for [main input]:
   constraints pass iff
   (b1, b2, .., bn) = unpack input,
   there is a proof making one of [ base_vk; merge_vk ] accept (b1, b2, .., bn) *)
  let%snarkydef main (input : Wrap_input.var) =
    let%bind input = with_label __LOC__ (Wrap_input.Checked.to_scalar input) in
    let%bind is_base =
      exists' Boolean.typ ~f:(fun {Prover_state.proof_type; _} ->
          Proof_type.is_base proof_type )
    in
    let%bind verification_key_precomp =
      with_label __LOC__
        (Verifier.Verification_key.Precomputation.if_ is_base
           ~then_:base_vk_precomp ~else_:merge_vk_precomp)
    in
    let%bind verification_key =
      with_label __LOC__
        (Verifier.Verification_key.if_ is_base
           ~then_:(Verifier.constant_vk base_vk)
           ~else_:(Verifier.constant_vk merge_vk))
    in
    let%bind result =
      let%bind proof =
        exists Verifier.Proof.typ
          ~compute:
            As_prover.(
              map get_state
                ~f:
                  (Fn.compose Verifier.proof_of_backend_proof
                     Prover_state.proof))
      in
      with_label __LOC__
        (Verifier.verify verification_key verification_key_precomp [input]
           proof)
    in
    with_label __LOC__ (Boolean.Assert.is_true result)

  let create_keys () = generate_keypair ~exposing:wrap_input main

  let cached =
    let load =
      let open Cached.Let_syntax in
      let%map verification =
        Cached.component ~label:"verification" ~f:Keypair.vk
          (module Verification_key)
      and proving =
        Cached.component ~label:"proving" ~f:Keypair.pk (module Proving_key)
      in
      (verification, {proving with value= ()})
    in
    Cached.Spec.create ~load ~name:"transaction-snark wrap keys"
      ~autogen_path:Cache_dir.autogen_path
      ~manual_install_path:Cache_dir.manual_install_path
      ~brew_install_path:Cache_dir.brew_install_path
      ~digest_input:(fun x ->
        Md5.to_hex (R1CS_constraint_system.digest (Lazy.force x)) )
      ~input:(lazy (constraint_system ~exposing:wrap_input main))
      ~create_env:(fun x -> Keypair.generate (Lazy.force x))
end

module type S = sig
  include Verification.S

  val of_transaction :
       ?preeval:bool
    -> sok_digest:Sok_message.Digest.t
    -> source:Frozen_ledger_hash.t
    -> target:Frozen_ledger_hash.t
    -> pending_coinbase_stack_state:Pending_coinbase_stack_state.t
    -> Transaction.t
    -> Tick.Handler.t
    -> t

  val of_user_command :
       sok_digest:Sok_message.Digest.t
    -> source:Frozen_ledger_hash.t
    -> target:Frozen_ledger_hash.t
    -> pending_coinbase_stack:Pending_coinbase.Stack.t
    -> User_command.With_valid_signature.t
    -> Tick.Handler.t
    -> t

  val of_fee_transfer :
       sok_digest:Sok_message.Digest.t
    -> source:Frozen_ledger_hash.t
    -> target:Frozen_ledger_hash.t
    -> pending_coinbase_stack:Pending_coinbase.Stack.t
    -> Fee_transfer.t
    -> Tick.Handler.t
    -> t

  val merge : t -> t -> sok_digest:Sok_message.Digest.t -> t Or_error.t
end

let check_transaction_union ?(preeval = false) sok_message source target
    pending_coinbase_stack_state transaction handler =
  let sok_digest = Sok_message.digest sok_message in
  let prover_state : Base.Prover_state.t =
    { state1= source
    ; state2= target
    ; transaction
    ; sok_digest
    ; pending_coinbase_stack_state }
  in
  let top_hash =
    base_top_hash ~sok_digest ~state1:source ~state2:target
      ~pending_coinbase_stack_state
      ~fee_excess:(Transaction_union.excess transaction)
      ~supply_increase:(Transaction_union.supply_increase transaction)
  in
  let open Tick in
  let main =
    if preeval then failwith "preeval currently disabled" else Base.main
  in
  let main =
    handle
      (Checked.map (main (Field.Var.constant top_hash)) ~f:As_prover.return)
      handler
  in
  Or_error.ok_exn (run_and_check main prover_state) |> ignore

let check_transaction ?preeval ~sok_message ~source ~target
    ~pending_coinbase_stack_state (t : Transaction.t) handler =
  check_transaction_union ?preeval sok_message source target
    pending_coinbase_stack_state
    (Transaction_union.of_transaction t)
    handler

let check_user_command ~sok_message ~source ~target pending_coinbase_stack t
    handler =
  check_transaction ~sok_message ~source ~target
    ~pending_coinbase_stack_state:
      Pending_coinbase_stack_state.Stable.Latest.
        {source= pending_coinbase_stack; target= pending_coinbase_stack}
    (User_command t) handler

let generate_transaction_union_witness ?(preeval = false) sok_message source
    target transaction pending_coinbase_stack_state handler =
  let sok_digest = Sok_message.digest sok_message in
  let prover_state : Base.Prover_state.t =
    { state1= source
    ; state2= target
    ; transaction
    ; sok_digest
    ; pending_coinbase_stack_state }
  in
  let top_hash =
    base_top_hash ~sok_digest ~state1:source ~state2:target
      ~fee_excess:(Transaction_union.excess transaction)
      ~supply_increase:(Transaction_union.supply_increase transaction)
      ~pending_coinbase_stack_state
  in
  let open Tick in
  let main =
    if preeval then failwith "preeval currently disabled" else Base.main
  in
  let main x = handle (main x) handler in
  generate_auxiliary_input (tick_input ()) prover_state main top_hash

let generate_transaction_witness ?preeval ~sok_message ~source ~target
    pending_coinbase_stack_state (t : Transaction.t) handler =
  generate_transaction_union_witness ?preeval sok_message source target
    (Transaction_union.of_transaction t)
    pending_coinbase_stack_state handler

let verification_keys_of_keys {Keys0.verification; _} = verification

module Make (K : sig
  val keys : Keys0.t
end) =
struct
  open K

  include Verification.Make (struct
    let keys = verification_keys_of_keys keys
  end)

  module Wrap = Wrap (struct
    let merge = keys.verification.merge

    let base = keys.verification.base
  end)

  let wrap proof_type proof input =
    let prover_state = {Wrap.Prover_state.proof; proof_type} in
    Tock.prove keys.proving.wrap wrap_input prover_state Wrap.main
      (Wrap_input.of_tick_field input)

  let merge_proof sok_digest ledger_hash1 ledger_hash2 ledger_hash3
      transition12 transition23 =
    let fee_excess =
      Amount.Signed.add transition12.Transition_data.fee_excess
        transition23.Transition_data.fee_excess
      |> Option.value_exn
    in
    let supply_increase =
      Amount.add transition12.supply_increase transition23.supply_increase
      |> Option.value_exn
    in
    let top_hash =
      merge_top_hash wrap_vk_bits ~sok_digest ~state1:ledger_hash1
        ~state2:ledger_hash3
        ~pending_coinbase_stack_state:
          Pending_coinbase_stack_state.Stable.Latest.
            { source= transition12.pending_coinbase_stack_state.source
            ; target= transition23.pending_coinbase_stack_state.target }
        ~fee_excess ~supply_increase
    in
    let prover_state =
      let ledger_to_bits = Frozen_ledger_hash.to_bits in
      let coinbase_to_bits = Pending_coinbase.Stack.to_bits in
      { Merge.Prover_state.sok_digest
      ; ledger_hash1= ledger_to_bits ledger_hash1
      ; ledger_hash2= ledger_to_bits ledger_hash2
      ; ledger_hash3= ledger_to_bits ledger_hash3
      ; pending_coinbase_stack1=
          coinbase_to_bits transition12.pending_coinbase_stack_state.source
      ; pending_coinbase_stack2=
          coinbase_to_bits transition12.pending_coinbase_stack_state.target
      ; pending_coinbase_stack3=
          coinbase_to_bits transition23.pending_coinbase_stack_state.target
      ; transition12
      ; transition23
      ; tock_vk= keys.verification.wrap }
    in
    ( top_hash
    , Tick.prove keys.proving.merge (tick_input ()) prover_state Merge.main
        top_hash )

  let of_transaction_union ?preeval sok_digest source target
      ~pending_coinbase_stack_state transaction handler =
    let top_hash, proof =
      Base.transaction_union_proof ?preeval sok_digest
        ~proving_key:keys.proving.base source target
        pending_coinbase_stack_state transaction handler
    in
    { source
    ; sok_digest
    ; target
    ; proof_type= `Base
    ; fee_excess= Transaction_union.excess transaction
    ; pending_coinbase_stack_state
    ; supply_increase= Transaction_union.supply_increase transaction
    ; proof= wrap `Base proof top_hash }

  let of_transaction ?preeval ~sok_digest ~source ~target
      ~pending_coinbase_stack_state transition handler =
    of_transaction_union ?preeval sok_digest source target
      ~pending_coinbase_stack_state
      (Transaction_union.of_transaction transition)
      handler

  let of_user_command ~sok_digest ~source ~target ~pending_coinbase_stack
      user_command handler =
    of_transaction ~sok_digest ~source ~target
      ~pending_coinbase_stack_state:
        Pending_coinbase_stack_state.Stable.Latest.
          {source= pending_coinbase_stack; target= pending_coinbase_stack}
      (User_command user_command) handler

  let of_fee_transfer ~sok_digest ~source ~target ~pending_coinbase_stack
      transfer handler =
    of_transaction ~sok_digest ~source ~target
      ~pending_coinbase_stack_state:
        Pending_coinbase_stack_state.Stable.Latest.
          {source= pending_coinbase_stack; target= pending_coinbase_stack}
      (Fee_transfer transfer) handler

  let merge t1 t2 ~sok_digest =
    if not (Frozen_ledger_hash.( = ) t1.target t2.source) then
      failwithf
        !"Transaction_snark.merge: t1.target <> t2.source \
          (%{sexp:Frozen_ledger_hash.t} vs %{sexp:Frozen_ledger_hash.t})"
        t1.target t2.source () ;
    let input, proof =
      merge_proof sok_digest t1.source t1.target t2.target
        { Transition_data.proof= (t1.proof_type, t1.proof)
        ; fee_excess= t1.fee_excess
        ; supply_increase= t1.supply_increase
        ; sok_digest= t1.sok_digest
        ; pending_coinbase_stack_state= t1.pending_coinbase_stack_state }
        { Transition_data.proof= (t2.proof_type, t2.proof)
        ; fee_excess= t2.fee_excess
        ; supply_increase= t2.supply_increase
        ; sok_digest= t2.sok_digest
        ; pending_coinbase_stack_state= t2.pending_coinbase_stack_state }
    in
    let open Or_error.Let_syntax in
    let%map fee_excess =
      Amount.Signed.add t1.fee_excess t2.fee_excess
      |> Option.value_map ~f:Or_error.return
           ~default:
             (Or_error.errorf "Transaction_snark.merge: Amount overflow")
    and supply_increase =
      Amount.add t1.supply_increase t2.supply_increase
      |> Option.value_map ~f:Or_error.return
           ~default:
             (Or_error.errorf
                "Transaction_snark.merge: Supply change amount overflow")
    in
    { source= t1.source
    ; target= t2.target
    ; sok_digest
    ; fee_excess
    ; supply_increase
    ; pending_coinbase_stack_state=
        { source= t1.pending_coinbase_stack_state.source
        ; target= t2.pending_coinbase_stack_state.target }
    ; proof_type= `Merge
    ; proof= wrap `Merge proof input }
end

module Keys = struct
  module Storage = Storage.List.Make (Storage.Disk)

  module Per_snark_location = struct
    module T = struct
      type t =
        { base: Storage.location
        ; merge: Storage.location
        ; wrap: Storage.location }
      [@@deriving sexp]
    end

    include T
    include Sexpable.To_stringable (T)
  end

  let checksum ~prefix ~base ~merge ~wrap =
    Md5.digest_string
      ( "Transaction_snark_" ^ prefix ^ Md5.to_hex base ^ Md5.to_hex merge
      ^ Md5.to_hex wrap )

  module Verification = struct
    include Keys0.Verification
    module Location = Per_snark_location

    let checksum ~base ~merge ~wrap =
      checksum ~prefix:"verification" ~base ~merge ~wrap

    let load ({merge; base; wrap} : Location.t) =
      let open Storage in
      let logger = Logger.create () in
      let tick_controller =
        Controller.create ~logger (module Tick.Verification_key)
      in
      let tock_controller =
        Controller.create ~logger (module Tock.Verification_key)
      in
      let open Async in
      let load c p =
        match%map load_with_checksum c p with
        | Ok x ->
            x
        | Error _e ->
            failwithf
              !"Transaction_snark: load failed on %{sexp:Storage.location}"
              p ()
      in
      let%map base = load tick_controller base
      and merge = load tick_controller merge
      and wrap = load tock_controller wrap in
      let t = {base= base.data; merge= merge.data; wrap= wrap.data} in
      ( t
      , checksum ~base:base.checksum ~merge:merge.checksum ~wrap:wrap.checksum
      )
  end

  module Proving = struct
    include Keys0.Proving
    module Location = Per_snark_location

    let checksum ~base ~merge ~wrap =
      checksum ~prefix:"proving" ~base ~merge ~wrap

    let load ({merge; base; wrap} : Location.t) =
      let open Storage in
      let logger = Logger.create () in
      let tick_controller =
        Controller.create ~logger (module Tick.Proving_key)
      in
      let tock_controller =
        Controller.create ~logger (module Tock.Proving_key)
      in
      let open Async in
      let load c p =
        match%map load_with_checksum c p with
        | Ok x ->
            x
        | Error _e ->
            failwithf
              !"Transaction_snark: load failed on %{sexp:Storage.location}"
              p ()
      in
      let%map base = load tick_controller base
      and merge = load tick_controller merge
      and wrap = load tock_controller wrap in
      let t = {base= base.data; merge= merge.data; wrap= wrap.data} in
      ( t
      , checksum ~base:base.checksum ~merge:merge.checksum ~wrap:wrap.checksum
      )
  end

  module Location = struct
    module T = struct
      type t =
        {proving: Proving.Location.t; verification: Verification.Location.t}
      [@@deriving sexp]
    end

    include T
    include Sexpable.To_stringable (T)
  end

  include Keys0.T

  module Checksum = struct
    type t = {proving: Md5.t; verification: Md5.t}
  end

  let create () =
    let base = Base.create_keys () in
    let merge = Merge.create_keys () in
    let wrap =
      let module Wrap = Wrap (struct
        let base = Tick.Keypair.vk base

        let merge = Tick.Keypair.vk merge
      end) in
      Wrap.create_keys ()
    in
    { proving=
        { base= Tick.Keypair.pk base
        ; merge= Tick.Keypair.pk merge
        ; wrap= Tock.Keypair.pk wrap }
    ; verification=
        { base= Tick.Keypair.vk base
        ; merge= Tick.Keypair.vk merge
        ; wrap= Tock.Keypair.vk wrap } }

  let cached () =
    let paths path = Cache_dir.possible_paths (Filename.basename path) in
    let open Async in
    let%bind base_vk, base_pk = Cached.run Base.cached in
    let%bind merge_vk, merge_pk = Cached.run Merge.cached in
    let%map wrap_vk, wrap_pk =
      let module Wrap = Wrap (struct
        let base = base_vk.value

        let merge = merge_vk.value
      end) in
      Cached.run Wrap.cached
    in
    let t : Verification.t =
      {base= base_vk.value; merge= merge_vk.value; wrap= wrap_vk.value}
    in
    let location : Location.t =
      { proving=
          { base= paths base_pk.path
          ; merge= paths merge_pk.path
          ; wrap= paths wrap_pk.path }
      ; verification=
          { base= paths base_vk.path
          ; merge= paths merge_vk.path
          ; wrap= paths wrap_vk.path } }
    in
    let checksum =
      { Checksum.proving=
          Proving.checksum ~base:base_pk.checksum ~merge:merge_pk.checksum
            ~wrap:wrap_pk.checksum
      ; verification=
          Verification.checksum ~base:base_vk.checksum ~merge:merge_vk.checksum
            ~wrap:wrap_vk.checksum }
    in
    (location, t, checksum)
end

let%test_module "transaction_snark" =
  ( module struct
    (* For tests let's just monkey patch ledger and sparse ledger to freeze their
     * ledger_hashes. The nominal type is just so we don't mix this up in our
     * real code. *)
    module Ledger = struct
      include Ledger

      let merkle_root t = Frozen_ledger_hash.of_ledger_hash @@ merkle_root t

      let merkle_root_after_user_command_exn t txn =
        Frozen_ledger_hash.of_ledger_hash
        @@ merkle_root_after_user_command_exn t txn
    end

    module Sparse_ledger = struct
      include Sparse_ledger

      let merkle_root t = Frozen_ledger_hash.of_ledger_hash @@ merkle_root t
    end

    type wallet = {private_key: Private_key.t; account: Account.t}

    let random_wallets () =
      let random_wallet () : wallet =
        let private_key = Private_key.create () in
        { private_key
        ; account=
            Account.create
              (Public_key.compress (Public_key.of_private_key_exn private_key))
              (Balance.of_int (50 + Random.int 100)) }
      in
      let n = min (Int.pow 2 ledger_depth) (1 lsl 10) in
      Array.init n ~f:(fun _ -> random_wallet ())

    let user_command wallets i j amt fee nonce memo =
      let sender = wallets.(i) in
      let receiver = wallets.(j) in
      let payload : User_command.Payload.t =
        User_command.Payload.create ~fee ~nonce ~memo
          ~body:
            (Payment
               { receiver= receiver.account.public_key
               ; amount= Amount.of_int amt })
      in
      let signature = Schnorr.sign sender.private_key payload in
      User_command.check
        User_command.Poly.Stable.Latest.
          { payload
          ; sender= Public_key.of_private_key_exn sender.private_key
          ; signature }
      |> Option.value_exn

    let keys = Keys.create ()

    include Make (struct
      let keys = keys
    end)

    let of_user_command' sok_digest ledger user_command pending_coinbase_stack
        handler =
      let source = Ledger.merkle_root ledger in
      let target =
        Ledger.merkle_root_after_user_command_exn ledger user_command
      in
      of_user_command ~sok_digest ~source ~target ~pending_coinbase_stack
        user_command handler

    (*
                ~proposer:
                  { x=
                      Snark_params.Tick.Field.of_string
                        "39876046544032071884326965137489542106804584544160987424424979200505499184903744868114140"
                  ; is_odd= true }
                ~fee_transfer:
                  (Some
                     ( { x=
                           Snark_params.Tick.Field.of_string
                             "221715137372156378645114069225806158618712943627692160064142985953895666487801880947288786"
                       ; is_odd= true }
       *)
    let%test_unit "coinbase" =
      Test_util.with_randomness 123456789 (fun () ->
          let mk_pubkey () =
            Public_key.(compress (of_private_key_exn (Private_key.create ())))
          in
          let proposer = mk_pubkey () in
          let other = mk_pubkey () in
          let pending_coinbase_init = Pending_coinbase.Stack.empty in
          let cb =
            Coinbase.create
              ~amount:(Currency.Amount.of_int 10)
              ~proposer
              ~fee_transfer:(Some (other, Currency.Fee.of_int 1))
            |> Or_error.ok_exn
          in
          let transaction = Transaction.Coinbase cb in
          Ledger.with_ledger ~f:(fun ledger ->
              Ledger.create_new_account_exn ledger proposer
                (Account.create proposer Balance.zero) ;
              let sparse_ledger =
                Sparse_ledger.of_ledger_subset_exn ledger [proposer; other]
              in
              check_transaction transaction
                (unstage (Sparse_ledger.handler sparse_ledger))
                ~sok_message:
                  (Coda_base.Sok_message.create ~fee:Currency.Fee.zero
                     ~prover:Public_key.Compressed.empty)
                ~source:(Sparse_ledger.merkle_root sparse_ledger)
                ~target:
                  Sparse_ledger.(
                    merkle_root
                      (apply_transaction_exn sparse_ledger transaction))
                ~pending_coinbase_stack_state:
                  { source= pending_coinbase_init
                  ; target=
                      Pending_coinbase.Stack.push pending_coinbase_init cb } )
      )

    let%test_unit "new_account" =
      Test_util.with_randomness 123456789 (fun () ->
          let wallets = random_wallets () in
          Ledger.with_ledger ~f:(fun ledger ->
              Array.iter
                (Array.sub wallets ~pos:1 ~len:(Array.length wallets - 1))
                ~f:(fun {account; private_key= _} ->
                  Ledger.create_new_account_exn ledger account.public_key
                    account ) ;
              let t1 =
                user_command wallets 1 0 8
                  (Fee.of_int (Random.int 20))
                  Account.Nonce.zero
                  (User_command_memo.create_by_digesting_string_exn
                     (Test_util.arbitrary_string
                        ~len:User_command_memo.max_digestible_string_length))
              in
              let target =
                Ledger.merkle_root_after_user_command_exn ledger t1
              in
              let mentioned_keys =
                User_command.accounts_accessed (t1 :> User_command.t)
              in
              let sparse_ledger =
                Sparse_ledger.of_ledger_subset_exn ledger mentioned_keys
              in
              let sok_message =
                Sok_message.create ~fee:Fee.zero
                  ~prover:wallets.(1).account.public_key
              in
              let pending_coinbase_stack = Pending_coinbase.Stack.empty in
              check_user_command ~sok_message
                ~source:(Ledger.merkle_root ledger)
                ~target pending_coinbase_stack t1
                (unstage @@ Sparse_ledger.handler sparse_ledger) ) )

    let%test "base_and_merge" =
      Test_util.with_randomness 123456789 (fun () ->
          let wallets = random_wallets () in
          Ledger.with_ledger ~f:(fun ledger ->
              Array.iter wallets ~f:(fun {account; private_key= _} ->
                  Ledger.create_new_account_exn ledger account.public_key
                    account ) ;
              let t1 =
                user_command wallets 0 1 8
                  (Fee.of_int (Random.int 20))
                  Account.Nonce.zero
                  (User_command_memo.create_by_digesting_string_exn
                     (Test_util.arbitrary_string
                        ~len:User_command_memo.max_digestible_string_length))
              in
              let t2 =
                user_command wallets 1 2 3
                  (Fee.of_int (Random.int 20))
                  Account.Nonce.zero
                  (User_command_memo.create_by_digesting_string_exn
                     (Test_util.arbitrary_string
                        ~len:User_command_memo.max_digestible_string_length))
              in
              let pending_coinbase_stack_state =
                Pending_coinbase_stack_state.Stable.Latest.
                  { source= Pending_coinbase.Stack.empty
                  ; target= Pending_coinbase.Stack.empty }
              in
              let sok_digest =
                Sok_message.create ~fee:Fee.zero
                  ~prover:wallets.(0).account.public_key
                |> Sok_message.digest
              in
              let state1 = Ledger.merkle_root ledger in
              let sparse_ledger =
                Sparse_ledger.of_ledger_subset_exn ledger
                  (List.concat_map
                     ~f:(fun t ->
                       User_command.accounts_accessed (t :> User_command.t) )
                     [t1; t2])
              in
              let proof12 =
                of_user_command' sok_digest ledger t1
                  Pending_coinbase.Stack.empty
                  (unstage @@ Sparse_ledger.handler sparse_ledger)
              in
              let sparse_ledger =
                Sparse_ledger.apply_user_command_exn sparse_ledger
                  (t1 :> User_command.t)
              in
              Ledger.apply_user_command ledger t1 |> Or_error.ok_exn |> ignore ;
              [%test_eq: Frozen_ledger_hash.t]
                (Ledger.merkle_root ledger)
                (Sparse_ledger.merkle_root sparse_ledger) ;
              let proof23 =
                of_user_command' sok_digest ledger t2
                  Pending_coinbase.Stack.empty
                  (unstage @@ Sparse_ledger.handler sparse_ledger)
              in
              let sparse_ledger =
                Sparse_ledger.apply_user_command_exn sparse_ledger
                  (t2 :> User_command.t)
              in
              Ledger.apply_user_command ledger t2 |> Or_error.ok_exn |> ignore ;
              [%test_eq: Frozen_ledger_hash.t]
                (Ledger.merkle_root ledger)
                (Sparse_ledger.merkle_root sparse_ledger) ;
              let total_fees =
                let open Amount in
                let magnitude =
                  of_fee
                    (User_command_payload.fee (t1 :> User_command.t).payload)
                  + of_fee
                      (User_command_payload.fee (t2 :> User_command.t).payload)
                  |> Option.value_exn
                in
                Signed.create ~magnitude ~sgn:Sgn.Pos
              in
              let state3 = Sparse_ledger.merkle_root sparse_ledger in
              let proof13 =
                merge ~sok_digest proof12 proof23 |> Or_error.ok_exn
              in
              Tock.verify proof13.proof keys.verification.wrap wrap_input
                (Wrap_input.of_tick_field
                   (merge_top_hash ~sok_digest ~state1 ~state2:state3
                      ~supply_increase:Amount.zero ~fee_excess:total_fees
                      ~pending_coinbase_stack_state wrap_vk_bits)) ) )
  end )

let constraint_system_digests () =
  let module W = Wrap (struct
    let merge = Verification_keys.dummy.merge

    let base = Verification_keys.dummy.base
  end) in
  let digest = Tick.R1CS_constraint_system.digest in
  let digest' = Tock.R1CS_constraint_system.digest in
  [ ( "transaction-merge"
    , digest Merge.(Tick.constraint_system ~exposing:(input ()) main) )
  ; ( "transaction-base"
    , digest Base.(Tick.constraint_system ~exposing:(tick_input ()) main) )
  ; ( "transaction-wrap"
    , digest' W.(Tock.constraint_system ~exposing:wrap_input main) ) ]
