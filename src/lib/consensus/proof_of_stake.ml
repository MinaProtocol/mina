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

  let zero = Snark_params.Tick.Pedersen.zero_hash

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

let iter_none ~f opt = match opt with None -> f () ; None | Some x -> Some x

module Make (Inputs : Inputs_intf) :
  Mechanism.S
  with type Internal_transition.Ledger_builder_diff.t =
              Inputs.Ledger_builder_diff.t
   and type External_transition.Ledger_builder_diff.t =
              Inputs.Ledger_builder_diff.t = struct
  module Ledger_builder_diff = Inputs.Ledger_builder_diff
  module Time = Inputs.Time

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

  module Local_state = struct
    type t =
      { mutable last_epoch_ledger: Coda_base.Ledger.t option
      ; mutable curr_epoch_ledger: Coda_base.Ledger.t option }
    [@@deriving sexp]

    let create () = {last_epoch_ledger= None; curr_epoch_ledger= None}
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

      let interval = Inputs.slot_interval

      let unforkable_count =
        UInt32.of_int
          ( Inputs.probable_slots_per_transition_count
          * Inputs.unforkable_transition_count )

      let in_seed_update_range (slot : t) =
        let open UInt32 in
        let open UInt32.Infix in
        let ( <= ) x y = compare x y <= 0 in
        let ( < ) x y = compare x y < 0 in
        unforkable_count <= slot && slot < unforkable_count * of_int 2

      let in_seed_update_range_var (slot : Unpacked.var) =
        let open Snark_params.Tick in
        let open Snark_params.Tick.Let_syntax in
        let open Field.Checked in
        let unforkable_count =
          Unpacked.var_of_value @@ of_int @@ UInt32.to_int unforkable_count
        and unforkable_count_times_2 =
          Unpacked.var_of_value @@ of_int
          @@ (UInt32.to_int unforkable_count * 2)
        in
        let%bind slot_gte_unforkable_count =
          compare_var unforkable_count slot >>| fun c -> c.less_or_equal
        and slot_lt_unforkable_count_times_2 =
          compare_var slot unforkable_count_times_2 >>| fun c -> c.less
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

  module Vrf = struct
    module Scalar = struct
      type value = Snark_params.Tick.Inner_curve.Scalar.t

      type var =
        Snark_params.Tick.Boolean.var Bitstring_lib.Bitstring.Lsb_first.t

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
      type ('epoch, 'slot, 'epoch_seed, 'state_hash) t =
        { epoch: 'epoch
        ; slot: 'slot
        ; seed: 'epoch_seed
        ; lock_checkpoint: 'state_hash }

      type value =
        (Epoch.t, Epoch.Slot.t, Epoch_seed.t, Coda_base.State_hash.t) t

      type var =
        ( Epoch.Unpacked.var
        , Epoch.Slot.Unpacked.var
        , Epoch_seed.var
        , Coda_base.State_hash.var )
        t

      let to_hlist {epoch; slot; seed; lock_checkpoint} =
        Coda_base.H_list.[epoch; slot; seed; lock_checkpoint]

      let of_hlist :
             ( unit
             , 'epoch -> 'slot -> 'epoch_seed -> 'state_hash -> unit )
             Coda_base.H_list.t
          -> ('epoch, 'slot, 'epoch_seed, 'state_hash) t =
       fun Coda_base.H_list.([epoch; slot; seed; lock_checkpoint]) ->
        {epoch; slot; seed; lock_checkpoint}

      let data_spec =
        let open Snark_params.Tick.Data_spec in
        [ Epoch.Unpacked.typ
        ; Epoch.Slot.Unpacked.typ
        ; Epoch_seed.typ
        ; Coda_base.State_hash.typ ]

      let typ =
        Snark_params.Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
          ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
          ~value_of_hlist:of_hlist

      let fold {epoch; slot; seed; lock_checkpoint} =
        let open Fold in
        Epoch.fold epoch +> Epoch.Slot.fold slot +> Epoch_seed.fold seed
        +> Coda_base.State_hash.fold lock_checkpoint

      let hash_to_group msg =
        let msg_hash_state =
          Snark_params.Tick.Pedersen.hash_fold
            Coda_base.Hash_prefix.vrf_message (fold msg)
        in
        msg_hash_state.acc

      module Checked = struct
        let var_to_triples {epoch; slot; seed; lock_checkpoint} =
          let open Snark_params.Tick.Let_syntax in
          let%map seed_triples = Epoch_seed.var_to_triples seed
          and lock_checkpoint_triples =
            Coda_base.State_hash.var_to_triples lock_checkpoint
          in
          Epoch.Unpacked.var_to_triples epoch
          @ Epoch.Slot.Unpacked.var_to_triples slot
          @ seed_triples @ lock_checkpoint_triples

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
        and lock_checkpoint = Coda_base.State_hash.gen in
        {epoch; slot; seed; lock_checkpoint}
    end

    module Output = struct
      type value = Sha256.Digest.t [@@deriving eq, sexp]

      type var = Sha256.Digest.var

      let typ : (var, value) Snark_params.Tick.Typ.t = Sha256.Digest.typ

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
        Sha256.digest (Snark_params.Tick.Pedersen.Digest.Bits.to_bits digest)

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

      let gen = Quickcheck.Generator.list_with_length 256 Bool.gen

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
               (fun (msg, g) -> hash msg g))
    end

    module Threshold = struct
      include Bignum_bigint

      let of_uint64_exn = Fn.compose of_int64_exn UInt64.to_int64

      let create ~owned_stake ~total_stake =
        let owned_stake = Balance.to_uint64 owned_stake in
        let total_stake = Amount.to_uint64 total_stake in
        let stake_ratio = of_uint64_exn (UInt64.div owned_stake total_stake) in
        stake_ratio * pow (of_int 2) (of_int 256)

      let satisfies threshold output = of_bits_lsb output <= threshold
    end

    include Vrf_lib.Integrated.Make (Snark_params.Tick) (Scalar) (Group)
              (Message)
              (Output)

    let check ~epoch ~slot ~seed ~lock_checkpoint ~private_key ~owned_stake
        ~total_stake ~logger =
      let open Message in
      let result = eval ~private_key {epoch; slot; seed; lock_checkpoint} in
      let threshold = Threshold.create ~owned_stake ~total_stake in
      Logger.info logger
        !"Checking vrf at %d:%d - owned_stake: %d, total_stake: %d, \
          evaluation: %{sexp: Output.value}, threshold: %{sexp: Threshold.t}"
        (Epoch.to_int epoch) (Epoch.Slot.to_int slot)
        (Balance.to_int owned_stake)
        (Amount.to_int total_stake)
        result threshold ;
      Option.some_if (Threshold.satisfies threshold result) result
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

    let get_stake ~logger ~public_key ~local_state {hash; total_currency} =
      let open Local_state in
      let open Option.Let_syntax in
      let%bind ledger =
        if Coda_base.Frozen_ledger_hash.equal hash genesis_ledger_hash then
          Some Genesis_ledger.t
        else
          let%bind last_epoch_ledger = local_state.last_epoch_ledger in
          let last_epoch_ledger_hash =
            Coda_base.Frozen_ledger_hash.of_ledger_hash
              (Coda_base.Ledger.merkle_root last_epoch_ledger)
          in
          if Coda_base.Frozen_ledger_hash.equal hash last_epoch_ledger_hash
          then Some last_epoch_ledger
          else None
      in
      let%map account_location =
        Coda_base.Ledger.location_of_key ledger
          (Public_key.compress public_key)
        |> iter_none ~f:(fun () ->
               Logger.warn logger "no account associated with public key" )
      in
      let balance =
        Coda_base.Ledger.get ledger account_location
        |> Option.map ~f:Coda_base.Account.balance
        |> Option.value ~default:Balance.zero
      in
      (balance, total_currency)
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
      ; seed= Epoch_seed.(of_hash zero)
      ; start_checkpoint= Coda_base.State_hash.(of_hash zero)
      ; lock_checkpoint= Coda_base.State_hash.(of_hash zero)
      ; length= Length.zero }

    let update_pair (last_data, curr_data) epoch_length ~prev_epoch ~next_epoch
        ~next_slot ~prev_protocol_state_hash ~proposer_vrf_result ~ledger_hash
        ~total_currency =
      let open Epoch_ledger in
      let last_data, curr_data, epoch_length =
        if next_epoch > prev_epoch then
          ( curr_data
          , { seed= Epoch_seed.(of_hash zero)
            ; ledger= {hash= ledger_hash; total_currency}
            ; start_checkpoint= prev_protocol_state_hash
            ; lock_checkpoint= Coda_base.State_hash.(of_hash zero)
            ; length= Length.zero }
          , Length.succ epoch_length )
        else (last_data, curr_data, epoch_length)
      in
      let curr_seed, curr_lock_checkpoint =
        if Epoch.Slot.in_seed_update_range next_slot then
          ( Epoch_seed.update curr_data.seed proposer_vrf_result
          , prev_protocol_state_hash )
        else (curr_data.seed, curr_data.lock_checkpoint)
      in
      let curr_data =
        {curr_data with seed= curr_seed; lock_checkpoint= curr_lock_checkpoint}
      in
      (last_data, curr_data, epoch_length)

    let update_pair_checked (last_data, curr_data) epoch_length ~prev_epoch
        ~next_epoch ~next_slot ~prev_protocol_state_hash ~proposer_vrf_result
        ~ledger_hash ~total_currency =
      let open Snark_params.Tick.Let_syntax in
      let%bind last_data, curr_data, epoch_length =
        let%bind epoch_changed =
          Epoch.compare_var prev_epoch next_epoch >>| fun c -> c.less
        in
        let%map last_data = if_ epoch_changed ~then_:curr_data ~else_:last_data
        and curr_data =
          if_ epoch_changed
            ~then_:
              { seed= Epoch_seed.(var_of_t (of_hash zero))
              ; ledger= {hash= ledger_hash; total_currency}
              ; start_checkpoint= prev_protocol_state_hash
              ; lock_checkpoint= Coda_base.State_hash.(var_of_t (of_hash zero))
              ; length= Length.Unpacked.var_of_value Length.zero }
            ~else_:curr_data
        and epoch_length =
          Length.increment_if_var epoch_length epoch_changed
        in
        (last_data, curr_data, epoch_length)
      in
      let%map curr_seed, curr_lock_checkpoint =
        let%bind updated_curr_seed =
          Epoch_seed.update_var curr_data.seed proposer_vrf_result
        and in_seed_update_range =
          Epoch.Slot.in_seed_update_range_var next_slot
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
    type ('epoch, 'slot, 'vrf_result) t =
      {epoch: 'epoch; slot: 'slot; proposer_vrf_result: 'vrf_result}
    [@@deriving sexp, bin_io, eq, compare]

    type value = (Epoch.t, Epoch.Slot.t, Sha256.Digest.t) t
    [@@deriving sexp, bin_io, eq, compare]

    type var =
      (Epoch.Unpacked.var, Epoch.Slot.Unpacked.var, Sha256.Digest.var) t

    let genesis =
      { epoch= Epoch.zero
      ; slot= Epoch.Slot.zero
      ; proposer_vrf_result= List.init 256 ~f:(fun _ -> false) }

    let to_hlist {epoch; slot; proposer_vrf_result} =
      Coda_base.H_list.[epoch; slot; proposer_vrf_result]

    let of_hlist :
           (unit, 'epoch -> 'slot -> 'vrf_result -> unit) Coda_base.H_list.t
        -> ('epoch, 'slot, 'vrf_result) t =
     fun Coda_base.H_list.([epoch; slot; proposer_vrf_result]) ->
      {epoch; slot; proposer_vrf_result}

    let data_spec =
      let open Snark_params.Tick.Data_spec in
      [Epoch.Unpacked.typ; Epoch.Slot.Unpacked.typ; Sha256.Digest.typ]

    let typ =
      Snark_params.Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
        ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist

    let fold {epoch; slot; proposer_vrf_result} =
      let open Fold in
      Epoch.fold epoch +> Epoch.Slot.fold slot
      +> Sha256.Digest.fold proposer_vrf_result

    let var_to_triples {epoch; slot; proposer_vrf_result} =
      Epoch.Unpacked.var_to_triples epoch
      @ Epoch.Slot.Unpacked.var_to_triples slot
      @ proposer_vrf_result

    let length_in_triples =
      Epoch.length_in_triples + Epoch.Slot.length_in_triples
      + Sha256.Digest.length_in_triples
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
        ~(ledger_hash : Coda_base.Frozen_ledger_hash.t) : value Or_error.t =
      let open Or_error.Let_syntax in
      let open Consensus_transition_data in
      let%map total_currency =
        Amount.add previous_consensus_state.total_currency Inputs.coinbase
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
          ~next_slot:consensus_transition_data.slot
          ~prev_protocol_state_hash:previous_protocol_state_hash
          ~proposer_vrf_result:consensus_transition_data.proposer_vrf_result
          ~ledger_hash ~total_currency
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
        (ledger_hash : Coda_base.Frozen_ledger_hash.var) :
        (var, _) Snark_params.Tick.Checked.t =
      let open Snark_params.Tick.Let_syntax in
      let%bind length = Length.increment_var previous_state.length
      (* TODO: keep track of total_currency in transaction snark. The current_slot
       * implementation would allow an adversary to make then total_currency incorrect by
       * not adding the coinbase to their account. *)
      and total_currency =
        Amount.Checked.add previous_state.total_currency
          (Amount.var_of_t Inputs.coinbase)
      in
      (* TODO: check vrf result from transition data *)
      let%map last_epoch_data, curr_epoch_data, epoch_length =
        Epoch_data.update_pair_checked
          (previous_state.last_epoch_data, previous_state.curr_epoch_data)
          previous_state.epoch_length ~prev_epoch:previous_state.curr_epoch
          ~next_epoch:transition_data.epoch ~next_slot:transition_data.slot
          ~prev_protocol_state_hash:previous_protocol_state_hash
          ~proposer_vrf_result:transition_data.proposer_vrf_result ~ledger_hash
          ~total_currency
      in
      { length
      ; epoch_length
      ; curr_epoch= transition_data.epoch
      ; curr_slot= transition_data.slot
      ; total_currency
      ; last_epoch_data
      ; curr_epoch_data }

    let length (t : value) = t.length

    let to_lite = None
  end

  module Blockchain_state =
    Coda_base.Blockchain_state.Make (Inputs.Genesis_ledger)
  module Protocol_state =
    Coda_base.Protocol_state.Make (Blockchain_state) (Consensus_state)

  module Snark_transition = Coda_base.Snark_transition.Make (struct
    module Genesis_ledger = Inputs.Genesis_ledger
    module Blockchain_state = Blockchain_state
    module Consensus_data = Consensus_transition_data
  end)

  module Internal_transition =
    Coda_base.Internal_transition.Make (Ledger_builder_diff) (Snark_transition)
  module External_transition =
    Coda_base.External_transition.Make (Ledger_builder_diff) (Protocol_state)

  (* TODO: only track total currency from accounts > 1% of the currency using transactions *)
  let generate_transition ~(previous_protocol_state : Protocol_state.value)
      ~blockchain_state ~local_state ~time ~keypair ~transactions:_ ~ledger
      ~logger =
    let open Consensus_state in
    let open Epoch_data in
    let open Keypair in
    let open Option.Let_syntax in
    let previous_consensus_state =
      Protocol_state.consensus_state previous_protocol_state
    in
    let time = Time.of_span_since_epoch (Time.Span.of_ms time) in
    let epoch, slot = Epoch.epoch_and_slot_of_time_exn time in
    let%bind proposer_stake, total_stake =
      Epoch_ledger.get_stake previous_consensus_state.last_epoch_data.ledger
        ~logger ~public_key:keypair.public_key ~local_state
    in
    let%map proposer_vrf_result =
      Vrf.check ~epoch ~slot
        ~seed:previous_consensus_state.last_epoch_data.seed
        ~lock_checkpoint:
          previous_consensus_state.last_epoch_data.lock_checkpoint
        ~private_key:keypair.private_key ~owned_stake:proposer_stake
        ~total_stake ~logger
    in
    let consensus_transition_data =
      Consensus_transition_data.{epoch; slot; proposer_vrf_result}
    in
    let consensus_state =
      Or_error.ok_exn
        (Consensus_state.update ~previous_consensus_state
           ~consensus_transition_data
           ~previous_protocol_state_hash:
             (Protocol_state.hash previous_protocol_state)
           ~ledger_hash:
             ( Coda_base.Ledger.merkle_root ledger
             |> Coda_base.Frozen_ledger_hash.of_ledger_hash ))
    in
    let protocol_state =
      Protocol_state.create_value
        ~previous_state_hash:(Protocol_state.hash previous_protocol_state)
        ~blockchain_state ~consensus_state
    in
    (protocol_state, consensus_transition_data)

  let is_transition_valid_checked _transition =
    Snark_params.Tick.(Let_syntax.return Boolean.true_)

  let next_state_checked previous_state previous_state_hash transition =
    Consensus_state.update_var previous_state
      (Snark_transition.consensus_data transition)
      previous_state_hash
      ( transition |> Snark_transition.blockchain_state
      |> Blockchain_state.ledger_hash )

  let select this that ~logger ~time_received =
    let open Consensus_state in
    let open Epoch_data in
    let logger = Logger.child logger "proof_of_stake" in
    (* TODO: update time_received check and `Keep when it is not met *)
    if
      not
        (time_in_epoch_slot that
           Time.(of_span_since_epoch (Span.of_ms time_received)))
    then Logger.error logger "received a transition outside of it's slot time" ;
    (* TODO: add fork_before_checkpoint check *)
    (* not (List.exists this.checkpoints ~f:(fun c ->
     *   List.exists that.checkpoints ~f:(
     *     Coda_base.State_hash.equal c)))
     *)
    if
      Coda_base.State_hash.equal this.last_epoch_data.lock_checkpoint
        that.last_epoch_data.lock_checkpoint
    then if Length.compare this.length that.length < 0 then `Take else `Keep
    else if
      Coda_base.State_hash.equal this.last_epoch_data.start_checkpoint
        that.last_epoch_data.start_checkpoint
    then
      if
        Length.compare this.last_epoch_data.length that.last_epoch_data.length
        < 0
      then `Take
      else `Keep
    else `Keep

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
      let open Option.Let_syntax in
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
      let%bind proposer_stake, total_stake =
        Epoch_ledger.get_stake epoch_data.ledger ~logger
          ~public_key:keypair.public_key ~local_state
      in
      Logger.info logger "Theoretical chance of winning a slot: %f"
        ( (float_of_int @@ Balance.to_int proposer_stake)
        /. (float_of_int @@ Amount.to_int total_stake) ) ;
      let is_winning_slot slot =
        Option.is_some
          (Vrf.check ~epoch ~slot ~seed:epoch_data.seed
             ~lock_checkpoint:epoch_data.lock_checkpoint
             ~private_key:keypair.private_key ~owned_stake:proposer_stake
             ~total_stake ~logger)
      in
      let rec find_winning_slot slot =
        if UInt32.of_int (Epoch.Slot.to_int slot) >= Epoch.size then None
        else if is_winning_slot slot then Some slot
        else find_winning_slot (Epoch.Slot.succ slot)
      in
      find_winning_slot (Epoch.Slot.succ slot)
    in
    match next_slot with
    | Some next_slot ->
        Logger.info logger "Proposing in %d slots"
          (Epoch.Slot.to_int next_slot - Epoch.Slot.to_int slot) ;
        `Propose
          ( Epoch.slot_start_time epoch next_slot
          |> Time.to_span_since_epoch |> Time.Span.to_ms )
    | None ->
        Logger.info logger
          "No slots won in this epoch... waiting for next epoch" ;
        `Check_again
          (Epoch.end_time epoch |> Time.to_span_since_epoch |> Time.Span.to_ms)

  (* TODO *)
  let lock_transition prev next ~snarked_ledger ~local_state =
    let open Local_state in
    let open Consensus_state in
    if not (Epoch.equal prev.curr_epoch next.curr_epoch) then (
      let ledger =
        match snarked_ledger () with Ok l -> l | Error e -> Error.raise e
      in
      local_state.last_epoch_ledger <- local_state.curr_epoch_ledger ;
      local_state.curr_epoch_ledger <- Some ledger )

  (* TODO: determine correct definition of genesis state *)
  let genesis_protocol_state =
    let consensus_state =
      Or_error.ok_exn
        (Consensus_state.update
           ~previous_consensus_state:
             Protocol_state.(consensus_state negative_one)
           ~previous_protocol_state_hash:Protocol_state.(hash negative_one)
           ~consensus_transition_data:Snark_transition.(consensus_data genesis)
           ~ledger_hash:genesis_ledger_hash)
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
