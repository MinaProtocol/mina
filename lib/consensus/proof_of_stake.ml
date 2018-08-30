open Core_kernel
open Signed
open Unsigned
open Coda_numbers
open Currency
open Sha256_lib
open Fold_lib

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

  val genesis_state_timestamp : Time.t

  val genesis_ledger_total_currency : Amount.t

  val genesis_ledger : Nanobit_base.Ledger.t

  val coinbase : Amount.t

  val slot_interval : Time.Span.t

  val unforkable_transition_count : int

  val probable_slots_per_transition_count : int
end

module Segment_id = Nat.Make32 ()

module Epoch_seed = struct
  include Nanobit_base.Data_hash.Make_full_size ()

  let zero = Snark_params.Tick.Pedersen.zero_hash

  let fold_vrf_result seed vrf_result =
    Fold.(fold seed +> Sha256.Digest.fold vrf_result)

  let update seed vrf_result =
    let open Snark_params.Tick in
    of_hash
      (Pedersen.digest_fold Nanobit_base.Hash_prefix.epoch_seed
         (fold_vrf_result seed vrf_result))

  let update_var (seed: var) (vrf_result: Sha256.Digest.var) :
      (var, _) Snark_params.Tick.Checked.t =
    let open Snark_params.Tick in
    let open Snark_params.Tick.Let_syntax in
    let%bind seed_triples = var_to_triples seed in
    let%map hash =
      Pedersen.Checked.digest_triples ~init:Nanobit_base.Hash_prefix.epoch_seed
        ( seed_triples
        @ Fold.(to_list (group3 ~default:Boolean.false_ (of_list vrf_result)))
        )
    in
    var_of_hash_packed hash
end

let uint32_of_int64 x = x |> Int64.to_int64 |> UInt32.of_int64

let int64_of_uint32 x = x |> UInt32.to_int64 |> Int64.of_int64

module Vrf =
  Vrf_lib.Integrated.Make (Snark_params.Tick)
    (struct
      type var = Snark_params.Tick.Boolean.var list
    end)
    (struct
      include Snark_params.Tick.Inner_curve.Checked

      let scale_generator shifted s ~init =
        scale_known shifted Snark_params.Tick.Inner_curve.one s ~init
    end)

module Make (Inputs : Inputs_intf) :
  Mechanism.S
  with type Internal_transition.Ledger_builder_diff.t =
              Inputs.Ledger_builder_diff.t
   and type External_transition.Ledger_builder_diff.t =
              Inputs.Ledger_builder_diff.t =
struct
  module Ledger_builder_diff = Inputs.Ledger_builder_diff
  module Time = Inputs.Time

  let genesis_ledger_hash =
    Nanobit_base.Ledger.merkle_root Inputs.genesis_ledger

  module Ledger_pool =
    Rc_pool.Make (Nanobit_base.Ledger_hash)
      (struct
        include Nanobit_base.Ledger

        let to_key = merkle_root
      end)

  module Local_state = struct
    type t = Ledger_pool.t sexp_opaque [@@deriving sexp]

    let create () = Ledger_pool.create ()
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

      let unforkable_count =
        UInt32.of_int
          ( Inputs.probable_slots_per_transition_count
          * Inputs.unforkable_transition_count )

      let in_seed_update_range (slot: t) =
        let open UInt32 in
        let open UInt32.Infix in
        let ( <= ) x y = compare x y <= 0 in
        let ( < ) x y = compare x y < 0 in
        unforkable_count <= slot && slot < unforkable_count * of_int 2

      let in_seed_update_range_var (slot: Unpacked.var) =
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

      let%test_unit "in_seed_update_range_var" =
        Quickcheck.test gen ~f:(fun slot ->
            Test_util.test_equal Unpacked.typ Snark_params.Tick.Boolean.typ
              in_seed_update_range_var in_seed_update_range slot )
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
      Nanobit_base.H_list.[epoch; slot; proposer_vrf_result]

    let of_hlist :
           (unit, 'epoch -> 'slot -> 'vrf_result -> unit) Nanobit_base.H_list.t
        -> ('epoch, 'slot, 'vrf_result) t =
     fun Nanobit_base.H_list.([epoch; slot; proposer_vrf_result]) ->
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
    type ('length, 'epoch, 'slot, 'amount, 'epoch_seed, 'ledger_hash) t =
      { length: 'length
      ; current_epoch: 'epoch
      ; current_slot: 'slot
      ; total_currency: 'amount
      ; epoch_seed: 'epoch_seed
      ; epoch_ledger_hash: 'ledger_hash
      ; next_epoch_seed: 'epoch_seed
      ; next_epoch_ledger_hash: 'ledger_hash }
    [@@deriving sexp, bin_io, eq, compare, hash]

    type value =
      ( Length.t
      , Epoch.t
      , Epoch.Slot.t
      , Amount.t
      , Epoch_seed.t
      , Nanobit_base.Ledger_hash.t )
      t
    [@@deriving sexp, bin_io, eq, compare, hash]

    type var =
      ( Length.Unpacked.var
      , Epoch.Unpacked.var
      , Epoch.Slot.Unpacked.var
      , Amount.var
      , Epoch_seed.var
      , Nanobit_base.Ledger_hash.var )
      t

    let genesis : value =
      { length= Length.zero
      ; current_epoch= Epoch.zero
      ; current_slot= Epoch.Slot.zero
      ; total_currency=
          Inputs.genesis_ledger_total_currency
          (* TODO: epoch_seed needs to be non-determinable by o1-labs before mainnet launch *)
      ; epoch_seed= Epoch_seed.of_hash Epoch_seed.zero
      ; epoch_ledger_hash= genesis_ledger_hash
      ; next_epoch_seed= Epoch_seed.of_hash Epoch_seed.zero
      ; next_epoch_ledger_hash= genesis_ledger_hash }

    let update_stateless ~(previous_consensus_state: value)
        ~(consensus_transition_data: Consensus_transition_data.value)
        ~(ledger_hash: Nanobit_base.Ledger_hash.t) : value Or_error.t =
      let open Or_error.Let_syntax in
      let open Consensus_transition_data in
      let%map total_currency =
        Amount.add previous_consensus_state.total_currency Inputs.coinbase
        |> Option.map ~f:Or_error.return
        |> Option.value
             ~default:(Or_error.error_string "failed to add total_currency")
      in
      let ( epoch_seed
          , epoch_ledger_hash
          , next_epoch_seed
          , next_epoch_ledger_hash ) =
        if
          consensus_transition_data.epoch
          > previous_consensus_state.current_epoch
        then
          ( previous_consensus_state.next_epoch_seed
          , previous_consensus_state.next_epoch_ledger_hash
          , Epoch_seed.of_hash Epoch_seed.zero
          , ledger_hash )
        else
          ( previous_consensus_state.epoch_seed
          , previous_consensus_state.epoch_ledger_hash
          , previous_consensus_state.next_epoch_seed
          , previous_consensus_state.next_epoch_ledger_hash )
      in
      let next_epoch_seed =
        if Epoch.Slot.in_seed_update_range consensus_transition_data.slot then
          Epoch_seed.update next_epoch_seed
            consensus_transition_data.proposer_vrf_result
        else next_epoch_seed
      in
      { length= Length.succ previous_consensus_state.length
      ; current_epoch= consensus_transition_data.epoch
      ; current_slot= consensus_transition_data.slot
      ; total_currency
      ; epoch_seed
      ; epoch_ledger_hash
      ; next_epoch_seed
      ; next_epoch_ledger_hash }

    let update ~(previous_consensus_state: value)
        ~(consensus_transition_data: Consensus_transition_data.value)
        ~(local_state: Local_state.t) ~(ledger: Nanobit_base.Ledger.t) :
        value Or_error.t =
      let open Or_error.Let_syntax in
      let%map next_consensus_state =
        update_stateless ~previous_consensus_state ~consensus_transition_data
          ~ledger_hash:(Nanobit_base.Ledger.merkle_root ledger)
      in
      if
        previous_consensus_state.epoch_ledger_hash
        <> next_consensus_state.epoch_ledger_hash
      then (
        Ledger_pool.free local_state previous_consensus_state.epoch_ledger_hash ;
        Ledger_pool.save local_state ledger ) ;
      next_consensus_state

    let update_var (previous_state: var)
        (transition_data: Consensus_transition_data.var)
        (ledger_hash: Nanobit_base.Ledger_hash.var) :
        (var, _) Snark_params.Tick.Checked.t =
      let open Snark_params.Tick.Let_syntax in
      let%bind length = Length.increment_var previous_state.length
      (* TODO: keep track of total_currency in transaction snark. The current_slot
       * implementation would allow an adversary to make then total_currency incorrect by
       * not adding the coinbase to their account. *)
      and total_currency =
        Amount.Checked.add previous_state.total_currency
          (Amount.var_of_t Inputs.coinbase)
      and ( epoch_seed
          , epoch_ledger_hash
          , next_epoch_seed
          , next_epoch_ledger_hash ) =
        let%bind epoch_changed =
          Epoch.compare_var previous_state.current_epoch transition_data.epoch
          >>| fun c -> c.less
        in
        let%map epoch_seed =
          Epoch_seed.if_ epoch_changed ~then_:previous_state.next_epoch_seed
            ~else_:previous_state.epoch_seed
        and next_epoch_seed =
          Epoch_seed.if_ epoch_changed
            ~then_:(Epoch_seed.var_of_t (Epoch_seed.of_hash Epoch_seed.zero))
            ~else_:previous_state.next_epoch_seed
        and epoch_ledger_hash =
          Nanobit_base.Ledger_hash.if_ epoch_changed
            ~then_:previous_state.next_epoch_ledger_hash
            ~else_:previous_state.epoch_ledger_hash
        and next_epoch_ledger_hash =
          Nanobit_base.Ledger_hash.if_ epoch_changed ~then_:ledger_hash
            ~else_:previous_state.next_epoch_ledger_hash
        in
        (epoch_seed, epoch_ledger_hash, next_epoch_seed, next_epoch_ledger_hash)
      in
      let%map next_epoch_seed =
        let%bind updated_next_epoch_seed =
          Epoch_seed.update_var next_epoch_seed
            transition_data.proposer_vrf_result
        and in_seed_update_range =
          Epoch.Slot.in_seed_update_range_var transition_data.slot
        in
        Epoch_seed.if_ in_seed_update_range ~then_:updated_next_epoch_seed
          ~else_:next_epoch_seed
      in
      { length
      ; current_epoch= transition_data.epoch
      ; current_slot= transition_data.slot
      ; total_currency
      ; epoch_seed
      ; epoch_ledger_hash
      ; next_epoch_seed
      ; next_epoch_ledger_hash }

    let to_hlist
        { length
        ; current_epoch
        ; current_slot
        ; total_currency
        ; epoch_seed
        ; epoch_ledger_hash
        ; next_epoch_seed
        ; next_epoch_ledger_hash } =
      let open Nanobit_base.H_list in
      [ length
      ; current_epoch
      ; current_slot
      ; total_currency
      ; epoch_seed
      ; epoch_ledger_hash
      ; next_epoch_seed
      ; next_epoch_ledger_hash ]

    let of_hlist :
           ( unit
           ,    'length
             -> 'epoch
             -> 'slot
             -> 'amount
             -> 'epoch_seed
             -> 'ledger_hash
             -> 'epoch_seed
             -> 'ledger_hash
             -> unit )
           Nanobit_base.H_list.t
        -> ('length, 'epoch, 'slot, 'amount, 'epoch_seed, 'ledger_hash) t =
     fun Nanobit_base.H_list.([ length
                              ; current_epoch
                              ; current_slot
                              ; total_currency
                              ; epoch_seed
                              ; epoch_ledger_hash
                              ; next_epoch_seed
                              ; next_epoch_ledger_hash ]) ->
      { length
      ; current_epoch
      ; current_slot
      ; total_currency
      ; epoch_seed
      ; epoch_ledger_hash
      ; next_epoch_seed
      ; next_epoch_ledger_hash }

    let data_spec =
      let open Snark_params.Tick.Data_spec in
      [ Length.Unpacked.typ
      ; Epoch.Unpacked.typ
      ; Epoch.Slot.Unpacked.typ
      ; Amount.typ
      ; Epoch_seed.typ
      ; Nanobit_base.Ledger_hash.typ
      ; Epoch_seed.typ
      ; Nanobit_base.Ledger_hash.typ ]

    let typ =
      Snark_params.Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
        ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist

    let var_to_triples
        { length
        ; current_epoch
        ; current_slot
        ; total_currency
        ; epoch_seed
        ; epoch_ledger_hash
        ; next_epoch_seed
        ; next_epoch_ledger_hash } =
      let open Snark_params.Tick.Let_syntax in
      let%map epoch_seed_triples = Epoch_seed.var_to_triples epoch_seed
      and next_epoch_seed_triples = Epoch_seed.var_to_triples next_epoch_seed
      and epoch_ledger_hash_triples =
        Nanobit_base.Ledger_hash.var_to_triples epoch_ledger_hash
      and next_epoch_ledger_hash_triples =
        Nanobit_base.Ledger_hash.var_to_triples next_epoch_ledger_hash
      in
      Length.Unpacked.var_to_triples length
      @ Epoch.Unpacked.var_to_triples current_epoch
      @ Epoch.Slot.Unpacked.var_to_triples current_slot
      @ Amount.var_to_triples total_currency
      @ epoch_seed_triples @ epoch_ledger_hash_triples
      @ next_epoch_seed_triples @ next_epoch_ledger_hash_triples

    let fold
        { length
        ; current_epoch
        ; current_slot
        ; total_currency
        ; epoch_seed
        ; epoch_ledger_hash
        ; next_epoch_seed
        ; next_epoch_ledger_hash } =
      let open Fold in
      Length.fold length +> Epoch.fold current_epoch
      +> Epoch.Slot.fold current_slot
      +> Amount.fold total_currency +> Epoch_seed.fold epoch_seed
      +> Nanobit_base.Ledger_hash.fold epoch_ledger_hash
      +> Epoch_seed.fold next_epoch_seed
      +> Nanobit_base.Ledger_hash.fold next_epoch_ledger_hash

    let length_in_triples =
      Length.length_in_triples + Epoch.length_in_triples
      + Epoch.Slot.length_in_triples + Amount.length_in_triples
      + Epoch_seed.length_in_triples
      + Nanobit_base.Ledger_hash.length_in_triples
      + Epoch_seed.length_in_triples
      + Nanobit_base.Ledger_hash.length_in_triples
  end

  module Protocol_state = Nanobit_base.Protocol_state.Make (Consensus_state)
  module Snark_transition = Nanobit_base.Snark_transition.Make (Consensus_transition_data)
  module Internal_transition =
    Nanobit_base.Internal_transition.Make (Ledger_builder_diff)
      (Snark_transition)
  module External_transition =
    Nanobit_base.External_transition.Make (Ledger_builder_diff)
      (Protocol_state)

  (* TODO: only track total currency from accounts > 1% of the currency using transactions *)
  let generate_transition ~previous_protocol_state ~blockchain_state
      ~local_state ~time ~transactions:_ ~ledger =
    let previous_consensus_state =
      Protocol_state.consensus_state previous_protocol_state
    in
    let time = Time.of_span_since_epoch (Time.Span.of_ms time) in
    let epoch, slot = Epoch.epoch_and_slot_of_time_exn time in
    (* TODO: mock VRF *)
    let proposer_vrf_result = List.init 256 ~f:(fun _ -> false) in
    let consensus_transition_data =
      Consensus_transition_data.{epoch; slot; proposer_vrf_result}
    in
    let consensus_state =
      Or_error.ok_exn
        (Consensus_state.update ~previous_consensus_state
           ~consensus_transition_data ~local_state ~ledger)
    in
    let protocol_state =
      Protocol_state.create_value
        ~previous_state_hash:(Protocol_state.hash previous_protocol_state)
        ~blockchain_state ~consensus_state
    in
    Some (protocol_state, consensus_transition_data)

  let is_transition_valid_checked _transition =
    Snark_params.Tick.(Let_syntax.return Boolean.true_)

  let next_state_checked previous_state transition =
    Consensus_state.update_var previous_state
      (Snark_transition.consensus_data transition)
      ( transition |> Snark_transition.blockchain_state
      |> Nanobit_base.Blockchain_state.ledger_hash )

  let select current candidate =
    let open Consensus_state in
    if Length.compare current.length candidate.length < 0 then `Take else `Keep

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

  let genesis_protocol_state =
    let consensus_state =
      Or_error.ok_exn
        (Consensus_state.update_stateless
           ~previous_consensus_state:
             Protocol_state.(consensus_state negative_one)
           ~consensus_transition_data:Snark_transition.(consensus_data genesis)
           ~ledger_hash:genesis_ledger_hash)
    in
    Protocol_state.create_value
      ~previous_state_hash:Protocol_state.(hash negative_one)
      ~blockchain_state:Snark_transition.(blockchain_state genesis)
      ~consensus_state
end
