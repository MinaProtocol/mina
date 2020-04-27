open Core_kernel
open Snarky
open Snark_params.Tick
open Unsigned
module Length = Coda_numbers.Length

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

  let to_time = Fn.compose Block_time.Unpacked.var_of_bits (Integer.to_bits ~m)

  let of_timespan =
    Fn.compose (Integer.of_bits ~m) Block_time.Span.Unpacked.var_to_bits

  let to_timespan =
    Fn.compose Block_time.Span.Unpacked.var_of_bits (Integer.to_bits ~m)

  let ( / ) (t : t) (t' : t) = Integer.div_mod ~m t t' |> fst

  let ( * ) = Integer.mul ~m
end

(*constants required for blockchain snark*)
module In_snark = struct
  module Poly = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ('length, 'timespan) t =
          { k: 'length
          ; c: 'length
          ; slots_per_sub_window: 'length
          ; sub_windows_per_window: 'length
          ; slots_per_epoch: 'length
          ; slot_duration_ms: 'timespan
          ; checkpoint_window_size_in_slots: 'length
          ; block_window_duration_ms: 'timespan }
        [@@deriving eq, ord, hash, sexp, to_yojson]
      end
    end]

    type ('length, 'timespan) t = ('length, 'timespan) Stable.Latest.t =
      { k: 'length
      ; c: 'length
      ; slots_per_sub_window: 'length
      ; sub_windows_per_window: 'length
      ; slots_per_epoch: 'length
      ; slot_duration_ms: 'timespan
      ; checkpoint_window_size_in_slots: 'length
      ; block_window_duration_ms: 'timespan }
    [@@deriving sexp, eq, to_yojson]
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        (Length.Stable.V1.t, Block_time.Span.Stable.V1.t) Poly.Stable.V1.t
      [@@deriving eq, ord, hash, sexp, to_yojson]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t [@@deriving to_yojson]

  type var = (Length.Checked.t, Block_time.Span.Unpacked.var) Poly.t

  let create' (type a b)
      (module M : M_intf with type length = a
                          and type timespan = b)
      ~(in_snark_constants : a Genesis_constants.Protocol.In_snark.Poly.t) :
      (a, b) Poly.t =
    let open M in
    let module P = Genesis_constants.Protocol.In_snark in
    let c = constant Coda_compile_config.c in
    let block_window_duration_ms =
      constant Coda_compile_config.block_window_duration_ms
    in
    let k = of_length (P.k in_snark_constants) in
    (*TODO: sub_windows_per_window, slots_per_sub_window are currently dummy
  values and need to be updated before mainnet*)
    let sub_windows_per_window = c in
    let slots_per_sub_window = k in
    (* Number of slots =24k in ouroboros praos *)
    let slots_per_epoch = constant 3 * c * k in
    let slot_duration_ms = block_window_duration_ms in
    let res : (a, b) Poly.t =
      { Poly.k= to_length k
      ; c= to_length c
      ; block_window_duration_ms= to_timespan block_window_duration_ms
      ; slots_per_sub_window= to_length slots_per_sub_window
      ; sub_windows_per_window= to_length sub_windows_per_window
      ; slots_per_epoch= to_length slots_per_epoch
      ; slot_duration_ms=
          to_timespan slot_duration_ms
          (*Updated in the top-level create function*)
      ; checkpoint_window_size_in_slots= to_length zero }
    in
    res

  let create ~in_snark_constants : t =
    let c : t = create' (module Constants_UInt32) ~in_snark_constants in
    let checkpoint_window_size_in_slots =
      let per_year = 12 in
      let slots_per_year =
        let one_year_ms =
          Core.Time.Span.(to_ms (of_day 365.)) |> Float.to_int
        in
        one_year_ms
        / (Block_time.Span.to_ms c.slot_duration_ms |> Int64.to_int_exn)
      in
      let size_in_slots =
        assert (slots_per_year mod per_year = 0) ;
        slots_per_year / per_year
      in
      Length.of_int size_in_slots
    in
    {c with checkpoint_window_size_in_slots}

  let to_hlist
      ({ k
       ; c
       ; slots_per_sub_window
       ; sub_windows_per_window
       ; slots_per_epoch
       ; checkpoint_window_size_in_slots
       ; block_window_duration_ms
       ; slot_duration_ms } :
        _ Poly.t) =
    H_list.
      [ k
      ; c
      ; slots_per_sub_window
      ; sub_windows_per_window
      ; slots_per_epoch
      ; checkpoint_window_size_in_slots
      ; block_window_duration_ms
      ; slot_duration_ms ]

  let of_hlist : (unit, _) H_list.t -> _ Poly.t =
   fun H_list.
         [ k
         ; c
         ; slots_per_sub_window
         ; sub_windows_per_window
         ; slots_per_epoch
         ; checkpoint_window_size_in_slots
         ; block_window_duration_ms
         ; slot_duration_ms ] ->
    { k
    ; c
    ; slots_per_sub_window
    ; sub_windows_per_window
    ; slots_per_epoch
    ; checkpoint_window_size_in_slots
    ; block_window_duration_ms
    ; slot_duration_ms }

  let data_spec =
    Data_spec.
      [ Length.Checked.typ
      ; Length.Checked.typ
      ; Length.Checked.typ
      ; Length.Checked.typ
      ; Length.Checked.typ
      ; Length.Checked.typ
      ; Block_time.Span.Unpacked.typ
      ; Block_time.Span.Unpacked.typ ]

  let typ =
    Typ.of_hlistable data_spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let to_input (t : t) =
    let u = Length.to_bits in
    let s = Block_time.Span.Bits.to_bits in
    Random_oracle.Input.bitstrings
      (Array.concat
         [ Array.map ~f:u
             [| t.k
              ; t.c
              ; t.slots_per_sub_window
              ; t.sub_windows_per_window
              ; t.slots_per_epoch
              ; t.checkpoint_window_size_in_slots |]
         ; Array.map ~f:s [|t.block_window_duration_ms; t.slot_duration_ms|] ])

  module Checked = struct
    let to_input (var : var) =
      let l = Bitstring_lib.Bitstring.Lsb_first.to_list in
      let u = Length.Checked.to_bits in
      let s = Block_time.Span.Unpacked.var_to_bits in
      let%map k = u var.k
      and c = u var.c
      and slots_per_sub_window = u var.slots_per_sub_window
      and sub_windows_per_window = u var.sub_windows_per_window
      and slots_per_epoch = u var.slots_per_epoch
      and checkpoint_window_size_in_slots =
        u var.checkpoint_window_size_in_slots
      in
      let block_window_duration_ms = s var.block_window_duration_ms in
      let slot_duration_ms = s var.slot_duration_ms in
      Random_oracle.Input.bitstrings
        (Array.map ~f:l
           [| k
            ; c
            ; slots_per_sub_window
            ; sub_windows_per_window
            ; slots_per_epoch
            ; checkpoint_window_size_in_slots
            ; block_window_duration_ms
            ; slot_duration_ms |])

    let create ~(in_snark_constants : Coda_base.Protocol_constants_checked.var)
        : (var, _) Checked.t =
      let open Snarky_integer in
      let%bind constants =
        make_checked (fun () ->
            create' (module Constants_checked) ~in_snark_constants )
      in
      let%map checkpoint_window_size_in_slots =
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
          let size_in_slots, rem =
            Integer.div_mod ~m slots_per_year per_year
          in
          let%map () =
            Boolean.Assert.is_true (Integer.equal ~m rem (constant 0))
          in
          size_in_slots
        in
        Length.Checked.Unsafe.of_integer size_in_slots
      in
      {constants with checkpoint_window_size_in_slots}
  end

  let%test_unit "checked = unchecked" =
    let open Coda_base in
    let compiled = Genesis_constants.compiled.protocol.in_snark in
    let test =
      Test_util.test_equal Protocol_constants_checked.typ typ
        (fun in_snark_constants -> Checked.create ~in_snark_constants)
        (fun in_snark_constants -> create ~in_snark_constants)
    in
    Quickcheck.test ~trials:100 Protocol_constants_checked.Value.gen
      ~examples:[Protocol_constants_checked.value_of_t compiled]
      ~f:test
end

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
      [@@deriving eq, ord, hash, sexp, to_yojson]
    end
  end]

  type ('length, 'time, 'timespan) t =
        ('length, 'time, 'timespan) Stable.Latest.t =
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
  [@@deriving sexp, eq, to_yojson]
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

type t = Stable.Latest.t [@@deriving sexp, eq, to_yojson]

type var = In_snark.var

let create ~(protocol_constants : Genesis_constants.Protocol.t) : t =
  let module P_in_snark = Genesis_constants.Protocol.In_snark in
  let module P_out_of_snark = Genesis_constants.Protocol.Out_of_snark in
  let to_length = Length.of_int in
  let to_timespan = Fn.compose Block_time.Span.of_ms Int64.of_int in
  let in_snark_constants =
    Coda_base.Protocol_constants_checked.value_of_t protocol_constants.in_snark
  in
  let in_snark = In_snark.create ~in_snark_constants in
  let delta = Genesis_constants.Protocol.delta protocol_constants in
  let slots_per_window =
    Length.to_int in_snark.sub_windows_per_window
    * Length.to_int in_snark.slots_per_sub_window
  in
  let slot_duration_int =
    Block_time.Span.to_ms in_snark.slot_duration_ms |> Int64.to_int_exn
  in
  let module Epoch = struct
    let size = in_snark.slots_per_epoch

    (* Amount of time in total for an epoch *)
    let duration = slot_duration_int * Length.to_int size
  end in
  let checkpoint_window_slots_per_year =
    let slots_per_year =
      let one_year_ms = Core.Time.Span.(to_ms (of_day 365.)) |> Float.to_int in
      one_year_ms / slot_duration_int
    in
    to_length slots_per_year
  in
  let delta_duration = slot_duration_int * delta in
  { Poly.k= in_snark.k
  ; c= in_snark.c
  ; delta= to_length delta
  ; block_window_duration_ms= in_snark.block_window_duration_ms
  ; slots_per_sub_window= in_snark.slots_per_sub_window
  ; slots_per_window= to_length slots_per_window
  ; sub_windows_per_window= in_snark.sub_windows_per_window
  ; slots_per_epoch= in_snark.slots_per_epoch
  ; slot_duration_ms= in_snark.slot_duration_ms
  ; epoch_size= Epoch.size
  ; epoch_duration= to_timespan Epoch.duration
  ; checkpoint_window_slots_per_year
  ; checkpoint_window_size_in_slots= in_snark.checkpoint_window_size_in_slots
  ; delta_duration= to_timespan delta_duration
  ; genesis_state_timestamp=
      Block_time.of_time
        (Genesis_constants.Protocol.genesis_state_timestamp protocol_constants)
  }

let compiled = create ~protocol_constants:Genesis_constants.compiled.protocol

let to_snark_constants (t : t) : In_snark.t =
  { In_snark.Poly.k= t.k
  ; c= t.c
  ; block_window_duration_ms= t.block_window_duration_ms
  ; slots_per_sub_window= t.slots_per_sub_window
  ; sub_windows_per_window= t.sub_windows_per_window
  ; slots_per_epoch= t.slots_per_epoch
  ; slot_duration_ms= t.slot_duration_ms
  ; checkpoint_window_size_in_slots= t.checkpoint_window_size_in_slots }

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
