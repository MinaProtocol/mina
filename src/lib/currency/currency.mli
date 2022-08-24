[%%import "/src/config.mlh"]

open Core_kernel

[%%ifdef consensus_mechanism]

open Snark_params.Tick

module Signed_var : sig
  type 'mag repr = ('mag, Sgn.var) Signed_poly.t

  (* Invariant: At least one of these is Some *)
  type nonrec 'mag t = { repr : 'mag repr; mutable value : Field.Var.t option }
end

[%%endif]

type uint64 = Unsigned.uint64

module Signed_poly = Signed_poly

module Fee : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
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
      var -> Amount.Signed.var -> (var * [ `Overflow of Boolean.var ]) Checked.t

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
