[%%import "/src/config.mlh"]

open Core_kernel
open Snark_bits
open Snark_params.Tick

type uint64 = Unsigned.uint64

module type Basic = sig
  type t [@@deriving sexp, compare, hash, yojson]

  type magnitude = t [@@deriving sexp, compare]

  (* not automatically derived *)
  val dhall_type : Ppx_dhall_type.Dhall_type.t

  val max_int : t

  val length_in_bits : int

  include Comparable.S with type t := t

  val gen_incl : t -> t -> t Quickcheck.Generator.t

  val gen : t Quickcheck.Generator.t

  include Bits_intf.Convertible_bits with type t := t

  val to_input : t -> Field.t Random_oracle.Input.Chunked.t

  val to_input_legacy : t -> (_, bool) Random_oracle.Legacy.Input.t

  val zero : t

  val one : t

  val of_string : string -> t

  val to_string : t -> string

  val of_mina_string_exn : string -> t

  val to_mina_string : t -> string

  val to_uint64 : t -> uint64

  val of_uint64 : uint64 -> t

  (* The functions below are unsafe, because they could overflow or
     underflow. They perform appropriate checks to guard against this
     and either raise Currency_overflow exception or return None
     depending on the error-handling strategy.

     It is advisable to use nanomina and mina wherever possible and
     limit the use of _exn veriants to places where a fixed value is
     being converted and hence overflow cannot happen. *)
  val of_mina_int_exn : int -> t

  val of_nanomina_int_exn : int -> t

  val of_mina_int : int -> t option

  val of_nanomina_int : int -> t option

  val to_mina_int : t -> int

  val to_nanomina_int : t -> int

  [%%ifdef consensus_mechanism]

  type var

  val typ : (var, t) Typ.t

  val var_of_t : t -> var

  val var_to_bits :
    var -> Boolean.var Bitstring_lib.Bitstring.Lsb_first.t Checked.t

  val var_to_input : var -> Field.Var.t Random_oracle.Input.Chunked.t

  val var_to_input_legacy :
    var -> (Field.Var.t, Boolean.var) Random_oracle.Input.Legacy.t Checked.t

  val equal_var : var -> var -> Boolean.var Checked.t

  val pack_var : var -> Field.Var.t

  [%%endif]
end

module type Arithmetic_intf = sig
  type t

  val add : t -> t -> t option

  val add_flagged : t -> t -> t * [ `Overflow of bool ]

  val sub : t -> t -> t option

  val sub_flagged : t -> t -> t * [ `Underflow of bool ]

  val ( + ) : t -> t -> t option

  val ( - ) : t -> t -> t option

  val scale : t -> int -> t option
end

module type Signed_intf = sig
  type magnitude

  type signed_fee

  [%%ifdef consensus_mechanism]

  type magnitude_var

  [%%endif]

  type t = (magnitude, Sgn.t) Signed_poly.t
  [@@deriving sexp, hash, compare, equal, yojson]

  val gen : t Quickcheck.Generator.t

  val create :
    magnitude:'magnitude -> sgn:'sgn -> ('magnitude, 'sgn) Signed_poly.t

  val sgn : t -> Sgn.t

  val magnitude : t -> magnitude

  val zero : t

  val is_zero : t -> bool

  val is_positive : t -> bool

  val is_negative : t -> bool

  val to_input : t -> Field.t Random_oracle.Input.Chunked.t

  val to_input_legacy : t -> (_, bool) Random_oracle.Legacy.Input.t

  val add : t -> t -> t option

  val add_flagged : t -> t -> t * [ `Overflow of bool ]

  val ( + ) : t -> t -> t option

  val negate : t -> t

  val of_unsigned : magnitude -> t

  val to_fee : t -> signed_fee

  val of_fee : signed_fee -> t

  [%%ifdef consensus_mechanism]

  type var (* = (magnitude_var, Sgn.var) Signed_poly.t *)

  val create_var : magnitude:magnitude_var -> sgn:Sgn.var -> var

  val typ : (var, t) Typ.t

  module Checked : sig
    type signed_fee_var

    val constant : t -> var

    val of_unsigned : magnitude_var -> var

    val sgn : var -> Sgn.var Checked.t

    val magnitude : var -> magnitude_var Checked.t

    val negate : var -> var

    val if_ : Boolean.var -> then_:var -> else_:var -> var Checked.t

    val to_input : var -> Field.Var.t Random_oracle.Input.Chunked.t Checked.t

    val to_input_legacy :
      var -> (_, Boolean.var) Random_oracle.Legacy.Input.t Checked.t

    val add : var -> var -> var Checked.t

    val add_flagged :
      var -> var -> (var * [ `Overflow of Boolean.var ]) Checked.t

    val assert_equal : var -> var -> unit Checked.t

    val equal : var -> var -> Boolean.var Checked.t

    val ( + ) : var -> var -> var Checked.t

    val to_field_var : var -> Field.Var.t Checked.t

    val to_fee : var -> signed_fee_var

    val of_fee : signed_fee_var -> var

    type t = var
  end

  [%%endif]
end

[%%ifdef consensus_mechanism]

module type Checked_arithmetic_intf = sig
  type value

  type var

  type t = var

  type signed_var

  val if_ : Boolean.var -> then_:var -> else_:var -> var Checked.t

  val add : var -> var -> var Checked.t

  val sub : var -> var -> var Checked.t

  val sub_flagged :
    var -> var -> (var * [ `Underflow of Boolean.var ]) Checked.t

  val sub_or_zero : var -> var -> var Checked.t

  val add_flagged : var -> var -> (var * [ `Overflow of Boolean.var ]) Checked.t

  val ( + ) : var -> var -> var Checked.t

  val ( - ) : var -> var -> var Checked.t

  val add_signed : var -> signed_var -> var Checked.t

  val add_signed_flagged :
    var -> signed_var -> (var * [ `Overflow of Boolean.var ]) Checked.t

  val assert_equal : var -> var -> unit Checked.t

  val equal : var -> var -> Boolean.var Checked.t

  val ( = ) : t -> t -> Boolean.var Checked.t

  val ( < ) : t -> t -> Boolean.var Checked.t

  val ( > ) : t -> t -> Boolean.var Checked.t

  val ( <= ) : t -> t -> Boolean.var Checked.t

  val ( >= ) : t -> t -> Boolean.var Checked.t

  val scale : Field.Var.t -> var -> var Checked.t
end

[%%endif]

module type S = sig
  include Basic

  include Arithmetic_intf with type t := t

  [%%ifdef consensus_mechanism]

  module Signed :
    Signed_intf with type magnitude := t and type magnitude_var := var

  module Checked :
    Checked_arithmetic_intf
      with type var := var
       and type signed_var := Signed.var
       and type value := t

  [%%else]

  module Signed : Signed_intf with type magnitude := t

  [%%endif]

  val add_signed_flagged : t -> Signed.t -> t * [ `Overflow of bool ]
end

module type Full = sig
  [%%ifdef consensus_mechanism]

  open Snark_params.Tick

  module Signed_var : sig
    type 'mag repr = ('mag, Sgn.var) Signed_poly.t

    (* Invariant: At least one of these is Some *)
    type nonrec 'mag t =
      { repr : 'mag repr; mutable value : Field.Var.t option }
  end

  [%%endif]

  module Signed_poly = Signed_poly

  module Fee : sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        [@@@with_all_version_tags]

        type t [@@deriving sexp, compare, hash, yojson, equal]

        (* not automatically derived *)
        val dhall_type : Ppx_dhall_type.Dhall_type.t
      end
    end]

    include Basic with type t := Stable.Latest.t

    include Arithmetic_intf with type t := t

    include Codable.S with type t := t

    (* TODO: Get rid of signed fee, use signed amount *)
    [%%ifdef consensus_mechanism]

    module Signed :
      Signed_intf
        with type magnitude := t
         and type magnitude_var := var
         and type signed_fee := (t, Sgn.t) Signed_poly.t
         and type Checked.signed_fee_var := Field.Var.t Signed_var.t

    [%%else]

    module Signed :
      Signed_intf
        with type magnitude := t
         and type signed_fee := (t, Sgn.t) Signed_poly.t

    [%%endif]

    [%%ifdef consensus_mechanism]

    module Checked : sig
      include
        Checked_arithmetic_intf
          with type var := var
           and type signed_var := Signed.var
           and type value := t

      val add_signed : var -> Signed.var -> var Checked.t
    end

    [%%endif]
  end
  [@@warning "-32"]

  module Amount : sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        [@@@with_all_version_tags]

        type t [@@deriving sexp, compare, hash, equal, yojson]

        (* not automatically derived *)
        val dhall_type : Ppx_dhall_type.Dhall_type.t
      end
    end]

    include Basic with type t := Stable.Latest.t

    include Arithmetic_intf with type t := t

    include Codable.S with type t := t

    [%%ifdef consensus_mechanism]

    module Signed :
      Signed_intf
        with type magnitude := t
         and type magnitude_var := var
         and type signed_fee := Fee.Signed.t
         and type Checked.signed_fee_var := Fee.Signed.Checked.t

    [%%else]

    module Signed :
      Signed_intf with type magnitude := t and type signed_fee := Fee.Signed.t

    [%%endif]

    (* TODO: Delete these functions *)

    val of_fee : Fee.t -> t

    val to_fee : t -> Fee.t

    val add_fee : t -> Fee.t -> t option

    val add_signed_flagged : t -> Signed.t -> t * [ `Overflow of bool ]

    [%%ifdef consensus_mechanism]

    module Checked : sig
      include
        Checked_arithmetic_intf
          with type var := var
           and type signed_var := Signed.var
           and type value := t

      val add_signed : var -> Signed.var -> var Checked.t

      val add_signed_flagged :
        var -> Signed.var -> (var * [ `Overflow of Boolean.var ]) Checked.t

      val of_fee : Fee.var -> var

      val to_fee : var -> Fee.var

      val to_field : var -> Field.Var.t

      module Unsafe : sig
        val of_field : Field.Var.t -> t
      end
    end

    [%%endif]
  end
  [@@warning "-32"]

  module Balance : sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        type t [@@deriving sexp, compare, hash, yojson, equal]

        (* not automatically derived *)
        val dhall_type : Ppx_dhall_type.Dhall_type.t
      end
    end]

    include Basic with type t := Stable.Latest.t

    val to_amount : t -> Amount.t

    val add_amount : t -> Amount.t -> t option

    val add_amount_flagged : t -> Amount.t -> t * [ `Overflow of bool ]

    val sub_amount : t -> Amount.t -> t option

    val sub_amount_flagged : t -> Amount.t -> t * [ `Underflow of bool ]

    val add_signed_amount_flagged :
      t -> Amount.Signed.t -> t * [ `Overflow of bool ]

    val ( + ) : t -> Amount.t -> t option

    val ( - ) : t -> Amount.t -> t option

    [%%ifdef consensus_mechanism]

    module Checked : sig
      type t = var

      val to_amount : t -> Amount.var

      val add_signed_amount : var -> Amount.Signed.var -> var Checked.t

      val add_amount : var -> Amount.var -> var Checked.t

      val sub_amount : var -> Amount.var -> var Checked.t

      val sub_amount_flagged :
        var -> Amount.var -> (var * [ `Underflow of Boolean.var ]) Checked.t

      val add_amount_flagged :
        var -> Amount.var -> (var * [ `Overflow of Boolean.var ]) Checked.t

      val add_signed_amount_flagged :
           var
        -> Amount.Signed.var
        -> (var * [ `Overflow of Boolean.var ]) Checked.t

      val sub_or_zero : var -> var -> var Checked.t

      val ( + ) : var -> Amount.var -> var Checked.t

      val ( - ) : var -> Amount.var -> var Checked.t

      val equal : var -> var -> Boolean.var Checked.t

      val ( = ) : var -> var -> Boolean.var Checked.t

      val ( < ) : var -> var -> Boolean.var Checked.t

      val ( > ) : var -> var -> Boolean.var Checked.t

      val ( <= ) : var -> var -> Boolean.var Checked.t

      val ( >= ) : var -> var -> Boolean.var Checked.t

      val if_ : Boolean.var -> then_:var -> else_:var -> var Checked.t

      val to_field : var -> Field.Var.t

      module Unsafe : sig
        val of_field : Field.Var.t -> var
      end
    end

    [%%endif]
  end
  [@@warning "-32"]

  module Fee_rate : sig
    type t

    include Arithmetic_intf with type t := t

    include Comparable.S with type t := t

    include Sexpable.S with type t := t

    val of_q : Q.t -> t option

    val of_q_exn : Q.t -> t

    val to_q : t -> Q.t

    (** construct a fee rate from a fee and a weight *)
    val make : Fee.t -> int -> t option

    (** construct a fee rate from a fee and a weight *)
    val make_exn : Fee.t -> int -> t

    (** convert to uint64, if the fee rate is equivalent to an integer. *)
    val to_uint64 : t -> uint64 option

    (** convert to uint64, if the fee rate is equivalent to an integer. *)
    val to_uint64_exn : t -> uint64

    val mul : t -> t -> t option

    val scale_exn : t -> int -> t

    val div : t -> t -> t option

    val ( * ) : t -> t -> t option
  end
end
