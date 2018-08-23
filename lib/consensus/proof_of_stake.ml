open Core_kernel
open Signed
open Unsigned
open Coda_numbers
open Currency
open Sha256_lib

module type Inputs_intf = sig
  module Proof : sig
    type t [@@deriving bin_io, sexp]
  end

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

  val genesis_state_timestamp : Time.t

  val genesis_ledger_total_currency : Amount.t

  val coinbase : Amount.t

  val slot_interval : Time.Span.t

  val unforkable_transition_count : int

  val probable_slots_per_transition_count : int
end

module Segment_id = Nat.Make32 ()

module Epoch_seed = struct
  include Nanobit_base.Data_hash.Make_full_size ()

  let zero = Snark_params.Tick.Pedersen.zero_hash

  let update seed vrf_result =
    let open Nanobit_base.Util in
    let open Snark_params.Tick in
    let fold_hash = fold seed +> List.fold vrf_result in
    of_hash (Pedersen.digest_fold Nanobit_base.Hash_prefix.epoch_seed fold_hash)
end

let uint32_of_int64 x = x |> Int64.to_int64 |> UInt32.of_int64

let int64_of_uint32 x = x |> UInt32.to_int64 |> Int64.of_int64

module Make (Inputs : Inputs_intf) : Mechanism.S = struct
  module Proof = Inputs.Proof
  module Ledger_builder_diff = Inputs.Ledger_builder_diff
  module Time = Inputs.Time

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

    let start_time (epoch: t) =
      let ms =
        let open Int64.Infix in
        Time.Span.to_ms
          (Time.to_span_since_epoch Inputs.genesis_state_timestamp)
        + (int64_of_uint32 epoch * Time.Span.to_ms interval)
      in
      Time.of_span_since_epoch (Time.Span.of_ms ms)

    let end_time (epoch: t) = Time.add (start_time epoch) interval

    module Slot = struct
      include Segment_id

      let interval = Inputs.slot_interval

      let unforkable_count = UInt32.of_int (Inputs.probable_slots_per_transition_count * Inputs.unforkable_transition_count)

      let in_seed_update_range (slot : t) =
        let open UInt32 in
        let open UInt32.Infix in
        let (<=) x y = compare x y <= 0 in
        let (<) x y = compare x y < 0 in
        unforkable_count <= slot && slot < unforkable_count * of_int 2
    end

    let slot_start_time (epoch: t) (slot: Slot.t) =
      Time.add (start_time epoch)
        (Time.Span.of_ms
           Int64.Infix.(int64_of_uint32 slot * Time.Span.to_ms Slot.interval))

    let slot_end_time (epoch: t) (slot: Slot.t) =
      Time.add (slot_start_time epoch slot) Slot.interval

    let epoch_and_slot_of_time_exn t : t * Slot.t =
      let epoch = of_time_exn t in
      let time_since_epoch = Time.diff t (start_time epoch) in
      let slot =
        uint32_of_int64
        @@
        Int64.Infix.(
          Time.Span.to_ms time_since_epoch / Time.Span.to_ms Slot.interval)
      in
      (epoch, slot)
  end

  module Consensus_transition_data = struct
    type ('epoch, 'slot, 'amount, 'vrf_result) t =
      { epoch: 'epoch
      ; slot: 'slot
      ; total_currency_diff: 'amount
      ; proposer_vrf_result: 'vrf_result }
    [@@deriving sexp, bin_io, eq, compare]

    type value = (Epoch.t, Epoch.Slot.t, Amount.t, Sha256.Digest.t) t
    [@@deriving sexp, bin_io, eq, compare]

    type var =
      ( Epoch.Unpacked.var
      , Epoch.Slot.Unpacked.var
      , Amount.var
      , Sha256.Digest.var )
      t

    let genesis =
      { epoch= Epoch.zero
      ; slot= Epoch.Slot.zero
      ; total_currency_diff= Amount.zero
      ; proposer_vrf_result= List.init 256 ~f:(fun _ -> false) }

    let to_hlist {epoch; slot; total_currency_diff; proposer_vrf_result} =
      let open Nanobit_base.H_list in
      [epoch; slot; total_currency_diff; proposer_vrf_result]

    let of_hlist :
           ( unit
           , 'epoch -> 'slot -> 'amount -> 'vrf_result -> unit )
           Nanobit_base.H_list.t
        -> ('epoch, 'slot, 'amount, 'vrf_result) t =
     fun Nanobit_base.H_list.([ epoch
                              ; slot
                              ; total_currency_diff
                              ; proposer_vrf_result ]) ->
      {epoch; slot; total_currency_diff; proposer_vrf_result}

    let data_spec =
      let open Snark_params.Tick.Data_spec in
      [ Epoch.Unpacked.typ
      ; Epoch.Slot.Unpacked.typ
      ; Amount.typ
      ; Sha256.Digest.typ ]

    let typ =
      Snark_params.Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
        ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist

    let fold {epoch; slot; total_currency_diff; proposer_vrf_result} =
      let open Nanobit_base.Util in
      Epoch.Bits.fold epoch +> Epoch.Slot.Bits.fold slot
      +> Amount.fold total_currency_diff
      +> Sha256.Digest.fold proposer_vrf_result

    let var_to_bits {epoch; slot; total_currency_diff; proposer_vrf_result} =
      Epoch.Unpacked.var_to_bits epoch
      @ Epoch.Slot.Unpacked.var_to_bits slot
      @ ( total_currency_diff |> Amount.var_to_bits
        |> Bitstring_lib.Bitstring.Lsb_first.to_list )
      @ proposer_vrf_result

    let bit_length =
      Epoch.length_in_bits + Epoch.Slot.length_in_bits + Amount.length
      + Sha256.Digest.length_in_bits
  end

  module Consensus_state = struct
    type ('length, 'epoch, 'slot, 'amount, 'epoch_seed) t =
      { length: 'length
      ; current_epoch: 'epoch
      ; current_slot: 'slot
      ; total_currency: 'amount
      ; epoch_seed: 'epoch_seed
      ; next_epoch_seed: 'epoch_seed }
    [@@deriving sexp, bin_io, eq, compare, hash]

    type value = (Length.t, Epoch.t, Epoch.Slot.t, Amount.t, Epoch_seed.t) t
    [@@deriving sexp, bin_io, eq, compare, hash]

    type var =
      ( Length.Unpacked.var
      , Epoch.Unpacked.var
      , Epoch.Slot.Unpacked.var
      , Amount.var
      , Epoch_seed.var )
      t

    let genesis : value =
      { length= Length.zero
      ; current_epoch= Epoch.zero
      ; current_slot= Epoch.Slot.zero
      ; total_currency=
          Inputs.genesis_ledger_total_currency
          (* TODO: epoch_seed needs to be non-determinable by o1-labs before mainnet launch *)
      ; epoch_seed= Epoch_seed.of_hash Epoch_seed.zero
      ; next_epoch_seed= Epoch_seed.of_hash Epoch_seed.zero }

    let update (previous_state : value) (transition_data : Consensus_transition_data.value) : value Or_error.t =
      let open Or_error.Let_syntax in
      let open Consensus_transition_data in
      let%map total_currency =
        Amount.add previous_state.total_currency
          transition_data.total_currency_diff
        |> Option.map ~f:Or_error.return
        |> Option.value
             ~default:(Or_error.error_string "failed to add total_currency")
      in
      let epoch_seed, next_epoch_seed =
        if transition_data.epoch = previous_state.current_epoch then
          (previous_state.epoch_seed, previous_state.next_epoch_seed)
        else
          (previous_state.next_epoch_seed, Epoch_seed.of_hash Epoch_seed.zero)
      in
      let next_epoch_seed =
        if not (Epoch.Slot.in_seed_update_range transition_data.slot) then next_epoch_seed else
          Epoch_seed.update next_epoch_seed transition_data.proposer_vrf_result
      in
      { length= Length.succ previous_state.length
      ; current_epoch= transition_data.epoch
      ; current_slot= transition_data.slot
      ; total_currency
      ; epoch_seed
      ; next_epoch_seed }

    let to_hlist
        { length
        ; current_epoch
        ; current_slot
        ; total_currency
        ; epoch_seed
        ; next_epoch_seed } =
      let open Nanobit_base.H_list in
      [ length
      ; current_epoch
      ; current_slot
      ; total_currency
      ; epoch_seed
      ; next_epoch_seed ]

    let of_hlist :
           ( unit
           ,    'length
             -> 'epoch
             -> 'slot
             -> 'amount
             -> 'epoch_seed
             -> 'epoch_seed
             -> unit )
           Nanobit_base.H_list.t
        -> ('length, 'epoch, 'slot, 'amount, 'epoch_seed) t =
     fun Nanobit_base.H_list.([ length
                              ; current_epoch
                              ; current_slot
                              ; total_currency
                              ; epoch_seed
                              ; next_epoch_seed ]) ->
      { length
      ; current_epoch
      ; current_slot
      ; total_currency
      ; epoch_seed
      ; next_epoch_seed }

    let data_spec =
      let open Snark_params.Tick.Data_spec in
      [ Length.Unpacked.typ
      ; Epoch.Unpacked.typ
      ; Epoch.Slot.Unpacked.typ
      ; Amount.typ
      ; Epoch_seed.typ
      ; Epoch_seed.typ ]

    let typ =
      Snark_params.Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
        ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist

    let var_to_bits
        { length
        ; current_epoch
        ; current_slot
        ; total_currency
        ; epoch_seed
        ; next_epoch_seed } =
      let open Snark_params.Tick.Let_syntax in
      let%map epoch_seed_bits = Epoch_seed.var_to_bits epoch_seed
      and next_epoch_seed_bits = Epoch_seed.var_to_bits next_epoch_seed in
      Length.Unpacked.var_to_bits length
      @ Epoch.Unpacked.var_to_bits current_epoch
      @ Epoch.Slot.Unpacked.var_to_bits current_slot
      @ ( total_currency |> Amount.var_to_bits
        |> Bitstring_lib.Bitstring.Lsb_first.to_list )
      @ epoch_seed_bits @ next_epoch_seed_bits

    let fold
        { length
        ; current_epoch
        ; current_slot
        ; total_currency
        ; epoch_seed
        ; next_epoch_seed } =
      let open Nanobit_base.Util in
      Length.Bits.fold length
      +> Epoch.Bits.fold current_epoch
      +> Epoch.Slot.Bits.fold current_slot
      +> Amount.fold total_currency +> Epoch_seed.fold epoch_seed
      +> Epoch_seed.fold next_epoch_seed

    let bit_length =
      Length.length_in_bits + Epoch.length_in_bits + Epoch.Slot.length_in_bits
      + Amount.length + Epoch_seed.length_in_bits + Epoch_seed.length_in_bits
  end

  module Protocol_state = Nanobit_base.Protocol_state.Make (Consensus_state)
  module Snark_transition =
    Nanobit_base.Snark_transition.Make (Consensus_transition_data) (Proof)
  module Internal_transition =
    Nanobit_base.Internal_transition.Make (Ledger_builder_diff)
      (Snark_transition)
  module External_transition =
    Nanobit_base.External_transition.Make (Ledger_builder_diff)
      (Protocol_state)

  let verify _transition = Snark_params.Tick.(Let_syntax.return Boolean.true_)

  let update_var state _transition = Snark_params.Tick.Let_syntax.return state

  let update (previous_state: Consensus_state.value)
      (transition: Snark_transition.value) =
    Consensus_state.update previous_state
      (Snark_transition.consensus_data transition)

  let step = Async_kernel.Deferred.Or_error.return

  let select _curr _cand = `Keep

  (*
  let select curr cand =
    let cand_fork_before_checkpoint =
      not (List.exists curr.checkpoints ~f:(fun c ->
        List.exists cand.checkpoints ~f:(checkpoint_equal c)))
    in
    let cand_is_valid =
      (* shouldn't the proof have already been checked before this point? *)
      verify cand.proof?
      && Time.less_than (Epoch.Slot.start_time (cand.epoch, cand.slot)) time_of_reciept
      && Time.greater_than_equal (Epoch.Slot.end_time (cand.epoch, cand.slot)) time_of_reciept
      && check cand.state?
    in
    if not cand_fork_before_checkpoint || not cand_is_valid then
      `Keep
    else if curr.current_epoch.post_lock_hash = cand.current_epoch.post_lock_hash then
      argmax_(chain in [cand, curr])(len(chain))?
    else if curr.current_epoch.last_start_hash = cand.current_epoch.last_start_hash then
      argmax_(chain in [cand, curr])(len(chain.last_epoch_length))?
    else
      argmax_(chain in [cand, curr])(len(chain.last_epoch_participation))?
    *)
  (* TODO: only track total currency from accounts > 1% of the currency using transactions *)
  let generate_transition ~previous_protocol_state ~blockchain_state ~time
      ~transactions:_ =
    let previous_consensus_state =
      Protocol_state.consensus_state previous_protocol_state
    in
    let time = Time.of_span_since_epoch (Time.Span.of_ms time) in
    let epoch, slot = Epoch.epoch_and_slot_of_time_exn time in
    (* TODO: mock VRF *)
    let proposer_vrf_result = List.init 256 ~f:(fun _ -> false) in
    let consensus_transition_data =
      let open Consensus_transition_data in
      {epoch; slot; total_currency_diff= Inputs.coinbase; proposer_vrf_result}
    in
    let consensus_state =
      Or_error.ok_exn
      @@ Consensus_state.update previous_consensus_state
           consensus_transition_data
    in
    let protocol_state =
      Protocol_state.create_value
        ~previous_state_hash:(Protocol_state.hash previous_protocol_state)
        ~blockchain_state ~consensus_state
    in
    (protocol_state, consensus_transition_data)

  let genesis_protocol_state =
    Protocol_state.create_value
      ~previous_state_hash:(Protocol_state.hash Protocol_state.negative_one)
      ~blockchain_state:
        (Snark_transition.genesis |> Snark_transition.blockchain_state)
      ~consensus_state:
        ( Or_error.ok_exn
        @@ update
             (Protocol_state.consensus_state Protocol_state.negative_one)
             Snark_transition.genesis )
end
