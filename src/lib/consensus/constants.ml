open Core_kernel
open Snarky
open Snark_params.Tick
open Unsigned
module Length = Coda_numbers.Length

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('length, 'time, 'timespan) t =
        { k: 'length
        ; c: 'length
        ; delta: 'length
        ; slots_per_sub_window: 'length
        ; slots_per_window: 'length
        ; sub_windows_per_window: 'length
        ; slots_per_epoch: 'length
        ; epoch_size: 'length
        ; checkpoint_window_slots_per_year: 'length
        ; checkpoint_window_size_in_slots: 'length
        ; block_window_duration_ms: 'timespan
        ; slot_duration_ms: 'timespan
        ; epoch_duration: 'timespan
        ; delta_duration: 'timespan
        ; genesis_state_timestamp: 'time }
      [@@deriving eq, ord, hash, sexp, to_yojson, hlist]
    end
  end]
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      ( Length.Stable.V1.t
      , Block_time.Stable.V1.t
      , Block_time.Span.Stable.V1.t )
      Poly.Stable.V1.t
    [@@deriving eq, ord, hash, sexp, to_yojson]

    let to_latest = Fn.id
  end
end]

type var =
  ( Length.Checked.t
  , Block_time.Unpacked.var
  , Block_time.Span.Unpacked.var )
  Poly.t

module type M_intf = sig
  type t

  type length

  type time

  type timespan

  type bool_type

  val constant : int -> t

  val of_length : length -> t

  val to_length : t -> length

  val of_timespan : timespan -> t

  val to_timespan : t -> timespan

  val of_time : time -> t

  val to_time : t -> time

  val zero : t

  val ( / ) : t -> t -> t

  val ( * ) : t -> t -> t
end

module Constants_UInt32 :
  M_intf
  with type length = Length.t
   and type time = Block_time.t
   and type timespan = Block_time.Span.t = struct
  type t = UInt32.t

  type length = Length.t

  type time = Block_time.t

  type timespan = Block_time.Span.t

  type bool_type = bool

  let constant = UInt32.of_int

  let zero = UInt32.zero

  let of_length = Fn.id

  let to_length = Fn.id

  let of_time = Fn.compose UInt32.of_int64 Block_time.to_int64

  let to_time = Fn.compose Block_time.of_int64 UInt32.to_int64

  let of_timespan = Fn.compose UInt32.of_int64 Block_time.Span.to_ms

  let to_timespan = Fn.compose Block_time.Span.of_ms UInt32.to_int64

  let ( / ) = UInt32.Infix.( / )

  let ( * ) = UInt32.mul
end

module Constants_checked :
  M_intf
  with type length = Length.Checked.t
   and type time = Block_time.Unpacked.var
   and type timespan = Block_time.Span.Unpacked.var = struct
  open Snarky_integer

  type t = field Integer.t

  type length = Length.Checked.t

  type time = Block_time.Unpacked.var

  type timespan = Block_time.Span.Unpacked.var

  type bool_type = Boolean.var

  let constant c = Integer.constant ~m (Bignum_bigint.of_int c)

  let zero = constant 0

  let of_length = Length.Checked.to_integer

  let to_length = Length.Checked.Unsafe.of_integer

  let of_time = Fn.compose (Integer.of_bits ~m) Block_time.Unpacked.var_to_bits

  let to_time =
    Fn.compose Block_time.Unpacked.var_of_bits
      (Integer.to_bits ~m ~length:Block_time.Unpacked.size_in_bits)

  let of_timespan =
    Fn.compose (Integer.of_bits ~m) Block_time.Span.Unpacked.var_to_bits

  let to_timespan =
    Fn.compose Block_time.Span.Unpacked.var_of_bits
      (Integer.to_bits ~length:Block_time.Span.Unpacked.size_in_bits ~m)

  let ( / ) (t : t) (t' : t) = Integer.div_mod ~m t t' |> fst

  let ( * ) = Integer.mul ~m
end

let create' (type a b c)
    (module M : M_intf
      with type length = a
       and type time = b
       and type timespan = c)
    ~(constraint_constants : Genesis_constants.Constraint_constants.t)
    ~(protocol_constants : (a, a, b) Genesis_constants.Protocol.Poly.t) :
    (a, b, c) Poly.t =
  let open M in
  let c = constant constraint_constants.c in
  let block_window_duration_ms =
    constant constraint_constants.block_window_duration_ms
  in
  let k = of_length protocol_constants.k in
  let delta = of_length protocol_constants.delta in
  (*TODO: sub_windows_per_window, slots_per_sub_window are currently dummy
  values and need to be updated before mainnet*)
  let sub_windows_per_window = c in
  let slots_per_sub_window = k in
  let slots_per_window = sub_windows_per_window * slots_per_sub_window in
  (* Number of slots =24k in ouroboros praos *)
  let slots_per_epoch = constant 3 * c * k in
  let module Slot = struct
    let duration_ms = block_window_duration_ms
  end in
  let module Epoch = struct
    let size = slots_per_epoch

    (* Amount of time in total for an epoch *)
    let duration = Slot.duration_ms * size
  end in
  let delta_duration = Slot.duration_ms * delta in
  let res : (a, b, c) Poly.t =
    { Poly.k= to_length k
    ; c= to_length c
    ; delta= to_length delta
    ; block_window_duration_ms= to_timespan block_window_duration_ms
    ; slots_per_sub_window= to_length slots_per_sub_window
    ; slots_per_window= to_length slots_per_window
    ; sub_windows_per_window= to_length sub_windows_per_window
    ; slots_per_epoch= to_length slots_per_epoch
    ; slot_duration_ms= to_timespan Slot.duration_ms
    ; epoch_size= to_length Epoch.size
    ; epoch_duration= to_timespan Epoch.duration
    ; checkpoint_window_slots_per_year= to_length zero
    ; checkpoint_window_size_in_slots= to_length zero
    ; delta_duration= to_timespan delta_duration
    ; genesis_state_timestamp= protocol_constants.genesis_state_timestamp }
  in
  res

let create ~(constraint_constants : Genesis_constants.Constraint_constants.t)
    ~(protocol_constants : Genesis_constants.Protocol.t) : t =
  let protocol_constants =
    Coda_base.Protocol_constants_checked.value_of_t protocol_constants
  in
  let constants =
    create' (module Constants_UInt32) ~constraint_constants ~protocol_constants
  in
  let checkpoint_window_slots_per_year, checkpoint_window_size_in_slots =
    let per_year = 12 in
    let slots_per_year =
      let one_year_ms = Core.Time.Span.(to_ms (of_day 365.)) |> Float.to_int in
      one_year_ms
      / (Block_time.Span.to_ms constants.slot_duration_ms |> Int64.to_int_exn)
    in
    let size_in_slots =
      assert (slots_per_year mod per_year = 0) ;
      slots_per_year / per_year
    in
    (Length.of_int slots_per_year, Length.of_int size_in_slots)
  in
  { constants with
    checkpoint_window_size_in_slots
  ; checkpoint_window_slots_per_year }

let for_unit_tests =
  lazy
    (create
       ~constraint_constants:
         Genesis_constants.Constraint_constants.for_unit_tests
       ~protocol_constants:Genesis_constants.for_unit_tests.protocol)

let to_protocol_constants ({k; delta; genesis_state_timestamp; _} : _ Poly.t) =
  {Coda_base.Protocol_constants_checked.Poly.k; delta; genesis_state_timestamp}

let data_spec =
  Data_spec.
    [ Length.Checked.typ
    ; Length.Checked.typ
    ; Length.Checked.typ
    ; Length.Checked.typ
    ; Length.Checked.typ
    ; Length.Checked.typ
    ; Length.Checked.typ
    ; Length.Checked.typ
    ; Length.Checked.typ
    ; Length.Checked.typ
    ; Block_time.Span.Unpacked.typ
    ; Block_time.Span.Unpacked.typ
    ; Block_time.Span.Unpacked.typ
    ; Block_time.Span.Unpacked.typ
    ; Block_time.Unpacked.typ ]

let typ =
  Typ.of_hlistable data_spec ~var_to_hlist:Poly.to_hlist
    ~var_of_hlist:Poly.of_hlist ~value_to_hlist:Poly.to_hlist
    ~value_of_hlist:Poly.of_hlist

let to_input (t : t) =
  let u = Length.to_bits in
  let s = Block_time.Span.Bits.to_bits in
  Random_oracle.Input.bitstrings
    (Array.concat
       [ Array.map ~f:u
           [| t.k
            ; t.c
            ; t.delta
            ; t.slots_per_sub_window
            ; t.slots_per_window
            ; t.sub_windows_per_window
            ; t.slots_per_epoch
            ; t.epoch_size
            ; t.checkpoint_window_slots_per_year
            ; t.checkpoint_window_size_in_slots |]
       ; Array.map ~f:s
           [| t.block_window_duration_ms
            ; t.slot_duration_ms
            ; t.epoch_duration
            ; t.delta_duration |]
       ; [|Block_time.Bits.to_bits t.genesis_state_timestamp|] ])

let gc_parameters (constants : t) =
  let open Unsigned.UInt32 in
  let open Unsigned.UInt32.Infix in
  let delay = Block_time.Span.to_ms constants.delta_duration |> of_int64 in
  let gc_width = delay * of_int 2 in
  (* epoch, slot components of gc_width *)
  let gc_width_epoch = gc_width / constants.epoch_size in
  let gc_width_slot = gc_width mod constants.epoch_size in
  let gc_interval = gc_width in
  ( `Acceptable_network_delay delay
  , `Gc_width gc_width
  , `Gc_width_epoch gc_width_epoch
  , `Gc_width_slot gc_width_slot
  , `Gc_interval gc_interval )

module Checked = struct
  let to_input (var : var) =
    let l = Bitstring_lib.Bitstring.Lsb_first.to_list in
    let u = Length.Checked.to_bits in
    let s = Block_time.Span.Unpacked.var_to_bits in
    let%map k = u var.k
    and c = u var.c
    and delta = u var.delta
    and slots_per_sub_window = u var.slots_per_sub_window
    and slots_per_window = u var.slots_per_window
    and sub_windows_per_window = u var.sub_windows_per_window
    and slots_per_epoch = u var.slots_per_epoch
    and epoch_size = u var.epoch_size
    and checkpoint_window_slots_per_year =
      u var.checkpoint_window_slots_per_year
    and checkpoint_window_size_in_slots =
      u var.checkpoint_window_size_in_slots
    in
    let block_window_duration_ms = s var.block_window_duration_ms in
    let slot_duration_ms = s var.slot_duration_ms in
    let epoch_duration = s var.epoch_duration in
    let delta_duration = s var.delta_duration in
    let genesis_state_timestamp =
      Block_time.Unpacked.var_to_bits var.genesis_state_timestamp
    in
    Random_oracle.Input.bitstrings
      (Array.map ~f:l
         [| k
          ; c
          ; delta
          ; slots_per_sub_window
          ; slots_per_window
          ; sub_windows_per_window
          ; slots_per_epoch
          ; epoch_size
          ; checkpoint_window_slots_per_year
          ; checkpoint_window_size_in_slots
          ; block_window_duration_ms
          ; slot_duration_ms
          ; epoch_duration
          ; delta_duration
          ; genesis_state_timestamp |])

  let create ~(constraint_constants : Genesis_constants.Constraint_constants.t)
      ~(protocol_constants : Coda_base.Protocol_constants_checked.var) :
      (var, _) Checked.t =
    let open Snarky_integer in
    let%bind constants =
      make_checked (fun () ->
          create'
            (module Constants_checked)
            ~constraint_constants ~protocol_constants )
    in
    let%map checkpoint_window_slots_per_year, checkpoint_window_size_in_slots =
      let constant c = Integer.constant ~m (Bignum_bigint.of_int c) in
      let per_year = constant 12 in
      let slot_duration_ms =
        Integer.of_bits ~m
          (Block_time.Span.Unpacked.var_to_bits constants.slot_duration_ms)
      in
      let slots_per_year =
        let one_year_ms =
          constant (Core.Time.Span.(to_ms (of_day 365.)) |> Float.to_int)
        in
        fst (Integer.div_mod ~m one_year_ms slot_duration_ms)
      in
      let%map size_in_slots =
        let size_in_slots, rem = Integer.div_mod ~m slots_per_year per_year in
        let%map () =
          Boolean.Assert.is_true (Integer.equal ~m rem (constant 0))
        in
        size_in_slots
      in
      let to_length = Length.Checked.Unsafe.of_integer in
      (to_length slots_per_year, to_length size_in_slots)
    in
    { constants with
      checkpoint_window_slots_per_year
    ; checkpoint_window_size_in_slots }
end

let%test_unit "checked = unchecked" =
  let open Coda_base in
  let for_unit_tests = Genesis_constants.for_unit_tests.protocol in
  let constraint_constants =
    Genesis_constants.Constraint_constants.for_unit_tests
  in
  let test =
    Test_util.test_equal Protocol_constants_checked.typ typ
      (fun protocol_constants ->
        Checked.create ~constraint_constants ~protocol_constants )
      (fun protocol_constants ->
        create ~constraint_constants
          ~protocol_constants:
            (Protocol_constants_checked.t_of_value protocol_constants) )
  in
  Quickcheck.test ~trials:100 Protocol_constants_checked.Value.gen
    ~examples:[Protocol_constants_checked.value_of_t for_unit_tests]
    ~f:test
