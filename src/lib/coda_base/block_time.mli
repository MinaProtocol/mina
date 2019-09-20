open Core_kernel
open Snark_params
open Snark_bits
open Tuple_lib
open Fold_lib

module Time : sig
  type t [@@deriving sexp, eq, yojson]

  type t0 = t

  module Controller : sig
    type t

    val create : t -> t

    val basic : logger:Logger.t -> t
  end

  module Stable : sig
    module V1 : sig
      type nonrec t = t
      [@@deriving sexp, bin_io, compare, eq, hash, yojson, version]
    end
  end

  val length_in_triples : int

  module Bits : Bits_intf.S with type t := t

  val fold : t -> bool Triple.t Fold.t

  include
    Tick.Snarkable.Bits.Faithful
    with type Unpacked.value = t
     and type Packed.value = t
     and type Packed.var = private Tick.Field.Var.t

  module Span : sig
    type t [@@deriving sexp, compare]

    module Stable : sig
      module V1 : sig
        type nonrec t = t [@@deriving bin_io, sexp, compare]
      end
    end

    val of_time_span : Time.Span.t -> t

    include
      Tick.Snarkable.Bits.Faithful
      with type Unpacked.value = t
       and type Packed.value = t

    val to_time_ns_span : t -> Core.Time_ns.Span.t

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
  end

  val ( < ) : t -> t -> bool

  val ( > ) : t -> t -> bool

  val ( = ) : t -> t -> bool

  val ( <= ) : t -> t -> bool

  val ( >= ) : t -> t -> bool

  val field_var_to_unpacked :
    Tick.Field.Var.t -> (Unpacked.var, _) Tick.Checked.t

  val diff_checked :
    Unpacked.var -> Unpacked.var -> (Span.Unpacked.var, _) Tick.Checked.t

  val unpacked_to_number : Span.Unpacked.var -> Tick.Number.t

  val add : t -> Span.t -> t

  val diff : t -> t -> Span.t

  val sub : t -> Span.t -> t

  val to_span_since_epoch : t -> Span.t

  val of_span_since_epoch : Span.t -> t

  val modulus : t -> Span.t -> Span.t

  val of_time : Time.t -> t

  val to_time : t -> Time.t

  val now : Controller.t -> t

  val to_string : t -> string

  val of_string_exn : string -> t
end

include module type of Time

module Timeout : sig
  type 'a t

  val create : Controller.t -> Span.t -> f:(t0 -> 'a) -> 'a t

  val to_deferred : 'a t -> 'a Async_kernel.Deferred.t

  val peek : 'a t -> 'a option

  val cancel : Controller.t -> 'a t -> 'a -> unit

  val remaining_time : 'a t -> Span.t
end
