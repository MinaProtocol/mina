module type S = sig
  open Async_kernel
  open Core_kernel
  open Snark_params
  open Snark_bits

  (** A block timestamp: an {b unsigned} count of milliseconds since the Unix
      epoch ([Unsigned.UInt64.t]).  It is therefore ALWAYS non-negative and
      spans the full [0 .. 2^64-1] range, including values [>= 2^63];
      {!max_value} is itself a legal timestamp.

      Every operation that stays within the uint64 domain — bin_io, sexp,
      yojson, comparison, arithmetic, {!to_uint64}/{!of_uint64},
      {!to_string_exn}, and SNARK packing — is total and lossless across the
      whole range.  The ONLY genuinely partial conversion is mapping to Core's
      float-backed {!Core_kernel.Time.t}, which cannot faithfully hold values
      [>= 2^63] (~year 2262).  That partiality is isolated in {!to_time_opt};
      {!to_time_exn} is a checked wrapper that raises above it.  Note the
      [Span] float conversions ({!Span.to_time_span}, {!Span.to_time_ns_span})
      are lossy for large spans but never raise. *)
  module Time : sig
    type t [@@deriving sexp, compare, yojson]

    val zero : t

    val max_value : t

    include Comparable.S with type t := t

    include Hashable.S with type t := t

    module Controller : sig
      type t [@@deriving sexp, equal, compare]

      val basic : logger:Logger.t -> t

      (** Override the time offset set by the [MINA_TIME_OFFSET] environment
          variable for all block time controllers.
          [enable_setting_offset] must have been called first, and
          [disable_setting_offset] must not have been called, otherwise this
          raises a [Failure].
      *)
      val set_time_offset : Time.Span.t -> unit

      (** Get the current time offset, either from the [MINA_TIME_OFFSET]
          environment variable, or as last set by [set_time_offset].
      *)
      val get_time_offset : logger:Logger.t -> Time.Span.t

      (** Disallow setting the time offset. This should be run at every
          entrypoint which does not explicitly need to update the time offset.
      *)
      val disable_setting_offset : unit -> unit

      (** Allow setting the time offset. This may only be run if
          [disable_setting_offset] has not already been called, otherwise it will
          raise a [Failure].
      *)
      val enable_setting_offset : unit -> unit
    end

    [%%versioned:
    module Stable : sig
      [@@@no_toplevel_latest_type]

      module V1 : sig
        type nonrec t = t [@@deriving sexp, compare, equal, hash, yojson]

        include Hashable.S with type t := t
      end
    end]

    module Bits : Bits_intf.Convertible_bits with type t := t

    include
      Tick.Snarkable.Bits.Faithful
        with type Unpacked.value = t
         and type Packed.value = t
         and type Packed.var = private Tick.Field.Var.t

    val to_input : t -> Tick.Field.t Random_oracle_input.Chunked.t

    module Checked : sig
      open Snark_params.Tick

      type t

      val typ : (t, Stable.Latest.t) Typ.t

      val to_input : t -> Field.Var.t Random_oracle_input.Chunked.t

      val ( = ) : t -> t -> Boolean.var Checked.t

      val ( < ) : t -> t -> Boolean.var Checked.t

      val ( > ) : t -> t -> Boolean.var Checked.t

      val ( <= ) : t -> t -> Boolean.var Checked.t

      val ( >= ) : t -> t -> Boolean.var Checked.t

      val to_field : t -> Field.Var.t

      module Unsafe : sig
        val of_field : Field.Var.t -> t
      end
    end

    module Span : sig
      type t [@@deriving sexp, compare, equal, yojson]

      module Stable : sig
        module V1 : sig
          type nonrec t = t
          [@@deriving bin_io, equal, sexp, compare, hash, yojson, version]
        end
      end

      val of_time_span : Time.Span.t -> t

      (** Lossy calendar-domain conversion via float: spans [>= 2^63] ms exceed
          the signed-int64 reinterpretation and wrap to a NEGATIVE
          [Time.Span.t], and above [2^53] ms precision is lost.  Never raises,
          and is not a wire/serialization path; all in-repo callers pass small
          slot/diff spans. *)
      val to_time_span : t -> Time.Span.t

      module Bits : Bits_intf.Convertible_bits with type t := t

      include
        Tick.Snarkable.Bits.Faithful
          with type Unpacked.value = t
           and type Packed.value = t

      val to_time_ns_span : t -> Core_kernel.Time_ns.Span.t

      val of_time_ns_span : Core_kernel.Time_ns.Span.t -> t

      val to_string_hum : t -> string

      val to_ms : t -> Int64.t

      val of_ms : Int64.t -> t

      val ( + ) : t -> t -> t

      val ( - ) : t -> t -> t

      val ( * ) : t -> t -> t

      val ( < ) : t -> t -> bool

      val ( > ) : t -> t -> bool

      val ( = ) : t -> t -> bool

      val ( <= ) : t -> t -> bool

      val ( >= ) : t -> t -> bool

      val min : t -> t -> t

      val zero : t

      val to_input : t -> Tick.Field.t Random_oracle_input.Chunked.t

      module Checked : sig
        type t

        val typ : (t, Stable.V1.t) Snark_params.Tick.Typ.t

        open Snark_params.Tick

        val to_input : t -> Tick.Field.Var.t Random_oracle_input.Chunked.t

        val to_field : t -> Field.Var.t

        module Unsafe : sig
          val of_field : Field.Var.t -> t
        end
      end
    end

    val field_var_to_unpacked : Tick.Field.Var.t -> Unpacked.var Tick.Checked.t

    val diff_checked :
      Unpacked.var -> Unpacked.var -> Span.Unpacked.var Tick.Checked.t

    val unpacked_to_number : Span.Unpacked.var -> Tick.Number.t

    val add : t -> Span.t -> t

    val diff : t -> t -> Span.t

    val sub : t -> Span.t -> t

    val to_span_since_epoch : t -> Span.t

    val of_span_since_epoch : Span.t -> t

    val modulus : t -> Span.t -> Span.t

    val of_time : Time.t -> t

    (** [None] when [t >= 2^63], which is unrepresentable in the float-backed
        {!Core_kernel.Time.t}.  This is the single partial conversion out of
        the unsigned-uint64 domain; prefer it on any path that may see
        full-range input. *)
    val to_time_opt : t -> Time.t option

    (** Raises when [t >= 2^63].  Prefer {!to_time_opt}; use only where the
        caller has already established [t < 2^63] (e.g. locally-generated
        times). *)
    val to_time_exn : t -> Time.t

    val now : Controller.t -> t

    val to_int64 : t -> Int64.t

    val of_int64 : Int64.t -> t

    val of_uint64 : Unsigned.UInt64.t -> t

    val to_uint64 : t -> Unsigned.UInt64.t

    val of_time_ns : Time_ns.t -> t

    (** Total unsigned-decimal serialization; never raises (the [_exn] suffix
        is retained only to avoid a wide rename).  Lossless across
        [0 .. 2^64-1] and byte-identical to the yojson/sexp encoding. *)
    val to_string_exn : t -> string

    (** Strip time offset.  Total; never raises. *)
    val to_string_system_time_exn : Controller.t -> t -> string

    (** Strip time offset *)
    val to_system_time : Controller.t -> t -> t

    (** Parse an unsigned decimal string in [0 .. 2^64-1].  Raises on a leading
        '-' (negative timestamps are not representable) or on non-numeric /
        out-of-range input.  Inverse of {!to_string_exn}. *)
    val of_string_exn : string -> t

    val gen_incl : t -> t -> t Quickcheck.Generator.t

    val gen : t Quickcheck.Generator.t
  end

  include module type of Time with type t = Time.t

  module Timeout : sig
    type 'a t

    type time

    val create : Controller.t -> Span.t -> f:(time -> 'a) -> 'a t

    val to_deferred : 'a t -> 'a Async_kernel.Deferred.t

    val peek : 'a t -> 'a option

    val cancel : Controller.t -> 'a t -> 'a -> unit

    val remaining_time : 'a t -> Span.t

    val await :
         timeout_duration:Span.t
      -> Controller.t
      -> 'a Deferred.t
      -> [ `Ok of 'a | `Timeout ] Deferred.t

    val await_exn :
      timeout_duration:Span.t -> Controller.t -> 'a Deferred.t -> 'a Deferred.t
  end
  with type time := t
end
