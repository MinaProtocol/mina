module type S_base = sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t [@@deriving hash, sexp, compare, equal, yojson]
    end
  end]

  val to_uint32 : t -> Unsigned.uint32

  val of_uint32 : Unsigned.uint32 -> t

  val to_string : t -> string

  val of_string : string -> t

  val gen : t Core_kernel.Quickcheck.Generator.t

  val gen_incl : t -> t -> t Core_kernel.Quickcheck.Generator.t

  val dhall_type : Ppx_dhall_type.Dhall_type.t

  val zero : t

  val one : t

  val succ : t -> t

  val of_int : int -> t

  val to_int : t -> int

  val max_value : t

  val to_input : t -> Snark_params.Tick.Field.t Random_oracle.Input.Chunked.t

  val to_input_legacy : t -> ('a, bool) Random_oracle.Legacy.Input.t

  val to_field : t -> Snark_params.Tick.Field.t

  val random : unit -> t

  include Core_kernel.Comparable.S with type t := t
end

module type S = sig
  include S_base

  type global_slot_span

  module Checked : sig
    include Intf.S_checked with type unchecked := t

    type global_slot_span_checked

    open Snark_params.Tick

    val add : t -> global_slot_span_checked -> t Checked.t

    val sub : t -> global_slot_span_checked -> t Checked.t

    val diff : t -> t -> global_slot_span_checked Checked.t

    val diff_or_zero :
         t
      -> t
      -> ([ `Underflow of Boolean.var ] * global_slot_span_checked) Checked.t
  end

  val typ : (Checked.t, t) Snark_params.Tick.Typ.t

  val add : t -> global_slot_span -> t

  val sub : t -> global_slot_span -> t option

  val diff : t -> t -> global_slot_span option
end

module type S_span = sig
  include S_base

  module Checked : Intf.S_checked with type unchecked := t

  val typ : (Checked.t, t) Snark_params.Tick.Typ.t

  val add : t -> t -> t

  val sub : t -> t -> t option
end
