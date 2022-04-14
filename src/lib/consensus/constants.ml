open Core_kernel
open Snarky_backendless
open Snark_params.Tick
open Unsigned
module Length = Mina_numbers.Length

module Poly = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type ('length, 'time, 'timespan) t =
        { k : 'length
        ; delta : 'length
        ; slots_per_sub_window : 'length
        ; slots_per_window : 'length
        ; sub_windows_per_window : 'length
        ; slots_per_epoch : 'length (* The first slot after the grace period. *)
        ; grace_period_end : 'length
        ; checkpoint_window_slots_per_year : 'length
        ; checkpoint_window_size_in_slots : 'length
        ; block_window_duration_ms : 'timespan
        ; slot_duration_ms : 'timespan
        ; epoch_duration : 'timespan
        ; delta_duration : 'timespan
        ; genesis_state_timestamp : 'time
        }
      [@@deriving equal, compare, hash, sexp, to_yojson, hlist]
    end
  end]
end

[%%versioned
module Stable = struct
  module V2 = struct
    type t =
      ( Length.Stable.V1.t
      , Block_time.Stable.V1.t
      , Block_time.Span.Stable.V1.t )
      Poly.Stable.V2.t
    [@@deriving equal, ord, hash, sexp, to_yojson]

    let to_latest = Fn.id
  end
end]

type var =
  (Length.Checked.t, Block_time.Checked.t, Block_time.Span.Checked.t) Poly.t

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

  val one : t

  val ( / ) : t -> t -> t

  val ( * ) : t -> t -> t

  val ( + ) : t -> t -> t

  val min : t -> t -> t
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

  let one = UInt32.one

  let of_length = Fn.id

  let to_length = Fn.id

  let of_time = Fn.compose UInt32.of_int64 Block_time.to_int64

  let to_time = Fn.compose Block_time.of_int64 UInt32.to_int64

  let of_timespan = Fn.compose UInt32.of_int64 Block_time.Span.to_ms

  let to_timespan = Fn.compose Block_time.Span.of_ms UInt32.to_int64

  let ( / ) = UInt32.Infix.( / )

  let ( * ) = UInt32.mul

  let ( + ) = UInt32.add

  let min = UInt32.min
end

module N =
  Mina_numbers.Nat.Make_checked
    (Unsigned_extended.UInt64)
    (Snark_bits.Bits.UInt64)

module Constants_checked :
  M_intf
    with type length = Length.Checked.t
     and type time = Block_time.Checked.t
     and type timespan = Block_time.Span.Checked.t = struct
  type t = N.var

  type length = Length.Checked.t

  type time = Block_time.Checked.t

  type timespan = Block_time.Span.Checked.t

  type bool_type = Boolean.var

  let constant c = N.Unsafe.of_field (Field.Var.constant (Field.of_int c))

  let zero = constant 0

  let one = constant 1

  let of_length = Fn.compose N.Unsafe.of_field Length.Checked.to_field

  let to_length = Fn.compose Length.Checked.Unsafe.of_field N.to_field

  let of_time : Block_time.Checked.t -> t =
    Fn.compose N.Unsafe.of_field Block_time.Checked.to_field

  let to_time : t -> Block_time.Checked.t =
    Fn.compose Block_time.Checked.Unsafe.of_field N.to_field

  let of_timespan : timespan -> t =
    Fn.compose N.Unsafe.of_field Block_time.Span.Checked.to_field

  let to_timespan : t -> timespan =
    Fn.compose Block_time.Span.Checked.Unsafe.of_field N.to_field

  let ( / ) (t : t) (t' : t) = Run.run_checked (N.div_mod t t') |> fst

  let ( * ) x y = Run.run_checked (N.mul x y)

  let ( + ) x y = Run.run_checked (N.add x y)

  let min x y = Run.run_checked (N.min x y)
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
  let block_window_duration_ms =
    constant constraint_constants.block_window_duration_ms
  in
  let k = of_length protocol_constants.k in
  let delta = of_length protocol_constants.delta in
  (*TODO: sub_windows_per_window, slots_per_sub_window are currently dummy
    values and need to be updated before mainnet*)
  let slots_per_sub_window =
    of_length protocol_constants.slots_per_sub_window
  in
  let sub_windows_per_window =
    constant constraint_constants.sub_windows_per_window
  in
  let slots_per_window = slots_per_sub_window * sub_windows_per_window in
  let slots_per_epoch = of_length protocol_constants.slots_per_epoch in
  let module Slot = struct
    let duration_ms = block_window_duration_ms
  end in
  let module Epoch = struct
    let size = slots_per_epoch

    (* Amount of time in total for an epoch *)
    let duration = Slot.duration_ms * size
  end in
  let delta_duration = Slot.duration_ms * (delta + M.one) in
  let num_days = 3. in
  assert (Float.(num_days < 14.)) ;
  (* We forgo updating the min density for the first [num_days] days (or epoch, whichever comes first)
      of the network's operation. The reasoning is as follows:

      - There may be many empty slots in the beginning of the network, as everyone
        gets their nodes up and running. [num_days] days gives all involved in the project
        a chance to observe the actual fill rate and try to fix what's keeping it down.
      - With actual network parameters, 1 epoch = 2 weeks > [num_days] days,
        which means the long fork rule will not come into play during the grace period,
        and then we still have several days to compute min-density for the next epoch. *)
  let grace_period_end =
    let slots =
      let n_days =
        let n_days_ms =
          Time_ns.Span.(to_ms (of_day num_days))
          |> Float.round_up |> Float.to_int |> M.constant
        in
        M.( / ) n_days_ms block_window_duration_ms
      in
      M.min n_days slots_per_epoch
    in
    match constraint_constants.fork with
    | None ->
        slots
    | Some f ->
        M.( + )
          (M.constant (Unsigned.UInt32.to_int f.previous_global_slot))
          slots
  in
  let res : (a, b, c) Poly.t =
    { Poly.k = to_length k
    ; delta = to_length delta
    ; block_window_duration_ms = to_timespan block_window_duration_ms
    ; slots_per_sub_window = to_length slots_per_sub_window
    ; slots_per_window = to_length slots_per_window
    ; sub_windows_per_window = to_length sub_windows_per_window
    ; slots_per_epoch = to_length slots_per_epoch
    ; grace_period_end = to_length grace_period_end
    ; slot_duration_ms = to_timespan Slot.duration_ms
    ; epoch_duration = to_timespan Epoch.duration
    ; checkpoint_window_slots_per_year = to_length zero
    ; checkpoint_window_size_in_slots = to_length zero
    ; delta_duration = to_timespan delta_duration
    ; genesis_state_timestamp = protocol_constants.genesis_state_timestamp
    }
  in
  res

let create ~(constraint_constants : Genesis_constants.Constraint_constants.t)
    ~(protocol_constants : Genesis_constants.Protocol.t) : t =
  let protocol_constants =
    Mina_base.Protocol_constants_checked.value_of_t protocol_constants
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
  ; checkpoint_window_slots_per_year
  }

let for_unit_tests =
  lazy
    (create
       ~constraint_constants:
         Genesis_constants.Constraint_constants.for_unit_tests
       ~protocol_constants:Genesis_constants.for_unit_tests.protocol)

let to_protocol_constants
    ({ k
     ; delta
     ; genesis_state_timestamp
     ; slots_per_sub_window
     ; slots_per_epoch
     ; _
     } :
      _ Poly.t) =
  { Mina_base.Protocol_constants_checked.Poly.k
  ; delta
  ; genesis_state_timestamp
  ; slots_per_sub_window
  ; slots_per_epoch
  }

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
    ; Block_time.Span.Checked.typ
    ; Block_time.Span.Checked.typ
    ; Block_time.Span.Checked.typ
    ; Block_time.Span.Checked.typ
    ; Block_time.Checked.typ
    ]

let typ =
  Typ.of_hlistable data_spec ~var_to_hlist:Poly.to_hlist
    ~var_of_hlist:Poly.of_hlist ~value_to_hlist:Poly.to_hlist
    ~value_of_hlist:Poly.of_hlist

let to_input (t : t) =
  Array.reduce_exn ~f:Random_oracle.Input.Chunked.append
    (Array.concat
       [ Array.map ~f:Length.to_input
           [| t.k
            ; t.delta
            ; t.slots_per_sub_window
            ; t.slots_per_window
            ; t.sub_windows_per_window
            ; t.slots_per_epoch
            ; t.grace_period_end
            ; t.checkpoint_window_slots_per_year
            ; t.checkpoint_window_size_in_slots
           |]
       ; Array.map ~f:Block_time.Span.to_input
           [| t.block_window_duration_ms
            ; t.slot_duration_ms
            ; t.epoch_duration
            ; t.delta_duration
           |]
       ; [| Block_time.to_input t.genesis_state_timestamp |]
       ])

let gc_parameters (constants : t) =
  let open Unsigned.UInt32 in
  let open Unsigned.UInt32.Infix in
  let delay = Block_time.Span.to_ms constants.delta_duration |> of_int64 in
  let gc_width = delay * of_int 2 in
  (* epoch, slot components of gc_width *)
  let gc_width_epoch = gc_width / constants.slots_per_epoch in
  let gc_width_slot = gc_width mod constants.slots_per_epoch in
  let gc_interval = gc_width in
  ( `Acceptable_network_delay delay
  , `Gc_width gc_width
  , `Gc_width_epoch gc_width_epoch
  , `Gc_width_slot gc_width_slot
  , `Gc_interval gc_interval )

module Checked = struct
  let to_input (t : var) =
    Array.reduce_exn ~f:Random_oracle.Input.Chunked.append
      (Array.concat
         [ Array.map ~f:Length.Checked.to_input
             [| t.k
              ; t.delta
              ; t.slots_per_sub_window
              ; t.slots_per_window
              ; t.sub_windows_per_window
              ; t.slots_per_epoch
              ; t.grace_period_end
              ; t.checkpoint_window_slots_per_year
              ; t.checkpoint_window_size_in_slots
             |]
         ; Array.map ~f:Block_time.Span.Checked.to_input
             [| t.block_window_duration_ms
              ; t.slot_duration_ms
              ; t.epoch_duration
              ; t.delta_duration
             |]
         ; [| Block_time.Checked.to_input t.genesis_state_timestamp |]
         ])

  let create ~(constraint_constants : Genesis_constants.Constraint_constants.t)
      ~(protocol_constants : Mina_base.Protocol_constants_checked.var) :
      var Checked.t =
    let%bind constants =
      make_checked (fun () ->
          create'
            (module Constants_checked)
            ~constraint_constants ~protocol_constants)
    in
    let%map checkpoint_window_slots_per_year, checkpoint_window_size_in_slots =
      let constant c =
        N.Unsafe.of_field (Field.Var.constant (Field.of_int c))
      in
      let per_year = constant 12 in
      let slot_duration_ms =
        N.Unsafe.of_field
          (Block_time.Span.Checked.to_field constants.slot_duration_ms)
      in
      let%bind slots_per_year, _ =
        let one_year_ms =
          constant (Core.Time.Span.(to_ms (of_day 365.)) |> Float.to_int)
        in
        N.div_mod one_year_ms slot_duration_ms
      in
      let%map size_in_slots =
        let%bind size_in_slots, rem = N.div_mod slots_per_year per_year in
        let%map () = N.Assert.equal rem (constant 0) in
        size_in_slots
      in
      let to_length = Fn.compose Length.Checked.Unsafe.of_field N.to_field in
      (to_length slots_per_year, to_length size_in_slots)
    in
    { constants with
      checkpoint_window_slots_per_year
    ; checkpoint_window_size_in_slots
    }
end

let%test_unit "checked = unchecked" =
  let open Mina_base in
  let for_unit_tests = Genesis_constants.for_unit_tests.protocol in
  let constraint_constants =
    Genesis_constants.Constraint_constants.for_unit_tests
  in
  let test =
    Test_util.test_equal Protocol_constants_checked.typ typ
      (fun protocol_constants ->
        Checked.create ~constraint_constants ~protocol_constants)
      (fun protocol_constants ->
        create ~constraint_constants
          ~protocol_constants:
            (Protocol_constants_checked.t_of_value protocol_constants))
  in
  Quickcheck.test ~trials:100 Protocol_constants_checked.Value.gen
    ~examples:[ Protocol_constants_checked.value_of_t for_unit_tests ]
    ~f:test
