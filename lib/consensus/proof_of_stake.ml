open Core_kernel
open Unsigned
open Coda_numbers

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
    end

    val of_ms : Int64.t -> t

    val to_ms : t -> Int64.t

    val diff : t -> t -> Span.t

    val less_than : t -> t -> bool

    val ( < ) : t -> t -> bool

    val ( >= ) : t -> t -> bool

    val ( + ) : t -> t -> t

    val ( * ) : t -> t -> t
  end

  val genesis_block_timestamp : Time.t

  val slot_interval : Time.t

  val epoch_size : UInt64.t
end

module Segment_id = Nat.Make64 ()

module Make (Inputs : Inputs_intf) : Mechanism.S = struct
  module Proof = Inputs.Proof
  module Ledger_builder_diff = Inputs.Ledger_builder_diff
  module Time = Inputs.Time

  module Epoch = struct
    include Segment_id

    let size = Inputs.epoch_size

    let interval = Time.(Inputs.slot_interval * (of_ms @@ UInt64.to_int64 size))

    let of_time_exn t : t =
      if Time.(t < Inputs.genesis_block_timestamp) then
        raise
          (Invalid_argument
             "Epoch.of_time: time is less than genesis block timestamp") ;
      let time_since_genesis = Time.diff t Inputs.genesis_block_timestamp in
      UInt64.of_int64
        Int64.(Time.Span.to_ms time_since_genesis / Time.to_ms interval)

    let start_time (e: t) =
      let open Time in
      Inputs.genesis_block_timestamp + (of_ms (UInt64.to_int64 e) * interval)

    let end_time (e: t) = Time.(start_time e + interval)

    module Slot = struct
      include Segment_id

      let interval = Inputs.slot_interval
    end

    let slot_start_time (epoch: t) (slot: Slot.t) =
      Time.(start_time epoch + (of_ms (UInt64.to_int64 slot) * Slot.interval))

    let slot_end_time (epoch: t) (slot: Slot.t) =
      Time.(slot_start_time epoch slot + Slot.interval)

    let epoch_and_slot_of_time_exn t : t * Slot.t =
      let epoch = of_time_exn t in
      let time_since_epoch = Time.diff t (start_time epoch) in
      let slot =
        UInt64.of_int64
          Int64.(Time.Span.to_ms time_since_epoch / Time.to_ms Slot.interval)
      in
      (epoch, slot)
  end

  module Consensus_data = struct
    type ('epoch, 'slot) t = {epoch: 'epoch; slot: 'slot}
    [@@deriving sexp, bin_io, eq, compare]

    type value = (Epoch.t, Epoch.Slot.t) t
    [@@deriving sexp, bin_io, eq, compare]

    type var = (Epoch.Unpacked.var, Epoch.Slot.Unpacked.var) t

    let genesis = {epoch= UInt64.zero; slot= UInt64.zero}

    let to_hlist {epoch; slot} = Nanobit_base.H_list.[epoch; slot]

    let of_hlist :
           (unit, 'epoch -> 'slot -> unit) Nanobit_base.H_list.t
        -> ('epoch, 'slot) t =
     fun Nanobit_base.H_list.([epoch; slot]) -> {epoch; slot}

    let data_spec =
      Snark_params.Tick.Data_spec.[Epoch.Unpacked.typ; Epoch.Slot.Unpacked.typ]

    let typ =
      Snark_params.Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
        ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist

    let fold {epoch; slot} =
      Nanobit_base.Util.(Epoch.Bits.fold epoch +> Epoch.Slot.Bits.fold slot)

    let var_to_bits {epoch; slot} =
      Epoch.Unpacked.var_to_bits epoch @ Epoch.Slot.Unpacked.var_to_bits slot

    let bit_length = Epoch.length_in_bits + Epoch.Slot.length_in_bits
  end

  module Consensus_state = struct
    type ('length, 'epoch, 'slot) t =
      {length: 'length; current_epoch: 'epoch; current_slot: 'slot}
    [@@deriving sexp, bin_io, eq, compare, hash]

    (*
      ; checkpoints: ?
      ; last_epoch_length: Length.t?
      ; unique_participants: ?
      ; unique_participation: ?
      ; last_epoch_participation: ? }
       *)

    type value = (Length.t, Epoch.t, Epoch.Slot.t) t
    [@@deriving sexp, bin_io, eq, compare, hash]

    type var =
      (Length.Unpacked.var, Epoch.Unpacked.var, Epoch.Slot.Unpacked.var) t

    let genesis =
      { length= Length.zero
      ; current_epoch= UInt64.zero
      ; current_slot= UInt64.zero }

    let to_hlist {length; current_epoch; current_slot} =
      Nanobit_base.H_list.[length; current_epoch; current_slot]

    let of_hlist :
           (unit, 'length -> 'epoch -> 'slot -> unit) Nanobit_base.H_list.t
        -> ('length, 'epoch, 'slot) t =
     fun Nanobit_base.H_list.([length; current_epoch; current_slot]) ->
      {length; current_epoch; current_slot}

    let data_spec =
      let open Snark_params.Tick.Data_spec in
      [Length.Unpacked.typ; Epoch.Unpacked.typ; Epoch.Slot.Unpacked.typ]

    let typ =
      Snark_params.Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
        ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist

    let var_to_bits {length; current_epoch; current_slot} =
      Snark_params.Tick.Let_syntax.return
        ( Length.Unpacked.var_to_bits length
        @ Epoch.Unpacked.var_to_bits current_epoch
        @ Epoch.Slot.Unpacked.var_to_bits current_slot )

    let fold {length; current_epoch; current_slot} =
      let open Nanobit_base.Util in
      Length.Bits.fold length
      +> Epoch.Bits.fold current_epoch
      +> Epoch.Slot.Bits.fold current_slot

    let bit_length =
      Length.length_in_bits + Epoch.length_in_bits + Epoch.Slot.length_in_bits
  end

  module Protocol_state = Nanobit_base.Protocol_state.Make (Consensus_state)
  module Snark_transition =
    Nanobit_base.Snark_transition.Make (Consensus_data) (Proof)
  module Internal_transition =
    Nanobit_base.Internal_transition.Make (Ledger_builder_diff)
      (Snark_transition)
  module External_transition =
    Nanobit_base.External_transition.Make (Ledger_builder_diff)
      (Protocol_state)

  let verify (_transition: Snark_transition.var) =
    Snark_params.Tick.(Let_syntax.return Boolean.true_)

  let update_var (state: Consensus_state.var) _block =
    Snark_params.Tick.Let_syntax.return state

  let update state transition =
    let open Consensus_data in
    let open Consensus_state in
    let consensus_data = Snark_transition.consensus_data transition in
    let state =
      { length= Length.succ state.length
      ; current_epoch= consensus_data.epoch
      ; current_slot= consensus_data.slot }
    in
    Or_error.return state

  let step = Async_kernel.Deferred.Or_error.return

  let select _curr _cand = `Keep

  (*
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
      () (* argmax_(chain in [cand, curr])(len(chain)) *)
    else if curr.current_epoch.last_start_hash = cand.current_epoch.last_start_hash then
      () (* argmax_(chain in [cand, curr])(len(chain.last_epoch_length)) *)
    else
      () (* argmax_(chain in [cand, curr])(len(chain.last_epoch_participation)) *)
    *)

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

  let create_consensus_data _state = Some Consensus_data.genesis

  let create_consensus_state _state = Consensus_state.genesis
end
