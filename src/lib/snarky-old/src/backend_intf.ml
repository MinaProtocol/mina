open Core_kernel

module type S = sig
  module Field : Field_intf.S

  module Bigint : sig
    module R : Bigint_intf.Extended with type field := Field.t
  end

  val field_size : Bigint.R.t

  module Var : sig
    type t

    val index : t -> int

    val create : int -> t
  end

  module Linear_combination : sig
    type t

    val create : unit -> t

    val of_var : Var.t -> t

    val of_field : Field.t -> t

    val add_term : t -> Field.t -> Var.t -> unit
  end

  module R1CS_constraint : sig
    type t

    val create :
      Linear_combination.t -> Linear_combination.t -> Linear_combination.t -> t

    val set_is_square : t -> bool -> unit
  end

  module Proving_key : sig
    type t [@@deriving bin_io]

    val to_string : t -> string

    val of_string : string -> t

    val to_bigstring : t -> Bigstring.t

    val of_bigstring : Bigstring.t -> t
  end

  module Verification_key : sig
    type t

    include Stringable.S with type t := t

    val to_bigstring : t -> Bigstring.t

    val of_bigstring : Bigstring.t -> t
  end

  module Proof : sig
    type t

    include Stringable.S with type t := t

    val create :
      Proving_key.t -> primary:Field.Vector.t -> auxiliary:Field.Vector.t -> t

    val verify : t -> Verification_key.t -> Field.Vector.t -> bool
  end

  module R1CS_constraint_system : sig
    type t

    val create : unit -> t

    val report_statistics : t -> unit

    val add_constraint : t -> R1CS_constraint.t -> unit

    val add_constraint_with_annotation :
      t -> R1CS_constraint.t -> string -> unit

    val set_primary_input_size : t -> int -> unit

    val set_auxiliary_input_size : t -> int -> unit

    val get_primary_input_size : t -> int

    val get_auxiliary_input_size : t -> int

    val check_exn : t -> unit

    val is_satisfied :
         t
      -> primary_input:Field.Vector.t
      -> auxiliary_input:Field.Vector.t
      -> bool

    val digest : t -> Md5.t
  end

  module Keypair : sig
    type t

    val pk : t -> Proving_key.t

    val vk : t -> Verification_key.t

    val create : R1CS_constraint_system.t -> t
  end
end
