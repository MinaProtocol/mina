[%%import
"../../config.mlh"]

[%%if
consensus_mechanism = "proof_of_stake"]

let name = "proof_of_stake"

open Core_kernel
open Signed
open Unsigned
open Coda_numbers
open Currency
open Fold_lib
open Signature_lib
open Module_version
module Time = Coda_base.Block_time

module Segment_id = Nat.Make32 ()

module Typ = Crypto_params.Tick0.Typ

module Epoch_seed = struct
  include Coda_base.Data_hash.Make_full_size ()

  let initial : t = of_hash Snark_params.Tick.Pedersen.zero_hash

  let fold_vrf_result seed vrf_result =
    Fold.(fold seed +> Random_oracle.Digest.fold vrf_result)

  let update seed vrf_result =
    let open Snark_params.Tick in
    of_hash
      (Pedersen.digest_fold Coda_base.Hash_prefix.epoch_seed
         (fold_vrf_result seed vrf_result))

  let update_var (seed : var) (vrf_result : Random_oracle.Digest.Checked.t) :
      (var, _) Snark_params.Tick.Checked.t =
    let open Snark_params.Tick in
    let%bind seed_triples = var_to_triples seed in
    let%map hash =
      Pedersen.Checked.digest_triples ~init:Coda_base.Hash_prefix.epoch_seed
        (seed_triples @ Random_oracle.Digest.Checked.to_triples vrf_result)
    in
    var_of_hash_packed hash
end

let uint32_of_int64 x = x |> Int64.to_int64 |> UInt32.of_int64

let int64_of_uint32 x = x |> UInt32.to_int64 |> Int64.of_int64

module Constants = struct
  include Constants

  module Slot = struct
    let duration = Constants.block_window_duration

    let duration_ms = Int64.of_int block_window_duration_ms
  end

  module Epoch = struct
    (** Number of slots =24k in ouroboros praos *)
    let size = UInt32.of_int (3 * c * k)

    (** Amount of time in total for an epoch *)
    let duration =
      Time.Span.of_ms Int64.Infix.(Slot.duration_ms * int64_of_uint32 size)
  end

  module Checkpoint_window = struct
    let per_year = 12

    let slots_per_year =
      let one_year_ms =
        Core.Time.Span.(to_ms (of_day 365.)) |> Float.to_int |> Int.to_int64
      in
      Int64.Infix.(one_year_ms / Slot.duration_ms) |> Int64.to_int

    let size_in_slots =
      assert (slots_per_year mod per_year = 0) ;
      slots_per_year / per_year

    (* Number of bits required to represent a number
   < size_in_slots *)
    let per_window_index_size_in_bits = Core.Int.ceil_log2 size_in_slots
  end

  (** The duration of delta *)
  let delta_duration =
    Time.Span.of_ms (Int64.of_int (Int64.to_int Slot.duration_ms * delta))
end

module Proposal_data = struct
  (* TODO : version *)
  type t =
    { stake_proof: Coda_base.Stake_proof.t
    ; vrf_result: Random_oracle.Digest.Stable.V1.t }
  [@@deriving bin_io]

  let prover_state {stake_proof; _} = stake_proof
end

let genesis_ledger_total_currency =
  Coda_base.Ledger.to_list Genesis_ledger.t
  |> List.fold_left ~init:Balance.zero ~f:(fun sum account ->
         Balance.add_amount sum
           (Balance.to_amount @@ Coda_base.Account.balance account)
         |> Option.value_exn ?here:None ?error:None
              ~message:"failed to calculate total currency in genesis ledger"
     )
  |> Balance.to_amount

let genesis_ledger_hash =
  Coda_base.Ledger.merkle_root Genesis_ledger.t
  |> Coda_base.Frozen_ledger_hash.of_ledger_hash

let compute_delegators self_pk ~iter_accounts =
  let open Coda_base in
  let t = Account.Index.Table.create () in
  let matches_pubkey pubkey =
    match self_pk with
    | `Include_self, pk -> Public_key.Compressed.equal pk pubkey
    | `Don't_include_self, _ -> false
  in
  iter_accounts (fun i (acct : Account.t) ->
      (* TODO: The second disjunct is a hack and should be removed once the delegation
             command PR lands. *)
      if
        Public_key.Compressed.equal (snd self_pk) acct.delegate
        || matches_pubkey acct.public_key
      then Hashtbl.add t ~key:i ~data:acct.balance |> ignore
      else () ) ;
  t

module Epoch = struct
  include Segment_id

  let of_time_exn t : t =
    if Time.(t < Constants.genesis_state_timestamp) then
      raise
        (Invalid_argument
           "Epoch.of_time: time is earlier than genesis block timestamp") ;
    let time_since_genesis = Time.diff t Constants.genesis_state_timestamp in
    uint32_of_int64
      Int64.Infix.(
        Time.Span.to_ms time_since_genesis
        / Time.Span.to_ms Constants.Epoch.duration)

  let start_time (epoch : t) =
    let ms =
      let open Int64.Infix in
      Time.Span.to_ms
        (Time.to_span_since_epoch Constants.genesis_state_timestamp)
      + (int64_of_uint32 epoch * Time.Span.to_ms Constants.Epoch.duration)
    in
    Time.of_span_since_epoch (Time.Span.of_ms ms)

  let end_time (epoch : t) =
    Time.add (start_time epoch) Constants.Epoch.duration

  module Slot = struct
    include Segment_id

    let after_lock_checkpoint (slot : t) =
      let ck = Constants.(c * k |> UInt32.of_int) in
      let open UInt32.Infix in
      ck * UInt32.of_int 2 < slot

    let in_seed_update_range (slot : t) =
      let ck = Constants.(c * k |> UInt32.of_int) in
      let open UInt32.Infix in
      ck <= slot && slot < ck * UInt32.of_int 2

    let in_seed_update_range_var (slot : Unpacked.var) =
      let open Snark_params.Tick in
      let open Snark_params.Tick.Let_syntax in
      let uint32_msb x =
        List.init 32 ~f:(fun i ->
            UInt32.Infix.((x lsr Int.sub 31 i) land UInt32.one = UInt32.one) )
        |> Bitstring_lib.Bitstring.Msb_first.of_list
      in
      let ( < ) = Bitstring_checked.lt_value in
      let ck = Constants.(c * k) |> UInt32.of_int in
      let ck_bitstring = uint32_msb ck
      and ck_times_2 = uint32_msb UInt32.(Infix.(of_int 2 * ck)) in
      let slot_msb =
        Bitstring_lib.Bitstring.Msb_first.of_lsb_first
          (Unpacked.var_to_bits slot)
      in
      let%bind slot_gte_ck = slot_msb < ck_bitstring >>| Boolean.not
      and slot_lt_ck_times_2 = slot_msb < ck_times_2 in
      Boolean.(slot_gte_ck && slot_lt_ck_times_2)

    let gen =
      let open Quickcheck.Let_syntax in
      Core.Int.gen_incl 0 (Constants.(c * k) * 3) >>| UInt32.of_int

    let%test_unit "in_seed_update_range unchecked vs. checked equality" =
      let test =
        Test_util.test_equal Unpacked.typ Snark_params.Tick.Boolean.typ
          in_seed_update_range_var in_seed_update_range
      in
      let x = Constants.(c * k) in
      let examples =
        List.map ~f:UInt32.of_int
          [x; x - 1; x + 1; x * 2; (x * 2) - 1; (x * 2) + 1]
      in
      Quickcheck.test ~trials:100 ~examples gen ~f:test
  end

  let slot_start_time (epoch : t) (slot : Slot.t) =
    Time.add (start_time epoch)
      (Time.Span.of_ms
         Int64.Infix.(int64_of_uint32 slot * Constants.Slot.duration_ms))

  let slot_end_time (epoch : t) (slot : Slot.t) =
    Time.add (slot_start_time epoch slot) Constants.Slot.duration

  let epoch_and_slot_of_time_exn tm : t * Slot.t =
    let epoch = of_time_exn tm in
    let time_since_epoch = Time.diff tm (start_time epoch) in
    let slot =
      uint32_of_int64
      @@ Int64.Infix.(
           Time.Span.to_ms time_since_epoch / Constants.Slot.duration_ms)
    in
    (epoch, slot)
end

module Local_state = struct
  module Snapshot = struct
    type t =
      { ledger: Coda_base.Sparse_ledger.t
      ; delegators: Currency.Balance.t Coda_base.Account.Index.Table.t }
    [@@deriving sexp]

    let create_empty () =
      { ledger= Coda_base.Sparse_ledger.of_root Coda_base.Ledger_hash.empty_hash
      ; delegators= Coda_base.Account.Index.Table.create () }
  end

  type t =
    { mutable last_epoch_snapshot: Snapshot.t option
    ; mutable curr_epoch_snapshot: Snapshot.t option
    ; mutable last_checked_slot_and_epoch: Epoch.t * Epoch.Slot.t
    ; genesis_epoch_snapshot: Snapshot.t
    ; proposer_public_key: Public_key.Compressed.t option }
  [@@deriving sexp]

  let create proposer_public_key =
    (* TODO: remove duplicated genesis ledger *)
    let genesis_epoch_snapshot =
      match proposer_public_key with
      | None -> Snapshot.create_empty ()
      | Some key ->
          let open Snapshot in
          let delegators =
            compute_delegators
              (* TODO: Propagate Include_self to the right place *)
              (`Include_self, key)
              ~iter_accounts:(fun f ->
                let open Coda_base in
                Ledger.foldi ~init:() Genesis_ledger.t ~f:(fun i () acct ->
                    f (Ledger.Addr.to_int i) acct ) )
          in
          let ledger =
            Coda_base.Sparse_ledger.of_ledger_index_subset_exn
              (Coda_base.Ledger.Any_ledger.cast
                 (module Coda_base.Ledger)
                 Genesis_ledger.t)
              (Coda_base.Account.Index.Table.keys delegators)
          in
          {delegators; ledger}
    in
    { last_epoch_snapshot= None
    ; curr_epoch_snapshot= None
    ; genesis_epoch_snapshot
    ; last_checked_slot_and_epoch= (Epoch.zero, Epoch.Slot.zero)
    ; proposer_public_key }

  let seen_slot t epoch slot =
    match
      Tuple2.compare ~cmp1:Epoch.compare ~cmp2:Epoch.Slot.compare
        t.last_checked_slot_and_epoch (epoch, slot)
    with
    | i when i >= 0 -> `Seen
    | i when i < 0 ->
        t.last_checked_slot_and_epoch <- (epoch, slot) ;
        `Unseen
    | _ -> failwith "forall x : int. x >= 0 || x < 0 is impossibly false"
end

module Epoch_ledger = struct
  type ('ledger_hash, 'amount) t = {hash: 'ledger_hash; total_currency: 'amount}
  [@@deriving sexp, bin_io, eq, compare, hash, to_yojson]

  (* TODO : version *)
  type value = (Coda_base.Frozen_ledger_hash.Stable.V1.t, Amount.Stable.V1.t) t
  [@@deriving sexp, bin_io, eq, compare, hash, to_yojson]

  type var = (Coda_base.Frozen_ledger_hash.var, Amount.var) t

  let to_hlist {hash; total_currency} = Coda_base.H_list.[hash; total_currency]

  let of_hlist :
         (unit, 'ledger_hash -> 'total_currency -> unit) Coda_base.H_list.t
      -> ('ledger_hash, 'total_currency) t =
   fun Coda_base.H_list.([hash; total_currency]) -> {hash; total_currency}

  let data_spec =
    Snark_params.Tick.Data_spec.[Coda_base.Frozen_ledger_hash.typ; Amount.typ]

  let typ : (var, value) Typ.t =
    Snark_params.Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
      ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let var_to_triples {hash; total_currency} =
    let open Snark_params.Tick.Checked.Let_syntax in
    let%map hash_triples = Coda_base.Frozen_ledger_hash.var_to_triples hash in
    hash_triples @ Amount.var_to_triples total_currency

  let fold {hash; total_currency} =
    let open Fold in
    Coda_base.Frozen_ledger_hash.fold hash +> Amount.fold total_currency

  let length_in_triples =
    Coda_base.Frozen_ledger_hash.length_in_triples + Amount.length_in_triples

  let if_ cond ~then_ ~else_ =
    let open Snark_params.Tick.Checked.Let_syntax in
    let%map hash =
      Coda_base.Frozen_ledger_hash.if_ cond ~then_:then_.hash ~else_:else_.hash
    and total_currency =
      Amount.Checked.if_ cond ~then_:then_.total_currency
        ~else_:else_.total_currency
    in
    {hash; total_currency}

  let genesis =
    {hash= genesis_ledger_hash; total_currency= genesis_ledger_total_currency}
end

module Vrf = struct
  module Scalar = struct
    type value = Snark_params.Tick.Inner_curve.Scalar.t

    type var = Snark_params.Tick.Inner_curve.Scalar.var

    let typ : (var, value) Typ.t = Snark_params.Tick.Inner_curve.Scalar.typ
  end

  module Group = struct
    open Snark_params.Tick

    type value = Inner_curve.t

    type var = Inner_curve.var

    let scale = Inner_curve.scale

    module Checked = struct
      include Inner_curve.Checked

      let scale_generator shifted s ~init =
        scale_known shifted Inner_curve.one s ~init
    end
  end

  module Message = struct
    type ('epoch, 'slot, 'epoch_seed, 'delegator) t =
      {epoch: 'epoch; slot: 'slot; seed: 'epoch_seed; delegator: 'delegator}

    type value =
      (Epoch.t, Epoch.Slot.t, Epoch_seed.t, Coda_base.Account.Index.t) t

    type var =
      ( Epoch.Unpacked.var
      , Epoch.Slot.Unpacked.var
      , Epoch_seed.var
      , Coda_base.Account.Index.Unpacked.var )
      t

    let to_hlist {epoch; slot; seed; delegator} =
      Coda_base.H_list.[epoch; slot; seed; delegator]

    let of_hlist :
           ( unit
           , 'epoch -> 'slot -> 'epoch_seed -> 'del -> unit )
           Coda_base.H_list.t
        -> ('epoch, 'slot, 'epoch_seed, 'del) t =
     fun Coda_base.H_list.([epoch; slot; seed; delegator]) ->
      {epoch; slot; seed; delegator}

    let data_spec =
      let open Snark_params.Tick.Data_spec in
      [ Epoch.Unpacked.typ
      ; Epoch.Slot.Unpacked.typ
      ; Epoch_seed.typ
      ; Coda_base.Account.Index.Unpacked.typ ]

    let typ : (var, value) Typ.t =
      Snark_params.Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
        ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist

    let fold {epoch; slot; seed; delegator} =
      let open Fold in
      Epoch.fold epoch +> Epoch.Slot.fold slot +> Epoch_seed.fold seed
      +> Coda_base.Account.Index.fold delegator

    let hash_to_group msg =
      let msg_hash_state =
        Snark_params.Tick.Pedersen.hash_fold Coda_base.Hash_prefix.vrf_message
          (fold msg)
      in
      msg_hash_state.acc

    module Checked = struct
      let var_to_triples {epoch; slot; seed; delegator} =
        let open Snark_params.Tick.Checked.Let_syntax in
        let%map seed_triples = Epoch_seed.var_to_triples seed in
        Epoch.Unpacked.var_to_triples epoch
        @ Epoch.Slot.Unpacked.var_to_triples slot
        @ seed_triples
        @ Coda_base.Account.Index.Unpacked.var_to_triples delegator

      let hash_to_group msg =
        let open Snark_params.Tick in
        let open Snark_params.Tick.Checked.Let_syntax in
        let%bind msg_triples = var_to_triples msg in
        Pedersen.Checked.hash_triples ~init:Coda_base.Hash_prefix.vrf_message
          msg_triples
    end

    let gen =
      let open Quickcheck.Let_syntax in
      let%map epoch = Epoch.gen
      and slot = Epoch.Slot.gen
      and seed = Epoch_seed.gen
      and delegator = Coda_base.Account.Index.gen in
      {epoch; slot; seed; delegator}
  end

  module Output = struct
    (* TODO : version *)
    type t = Random_oracle.Digest.Stable.V1.t
    [@@deriving sexp, bin_io, eq, compare, hash, yojson]

    type var = Random_oracle.Digest.Checked.t

    let typ : (var, t) Typ.t = Random_oracle.Digest.typ

    let fold = Random_oracle.Digest.fold

    let length_in_triples = Random_oracle.Digest.length_in_triples

    let gen = Random_oracle.Digest.gen

    let to_string (t : t) = (t :> string)

    type value = t [@@deriving sexp]

    let dummy = Random_oracle.digest_string ""

    let hash msg g =
      let open Fold in
      let compressed_g =
        Non_zero_curve_point.(g |> of_inner_curve_exn |> compress)
      in
      let digest =
        Snark_params.Tick.Pedersen.digest_fold Coda_base.Hash_prefix.vrf_output
          ( Message.fold msg
          +> Non_zero_curve_point.Compressed.fold compressed_g )
      in
      Random_oracle.digest_field digest

    module Checked = struct
      include Random_oracle.Digest.Checked

      let hash msg g =
        let open Snark_params.Tick.Checked.Let_syntax in
        let%bind msg_triples = Message.Checked.var_to_triples msg in
        let%bind g_triples =
          Non_zero_curve_point.(compress_var g >>= Compressed.var_to_triples)
        in
        let%bind pedersen_digest =
          Snark_params.Tick.Pedersen.Checked.digest_triples
            ~init:Coda_base.Hash_prefix.vrf_output (msg_triples @ g_triples)
        in
        Random_oracle.Checked.digest_field pedersen_digest
    end

    let%test_unit "hash unchecked vs. checked equality" =
      let gen_inner_curve_point =
        let open Quickcheck.Generator.Let_syntax in
        let%map compressed = Non_zero_curve_point.gen in
        Non_zero_curve_point.to_inner_curve compressed
      in
      let gen_message_and_curve_point =
        let open Quickcheck.Generator.Let_syntax in
        let%map msg = Message.gen and g = gen_inner_curve_point in
        (msg, g)
      in
      Quickcheck.test ~trials:10 gen_message_and_curve_point
        ~f:
          (Test_util.test_equal ~equal:Random_oracle.Digest.equal
             Snark_params.Tick.Typ.(
               Message.typ * Snark_params.Tick.Inner_curve.typ)
             Random_oracle.Digest.typ
             (fun (msg, g) -> Checked.hash msg g)
             (fun (msg, g) -> hash msg g))
  end

  module Threshold = struct
    open Bignum_bigint

    let of_uint64_exn = Fn.compose of_int64_exn UInt64.to_int64

    (* TEMPORARY HACK FOR TESTNETS: c should be 1 otherwise *)
    let c_int = 2

    let c = of_int c_int

    (*  Check if
        vrf_output / 2^256 <= c * my_stake / total_currency

        So that we don't have to do division we check

        vrf_output * total_currency <= c * my_stake * 2^256
    *)
    let is_satisfied ~my_stake ~total_stake vrf_output =
      of_bit_fold_lsb (Random_oracle.Digest.fold_bits vrf_output)
      * of_uint64_exn (Amount.to_uint64 total_stake)
      <= shift_left
           (c * of_uint64_exn (Balance.to_uint64 my_stake))
           Random_oracle.Digest.length_in_bits

    module Checked = struct
      (* This version can't be used right now because the field is too small. *)
      let _is_satisfied ~my_stake ~total_stake vrf_output =
        let open Snark_params.Tick in
        let open Let_syntax in
        let open Number in
        let%bind lhs = of_bits vrf_output * Amount.var_to_number total_stake in
        let%bind rhs =
          let%bind x =
            (* someday: This should really just be a scalar multiply... *)
            constant (Field.of_int c_int) * Amount.var_to_number my_stake
          in
          mul_pow_2 x (`Two_to_the Random_oracle.Digest.length_in_bits)
        in
        lhs <= rhs

      (* It was somewhat involved to implement that check with the small field, so
         we've stubbed it out for now. *)
      let is_satisfied ~my_stake:_ ~total_stake:_ _vrf_output =
        let () = assert Coda_base.Insecure.vrf_threshold_check in
        Snark_params.Tick.(Checked.return Boolean.true_)
    end
  end

  module T =
    Vrf_lib.Integrated.Make (Snark_params.Tick) (Scalar) (Group) (Message)
      (Output)

  type _ Snarky.Request.t +=
    | Winner_address : Coda_base.Account.Index.t Snarky.Request.t
    | Private_key : Scalar.value Snarky.Request.t

  let%snarkydef get_vrf_evaluation shifted ~ledger ~message =
    let open Coda_base in
    let open Snark_params.Tick in
    let open Let_syntax in
    let%bind private_key =
      request_witness Scalar.typ (As_prover.return Private_key)
    in
    let winner_addr = message.Message.delegator in
    let%bind account =
      with_label __LOC__ (Frozen_ledger_hash.get ledger winner_addr)
    in
    let%bind delegate =
      with_label __LOC__ (Public_key.decompress_var account.delegate)
    in
    let%map evaluation =
      with_label __LOC__
        (T.Checked.eval_and_check_public_key shifted ~private_key
           ~public_key:delegate message)
    in
    (evaluation, account.balance)

  module Checked = struct
    let%snarkydef check shifted ~(epoch_ledger : Epoch_ledger.var) ~epoch ~slot
        ~seed =
      let open Snark_params.Tick in
      let open Let_syntax in
      let%bind winner_addr =
        request_witness Coda_base.Account.Index.Unpacked.typ
          (As_prover.return Winner_address)
      in
      let%bind result, my_stake =
        get_vrf_evaluation shifted ~ledger:epoch_ledger.hash
          ~message:{Message.epoch; slot; seed; delegator= winner_addr}
      in
      let%map satisifed =
        Threshold.Checked.is_satisfied ~my_stake
          ~total_stake:epoch_ledger.total_currency result
      in
      (satisifed, result)
  end

  let eval = T.eval

  module Precomputed = struct
    let handler : Snark_params.Tick.Handler.t =
      let pk, sk = Coda_base.Sample_keypairs.keypairs.(0) in
      let dummy_sparse_ledger =
        Coda_base.Sparse_ledger.of_ledger_subset_exn Genesis_ledger.t [pk]
      in
      let ledger_handler =
        unstage (Coda_base.Sparse_ledger.handler dummy_sparse_ledger)
      in
      fun (With {request; respond} as t) ->
        match request with
        | Winner_address -> respond (Provide 0)
        | Private_key -> respond (Provide sk)
        | _ -> ledger_handler t

    let vrf_output =
      let _, sk = Coda_base.Sample_keypairs.keypairs.(0) in
      eval ~private_key:sk
        { Message.epoch= Epoch.zero
        ; slot= Epoch.Slot.zero
        ; seed= Epoch_seed.initial
        ; delegator= 0 }
  end

  let check ~epoch ~slot ~seed ~private_key ~total_stake ~logger
      ~epoch_snapshot =
    let open Message in
    let open Local_state in
    let open Snapshot in
    let open Option.Let_syntax in
    Logger.info logger ~module_:__MODULE__ ~location:__LOC__
      "Checking vrf evaluations at %d:%d" (Epoch.to_int epoch)
      (Epoch.Slot.to_int slot) ;
    let%bind epoch_snapshot = epoch_snapshot in
    with_return (fun {return} ->
        Hashtbl.iteri epoch_snapshot.delegators
          ~f:(fun ~key:delegator ~data:balance ->
            let vrf_result =
              T.eval ~private_key {epoch; slot; seed; delegator}
            in
            Logger.info logger ~module_:__MODULE__ ~location:__LOC__
              !"vrf result for %d: %d/%d -> %{sexp: Bignum_bigint.t}"
              (Coda_base.Account.Index.to_int delegator)
              (Balance.to_int balance)
              (Amount.to_int total_stake)
              (Bignum_bigint.of_bit_fold_lsb
                 (Random_oracle.Digest.fold_bits vrf_result)) ;
            if Threshold.is_satisfied ~my_stake:balance ~total_stake vrf_result
            then
              return
                (Some
                   { Proposal_data.stake_proof=
                       {private_key; delegator; ledger= epoch_snapshot.ledger}
                   ; vrf_result }) ) ;
        None )
end

module Epoch_data = struct
  type ('epoch_ledger, 'epoch_seed, 'protocol_state_hash, 'length) t =
    { ledger: 'epoch_ledger
    ; seed: 'epoch_seed
    ; start_checkpoint: 'protocol_state_hash
    ; lock_checkpoint: 'protocol_state_hash
    ; length: 'length }
  [@@deriving sexp, bin_io, eq, compare, hash, to_yojson]

  (* TODO : version *)
  type value =
    ( Epoch_ledger.value
    , Epoch_seed.Stable.V1.t
    , Coda_base.State_hash.Stable.V1.t
    , Length.Stable.V1.t )
    t
  [@@deriving sexp, bin_io, eq, compare, hash, to_yojson]

  type var =
    ( Epoch_ledger.var
    , Epoch_seed.var
    , Coda_base.State_hash.var
    , Length.Unpacked.var )
    t

  let to_hlist {ledger; seed; start_checkpoint; lock_checkpoint; length} =
    Coda_base.H_list.[ledger; seed; start_checkpoint; lock_checkpoint; length]

  let of_hlist :
         ( unit
         ,    'ledger
           -> 'seed
           -> 'protocol_state_hash
           -> 'protocol_state_hash
           -> 'length
           -> unit )
         Coda_base.H_list.t
      -> ('ledger, 'seed, 'protocol_state_hash, 'length) t =
   fun Coda_base.H_list.([ ledger
                         ; seed
                         ; start_checkpoint
                         ; lock_checkpoint
                         ; length ]) ->
    {ledger; seed; start_checkpoint; lock_checkpoint; length}

  let data_spec =
    let open Snark_params.Tick.Data_spec in
    [ Epoch_ledger.typ
    ; Epoch_seed.typ
    ; Coda_base.State_hash.typ
    ; Coda_base.State_hash.typ
    ; Length.Unpacked.typ ]

  let typ : (var, value) Typ.t =
    Snark_params.Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
      ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let var_to_triples {ledger; seed; start_checkpoint; lock_checkpoint; length}
      =
    let open Snark_params.Tick.Checked.Let_syntax in
    let%map ledger_triples = Epoch_ledger.var_to_triples ledger
    and seed_triples = Epoch_seed.var_to_triples seed
    and start_checkpoint_triples =
      Coda_base.State_hash.var_to_triples start_checkpoint
    and lock_checkpoint_triples =
      Coda_base.State_hash.var_to_triples lock_checkpoint
    in
    ledger_triples @ seed_triples @ start_checkpoint_triples
    @ lock_checkpoint_triples
    @ Length.Unpacked.var_to_triples length

  let fold {ledger; seed; start_checkpoint; lock_checkpoint; length} =
    let open Fold in
    Epoch_ledger.fold ledger +> Epoch_seed.fold seed
    +> Coda_base.State_hash.fold start_checkpoint
    +> Coda_base.State_hash.fold lock_checkpoint
    +> Length.fold length

  let length_in_triples =
    Epoch_ledger.length_in_triples + Epoch_seed.length_in_triples
    + Coda_base.State_hash.length_in_triples
    + Coda_base.State_hash.length_in_triples + Length.length_in_triples

  let if_ cond ~then_ ~else_ =
    let open Snark_params.Tick.Checked.Let_syntax in
    let%map ledger =
      Epoch_ledger.if_ cond ~then_:then_.ledger ~else_:else_.ledger
    and seed = Epoch_seed.if_ cond ~then_:then_.seed ~else_:else_.seed
    and start_checkpoint =
      Coda_base.State_hash.if_ cond ~then_:then_.start_checkpoint
        ~else_:else_.start_checkpoint
    and lock_checkpoint =
      Coda_base.State_hash.if_ cond ~then_:then_.lock_checkpoint
        ~else_:else_.lock_checkpoint
    and length = Length.if_ cond ~then_:then_.length ~else_:else_.length in
    {ledger; seed; start_checkpoint; lock_checkpoint; length}

  let genesis =
    { ledger=
        Epoch_ledger.genesis
        (* TODO: epoch_seed needs to be non-determinable by o1-labs before mainnet launch *)
    ; seed= Epoch_seed.initial
    ; start_checkpoint= Coda_base.State_hash.(of_hash zero)
    ; lock_checkpoint= Coda_base.State_hash.(of_hash zero)
    ; length= Length.of_int 1 }

  let update_pair (last_data, curr_data) epoch_length ~prev_epoch ~next_epoch
      ~prev_slot ~prev_protocol_state_hash ~proposer_vrf_result
      ~snarked_ledger_hash ~total_currency =
    let open Epoch_ledger in
    let last_data, curr_data, epoch_length =
      if next_epoch > prev_epoch then
        ( curr_data
        , { seed= Epoch_seed.initial
          ; ledger= {hash= snarked_ledger_hash; total_currency}
          ; start_checkpoint= prev_protocol_state_hash
          ; lock_checkpoint= Coda_base.State_hash.(of_hash zero)
          ; length= Length.of_int 1 }
        , Length.succ epoch_length )
      else (
        assert (Epoch.equal next_epoch prev_epoch) ;
        ( last_data
        , {curr_data with length= Length.succ curr_data.length}
        , epoch_length ) )
    in
    let curr_seed, curr_lock_checkpoint =
      if Epoch.Slot.in_seed_update_range prev_slot then
        ( Epoch_seed.update curr_data.seed proposer_vrf_result
        , prev_protocol_state_hash )
      else (curr_data.seed, curr_data.lock_checkpoint)
    in
    let curr_data =
      {curr_data with seed= curr_seed; lock_checkpoint= curr_lock_checkpoint}
    in
    (last_data, curr_data, epoch_length)
end

module Consensus_transition_data = struct
  type ('epoch, 'slot) t = {epoch: 'epoch; slot: 'slot}
  [@@deriving sexp, bin_io, compare]

  type value = (Epoch.Stable.V1.t, Epoch.Slot.Stable.V1.t) t
  [@@deriving sexp, bin_io, compare]

  type var = (Epoch.Unpacked.var, Epoch.Slot.Unpacked.var) t

  let var_of_value ({epoch; slot} : value) : var =
    (* reuse variable names because field names the same *)
    let epoch = Epoch.(unpack_value epoch |> Unpacked.var_of_value) in
    let slot = Epoch.Slot.(unpack_value slot |> Unpacked.var_of_value) in
    {epoch; slot}

  let genesis = {epoch= Epoch.zero; slot= Epoch.Slot.zero}

  let to_hlist {epoch; slot} = Coda_base.H_list.[epoch; slot]

  let of_hlist :
      (unit, 'epoch -> 'slot -> unit) Coda_base.H_list.t -> ('epoch, 'slot) t =
   fun Coda_base.H_list.([epoch; slot]) -> {epoch; slot}

  let data_spec =
    let open Snark_params.Tick.Data_spec in
    [Epoch.Unpacked.typ; Epoch.Slot.Unpacked.typ]

  let typ : (var, value) Typ.t =
    Snark_params.Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
      ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
end

module Global_slot = struct
  open Snark_params.Tick

  include Nat.Make32 ()

  (* Make sure this optimization makes sense versus using
     an (epoch, slot) pair *)
  let () =
    assert (
      Core.Int.(
        1 + length_in_triples
        (* Cost of creating/unpacking *)
        + (5 * length_in_triples)
        (* Cost of hashing *)
        < 5 * (Epoch.length_in_triples + Epoch.Slot.length_in_triples)) )

  let create ~(epoch : Epoch.t) ~(slot : Epoch.Slot.t) =
    of_int
      ( Epoch.Slot.to_int slot
      + (UInt32.to_int Constants.Epoch.size * Epoch.to_int epoch) )

  module Checked = struct
    (* TODO: It's possible to share this hash computation with
       the hashing of the state. Might be worth doing. *)
    let create ~(epoch : Epoch.Unpacked.var) ~(slot : Epoch.Slot.Unpacked.var)
        =
      var_of_field_unsafe
        Field.Var.(
          add
            (Epoch.Slot.pack_var slot :> t)
            (scale
               (Epoch.pack_var epoch :> t)
               (Field.of_int (UInt32.to_int Constants.Epoch.size))))

    let to_integer (t : Packed.var) =
      Snarky_taylor.Integer.create
        ~value:(t :> Field.Var.t)
        ~upper_bound:(Bignum_bigint.of_int (1 lsl length_in_bits))
  end
end

module Checkpoints = struct
  module Hash = Coda_base.Data_hash.Make_full_size ()

  let merge (s : Coda_base.State_hash.t) (h : Hash.t) =
    Snark_params.Tick.Pedersen.digest_fold
      Coda_base.Hash_prefix.checkpoint_list
      Fold.(Coda_base.State_hash.fold s +> Hash.fold h)
    |> Hash.of_hash

  let length = Constants.Checkpoint_window.per_year

  module Repr = struct
    module Q = struct
      module List = struct
        type 'a t = 'a list [@@deriving to_yojson]
      end

      include Fqueue

      let to_yojson f t = List.to_yojson f (to_list t)
    end

    (* TODO : version *)
    type t =
      { (* TODO: Make a nice way to force this to have bounded (or fixed) size for
         bin_io reasons *)
        prefix: Coda_base.State_hash.Stable.V1.t Q.t
      ; tail: Hash.Stable.V1.t }
    [@@deriving sexp, bin_io, compare, hash, to_yojson]

    let equal t1 t2 = compare t1 t2 = 0

    let digest {prefix; tail} =
      let rec go acc p =
        match Fqueue.dequeue p with
        | None -> acc
        | Some (h, p) -> go (merge h acc) p
      in
      go tail prefix
  end

  type t = (Repr.t, Hash.t) With_hash.t [@@deriving sexp]

  let to_repr (t : t) = t.data

  let of_repr r = {With_hash.data= r; hash= Repr.digest r}

  let compare (t1 : t) (t2 : t) = Hash.compare t1.hash t2.hash

  let equal (t1 : t) (t2 : t) = Hash.equal t1.hash t2.hash

  let hash t = Repr.hash (to_repr t)

  let hash_fold_t s t = Repr.hash_fold_t s (to_repr t)

  let to_yojson = Fn.compose Repr.to_yojson to_repr

  include Binable.Of_binable
            (Repr)
            (struct
              type nonrec t = t

              let to_binable = to_repr

              let of_binable = of_repr
            end)

  let empty : t =
    let dummy = Hash.of_hash Snark_params.Tick.Field.zero in
    {hash= dummy; data= {prefix= Fqueue.empty; tail= dummy}}

  let cons sh (t : t) : t =
    (* This kind of defeats the purpose of having a queue, but oh well. *)
    let n = Fqueue.length t.data.prefix in
    let hash = merge sh t.hash in
    let {Repr.prefix; tail} = t.data in
    if n < length then {hash; data= {prefix= Fqueue.enqueue prefix sh; tail}}
    else
      let sh0, prefix = Fqueue.dequeue_exn prefix in
      {hash; data= {prefix= Fqueue.enqueue prefix sh; tail= merge sh0 tail}}

  let fold (t : t) = Hash.fold t.hash

  let length_in_triples = Hash.length_in_triples

  type var = Hash.var

  let typ =
    Typ.transport Hash.typ
      ~there:(fun (t : t) -> t.hash)
      ~back:(fun hash -> {hash; data= {prefix= Fqueue.empty; tail= hash}})

  module Checked = struct
    let if_ = Hash.if_

    let cons sh t =
      let open Snark_params.Tick in
      let open Checked in
      let%bind sh = Coda_base.State_hash.var_to_triples sh
      and t = Hash.var_to_triples t in
      Pedersen.Checked.digest_triples
        ~init:Coda_base.Hash_prefix.checkpoint_list (sh @ t)
      >>| Hash.var_of_hash_packed
  end
end

(* We have a list of state hashes. When we extend the blockchain,
   we see if the **previous** state should be saved as a checkpoint.
   This is because we have convenient access to the entire previous
   protocol state hash.

   We divide the slots of an epoch into "checkpoint windows": chunks of
   size [checkpoint_window_size]. The goal is to record the first block
   in a given window as a check-point if there are any blocks in that
   window, and zero checkpoints if the window was empty.

   To that end, we store in each state a bit [checkpoint_window_filled] which
   is true iff there has already been a state in the history of the given state
   which is in the same checkpoint window as the given state.
*)
module Consensus_state = struct
  type ( 'length
       , 'vrf_output
       , 'amount
       , 'epoch
       , 'slot
       , 'epoch_data
       , 'bool
       , 'checkpoints ) t_ =
    { length: 'length
    ; epoch_length: 'length
    ; last_vrf_output: 'vrf_output
    ; total_currency: 'amount
    ; curr_epoch: 'epoch
    ; curr_slot: 'slot
    ; last_epoch_data: 'epoch_data
    ; curr_epoch_data: 'epoch_data
    ; has_ancestor_in_same_checkpoint_window: 'bool
    ; checkpoints: 'checkpoints }
  [@@deriving sexp, bin_io, eq, compare, hash, to_yojson]

  module Value = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          let version = 1

          (* TODO : version components *)
          type t =
            ( Length.Stable.V1.t
            , Vrf.Output.t
            , Amount.Stable.V1.t
            , Epoch.Stable.V1.t
            , Epoch.Slot.Stable.V1.t
            , Epoch_data.value
            , bool
            , Checkpoints.t )
            t_
          [@@deriving sexp, bin_io, eq, compare, hash, to_yojson]
        end

        include T
        include Registration.Make_latest_version (T)
      end

      module Latest = V1

      module Module_decl = struct
        let name = "consensus_proof_of_stake"

        type latest = Latest.t
      end

      module Registrar = Registration.Make (Module_decl)
      module Registered_V1 = Registrar.Register (V1)
    end

    type t = Stable.Latest.t (* bin_io omitted intentionally *)
    [@@deriving sexp, eq, compare, hash, to_yojson]
  end

  open Snark_params.Tick

  type var =
    ( Length.Unpacked.var
    , Vrf.Output.var
    , Amount.var
    , Epoch.Unpacked.var
    , Epoch.Slot.Unpacked.var
    , Epoch_data.var
    , Boolean.var
    , Checkpoints.var )
    t_

  let to_hlist
      { length
      ; epoch_length
      ; last_vrf_output
      ; total_currency
      ; curr_epoch
      ; curr_slot
      ; last_epoch_data
      ; curr_epoch_data
      ; has_ancestor_in_same_checkpoint_window
      ; checkpoints } =
    let open Coda_base.H_list in
    [ length
    ; epoch_length
    ; last_vrf_output
    ; total_currency
    ; curr_epoch
    ; curr_slot
    ; last_epoch_data
    ; curr_epoch_data
    ; has_ancestor_in_same_checkpoint_window
    ; checkpoints ]

  let of_hlist :
         ( unit
         ,    'length
           -> 'length
           -> 'vrf_output
           -> 'amount
           -> 'epoch
           -> 'slot
           -> 'epoch_data
           -> 'epoch_data
           -> 'bool
           -> 'checkpoints
           -> unit )
         Coda_base.H_list.t
      -> ( 'length
         , 'vrf_output
         , 'amount
         , 'epoch
         , 'slot
         , 'epoch_data
         , 'bool
         , 'checkpoints )
         t_ =
   fun Coda_base.H_list.([ length
                         ; epoch_length
                         ; last_vrf_output
                         ; total_currency
                         ; curr_epoch
                         ; curr_slot
                         ; last_epoch_data
                         ; curr_epoch_data
                         ; has_ancestor_in_same_checkpoint_window
                         ; checkpoints ]) ->
    { length
    ; epoch_length
    ; last_vrf_output
    ; total_currency
    ; curr_epoch
    ; curr_slot
    ; last_epoch_data
    ; curr_epoch_data
    ; has_ancestor_in_same_checkpoint_window
    ; checkpoints }

  let data_spec =
    let open Snark_params.Tick.Data_spec in
    [ Length.Unpacked.typ
    ; Length.Unpacked.typ
    ; Vrf.Output.typ
    ; Amount.typ
    ; Epoch.Unpacked.typ
    ; Epoch.Slot.Unpacked.typ
    ; Epoch_data.typ
    ; Epoch_data.typ
    ; Boolean.typ
    ; Checkpoints.typ ]

  let typ : (var, Value.t) Typ.t =
    Snark_params.Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
      ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let var_to_triples
      { length
      ; epoch_length
      ; last_vrf_output
      ; total_currency
      ; curr_epoch
      ; curr_slot
      ; last_epoch_data
      ; curr_epoch_data } =
    let open Snark_params.Tick.Checked.Let_syntax in
    let%map last_epoch_data_triples = Epoch_data.var_to_triples last_epoch_data
    and curr_epoch_data_triples = Epoch_data.var_to_triples curr_epoch_data in
    Length.Unpacked.var_to_triples length
    @ Length.Unpacked.var_to_triples epoch_length
    @ Vrf.Output.Checked.to_triples last_vrf_output
    @ Epoch.Unpacked.var_to_triples curr_epoch
    @ Epoch.Slot.Unpacked.var_to_triples curr_slot
    @ Amount.var_to_triples total_currency
    @ last_epoch_data_triples @ curr_epoch_data_triples

  let fold
      { length
      ; epoch_length
      ; last_vrf_output
      ; curr_epoch
      ; curr_slot
      ; total_currency
      ; last_epoch_data
      ; curr_epoch_data } =
    let open Fold in
    Length.fold length +> Length.fold epoch_length
    +> Vrf.Output.fold last_vrf_output
    +> Epoch.fold curr_epoch +> Epoch.Slot.fold curr_slot
    +> Amount.fold total_currency
    +> Epoch_data.fold last_epoch_data
    +> Epoch_data.fold curr_epoch_data

  let length_in_triples =
    Length.length_in_triples + Length.length_in_triples
    + Vrf.Output.length_in_triples + Epoch.length_in_triples
    + Epoch.Slot.length_in_triples + Amount.length_in_triples
    + Epoch_data.length_in_triples + Epoch_data.length_in_triples

  let genesis : Value.t =
    { length= Length.zero
    ; epoch_length= Length.zero
    ; last_vrf_output= Vrf.Output.dummy
    ; total_currency= genesis_ledger_total_currency
    ; curr_epoch= Epoch.zero
    ; curr_slot= Epoch.Slot.zero
    ; curr_epoch_data= Epoch_data.genesis
    ; last_epoch_data= Epoch_data.genesis
    ; has_ancestor_in_same_checkpoint_window= false
    ; checkpoints= Checkpoints.empty }

  let checkpoint_window slot =
    Global_slot.to_int slot / Constants.Checkpoint_window.size_in_slots

  let same_checkpoint_window_unchecked slot1 slot2 =
    Core.Int.(checkpoint_window slot1 = checkpoint_window slot2)

  let update ~(previous_consensus_state : Value.t)
      ~(consensus_transition_data : Consensus_transition_data.value)
      ~(previous_protocol_state_hash : Coda_base.State_hash.t)
      ~(supply_increase : Currency.Amount.t)
      ~(snarked_ledger_hash : Coda_base.Frozen_ledger_hash.t)
      ~(proposer_vrf_result : Random_oracle.Digest.t) : Value.t Or_error.t =
    let open Or_error.Let_syntax in
    let open Consensus_transition_data in
    let%map total_currency =
      Amount.add previous_consensus_state.total_currency supply_increase
      |> Option.map ~f:Or_error.return
      |> Option.value
           ~default:(Or_error.error_string "failed to add total_currency")
    in
    let last_epoch_data, curr_epoch_data, epoch_length =
      Epoch_data.update_pair
        ( previous_consensus_state.last_epoch_data
        , previous_consensus_state.curr_epoch_data )
        previous_consensus_state.epoch_length
        ~prev_epoch:previous_consensus_state.curr_epoch
        ~next_epoch:consensus_transition_data.epoch
        ~prev_slot:previous_consensus_state.curr_slot
        ~prev_protocol_state_hash:previous_protocol_state_hash
        ~proposer_vrf_result ~snarked_ledger_hash ~total_currency
    in
    let checkpoints =
      if previous_consensus_state.has_ancestor_in_same_checkpoint_window then
        previous_consensus_state.checkpoints
      else
        Checkpoints.cons previous_protocol_state_hash
          previous_consensus_state.checkpoints
    in
    { length= Length.succ previous_consensus_state.length
    ; epoch_length
    ; last_vrf_output= proposer_vrf_result
    ; total_currency
    ; curr_epoch= consensus_transition_data.epoch
    ; curr_slot= consensus_transition_data.slot
    ; last_epoch_data
    ; curr_epoch_data
    ; has_ancestor_in_same_checkpoint_window=
        same_checkpoint_window_unchecked
          (Global_slot.create ~epoch:previous_consensus_state.curr_epoch
             ~slot:previous_consensus_state.curr_slot)
          (Global_slot.create ~epoch:consensus_transition_data.epoch
             ~slot:consensus_transition_data.slot)
    ; checkpoints }

  module M = Snarky.Snark.Run.Make (Crypto_params_init.Tick_backend)

  let m : M.field Snarky.Snark.m = (module M)

  let same_checkpoint_window ~prev:(slot1 : Global_slot.Packed.var)
      ~next:(slot2 : Global_slot.Packed.var) =
    let open Snarky_taylor in
    let open M in
    let _q1, r1 =
      Integer.div_mod ~m
        (Global_slot.Checked.to_integer slot1)
        (Integer.constant ~m
           (Bignum_bigint.of_int Constants.Checkpoint_window.size_in_slots))
    in
    let next_window_start =
      Field.(
        (slot1 :> Field.t)
        - Integer.to_field r1
        + of_int Constants.Checkpoint_window.size_in_slots)
    in
    (Field.compare ~bit_length:Global_slot.length_in_bits
       (slot2 :> Field.t)
       next_window_start)
      .less

  let same_checkpoint_window ~prev ~next =
    M.make_checked (fun () -> same_checkpoint_window ~prev ~next)

  (* Check that both epoch and slot are zero.
  *)
  let is_genesis (epoch : Epoch.Unpacked.var) (slot : Epoch.Slot.Unpacked.var)
      =
    let open Field in
    Checked.equal
      Checked.Infix.(
        (Epoch.pack_var epoch :> Var.t) + (Epoch.Slot.pack_var slot :> Var.t))
      (Var.constant zero)

  let%snarkydef update_var (previous_state : var)
      (transition_data : Consensus_transition_data.var)
      (previous_protocol_state_hash : Coda_base.State_hash.var)
      ~(supply_increase : Currency.Amount.var)
      ~(previous_blockchain_state_ledger_hash :
         Coda_base.Frozen_ledger_hash.var) =
    let open Consensus_transition_data in
    let open Snark_params.Tick in
    let {curr_epoch= prev_epoch; curr_slot= prev_slot; _} = previous_state in
    let {epoch= next_epoch; slot= next_slot} = transition_data in
    let%bind epoch_increased =
      let%bind c = Epoch.compare_var prev_epoch next_epoch in
      let%map () = Boolean.Assert.is_true c.less_or_equal in
      c.less
    in
    let%bind () =
      let%bind slot_increased =
        let%map c = Epoch.Slot.compare_var prev_slot next_slot in
        c.less
      in
      let%bind is_genesis = is_genesis next_epoch next_slot in
      Boolean.Assert.any [epoch_increased; slot_increased; is_genesis]
    in
    let%bind last_data =
      Epoch_data.if_ epoch_increased ~then_:previous_state.curr_epoch_data
        ~else_:previous_state.last_epoch_data
    in
    let%bind threshold_satisfied, vrf_result =
      let%bind (module M) = Inner_curve.Checked.Shifted.create () in
      Vrf.Checked.check
        (module M)
        ~epoch_ledger:last_data.ledger ~epoch:transition_data.epoch
        ~slot:transition_data.slot ~seed:last_data.seed
    in
    let%bind new_total_currency =
      Currency.Amount.Checked.add previous_state.total_currency supply_increase
    in
    let%bind checkpoints =
      let%bind consed =
        Checkpoints.Checked.cons previous_protocol_state_hash
          previous_state.checkpoints
      in
      Checkpoints.Checked.if_
        previous_state.has_ancestor_in_same_checkpoint_window
        ~then_:previous_state.checkpoints ~else_:consed
    in
    let%bind has_ancestor_in_same_checkpoint_window =
      same_checkpoint_window
        ~prev:(Global_slot.Checked.create ~epoch:prev_epoch ~slot:prev_slot)
        ~next:(Global_slot.Checked.create ~epoch:next_epoch ~slot:next_slot)
    in
    let%bind curr_data =
      let%map seed =
        let%bind in_seed_update_range =
          Epoch.Slot.in_seed_update_range_var prev_slot
        in
        let%bind base =
          Epoch_seed.if_ epoch_increased
            ~then_:Epoch_seed.(var_of_t initial)
            ~else_:previous_state.curr_epoch_data.seed
        in
        let%bind updated = Epoch_seed.update_var base vrf_result in
        Epoch_seed.if_ in_seed_update_range ~then_:updated ~else_:base
      and length =
        let%bind base =
          Field.Checked.if_ epoch_increased
            ~then_:Field.(Var.constant zero)
            ~else_:
              ( Length.pack_var previous_state.curr_epoch_data.length
                :> Field.Var.t )
        in
        Length.var_of_field Field.(Var.(add (constant one) base))
      and ledger =
        Epoch_ledger.if_ epoch_increased
          ~then_:
            { total_currency= new_total_currency
            ; hash= previous_blockchain_state_ledger_hash }
          ~else_:previous_state.curr_epoch_data.ledger
      and start_checkpoint =
        Coda_base.State_hash.if_ epoch_increased
          ~then_:previous_protocol_state_hash
          ~else_:previous_state.curr_epoch_data.start_checkpoint
      (* Want this to be the protocol state hash once we leave the seed
         update range. *)
      and lock_checkpoint =
        let%bind base =
          (* TODO: Should this be zero or some other sentinel value? *)
          Coda_base.State_hash.if_ epoch_increased
            ~then_:Coda_base.State_hash.(var_of_t (of_hash zero))
            ~else_:previous_state.curr_epoch_data.lock_checkpoint
        in
        let%bind in_seed_update_range =
          Epoch.Slot.in_seed_update_range_var previous_state.curr_slot
        in
        Coda_base.State_hash.if_ in_seed_update_range
          ~then_:previous_protocol_state_hash ~else_:base
      in
      {Epoch_data.seed; length; ledger; start_checkpoint; lock_checkpoint}
    and length = Length.increment_var previous_state.length
    (* TODO: keep track of total_currency in transaction snark. The current_slot
     * implementation would allow an adversary to make then total_currency incorrect by
     * not adding the coinbase to their account. *)
    and new_total_currency =
      Amount.Checked.add previous_state.total_currency supply_increase
    and epoch_length =
      Length.increment_if_var previous_state.epoch_length epoch_increased
    in
    Checked.return
      ( `Success threshold_satisfied
      , { length
        ; epoch_length
        ; last_vrf_output= vrf_result
        ; curr_epoch= transition_data.epoch
        ; curr_slot= transition_data.slot
        ; total_currency= new_total_currency
        ; last_epoch_data= last_data
        ; curr_epoch_data= curr_data
        ; has_ancestor_in_same_checkpoint_window
        ; checkpoints } )

  let length (t : Value.t) = t.length

  let time_hum (t : Value.t) =
    sprintf "%d:%d" (Epoch.to_int t.curr_epoch) (Epoch.Slot.to_int t.curr_slot)

  let to_lite = None

  type display =
    { length: int
    ; epoch_length: int
    ; curr_epoch: int
    ; curr_slot: int
    ; total_currency: int }
  [@@deriving yojson]

  let display (t : Value.t) =
    { length= Length.to_int t.length
    ; epoch_length= Length.to_int t.epoch_length
    ; curr_epoch= Segment_id.to_int t.curr_epoch
    ; curr_slot= Segment_id.to_int t.curr_slot
    ; total_currency= Amount.to_int t.total_currency }
end

module Blockchain_state = Coda_base.Blockchain_state.Make (Genesis_ledger)
module Protocol_state =
  Coda_base.Protocol_state.Make (Blockchain_state) (Consensus_state)

module Configuration = struct
  type t =
    { delta: int
    ; k: int
    ; c: int
    ; c_times_k: int
    ; slots_per_epoch: int
    ; slot_duration: int
    ; epoch_duration: int
    ; acceptable_network_delay: int }
  [@@deriving yojson, bin_io]

  let t =
    let open Constants in
    { delta
    ; k
    ; c
    ; c_times_k= c * k
    ; slots_per_epoch= UInt32.to_int Epoch.size
    ; slot_duration= Int64.to_int Slot.duration_ms
    ; epoch_duration= Int64.to_int (Time.Span.to_ms Epoch.duration)
    ; acceptable_network_delay= Int64.to_int (Time.Span.to_ms delta_duration)
    }
end

module Prover_state = struct
  include Coda_base.Stake_proof

  let precomputed_handler = Vrf.Precomputed.handler

  let handler {delegator; ledger; private_key} : Snark_params.Tick.Handler.t =
    let ledger_handler = unstage (Coda_base.Sparse_ledger.handler ledger) in
    fun (With {request; respond} as t) ->
      match request with
      | Vrf.Winner_address -> respond (Provide delegator)
      | Vrf.Private_key -> respond (Provide private_key)
      | _ -> ledger_handler t
end

module Snark_transition = Coda_base.Snark_transition.Make (struct
  module Genesis_ledger = Genesis_ledger
  module Blockchain_state = Blockchain_state
  module Consensus_data = Consensus_transition_data
end)

(* TODO: only track total currency from accounts > 1% of the currency using transactions *)
let generate_transition ~(previous_protocol_state : Protocol_state.Value.t)
    ~blockchain_state ~time ~proposal_data ~transactions:_ ~snarked_ledger_hash
    ~supply_increase ~logger:_ =
  let previous_consensus_state =
    Protocol_state.consensus_state previous_protocol_state
  in
  let epoch, slot =
    let time = Time.of_span_since_epoch (Time.Span.of_ms time) in
    Epoch.epoch_and_slot_of_time_exn time
  in
  let consensus_transition_data = Consensus_transition_data.{epoch; slot} in
  let consensus_state =
    Or_error.ok_exn
      (Consensus_state.update ~previous_consensus_state
         ~consensus_transition_data
         ~proposer_vrf_result:proposal_data.Proposal_data.vrf_result
         ~previous_protocol_state_hash:
           (Protocol_state.hash previous_protocol_state)
         ~supply_increase ~snarked_ledger_hash)
  in
  let protocol_state =
    Protocol_state.create_value
      ~previous_state_hash:(Protocol_state.hash previous_protocol_state)
      ~blockchain_state ~consensus_state
  in
  (protocol_state, consensus_transition_data)

let received_within_window (epoch, slot) ~time_received =
  let open Time in
  let time_received =
    of_span_since_epoch (Span.of_ms (Unix_timestamp.to_int64 time_received))
  in
  let window_start = Epoch.slot_start_time epoch slot in
  let window_end = add window_start Constants.delta_duration in
  window_start < time_received && time_received < window_end

let received_at_valid_time (consensus_state : Consensus_state.Value.t)
    ~time_received =
  let open Consensus_state in
  received_within_window
    (consensus_state.curr_epoch, consensus_state.curr_slot)
    ~time_received

include struct
  let%snarkydef next_state_checked ~(prev_state : Protocol_state.var)
      ~(prev_state_hash : Coda_base.State_hash.var) transition supply_increase
      =
    Consensus_state.update_var
      (Protocol_state.consensus_state prev_state)
      (Snark_transition.consensus_data transition)
      prev_state_hash ~supply_increase
      ~previous_blockchain_state_ledger_hash:
        ( Protocol_state.blockchain_state prev_state
        |> Blockchain_state.snarked_ledger_hash )
end

let select ~existing ~candidate ~logger =
  let open Consensus_state in
  let open Epoch_data in
  let string_of_choice = function `Take -> "Take" | `Keep -> "Keep" in
  let log_result choice msg =
    Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
      "RESULT: %s -- %s" (string_of_choice choice) msg
  in
  let log_choice ~precondition_msg ~choice_msg choice =
    let choice_msg =
      match choice with
      | `Take -> choice_msg
      | `Keep -> Printf.sprintf "not (%s)" choice_msg
    in
    let msg = Printf.sprintf "(%s) && (%s)" precondition_msg choice_msg in
    log_result choice msg
  in
  Logger.info logger ~module_:__MODULE__ ~location:__LOC__
    "selecting best consensus state"
    ~metadata:
      [ ("existing", Consensus_state.Value.to_yojson existing)
      ; ("candidate", Consensus_state.Value.to_yojson candidate) ] ;
  (* TODO: add fork_before_checkpoint check *)
  (* Each branch contains a precondition predicate and a choice predicate,
   * which takes the new state when true. Each predicate is also decorated
   * with a string description, used for debugging messages *)
  let candidate_vrf_is_bigger =
    let d = Fn.compose Random_oracle.digest_string Vrf.Output.to_string in
    Random_oracle.Digest.( > )
      (d candidate.last_vrf_output)
      (d existing.last_vrf_output)
  in
  let ( << ) a b =
    let c = Length.compare a b in
    c < 0 || (c = 0 && candidate_vrf_is_bigger)
  in
  let ( = ) = Coda_base.State_hash.equal in
  let branches =
    [ ( ( lazy
            ( existing.last_epoch_data.lock_checkpoint
            = candidate.last_epoch_data.lock_checkpoint )
        , "last epoch lock checkpoints are equal" )
      , ( lazy (existing.length << candidate.length)
        , "candidate is longer than existing" ) )
    ; ( ( lazy
            ( existing.last_epoch_data.start_checkpoint
            = candidate.last_epoch_data.start_checkpoint )
        , "last epoch start checkpoints are equal" )
      , ( lazy
            ( existing.last_epoch_data.length
            << candidate.last_epoch_data.length )
        , "candidate last epoch is longer than existing last epoch" ) )
      (* these two could be condensed into one entry *)
    ; ( ( lazy
            ( existing.curr_epoch_data.lock_checkpoint
            = candidate.last_epoch_data.lock_checkpoint )
        , "candidate last epoch lock checkpoint is equal to existing current \
           epoch lock checkpoint" )
      , ( lazy (existing.length << candidate.length)
        , "candidate is longer than existing" ) )
    ; ( ( lazy
            ( existing.last_epoch_data.lock_checkpoint
            = candidate.curr_epoch_data.lock_checkpoint )
        , "candidate current epoch lock checkpoint is equal to existing last \
           epoch lock checkpoint" )
      , ( lazy (existing.length << candidate.length)
        , "candidate is longer than existing" ) )
    ; ( ( lazy
            ( existing.curr_epoch_data.start_checkpoint
            = candidate.last_epoch_data.start_checkpoint )
        , "candidate last epoch start checkpoint is equal to existing current \
           epoch start checkpoint" )
      , ( lazy
            ( existing.curr_epoch_data.length
            << candidate.last_epoch_data.length )
        , "candidate last epoch is longer than existing current epoch" ) )
    ; ( ( lazy
            ( existing.last_epoch_data.start_checkpoint
            = candidate.curr_epoch_data.start_checkpoint )
        , "candidate current epoch start checkpoint is equal to existing last \
           epoch start checkpoint" )
      , ( lazy
            ( existing.last_epoch_data.length
            << candidate.curr_epoch_data.length )
        , "candidate current epoch is longer than existing last epoch" ) ) ]
  in
  match
    List.find_map branches
      ~f:(fun ((precondition, precondition_msg), (choice, choice_msg)) ->
        if Lazy.force precondition then (
          let choice = if Lazy.force choice then `Take else `Keep in
          log_choice ~precondition_msg ~choice_msg choice ;
          Some choice )
        else None )
  with
  | Some choice -> choice
  | None ->
      log_result `Keep "no predicates were matched" ;
      `Keep

let time_hum (now : Core_kernel.Time.t) =
  let epoch, slot = Epoch.epoch_and_slot_of_time_exn (Time.of_time now) in
  Printf.sprintf "%d:%d" (Epoch.to_int epoch) (Epoch.Slot.to_int slot)

let next_proposal now (state : Consensus_state.Value.t) ~local_state ~keypair
    ~logger =
  let open Consensus_state in
  let open Epoch_data in
  let open Keypair in
  Logger.info logger ~module_:__MODULE__ ~location:__LOC__
    "Checking for next proposal..." ;
  let epoch, slot =
    Epoch.epoch_and_slot_of_time_exn
      (Time.of_span_since_epoch (Time.Span.of_ms now))
  in
  Logger.info logger ~module_:__MODULE__ ~location:__LOC__
    "systime: %d, epoch-slot@systime: %08d-%04d, starttime@epoch@systime: %d"
    (Int64.to_int now) (Epoch.to_int epoch) (Epoch.Slot.to_int slot)
    ( Int64.to_int @@ Time.Span.to_ms @@ Time.to_span_since_epoch
    @@ Epoch.start_time epoch ) ;
  let epoch_transitioning = Epoch.equal epoch (Epoch.succ state.curr_epoch) in
  let next_slot =
    (* When we first enter an epoch, the protocol state may still be a previous
     * epoch. If that is the case, we need to select the staged vrf inputs
     * instead of the last vrf inputs, since if the protocol state were actually
     * up to date with the epoch, those would be the last vrf inputs.
    *)
    let epoch_data =
      Logger.info logger ~module_:__MODULE__ ~location:__LOC__
        !"Selecting correct epoch data from state -- epoch by time: %d, state \
          epoch: %d, state epoch length: %d"
        (Epoch.to_int epoch)
        (Epoch.to_int state.curr_epoch)
        (Length.to_int state.epoch_length) ;
      (* If we are in the current epoch or we are in the first epoch (before any
       * transitions), use the last epoch data.
      *)
      if
        Epoch.equal epoch state.curr_epoch
        || Length.equal state.epoch_length Length.zero
      then state.last_epoch_data
        (* If we are in the next epoch, use the current epoch data. *)
      else if epoch_transitioning then state.curr_epoch_data
        (* If the epoch we are in is none of the above, something is wrong. *)
      else (
        Logger.error logger ~module_:__MODULE__ ~location:__LOC__
          "system time is out of sync with protocol state time" ;
        failwith "System time is out of sync. (hint: setup NTP if you haven't)" )
    in
    let total_stake = epoch_data.ledger.total_currency in
    let epoch_snapshot =
      let source, snapshot =
        if
          Coda_base.Frozen_ledger_hash.equal epoch_data.ledger.hash
            genesis_ledger_hash
        then ("genesis", Some local_state.Local_state.genesis_epoch_snapshot)
        else if
          epoch_transitioning
          || state.curr_epoch_data.length <= Length.of_int Constants.k
        then ("curr", local_state.curr_epoch_snapshot)
        else ("last", local_state.Local_state.last_epoch_snapshot)
      in
      ( match snapshot with
      | None ->
          Logger.info logger ~module_:__MODULE__ ~location:__LOC__
            "Unable to check vrf evaluation: %s_epoch_ledger does not exist \
             in local state"
            source
      | Some snapshot ->
          Logger.info logger ~module_:__MODULE__ ~location:__LOC__
            !"using %s_epoch_snapshot root hash %{sexp:Coda_base.Ledger_hash.t}"
            source
            (Coda_base.Sparse_ledger.merkle_root snapshot.ledger) ) ;
      snapshot
    in
    let proposal_data slot =
      Vrf.check ~epoch ~slot ~seed:epoch_data.seed ~epoch_snapshot
        ~private_key:keypair.private_key ~total_stake ~logger
    in
    let rec find_winning_slot slot =
      if UInt32.of_int (Epoch.Slot.to_int slot) >= Constants.Epoch.size then
        None
      else
        match Local_state.seen_slot local_state epoch slot with
        | `Seen -> find_winning_slot (Epoch.Slot.succ slot)
        | `Unseen -> (
          match proposal_data slot with
          | None -> find_winning_slot (Epoch.Slot.succ slot)
          | Some data -> Some (slot, data) )
    in
    find_winning_slot slot
  in
  let ms_since_epoch = Fn.compose Time.Span.to_ms Time.to_span_since_epoch in
  match next_slot with
  | Some (next_slot, data) ->
      Logger.info logger ~module_:__MODULE__ ~location:__LOC__
        "Proposing in %d slots"
        (Epoch.Slot.to_int next_slot - Epoch.Slot.to_int slot) ;
      if Epoch.Slot.equal slot next_slot then `Propose_now data
      else
        `Propose
          ( Epoch.slot_start_time epoch next_slot
            |> Time.to_span_since_epoch |> Time.Span.to_ms
          , data )
  | None ->
      let epoch_end_time = Epoch.end_time epoch |> ms_since_epoch in
      Logger.info logger ~module_:__MODULE__ ~location:__LOC__
        "No slots won in this epoch. Waiting for next epoch, @%d"
        (Int64.to_int epoch_end_time) ;
      `Check_again epoch_end_time

(* TODO *)
let lock_transition (prev : Consensus_state.Value.t)
    (next : Consensus_state.Value.t) ~local_state ~snarked_ledger =
  let open Local_state in
  let open Consensus_state in
  if not (Epoch.equal prev.curr_epoch next.curr_epoch) then (
    let epoch_snapshot =
      Option.map local_state.proposer_public_key ~f:(fun pk ->
          let open Local_state.Snapshot in
          let delegators =
            compute_delegators
              (`Include_self, pk)
              ~iter_accounts:(fun f ->
                Coda_base.Ledger.Any_ledger.M.iteri snarked_ledger ~f )
          in
          let ledger =
            Coda_base.Sparse_ledger.of_ledger_index_subset_exn snarked_ledger
              (Coda_base.Account.Index.Table.keys delegators)
          in
          {delegators; ledger} )
    in
    local_state.last_epoch_snapshot <- local_state.curr_epoch_snapshot ;
    local_state.curr_epoch_snapshot <- epoch_snapshot )

let create_genesis_protocol_state consensus_transition_data blockchain_state =
  let consensus_state =
    Or_error.ok_exn
      (Consensus_state.update ~proposer_vrf_result:Vrf.Precomputed.vrf_output
         ~previous_consensus_state:
           Protocol_state.(consensus_state negative_one)
         ~previous_protocol_state_hash:Protocol_state.(hash negative_one)
         ~consensus_transition_data ~supply_increase:Currency.Amount.zero
         ~snarked_ledger_hash:genesis_ledger_hash)
  in
  let state =
    Protocol_state.create_value
      ~previous_state_hash:Protocol_state.(hash negative_one)
      ~blockchain_state ~consensus_state
  in
  With_hash.of_data ~hash_data:Protocol_state.hash state

let genesis_protocol_state =
  create_genesis_protocol_state
    Snark_transition.(consensus_data genesis)
    Snark_transition.(blockchain_state genesis)

module For_tests = struct
  let create_genesis_protocol_state ledger =
    let consensus_data = Snark_transition.(consensus_data genesis) in
    let root_ledger_hash = Coda_base.Ledger.merkle_root ledger in
    create_genesis_protocol_state consensus_data
      { Blockchain_state.genesis with
        staged_ledger_hash=
          Coda_base.Staged_ledger_hash.(
            of_aux_and_ledger_hash Aux_hash.dummy root_ledger_hash)
      ; snarked_ledger_hash=
          Coda_base.Frozen_ledger_hash.of_ledger_hash root_ledger_hash }

  let gen_consensus_state ~(gen_slot_advancement : int Quickcheck.Generator.t)
      :
      (   previous_protocol_state:( Protocol_state.Value.t
                                  , Coda_base.State_hash.t )
                                  With_hash.t
       -> snarked_ledger_hash:Coda_base.Frozen_ledger_hash.t
       -> Consensus_state.Value.t)
      Quickcheck.Generator.t =
    let open Consensus_state in
    let open Quickcheck.Let_syntax in
    let open UInt32.Infix in
    let%bind slot_advancement = gen_slot_advancement in
    let%map proposer_vrf_result = Vrf.Output.gen in
    fun ~(previous_protocol_state :
           (Protocol_state.Value.t, Coda_base.State_hash.t) With_hash.t)
        ~(snarked_ledger_hash : Coda_base.Frozen_ledger_hash.t) ->
      let prev =
        Protocol_state.consensus_state (With_hash.data previous_protocol_state)
      in
      let length = Length.succ prev.length in
      let curr_epoch, curr_slot =
        let slot = prev.curr_slot + UInt32.of_int slot_advancement in
        let epoch_advancement = slot / Constants.Epoch.size in
        (prev.curr_epoch + epoch_advancement, slot mod Constants.Epoch.size)
      in
      let total_currency =
        Option.value_exn (Amount.add prev.total_currency Constants.coinbase)
      in
      let last_epoch_data, curr_epoch_data, epoch_length =
        Epoch_data.update_pair
          (prev.last_epoch_data, prev.curr_epoch_data)
          prev.epoch_length ~prev_epoch:prev.curr_epoch ~next_epoch:curr_epoch
          ~prev_slot:prev.curr_slot
          ~prev_protocol_state_hash:(With_hash.hash previous_protocol_state)
          ~proposer_vrf_result ~snarked_ledger_hash ~total_currency
      in
      let checkpoints =
        if prev.has_ancestor_in_same_checkpoint_window then prev.checkpoints
        else Checkpoints.cons previous_protocol_state.hash prev.checkpoints
      in
      { length
      ; epoch_length
      ; last_vrf_output= proposer_vrf_result
      ; total_currency
      ; curr_epoch
      ; curr_slot
      ; last_epoch_data
      ; curr_epoch_data
      ; has_ancestor_in_same_checkpoint_window=
          same_checkpoint_window_unchecked
            (Global_slot.create ~epoch:prev.curr_epoch ~slot:prev.curr_slot)
            (Global_slot.create ~epoch:curr_epoch ~slot:curr_slot)
      ; checkpoints }
end

let should_bootstrap_len ~existing ~candidate =
  let length = Length.to_int in
  length candidate - length existing > (2 * Constants.k) + Constants.delta

let should_bootstrap ~existing ~candidate =
  should_bootstrap_len
    ~existing:(Consensus_state.length existing)
    ~candidate:(Consensus_state.length candidate)

let%test "should_bootstrap is sane" =
  (* Even when consensus constants are of prod sizes, candidate should still trigger a bootstrap *)
  should_bootstrap_len ~existing:Length.zero
    ~candidate:(Length.of_int 100_000_000)

let to_unix_timestamp recieved_time =
  recieved_time |> Time.to_span_since_epoch |> Time.Span.to_ms
  |> Unix_timestamp.of_int64

let%test "Receive a valid consensus_state with a bit of delay" =
  let ({curr_epoch; curr_slot; _} : Consensus_state.Value.t) =
    Consensus_state.genesis
  in
  let delay = Constants.delta / 2 |> UInt32.of_int in
  let new_slot = UInt32.Infix.(curr_slot + delay) in
  let time_received = Epoch.slot_start_time curr_epoch new_slot in
  received_at_valid_time Consensus_state.genesis
    ~time_received:(to_unix_timestamp time_received)

let%test "Receive an invalid consensus_state" =
  let epoch = Epoch.of_int 5 in
  let start_time = Epoch.start_time epoch in
  let curr_epoch, curr_slot = Epoch.epoch_and_slot_of_time_exn start_time in
  let consensus_state = {Consensus_state.genesis with curr_epoch; curr_slot} in
  let too_early = Epoch.start_time Consensus_state.genesis.curr_slot in
  let too_late =
    let delay = Constants.delta * 2 |> UInt32.of_int in
    let delayed_slot = UInt32.Infix.(curr_slot + delay) in
    Epoch.slot_start_time curr_epoch delayed_slot
  in
  let times = [too_late; too_early] in
  List.for_all times ~f:(fun time ->
      not
        (received_at_valid_time consensus_state
           ~time_received:(to_unix_timestamp time)) )

let%test_module "Proof of stake tests" =
  ( module struct
    open Consensus_state

    let%test_unit "update, update_var agree starting from same genesis state" =
      (* build pieces needed to apply "update" *)
      let previous_protocol_state = genesis_protocol_state in
      let snarked_ledger_hash =
        previous_protocol_state |> With_hash.data
        |> Protocol_state.blockchain_state
        |> Protocol_state.Blockchain_state.snarked_ledger_hash
      in
      let previous_consensus_state = genesis in
      let epoch, slot =
        Epoch.epoch_and_slot_of_time_exn
          (Time.of_time (Core_kernel.Time.now ()))
      in
      let consensus_transition_data : Consensus_transition_data.value =
        {epoch; slot}
      in
      let previous_protocol_state_hash =
        With_hash.hash previous_protocol_state
      in
      let supply_increase = Currency.Amount.of_int 42 in
      (* setup ledger, needed to compute proposer_vrf_result here and handler below *)
      let open Signature_lib in
      let open Coda_base in
      (* choose largest account as most likely to propose *)
      let ledger_data = Genesis_ledger.t in
      let ledger = Ledger.Any_ledger.cast (module Ledger) ledger_data in
      let maybe_sk, account = Genesis_ledger.largest_account_exn () in
      let private_key = Option.value_exn maybe_sk in
      let public_key = Account.public_key account in
      let location = Ledger.Any_ledger.M.location_of_key ledger public_key in
      let delegator =
        Option.value_exn location |> Ledger.Any_ledger.M.Location.to_path_exn
        |> Ledger.Addr.to_int
      in
      let proposer_vrf_result =
        Vrf.eval ~private_key {epoch; slot; seed= Epoch_seed.initial; delegator}
      in
      let next_consensus_state =
        update ~previous_consensus_state ~consensus_transition_data
          ~previous_protocol_state_hash ~supply_increase ~snarked_ledger_hash
          ~proposer_vrf_result
        |> Or_error.ok_exn
      in
      (* build pieces needed to apply "update_var" *)
      let checked_computation =
        let open Snark_params.Tick in
        let open Let_syntax in
        (* work in Checked monad *)
        let%bind previous_state =
          exists typ ~compute:(As_prover.return previous_consensus_state)
        in
        let%bind transition_data =
          exists Consensus_transition_data.typ
            ~compute:(As_prover.return consensus_transition_data)
        in
        let%bind previous_protocol_state_hash =
          exists State_hash.typ
            ~compute:(As_prover.return previous_protocol_state_hash)
        in
        let%bind supply_increase =
          exists Amount.typ ~compute:(As_prover.return supply_increase)
        in
        let%bind previous_blockchain_state_ledger_hash =
          exists Coda_base.Frozen_ledger_hash.typ
            ~compute:(As_prover.return snarked_ledger_hash)
        in
        let result =
          update_var previous_state transition_data
            previous_protocol_state_hash ~supply_increase
            ~previous_blockchain_state_ledger_hash
        in
        (* setup handler *)
        let indices =
          Ledger.Any_ledger.M.foldi ~init:[] ledger ~f:(fun i accum _acct ->
              Ledger.Any_ledger.M.Addr.to_int i :: accum )
        in
        let sparse_ledger =
          Sparse_ledger.of_ledger_index_subset_exn ledger indices
        in
        let handler =
          Prover_state.handler {delegator; ledger= sparse_ledger; private_key}
        in
        let%map `Success _, var = Snark_params.Tick.handle result handler in
        As_prover.read typ var
      in
      let (), checked_value =
        Or_error.ok_exn
        @@ Snark_params.Tick.run_and_check checked_computation ()
      in
      assert (Value.equal checked_value next_consensus_state) ;
      ()
  end )

[%%endif]
