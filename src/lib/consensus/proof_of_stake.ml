open Core_kernel
open Signed
open Unsigned
open Coda_numbers
open Currency
open Sha256_lib
open Fold_lib
open Signature_lib

module type Inputs_intf = sig
  module Ledger_builder_diff : sig
    type t [@@deriving bin_io, sexp]
  end

  module Time : sig
    type t

    module Span : sig
      type t

      val to_ms : t -> Int64.t

      val of_ms : Int64.t -> t

      val ( + ) : t -> t -> t

      val ( * ) : t -> t -> t
    end

    val ( < ) : t -> t -> bool

    val ( >= ) : t -> t -> bool

    val diff : t -> t -> Span.t

    val to_span_since_epoch : t -> Span.t

    val of_span_since_epoch : Span.t -> t

    val add : t -> Span.t -> t
  end

  module Genesis_ledger : sig
    val t : Coda_base.Ledger.t
  end

  val genesis_state_timestamp : Time.t

  val coinbase : Amount.t

  val slot_interval : Time.Span.t

  val unforkable_transition_count : int

  val probable_slots_per_transition_count : int

  val expected_network_delay : Time.Span.t

  val approximate_network_diameter : int
end

module Segment_id = Nat.Make32 ()

module Epoch_seed = struct
  include Coda_base.Data_hash.Make_full_size ()

  let initial : t = of_hash Snark_params.Tick.Pedersen.zero_hash

  let fold_vrf_result seed vrf_result =
    Fold.(fold seed +> Sha256.Digest.fold vrf_result)

  let update seed vrf_result =
    let open Snark_params.Tick in
    of_hash
      (Pedersen.digest_fold Coda_base.Hash_prefix.epoch_seed
         (fold_vrf_result seed vrf_result))

  let update_var (seed : var) (vrf_result : Sha256.Digest.var) :
      (var, _) Snark_params.Tick.Checked.t =
    let open Snark_params.Tick in
    let open Snark_params.Tick.Let_syntax in
    let%bind seed_triples = var_to_triples seed in
    let%map hash =
      Pedersen.Checked.digest_triples ~init:Coda_base.Hash_prefix.epoch_seed
        ( seed_triples
        @ Fold.(to_list (group3 ~default:Boolean.false_ (of_list vrf_result)))
        )
    in
    var_of_hash_packed hash
end

let uint32_of_int64 x = x |> Int64.to_int64 |> UInt32.of_int64

let int64_of_uint32 x = x |> UInt32.to_int64 |> Int64.of_int64

module Make (Inputs : Inputs_intf) :
  Mechanism.S
  with type Internal_transition.Ledger_builder_diff.t =
              Inputs.Ledger_builder_diff.t
   and type External_transition.Ledger_builder_diff.t =
              Inputs.Ledger_builder_diff.t = struct
  module Ledger_builder_diff = Inputs.Ledger_builder_diff
  module Time = Inputs.Time

  module Proposal_data = struct
    type t = {stake_proof: Coda_base.Stake_proof.t; vrf_result: Sha256.Digest.t}
    [@@deriving bin_io]

    let prover_state {stake_proof; _} = stake_proof
  end

  let block_interval_ms = Time.Span.to_ms Inputs.slot_interval

  let genesis_ledger_total_currency =
    Coda_base.Ledger.to_list Inputs.Genesis_ledger.t
    |> List.fold_left ~init:Balance.zero ~f:(fun sum account ->
           Balance.add_amount sum
             (Balance.to_amount @@ Coda_base.Account.balance account)
           |> Option.value_exn
                ~message:"failed to calculate total currency in genesis ledger"
       )
    |> Balance.to_amount

  let genesis_ledger_hash =
    Coda_base.Ledger.merkle_root Inputs.Genesis_ledger.t
    |> Coda_base.Frozen_ledger_hash.of_ledger_hash

  let compute_delegators self_pk ledger =
    let open Coda_base in
    let t = Account.Index.Table.create () in
    Ledger.foldi ledger ~init:() ~f:(fun i () acct ->
        (* TODO: The second disjunct is a hack and should be removed once the delegation
         command PR lands. *)
        if
          Public_key.Compressed.equal self_pk acct.delegate
          || Public_key.Compressed.equal self_pk acct.public_key
        then
          Hashtbl.add t ~key:(Ledger.Addr.to_int i) ~data:acct.balance
          |> ignore
        else () ) ;
    t

  module Local_state = struct
    type t =
      { mutable last_epoch_ledger: Coda_base.Ledger.t option
      ; mutable curr_epoch_ledger: Coda_base.Ledger.t option
      ; mutable delegators: Currency.Balance.t Coda_base.Account.Index.Table.t
      }
    [@@deriving sexp]

    let create keypair =
      let delegators =
        match keypair with
        | None -> Coda_base.Account.Index.Table.create ()
        | Some k ->
            compute_delegators
              (Public_key.compress k.Keypair.public_key)
              Genesis_ledger.t
      in
      {last_epoch_ledger= None; curr_epoch_ledger= None; delegators}
  end

  module Epoch = struct
    include Segment_id

    let size =
      UInt32.of_int
        ( 3 * Inputs.probable_slots_per_transition_count
        * Inputs.unforkable_transition_count )

    let interval =
      Time.Span.of_ms
        Int64.Infix.(
          Time.Span.to_ms Inputs.slot_interval * int64_of_uint32 size)

    let of_time_exn t : t =
      if Time.(t < Inputs.genesis_state_timestamp) then
        raise
          (Invalid_argument
             "Epoch.of_time: time is less than genesis block timestamp") ;
      let time_since_genesis = Time.diff t Inputs.genesis_state_timestamp in
      uint32_of_int64
        Int64.Infix.(
          Time.Span.to_ms time_since_genesis / Time.Span.to_ms interval)

    let start_time (epoch : t) =
      let ms =
        let open Int64.Infix in
        Time.Span.to_ms
          (Time.to_span_since_epoch Inputs.genesis_state_timestamp)
        + (int64_of_uint32 epoch * Time.Span.to_ms interval)
      in
      Time.of_span_since_epoch (Time.Span.of_ms ms)

    let end_time (epoch : t) = Time.add (start_time epoch) interval

    module Slot = struct
      include Segment_id
      include Comparable.Make (Segment_id)

      let interval = Inputs.slot_interval

      let unforkable_count =
        UInt32.of_int
          ( Inputs.probable_slots_per_transition_count
          * Inputs.unforkable_transition_count )

      let after_lock_checkpoint (slot : t) =
        let open UInt32.Infix in
        unforkable_count * UInt32.of_int 2 < slot

      let in_seed_update_range (slot : t) =
        let open UInt32.Infix in
        unforkable_count <= slot && slot < unforkable_count * UInt32.of_int 2

      let in_seed_update_range_var (slot : Unpacked.var) =
        let open Snark_params.Tick in
        let open Snark_params.Tick.Let_syntax in
        let uint32_msb x =
          List.init 32 ~f:(fun i ->
              UInt32.Infix.((x lsr Int.sub 31 i) land UInt32.one = UInt32.one)
          )
          |> Bitstring_lib.Bitstring.Msb_first.of_list
        in
        let ( < ) = Bitstring_checked.lt_value in
        let unforkable_count = uint32_msb unforkable_count
        and unforkable_count_times_2 =
          uint32_msb UInt32.(Infix.(of_int 2 * unforkable_count))
        in
        let slot_msb =
          Bitstring_lib.Bitstring.Msb_first.of_lsb_first
            (Unpacked.var_to_bits slot)
        in
        let%bind slot_gte_unforkable_count =
          slot_msb < unforkable_count >>| Boolean.not
        and slot_lt_unforkable_count_times_2 =
          slot_msb < unforkable_count_times_2
        in
        Boolean.(slot_gte_unforkable_count && slot_lt_unforkable_count_times_2)

      let gen =
        let open Quickcheck.Let_syntax in
        Core.Int.gen_incl 0 (UInt32.to_int unforkable_count * 3)
        >>| UInt32.of_int

      let%test_unit "in_seed_update_range unchecked vs. checked equality" =
        Quickcheck.test ~trials:100 gen ~f:(fun slot ->
            Test_util.test_equal Unpacked.typ Snark_params.Tick.Boolean.typ
              in_seed_update_range_var in_seed_update_range slot )
    end

    let slot_start_time (epoch : t) (slot : Slot.t) =
      Time.add (start_time epoch)
        (Time.Span.of_ms
           Int64.Infix.(int64_of_uint32 slot * Time.Span.to_ms Slot.interval))

    let slot_end_time (epoch : t) (slot : Slot.t) =
      Time.add (slot_start_time epoch slot) Slot.interval

    let epoch_and_slot_of_time_exn t : t * Slot.t =
      let epoch = of_time_exn t in
      let time_since_epoch = Time.diff t (start_time epoch) in
      let slot =
        uint32_of_int64
        @@ Int64.Infix.(
             Time.Span.to_ms time_since_epoch / Time.Span.to_ms Slot.interval)
      in
      (epoch, slot)
  end

  module Epoch_ledger = struct
    type ('ledger_hash, 'amount) t =
      {hash: 'ledger_hash; total_currency: 'amount}
    [@@deriving sexp, bin_io, eq, compare, hash]

    type value = (Coda_base.Frozen_ledger_hash.t, Amount.t) t
    [@@deriving sexp, bin_io, eq, compare, hash]

    type var = (Coda_base.Frozen_ledger_hash.var, Amount.var) t

    let to_hlist {hash; total_currency} =
      Coda_base.H_list.[hash; total_currency]

    let of_hlist :
           (unit, 'ledger_hash -> 'total_currency -> unit) Coda_base.H_list.t
        -> ('ledger_hash, 'total_currency) t =
     fun Coda_base.H_list.([hash; total_currency]) -> {hash; total_currency}

    let data_spec =
      Snark_params.Tick.Data_spec.
        [Coda_base.Frozen_ledger_hash.typ; Amount.typ]

    let typ =
      Snark_params.Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
        ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist

    let var_to_triples {hash; total_currency} =
      let open Snark_params.Tick.Let_syntax in
      let%map hash_triples =
        Coda_base.Frozen_ledger_hash.var_to_triples hash
      in
      hash_triples @ Amount.var_to_triples total_currency

    let fold {hash; total_currency} =
      let open Fold in
      Coda_base.Frozen_ledger_hash.fold hash +> Amount.fold total_currency

    let length_in_triples =
      Coda_base.Frozen_ledger_hash.length_in_triples + Amount.length_in_triples

    let if_ cond ~then_ ~else_ =
      let open Snark_params.Tick.Let_syntax in
      let%map hash =
        Coda_base.Frozen_ledger_hash.if_ cond ~then_:then_.hash
          ~else_:else_.hash
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

      let typ = Snark_params.Tick.Inner_curve.Scalar.typ
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
      type ('epoch, 'slot, 'epoch_seed, 'state_hash, 'delegator) t =
        { epoch: 'epoch
        ; slot: 'slot
        ; seed: 'epoch_seed
        ; lock_checkpoint: 'state_hash
        ; delegator: 'delegator }

      type value =
        ( Epoch.t
        , Epoch.Slot.t
        , Epoch_seed.t
        , Coda_base.State_hash.t
        , Coda_base.Account.Index.t )
        t

      type var =
        ( Epoch.Unpacked.var
        , Epoch.Slot.Unpacked.var
        , Epoch_seed.var
        , Coda_base.State_hash.var
        , Coda_base.Account.Index.Unpacked.var )
        t

      let to_hlist {epoch; slot; seed; lock_checkpoint; delegator} =
        Coda_base.H_list.[epoch; slot; seed; lock_checkpoint; delegator]

      let of_hlist :
             ( unit
             , 'epoch -> 'slot -> 'epoch_seed -> 'state_hash -> 'del -> unit
             )
             Coda_base.H_list.t
          -> ('epoch, 'slot, 'epoch_seed, 'state_hash, 'del) t =
       fun Coda_base.H_list.([epoch; slot; seed; lock_checkpoint; delegator]) ->
        {epoch; slot; seed; lock_checkpoint; delegator}

      let data_spec =
        let open Snark_params.Tick.Data_spec in
        [ Epoch.Unpacked.typ
        ; Epoch.Slot.Unpacked.typ
        ; Epoch_seed.typ
        ; Coda_base.State_hash.typ
        ; Coda_base.Account.Index.Unpacked.typ ]

      let typ =
        Snark_params.Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
          ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
          ~value_of_hlist:of_hlist

      let fold {epoch; slot; seed; lock_checkpoint; delegator} =
        let open Fold in
        Epoch.fold epoch +> Epoch.Slot.fold slot +> Epoch_seed.fold seed
        +> Coda_base.State_hash.fold lock_checkpoint
        +> Coda_base.Account.Index.fold delegator

      let hash_to_group msg =
        let msg_hash_state =
          Snark_params.Tick.Pedersen.hash_fold
            Coda_base.Hash_prefix.vrf_message (fold msg)
        in
        msg_hash_state.acc

      module Checked = struct
        let var_to_triples {epoch; slot; seed; lock_checkpoint; delegator} =
          let open Snark_params.Tick.Let_syntax in
          let%map seed_triples = Epoch_seed.var_to_triples seed
          and lock_checkpoint_triples =
            Coda_base.State_hash.var_to_triples lock_checkpoint
          in
          Epoch.Unpacked.var_to_triples epoch
          @ Epoch.Slot.Unpacked.var_to_triples slot
          @ seed_triples @ lock_checkpoint_triples
          @ Coda_base.Account.Index.Unpacked.var_to_triples delegator

        let hash_to_group msg =
          let open Snark_params.Tick in
          let open Snark_params.Tick.Let_syntax in
          let%bind msg_triples = var_to_triples msg in
          Pedersen.Checked.hash_triples ~init:Coda_base.Hash_prefix.vrf_message
            msg_triples
      end

      let gen =
        let open Quickcheck.Let_syntax in
        let%map epoch = Epoch.gen
        and slot = Epoch.Slot.gen
        and seed = Epoch_seed.gen
        and lock_checkpoint = Coda_base.State_hash.gen
        and delegator = Coda_base.Account.Index.gen in
        {epoch; slot; seed; lock_checkpoint; delegator}
    end

    module Output = struct
      type value = Sha256.Digest.t [@@deriving sexp]

      type var = Sha256.Digest.var

      let hash msg g =
        let open Fold in
        let compressed_g =
          Non_zero_curve_point.(g |> of_inner_curve_exn |> compress)
        in
        let digest =
          Snark_params.Tick.Pedersen.digest_fold
            Coda_base.Hash_prefix.vrf_output
            ( Message.fold msg
            +> Non_zero_curve_point.Compressed.fold compressed_g )
        in
        Sha256.digest_bits
          (Snark_params.Tick.Pedersen.Digest.Bits.to_bits digest)

      module Checked = struct
        let hash msg g =
          let open Snark_params.Tick.Let_syntax in
          let%bind msg_triples = Message.Checked.var_to_triples msg in
          let%bind g_triples =
            Non_zero_curve_point.(compress_var g >>= Compressed.var_to_triples)
          in
          let%bind pedersen_digest =
            Snark_params.Tick.Pedersen.Checked.digest_triples
              ~init:Coda_base.Hash_prefix.vrf_output (msg_triples @ g_triples)
            >>= Snark_params.Tick.Pedersen.Checked.Digest.choose_preimage
          in
          Sha256.Checked.digest
            (pedersen_digest :> Snark_params.Tick.Boolean.var list)
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
            (Test_util.test_equal
               ~equal:(List.equal ~equal:Bool.equal)
               Snark_params.Tick.Typ.(
                 Message.typ * Snark_params.Tick.Inner_curve.typ)
               (Snark_params.Tick.Typ.list ~length:256
                  Snark_params.Tick.Boolean.typ)
               (fun (msg, g) -> Checked.hash msg g)
               (fun (msg, g) -> Sha256_lib.Sha256.Digest.to_bits (hash msg g)))
    end

    module Threshold = struct
      open Bignum_bigint

      let of_uint64_exn = Fn.compose of_int64_exn UInt64.to_int64

      let c_int = 1

      let c = of_int c_int

      (*  Check if
          vrf_output / 2^256 <= c * my_stake / total_currency

          So that we don't have to do division we check

          vrf_output * total_currency <= c * my_stake * 2^256
      *)
      let is_satisfied ~my_stake ~total_stake vrf_output =
        of_bit_fold_lsb (Sha256.Digest.fold_bits vrf_output)
        * of_uint64_exn (Amount.to_uint64 total_stake)
        <= shift_left
             (c * of_uint64_exn (Balance.to_uint64 my_stake))
             Sha256.Digest.length_in_bits

      module Checked = struct
        (* This version can't be used right now because the field is too small. *)
        let _is_satisfied ~my_stake ~total_stake vrf_output =
          let open Snark_params.Tick in
          let open Let_syntax in
          let open Number in
          let%bind lhs =
            of_bits vrf_output * Amount.var_to_number total_stake
          in
          let%bind rhs =
            let%bind x =
              (* someday: This should really just be a scalar multiply... *)
              constant (Field.of_int c_int) * Amount.var_to_number my_stake
            in
            mul_pow_2 x (`Two_to_the Sha256.Digest.length_in_bits)
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

    let get_vrf_evaluation shifted ~ledger ~message =
      let open Coda_base in
      let open Snark_params.Tick in
      let open Let_syntax in
      let%bind private_key =
        request_witness Scalar.typ (As_prover.return Private_key)
      in
      let winner_addr = message.Message.delegator in
      let%bind account = Frozen_ledger_hash.get ledger winner_addr in
      let%bind delegate = Public_key.decompress_var account.delegate in
      let%map evaluation =
        T.Checked.eval_and_check_public_key shifted ~private_key
          ~public_key:delegate message
      in
      (evaluation, account.balance)

    module Checked = struct
      let check shifted ~(epoch_ledger : Epoch_ledger.var) ~epoch ~slot ~seed
          ~lock_checkpoint =
        let open Snark_params.Tick in
        let open Let_syntax in
        let%bind winner_addr =
          request_witness Coda_base.Account.Index.Unpacked.typ
            (As_prover.return Winner_address)
        in
        let%bind result, my_stake =
          get_vrf_evaluation shifted ~ledger:epoch_ledger.hash
            ~message:
              { Message.epoch
              ; slot
              ; seed
              ; lock_checkpoint
              ; delegator= winner_addr }
        in
        let%map satisifed =
          Threshold.Checked.is_satisfied ~my_stake
            ~total_stake:epoch_ledger.total_currency result
        in
        (satisifed, result)
    end

    let check ~local_state ~epoch ~slot ~seed ~lock_checkpoint ~private_key
        ~total_stake ~ledger_hash ~logger =
      let open Message in
      let open Option.Let_syntax in
      let%bind ledger =
        if Coda_base.Frozen_ledger_hash.equal ledger_hash genesis_ledger_hash
        then Some Genesis_ledger.t
        else local_state.Local_state.last_epoch_ledger
      in
      Logger.info logger "Checking vrf evaluations at %d:%d"
        (Epoch.to_int epoch) (Epoch.Slot.to_int slot) ;
      with_return (fun {return} ->
          Hashtbl.iteri local_state.delegators
            ~f:(fun ~key:delegator ~data:balance ->
              let vrf_result =
                T.eval ~private_key
                  {epoch; slot; seed; lock_checkpoint; delegator}
              in
              Logger.info logger
                !"vrf result for %d: %d/%d -> %{sexp: Bignum_bigint.t}"
                (Coda_base.Account.Index.to_int delegator)
                (Balance.to_int balance)
                (Amount.to_int total_stake)
                (Bignum_bigint.of_bit_fold_lsb
                   (Sha256.Digest.fold_bits vrf_result)) ;
              if
                Threshold.is_satisfied ~my_stake:balance ~total_stake
                  vrf_result
              then
                return
                  (Some
                     { Proposal_data.stake_proof=
                         { private_key
                         ; delegator
                         ; ledger=
                             Coda_base.Sparse_ledger.of_ledger_index_subset_exn
                               ledger [delegator] }
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
    [@@deriving sexp, bin_io, eq, compare, hash]

    type value =
      (Epoch_ledger.value, Epoch_seed.t, Coda_base.State_hash.t, Length.t) t
    [@@deriving sexp, bin_io, eq, compare, hash]

    type var =
      ( Epoch_ledger.var
      , Epoch_seed.var
      , Coda_base.State_hash.var
      , Length.Unpacked.var )
      t

    let to_hlist {ledger; seed; start_checkpoint; lock_checkpoint; length} =
      Coda_base.H_list.
        [ledger; seed; start_checkpoint; lock_checkpoint; length]

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

    let typ =
      Snark_params.Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
        ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist

    let var_to_triples {ledger; seed; start_checkpoint; lock_checkpoint; length}
        =
      let open Snark_params.Tick.Let_syntax in
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
      let open Snark_params.Tick.Let_syntax in
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
      ; length= Length.zero }

    let update_pair (last_data, curr_data) epoch_length ~prev_epoch ~next_epoch
        ~curr_slot ~prev_protocol_state_hash ~proposer_vrf_result
        ~snarked_ledger_hash ~total_currency =
      let open Epoch_ledger in
      let last_data, curr_data, epoch_length =
        if next_epoch > prev_epoch then
          ( curr_data
          , { seed= Epoch_seed.initial
            ; ledger= {hash= snarked_ledger_hash; total_currency}
            ; start_checkpoint= prev_protocol_state_hash
            ; lock_checkpoint= Coda_base.State_hash.(of_hash zero)
            ; length= Length.zero }
          , Length.succ epoch_length )
        else (
          assert (Epoch.equal next_epoch prev_epoch) ;
          (last_data, curr_data, epoch_length) )
      in
      let curr_seed, curr_lock_checkpoint =
        if Epoch.Slot.in_seed_update_range curr_slot then
          ( Epoch_seed.update curr_data.seed proposer_vrf_result
          , prev_protocol_state_hash )
        else (curr_data.seed, curr_data.lock_checkpoint)
      in
      let curr_data =
        {curr_data with seed= curr_seed; lock_checkpoint= curr_lock_checkpoint}
      in
      (last_data, curr_data, epoch_length)

    let _update_pair_checked (last_data, curr_data) epoch_length ~prev_epoch
        ~next_epoch ~next_slot:_ ~curr_slot ~prev_protocol_state_hash
        ~proposer_vrf_result ~new_ledger_hash ~new_total_currency =
      let open Snark_params.Tick in
      let open Let_syntax in
      let%bind last_data, curr_data, epoch_length =
        let%bind epoch_increased =
          let%bind c = Epoch.compare_var prev_epoch next_epoch in
          let%map () = Boolean.Assert.is_true c.less_or_equal in
          c.less
        in
        let%map last_data =
          if_ epoch_increased ~then_:curr_data ~else_:last_data
        and curr_data =
          if_ epoch_increased
            ~then_:
              { seed= Epoch_seed.(var_of_t initial)
              ; ledger=
                  {hash= new_ledger_hash; total_currency= new_total_currency}
              ; start_checkpoint= prev_protocol_state_hash
              ; lock_checkpoint= Coda_base.State_hash.(var_of_t (of_hash zero))
              ; length= Length.Unpacked.var_of_value Length.zero }
            ~else_:curr_data
        and epoch_length =
          Length.increment_if_var epoch_length epoch_increased
        in
        (last_data, curr_data, epoch_length)
      in
      let%map curr_seed, curr_lock_checkpoint =
        let%bind updated_curr_seed =
          Epoch_seed.update_var curr_data.seed proposer_vrf_result
        and in_seed_update_range =
          (* TODO: Should this be next_slot? *)
          Epoch.Slot.in_seed_update_range_var curr_slot
        in
        let%map curr_seed =
          Epoch_seed.if_ in_seed_update_range ~then_:updated_curr_seed
            ~else_:curr_data.seed
        and curr_lock_checkpoint =
          Coda_base.State_hash.if_ in_seed_update_range
            ~then_:prev_protocol_state_hash ~else_:curr_data.lock_checkpoint
        in
        (curr_seed, curr_lock_checkpoint)
      in
      let curr_data =
        {curr_data with seed= curr_seed; lock_checkpoint= curr_lock_checkpoint}
      in
      (last_data, curr_data, epoch_length)
  end

  module Consensus_transition_data = struct
    type ('epoch, 'slot) t = {epoch: 'epoch; slot: 'slot}
    [@@deriving sexp, bin_io, compare]

    type value = (Epoch.t, Epoch.Slot.t) t [@@deriving sexp, bin_io, compare]

    type var = (Epoch.Unpacked.var, Epoch.Slot.Unpacked.var) t

    let genesis = {epoch= Epoch.zero; slot= Epoch.Slot.zero}

    let to_hlist {epoch; slot} = Coda_base.H_list.[epoch; slot]

    let of_hlist :
        (unit, 'epoch -> 'slot -> unit) Coda_base.H_list.t -> ('epoch, 'slot) t
        =
     fun Coda_base.H_list.([epoch; slot]) -> {epoch; slot}

    let data_spec =
      let open Snark_params.Tick.Data_spec in
      [Epoch.Unpacked.typ; Epoch.Slot.Unpacked.typ]

    let typ =
      Snark_params.Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
        ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist
  end

  module Consensus_state = struct
    type ('length, 'amount, 'epoch, 'slot, 'epoch_data) t =
      { length: 'length
      ; epoch_length: 'length
      ; total_currency: 'amount
      ; curr_epoch: 'epoch
      ; curr_slot: 'slot
      ; last_epoch_data: 'epoch_data
      ; curr_epoch_data: 'epoch_data }
    [@@deriving sexp, bin_io, eq, compare, hash]

    type value =
      (Length.t, Amount.t, Epoch.t, Epoch.Slot.t, Epoch_data.value) t
    [@@deriving sexp, bin_io, eq, compare, hash]

    type var =
      ( Length.Unpacked.var
      , Amount.var
      , Epoch.Unpacked.var
      , Epoch.Slot.Unpacked.var
      , Epoch_data.var )
      t

    let to_hlist
        { length
        ; epoch_length
        ; total_currency
        ; curr_epoch
        ; curr_slot
        ; last_epoch_data
        ; curr_epoch_data } =
      let open Coda_base.H_list in
      [ length
      ; epoch_length
      ; total_currency
      ; curr_epoch
      ; curr_slot
      ; last_epoch_data
      ; curr_epoch_data ]

    let of_hlist :
           ( unit
           ,    'length
             -> 'length
             -> 'amount
             -> 'epoch
             -> 'slot
             -> 'epoch_data
             -> 'epoch_data
             -> unit )
           Coda_base.H_list.t
        -> ('length, 'amount, 'epoch, 'slot, 'epoch_data) t =
     fun Coda_base.H_list.([ length
                           ; epoch_length
                           ; total_currency
                           ; curr_epoch
                           ; curr_slot
                           ; last_epoch_data
                           ; curr_epoch_data ]) ->
      { length
      ; epoch_length
      ; total_currency
      ; curr_epoch
      ; curr_slot
      ; last_epoch_data
      ; curr_epoch_data }

    let data_spec =
      let open Snark_params.Tick.Data_spec in
      [ Length.Unpacked.typ
      ; Length.Unpacked.typ
      ; Amount.typ
      ; Epoch.Unpacked.typ
      ; Epoch.Slot.Unpacked.typ
      ; Epoch_data.typ
      ; Epoch_data.typ ]

    let typ =
      Snark_params.Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
        ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist

    let var_to_triples
        { length
        ; epoch_length
        ; total_currency
        ; curr_epoch
        ; curr_slot
        ; last_epoch_data
        ; curr_epoch_data } =
      let open Snark_params.Tick.Let_syntax in
      let%map last_epoch_data_triples =
        Epoch_data.var_to_triples last_epoch_data
      and curr_epoch_data_triples =
        Epoch_data.var_to_triples curr_epoch_data
      in
      Length.Unpacked.var_to_triples length
      @ Length.Unpacked.var_to_triples epoch_length
      @ Epoch.Unpacked.var_to_triples curr_epoch
      @ Epoch.Slot.Unpacked.var_to_triples curr_slot
      @ Amount.var_to_triples total_currency
      @ last_epoch_data_triples @ curr_epoch_data_triples

    let fold
        { length
        ; epoch_length
        ; curr_epoch
        ; curr_slot
        ; total_currency
        ; last_epoch_data
        ; curr_epoch_data } =
      let open Fold in
      Length.fold length +> Length.fold epoch_length +> Epoch.fold curr_epoch
      +> Epoch.Slot.fold curr_slot +> Amount.fold total_currency
      +> Epoch_data.fold last_epoch_data
      +> Epoch_data.fold curr_epoch_data

    let length_in_triples =
      Length.length_in_triples + Length.length_in_triples
      + Epoch.length_in_triples + Epoch.Slot.length_in_triples
      + Amount.length_in_triples + Epoch_data.length_in_triples
      + Epoch_data.length_in_triples

    let genesis : value =
      { length= Length.zero
      ; epoch_length= Length.zero
      ; total_currency= genesis_ledger_total_currency
      ; curr_epoch= Epoch.zero
      ; curr_slot= Epoch.Slot.zero
      ; curr_epoch_data= Epoch_data.genesis
      ; last_epoch_data= Epoch_data.genesis }

    let time_in_epoch_slot {curr_epoch; curr_slot; _} time =
      let open Time in
      Epoch.slot_start_time curr_epoch curr_slot < time
      && Epoch.slot_end_time curr_epoch curr_slot >= time

    let update ~(previous_consensus_state : value)
        ~(consensus_transition_data : Consensus_transition_data.value)
        ~(previous_protocol_state_hash : Coda_base.State_hash.t)
        ~(supply_increase : Currency.Amount.t)
        ~(snarked_ledger_hash : Coda_base.Frozen_ledger_hash.t)
        ~(proposer_vrf_result : Sha256.Digest.t) : value Or_error.t =
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
          ~curr_slot:previous_consensus_state.curr_slot
          ~prev_protocol_state_hash:previous_protocol_state_hash
          ~proposer_vrf_result ~snarked_ledger_hash ~total_currency
      in
      { length= Length.succ previous_consensus_state.length
      ; epoch_length
      ; total_currency
      ; curr_epoch= consensus_transition_data.epoch
      ; curr_slot= consensus_transition_data.slot
      ; last_epoch_data
      ; curr_epoch_data }

    let update_var (previous_state : var)
        (transition_data : Consensus_transition_data.var)
        (previous_protocol_state_hash : Coda_base.State_hash.var)
        ~(supply_increase : Currency.Amount.var)
        ~(previous_blockchain_state_ledger_hash :
           Coda_base.Frozen_ledger_hash.var) =
      let open Snark_params.Tick in
      let open Let_syntax in
      let prev_epoch = previous_state.curr_epoch in
      let next_epoch = transition_data.epoch in
      let next_slot = transition_data.slot in
      let%bind epoch_increased =
        let%bind c = Epoch.compare_var prev_epoch next_epoch in
        let%map () = Boolean.Assert.is_true c.less_or_equal in
        c.less
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
          ~lock_checkpoint:last_data.lock_checkpoint
      in
      let%bind curr_data =
        let%map seed =
          let%bind in_seed_update_range =
            Epoch.Slot.in_seed_update_range_var next_slot
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
              ~then_:Field.(Checked.constant zero)
              ~else_:
                ( Length.pack_var previous_state.curr_epoch_data.length
                  :> Field.var )
          in
          Length.var_of_field Field.(Checked.(add (constant one) base))
        and ledger =
          Epoch_ledger.if_ epoch_increased
            ~then_:
              { total_currency= previous_state.total_currency
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
      return
        ( `Success threshold_satisfied
        , { length
          ; epoch_length
          ; curr_epoch= transition_data.epoch
          ; curr_slot= transition_data.slot
          ; total_currency= new_total_currency
          ; last_epoch_data= last_data
          ; curr_epoch_data= curr_data } )

    let length (t : value) = t.length

    let to_lite = None

    let to_string_record t =
      Printf.sprintf
        "{length|%s}|{epoch_length|%s}|{curr_epoch|%s}|{curr_slot|%s}|{total_currency|%s}"
        (Length.to_string t.length)
        (Length.to_string t.epoch_length)
        (Segment_id.to_string t.curr_epoch)
        (Segment_id.to_string t.curr_slot)
        (Amount.to_string t.total_currency)
  end

  module Blockchain_state =
    Coda_base.Blockchain_state.Make (Inputs.Genesis_ledger)
  module Protocol_state =
    Coda_base.Protocol_state.Make (Blockchain_state) (Consensus_state)

  module Prover_state = struct
    include Coda_base.Stake_proof

    let handler {delegator; ledger; private_key} : Snark_params.Tick.Handler.t
        =
      let ledger_handler = unstage (Coda_base.Sparse_ledger.handler ledger) in
      fun (With {request; respond} as t) ->
        match request with
        | Vrf.Winner_address -> respond (Provide delegator)
        | Vrf.Private_key -> respond (Provide private_key)
        | _ -> ledger_handler t
  end

  module Snark_transition = Coda_base.Snark_transition.Make (struct
    module Genesis_ledger = Inputs.Genesis_ledger
    module Blockchain_state = Blockchain_state
    module Consensus_data = Consensus_transition_data
  end)

  module Internal_transition =
    Coda_base.Internal_transition.Make (Ledger_builder_diff) (Snark_transition)
      (Prover_state)
  module External_transition =
    Coda_base.External_transition.Make (Ledger_builder_diff) (Protocol_state)

  (* TODO: only track total currency from accounts > 1% of the currency using transactions *)
  let generate_transition ~(previous_protocol_state : Protocol_state.value)
      ~blockchain_state ~time ~proposal_data ~transactions:_
      ~snarked_ledger_hash ~supply_increase ~logger:_ =
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

  let next_state_checked ~(prev_state : Protocol_state.var)
      ~(prev_state_hash : Coda_base.State_hash.var) transition supply_increase
      =
    Consensus_state.update_var
      (Protocol_state.consensus_state prev_state)
      (Snark_transition.consensus_data transition)
      prev_state_hash ~supply_increase
      ~previous_blockchain_state_ledger_hash:
        ( Protocol_state.blockchain_state prev_state
        |> Blockchain_state.ledger_hash )

  let select ~existing ~candidate ~logger ~time_received =
    let open Consensus_state in
    let open Epoch_data in
    let logger = Logger.child logger "proof_of_stake" in
    let string_of_choice = function `Take -> "Take" | `Keep -> "Keep" in
    let log_result choice msg =
      Logger.debug logger "RESULT: %s -- %s" (string_of_choice choice) msg
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
    Logger.info logger "SELECTING BEST CONSENSUS STATE" ;
    Logger.info logger
      !"existing consensus state: %{sexp:Consensus_state.value}"
      existing ;
    Logger.info logger
      !"candidate consensus state: %{sexp:Consensus_state.value}"
      candidate ;
    (* TODO: update time_received check and `Keep when it is not met *)
    if
      not
        (time_in_epoch_slot candidate
           Time.(of_span_since_epoch (Span.of_ms time_received)))
    then Logger.error logger "received a transition outside of it's slot time" ;
    (* TODO: add fork_before_checkpoint check *)
    (* Each branch contains a precondition predicate and a choice predicate,
     * which takes the new state when true. Each predicate is also decorated
     * with a string description, used for debugging messages *)
    let ( = ) = Coda_base.State_hash.equal in
    let ( < ) a b = Length.compare a b < 0 in
    let branches =
      [ ( ( lazy
              ( existing.last_epoch_data.lock_checkpoint
              = candidate.last_epoch_data.lock_checkpoint )
          , "last epoch lock checkpoints are equal" )
        , ( lazy (existing.length < candidate.length)
          , "candidate is longer than existing" ) )
      ; ( ( lazy
              ( existing.last_epoch_data.start_checkpoint
              = candidate.last_epoch_data.start_checkpoint )
          , "last epoch start checkpoints are equal" )
        , ( lazy
              ( existing.last_epoch_data.length
              < candidate.last_epoch_data.length )
          , "candidate last epoch is longer than existing last epoch" ) )
        (* these two could be condensed into one entry *)
      ; ( ( lazy
              ( existing.curr_epoch_data.lock_checkpoint
              = candidate.last_epoch_data.lock_checkpoint )
          , "candidate last epoch lock checkpoint is equal to existing \
             current epoch lock checkpoint" )
        , ( lazy (existing.length < candidate.length)
          , "candidate is longer than existing" ) )
      ; ( ( lazy
              ( existing.last_epoch_data.lock_checkpoint
              = candidate.curr_epoch_data.lock_checkpoint )
          , "candidate current epoch lock checkpoint is equal to existing \
             last epoch lock checkpoint" )
        , ( lazy (existing.length < candidate.length)
          , "candidate is longer than existing" ) )
      ; ( ( lazy
              ( existing.curr_epoch_data.start_checkpoint
              = candidate.last_epoch_data.start_checkpoint )
          , "candidate last epoch start checkpoint is equal to existing \
             current epoch start checkpoint" )
        , ( lazy
              ( existing.curr_epoch_data.length
              < candidate.last_epoch_data.length )
          , "candidate last epoch is longer than existing current epoch" ) )
      ; ( ( lazy
              ( existing.last_epoch_data.start_checkpoint
              = candidate.curr_epoch_data.start_checkpoint )
          , "candidate current epoch start checkpoint is equal to existing \
             last epoch start checkpoint" )
        , ( lazy
              ( existing.last_epoch_data.length
              < candidate.curr_epoch_data.length )
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

  let next_proposal now (state : Consensus_state.value) ~local_state ~keypair
      ~logger =
    let open Consensus_state in
    let open Epoch_data in
    let open Keypair in
    let logger = Logger.child logger "proof_of_stake" in
    Logger.info logger "Checking for next proposal..." ;
    let epoch, slot =
      Epoch.epoch_and_slot_of_time_exn
        (Time.of_span_since_epoch (Time.Span.of_ms now))
    in
    let next_slot =
      (* When we first enter an epoch, the protocol state may still be a previous
       * epoch. If that is the case, we need to select the staged vrf inputs
       * instead of the last vrf inputs, since if the protocol state were actually
       * up to date with the epoch, those would be the last vrf inputs.
       *)
      let epoch_data =
        Logger.info logger
          !"Selecting correct epoch data from state -- epoch by time: %d, \
            state epoch: %d, state epoch length: %d"
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
        else if Epoch.equal epoch (Epoch.succ state.curr_epoch) then
          state.curr_epoch_data
          (* If the epoch we are in is none of the above, something is wrong. *)
        else (
          Logger.error logger
            "system time is out of sync with protocol state time" ;
          failwith
            "System time is out of sync. (hint: setup NTP if you haven't)" )
      in
      let total_stake = epoch_data.ledger.total_currency in
      let proposal_data slot =
        Vrf.check ~epoch ~slot ~seed:epoch_data.seed ~local_state
          ~lock_checkpoint:epoch_data.lock_checkpoint
          ~private_key:keypair.private_key ~total_stake
          ~ledger_hash:epoch_data.ledger.hash ~logger
      in
      let rec find_winning_slot slot =
        if UInt32.of_int (Epoch.Slot.to_int slot) >= Epoch.size then None
        else
          match proposal_data slot with
          | None -> find_winning_slot (Epoch.Slot.succ slot)
          | Some data -> Some (slot, data)
      in
      find_winning_slot (Epoch.Slot.succ slot)
    in
    match next_slot with
    | Some (next_slot, data) ->
        Logger.info logger "Proposing in %d slots"
          (Epoch.Slot.to_int next_slot - Epoch.Slot.to_int slot) ;
        `Propose
          ( Epoch.slot_start_time epoch next_slot
            |> Time.to_span_since_epoch |> Time.Span.to_ms
          , data )
    | None ->
        Logger.info logger
          "No slots won in this epoch... waiting for next epoch" ;
        `Check_again
          (Epoch.end_time epoch |> Time.to_span_since_epoch |> Time.Span.to_ms)

  (* TODO *)
  let lock_transition ?proposer_public_key prev next ~snarked_ledger
      ~local_state =
    let open Local_state in
    let open Consensus_state in
    if not (Epoch.equal prev.curr_epoch next.curr_epoch) then (
      let ledger =
        match snarked_ledger () with Ok l -> l | Error e -> Error.raise e
      in
      local_state.last_epoch_ledger <- local_state.curr_epoch_ledger ;
      ( match proposer_public_key with
      | None ->
          local_state.delegators <- Coda_base.Account.Index.Table.create ()
      | Some pk ->
          Option.iter local_state.last_epoch_ledger ~f:(fun l ->
              local_state.delegators <- compute_delegators pk l ) ) ;
      local_state.curr_epoch_ledger <- Some ledger )

  let genesis_protocol_state =
    let consensus_state =
      Or_error.ok_exn
        (Consensus_state.update
           ~proposer_vrf_result:(Sha256.digest_string "CodaInitialVRFResult")
           ~previous_consensus_state:
             Protocol_state.(consensus_state negative_one)
           ~previous_protocol_state_hash:Protocol_state.(hash negative_one)
           ~consensus_transition_data:Snark_transition.(consensus_data genesis)
           ~supply_increase:Currency.Amount.zero
           ~snarked_ledger_hash:genesis_ledger_hash)
    in
    Protocol_state.create_value
      ~previous_state_hash:Protocol_state.(hash negative_one)
      ~blockchain_state:Snark_transition.(blockchain_state genesis)
      ~consensus_state
end

let%test_module "Proof_of_stake tests" =
  ( module struct
    module Proof_of_stake = Make (struct
      module Ledger_builder_diff = struct
        type t = int [@@deriving bin_io, sexp]
      end

      module Time = Coda_base.Block_time
      module Genesis_ledger = Genesis_ledger

      let genesis_state_timestamp = Coda_base.Block_time.now ()

      let coinbase = Amount.of_int 20

      let slot_interval = Coda_base.Block_time.Span.of_ms (Int64.of_int 200)

      let unforkable_transition_count = 24

      let probable_slots_per_transition_count = 8

      let expected_network_delay =
        Coda_base.Block_time.Span.of_ms (Int64.of_int 1000)

      let approximate_network_diameter = 3
    end)
  end )
