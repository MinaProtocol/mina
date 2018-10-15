open Core_kernel
open Async_kernel
open Snark_params.Tick
open Snark_bits
open Fold_lib
open Tuple_lib

module Controller = struct
  module type S = sig
    type t

    val create : unit -> t
  end
end

module type S = sig
  module Controller : Controller.S

  type t [@@deriving sexp]

  module Stable : sig
    module V1 : sig
      type nonrec t = t [@@deriving sexp, bin_io]
    end
  end

  module Bits : Bits_intf.S with type t := t

  val fold : t -> bool Triple.t Fold.t

  include Snarkable.Bits.Faithful
          with type Unpacked.value = t
           and type Packed.value = t
           and type Packed.var = private Field.Checked.t

  module Span : sig
    type t

    val of_time_span : Core_kernel.Time.Span.t -> t

    val to_ms : t -> Int64.t

    val of_ms : Int64.t -> t

    val ( < ) : t -> t -> bool

    val ( > ) : t -> t -> bool

    val ( >= ) : t -> t -> bool

    val ( <= ) : t -> t -> bool

    val ( = ) : t -> t -> bool
  end

  module Timeout : sig
    type 'a t

    val create : Controller.t -> Span.t -> f:(Stable.V1.t -> 'a) -> 'a t

    val to_deferred : 'a t -> 'a Deferred.t

    val peek : 'a t -> 'a option

    val cancel : Controller.t -> 'a t -> 'a -> unit
  end

  val to_span_since_epoch : t -> Span.t

  val of_span_since_epoch : Span.t -> t

  val diff : t -> t -> Span.t

  val sub : t -> Span.t -> t

  val add : t -> Span.t -> t

  val modulus : t -> Span.t -> Span.t

  val now : Controller.t -> t
end
