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
    type t = Segment_id.t

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
      type 'segment_id t = 'segment_id * 'segment_id
      [@@deriving sexp, bin_io, eq, compare, hash]

      type value = Segment_id.t t [@@deriving sexp, bin_io, eq, compare, hash]

      type var = Segment_id.Unpacked.var t

      let to_hlist (e, s) = Nanobit_base.H_list.[e; s]

      let of_hlist :
             (unit, 'segment_id -> 'segment_id -> unit) Nanobit_base.H_list.t
          -> 'segment_id t =
       fun Nanobit_base.H_list.([e; s]) -> (e, s)

      let data_spec =
        let open Snark_params.Tick.Data_spec in
        [Segment_id.Unpacked.typ; Segment_id.Unpacked.typ]

      let typ =
        Snark_params.Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
          ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
          ~value_of_hlist:of_hlist

      let fold (e, s) =
        Nanobit_base.Util.(Segment_id.Bits.fold e +> Segment_id.Bits.fold s)

      let var_to_bits (e, s) =
        Segment_id.Unpacked.var_to_bits e @ Segment_id.Unpacked.var_to_bits s

      let bit_length = Segment_id.length_in_bits * 2

      let interval = Inputs.slot_interval

      let of_time_exn t : value =
        let epoch = of_time_exn t in
        let time_since_epoch = Time.diff t (start_time epoch) in
        let slot =
          UInt64.of_int64
            Int64.(Time.Span.to_ms time_since_epoch / Time.to_ms interval)
        in
        (epoch, slot)

      let start_time ((epoch, slot): value) =
        Time.(start_time epoch + (of_ms (UInt64.to_int64 slot) * interval))

      let end_time (s: value) = Time.(start_time s + interval)
    end
  end

  module Transition_data = struct
    type 'amount t = {total_currency_diff: 'amount}
    [@@deriving sexp, bin_io, eq, compare]

    type value = Currency.Amount.t t
    [@@deriving sexp, bin_io, eq, compare]

    type var = Currency.Amount.var t

    let genesis = {total_currency_diff= Currency.Amount.zero}

    let to_hlist {total_currency_diff} = Nanobit_base.H_list.[total_currency_diff]

    let of_hlist : (unit, 'amount -> unit) Nanobit_base.H_list.t -> 'amount t =
     fun Nanobit_base.H_list.[total_currency_diff] -> {total_currency_diff}

    let data_spec = Snark_params.Tick.Data_spec.[Currency.Amount.typ]

    let typ =
      Snark_params.Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
        ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist

    let fold {total_currency_diff} =
      Currency.Amount.fold total_currency_diff

    let var_to_bits {total_currency_diff} = Currency.Amount.var_to_bits total_currency_diff

    let bit_length = Currency.Amount.length
  end

  module Epoch_info = struct
    type 'slot t = {slot: 'slot} [@@deriving sexp, bin_io, eq, compare, hash]

    (*
      ; seed: Ledger.t?
      ; ledger: Ledger.t?
      ; post_lock_hash: Ledger_hash.t?
      ; last_start_hash: Ledger_hash.t? }
       *)
    type value = Epoch.Slot.value t
    [@@deriving sexp, bin_io, eq, compare, hash]

    type var = Epoch.Slot.var t

    let to_hlist {slot} = Nanobit_base.H_list.[slot]

    let of_hlist : (unit, 'slot -> unit) Nanobit_base.H_list.t -> 'slot t =
     fun Nanobit_base.H_list.([slot]) -> {slot}

    let data_spec = Snark_params.Tick.Data_spec.[Epoch.Slot.typ]

    let typ =
      Snark_params.Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
        ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist

    let fold {slot} = Epoch.Slot.fold slot

    let var_to_bits {slot} = Epoch.Slot.var_to_bits slot

    let bit_length = Epoch.Slot.bit_length
  end

  module State_data = struct
    type ('length, 'epoch_info) t =
      {length: 'length; current_epoch: 'epoch_info; next_epoch: 'epoch_info}
    [@@deriving sexp, bin_io, eq, compare, hash]

    (*
      ; checkpoints: ?
      ; last_epoch_length: Length.t?
      ; unique_participants: ?
      ; unique_participation: ?
      ; last_epoch_participation: ? }
       *)
    type value = (Length.t, Epoch_info.value) t
    [@@deriving sexp, bin_io, eq, compare, hash]

    type var = (Length.Unpacked.var, Epoch_info.var) t

    let genesis =
      let open Epoch_info in
      { length= Length.zero
      ; current_epoch= {slot= (UInt64.zero, UInt64.zero)}
      ; next_epoch= {slot= (UInt64.zero, UInt64.zero)} }

    let to_hlist {length; current_epoch; next_epoch} =
      Nanobit_base.H_list.[length; current_epoch; next_epoch]

    let of_hlist :
           ( unit
           , 'length -> 'epoch_info -> 'epoch_info -> unit )
           Nanobit_base.H_list.t
        -> ('length, 'epoch_info) t =
     fun Nanobit_base.H_list.([length; current_epoch; next_epoch]) ->
      {length; current_epoch; next_epoch}

    let data_spec =
      let open Snark_params.Tick.Data_spec in
      [Length.Unpacked.typ; Epoch_info.typ; Epoch_info.typ]

    let typ =
      Snark_params.Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
        ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist

    let var_to_bits {length; current_epoch; next_epoch} =
      Snark_params.Tick.Let_syntax.return
        ( Length.Unpacked.var_to_bits length
        @ Epoch_info.var_to_bits current_epoch
        @ Epoch_info.var_to_bits next_epoch )

    let fold {length; current_epoch; next_epoch} =
      let open Nanobit_base.Util in
      Length.Bits.fold length
      +> Epoch_info.fold current_epoch
      +> Epoch_info.fold next_epoch

    let bit_length =
      Length.length_in_bits + Epoch_info.bit_length + Epoch_info.bit_length
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

  let update state _transition =
    let open Consensus_state in
    let current_epoch, next_epoch =
      if Epoch.Slot.slot_id state.current_epoch.slot >= Epoch.size then
        ( state.next_epoch
        , let open Epoch_info in
          { slot=
              ( Epoch.Slot.epoch_id state.next_epoch.slot + UInt64.one
              , UInt64.zero ) } )
      else
        ( (let open Epoch_info in
          { slot=
              ( Epoch.Slot.epoch_id state.current_epoch.slot
              , Epoch.Slot.slot_id state.current_epoch.slot + UInt64.one ) })
        , state.next_epoch )
    in
    let state =
      {length= Length.succ state.length; current_epoch; next_epoch}
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

  let create_transition_data _state =
    Some ()

  let create_state_data _state = Consensus_state.genesis
end
