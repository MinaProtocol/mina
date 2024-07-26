open Core_kernel
open Snark_params
open Tick
open Unsigned_extended
open Snark_bits

(** See documentation of the {!Mina_wire_types} library *)
module Wire_types = Mina_wire_types.Block_time

module Make_sig (A : Wire_types.Types.S) = struct
  module type S = Intf.S with type Time.t = A.V1.t
end

module Make_str (_ : Wire_types.Concrete) = struct
  module Time = struct
    (* Milliseconds since epoch *)
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = UInt64.Stable.V1.t
        [@@deriving sexp, compare, equal, hash, yojson]

        let to_latest = Fn.id

        module T = struct
          type typ = t [@@deriving sexp, compare, hash]

          type t = typ [@@deriving sexp, compare, hash]
        end

        include Hashable.Make (T)
      end
    end]

    let max_value = UInt64.max_int

    let zero = UInt64.zero

    module Controller = struct
      type t = unit -> Time.Span.t [@@deriving sexp]

      (* NB: All instances are identical by construction (see basic below). *)
      let equal _ _ = true

      (* NB: All instances are identical by construction (see basic below). *)
      let compare _ _ = 0

      let time_offset = ref None

      let setting_enabled = ref None

      let disable_setting_offset () = setting_enabled := Some false

      let enable_setting_offset () =
        match !setting_enabled with
        | None ->
            setting_enabled := Some true
        | Some true ->
            ()
        | Some false ->
            failwith
              "Cannot enable time offset mutations; it has been explicitly \
               disabled"

      let set_time_offset offset =
        match !setting_enabled with
        | Some true ->
            time_offset := Some offset
        | None | Some false ->
            failwith "Cannot mutate the time offset"

      let create offset = offset

      let basic ~logger:_ () =
        match !time_offset with
        | Some offset ->
            offset
        | None ->
            let offset =
              let env = "MINA_TIME_OFFSET" in
              let env_offset =
                match Core_kernel.Sys.getenv_opt env with
                | Some tm ->
                    Int.of_string tm
                | None ->
                    let default = 0 in
                    eprintf
                      "Environment variable %s not found, using default of %d\n\
                       %!"
                      env default ;
                    default
              in
              Core_kernel.Time.Span.of_int_sec env_offset
            in
            time_offset := Some offset ;
            offset

      let get_time_offset ~logger = basic ~logger ()
    end

    module B = Bits
    module Bits = Bits.UInt64
    include B.Snarkable.UInt64 (Tick)
    module N = Mina_numbers.Nat.Make_checked (UInt64) (Bits)

    let to_input (t : t) =
      Random_oracle_input.Chunked.packed
        (Tick.Field.project (Bits.to_bits t), 64)

    module Checked = struct
      type t = N.var

      module Unsafe = N.Unsafe

      let to_input (t : t) = N.to_input t

      let to_field = N.to_field

      [%%define_locally N.(typ, ( = ), ( <= ), ( >= ), ( < ), ( > ))]
    end

    module Span = struct
      [%%versioned
      module Stable = struct
        module V1 = struct
          type t = UInt64.Stable.V1.t
          [@@deriving sexp, compare, equal, hash, yojson]

          let to_latest = Fn.id
        end
      end]

      module Bits = B.UInt64
      include B.Snarkable.UInt64 (Tick)

      let of_time_span s = UInt64.of_int64 (Int64.of_float (Time.Span.to_ms s))

      let to_time_span s = Time.Span.of_ms (Int64.to_float (UInt64.to_int64 s))

      let to_time_ns_span s =
        Time_ns.Span.of_ms (Int64.to_float (UInt64.to_int64 s))

      let of_time_ns_span ns : t =
        let int64_ns = ns |> Time_ns.Span.to_int63_ns |> Int63.to_int64 in
        (* convert to milliseconds *)
        Int64.(int64_ns / 1_000_000L) |> UInt64.of_int64

      let to_string_hum s = to_time_ns_span s |> Time_ns.Span.to_string_hum

      let to_ms = UInt64.to_int64

      let of_ms = UInt64.of_int64

      [%%define_locally UInt64.Infix.(( + ), ( - ), ( * ))]

      [%%define_locally UInt64.(( < ), ( > ), ( = ), ( <= ), ( >= ), min, zero)]

      let to_input = to_input

      module Checked = Checked
    end

    include Comparable.Make (Stable.Latest)
    include Hashable.Make (Stable.Latest)

    let of_time t =
      UInt64.of_int64
        (Int64.of_float (Time.Span.to_ms (Time.to_span_since_epoch t)))

    (* TODO: Time.t can't hold the full uint64 range, so this can fail for large t *)
    let to_time_exn t =
      let t_int64 = UInt64.to_int64 t in
      if Int64.(t_int64 < zero) then failwith "converting to negative timestamp" ;
      Time.of_span_since_epoch (Time.Span.of_ms (Int64.to_float t_int64))

    let now offset = of_time (Time.sub (Time.now ()) (offset ()))

    let field_var_to_unpacked (x : Tick.Field.Var.t) =
      Tick.Field.Checked.unpack ~length:64 x

    let epoch = of_time Time.epoch

    let add x y = UInt64.add x y

    let diff x y = UInt64.sub x y

    let sub x y = UInt64.sub x y

    let to_span_since_epoch t = diff t epoch

    let of_span_since_epoch s = UInt64.add s epoch

    let diff_checked x y =
      let pack = Tick.Field.Var.project in
      Span.unpack_var Tick.Field.Checked.(pack x - pack y)

    let modulus t span = UInt64.rem t span

    let unpacked_to_number var =
      let bits = Span.Unpacked.var_to_bits var in
      Number.of_bits (bits :> Boolean.var list)

    let to_int64 = Fn.compose Span.to_ms to_span_since_epoch

    let of_int64 = Fn.compose of_span_since_epoch Span.of_ms

    let of_uint64 : UInt64.t -> t = of_span_since_epoch

    let to_uint64 : t -> UInt64.t = to_span_since_epoch

    (* TODO: this can fail if the input has more than 63 bits, because it would be serialized to a negative number string *)
    let to_string_exn t =
      let t_int64 = UInt64.to_int64 t in
      if Int64.(t_int64 < zero) then failwith "converting to negative timestamp" ;
      Int64.to_string t_int64

    let of_time_ns ns : t =
      let int64_ns = ns |> Time_ns.to_int63_ns_since_epoch |> Int63.to_int64 in
      (* convert to milliseconds *)
      Int64.(int64_ns / 1_000_000L) |> UInt64.of_int64

    let to_system_time (offset : Controller.t) (t : t) =
      of_span_since_epoch
        Span.(to_span_since_epoch t + of_time_span (offset ()))

    let to_string_system_time_exn (offset : Controller.t) (t : t) : string =
      to_system_time offset t |> to_string_exn

    let of_string_exn string =
      Int64.of_string string |> Span.of_ms |> of_span_since_epoch

    let gen_incl time_beginning time_end =
      let open Quickcheck.Let_syntax in
      let time_beginning_int64 = to_int64 time_beginning in
      let time_end_int64 = to_int64 time_end in
      let%map int64_time_span =
        Int64.(gen_incl time_beginning_int64 time_end_int64)
      in
      of_span_since_epoch @@ Span.of_ms int64_time_span

    let gen =
      let open Quickcheck.Let_syntax in
      let%map int64_time_span = Int64.(gen_incl zero max_value) in
      of_span_since_epoch @@ Span.of_ms int64_time_span
  end

  include Time
  module Timeout = Timeout_lib.Make (Time)
end

include Wire_types.Make (Make_sig) (Make_str)
