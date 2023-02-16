module type S = sig
  open Core_kernel
  module Proofs_verified = Pickles_base.Proofs_verified

  module Domain_log2 : sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        type t [@@deriving compare, sexp, yojson, hash, equal]
      end
    end]

    val of_int_exn : int -> t
  end

  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t =
        { proofs_verified : Proofs_verified.Stable.V1.t
        ; domain_log2 : Domain_log2.Stable.V1.t
        }
      [@@deriving hlist, compare, sexp, yojson, hash, equal]
    end
  end]

  module Checked : sig
    type 'f t =
      { proofs_verified_mask : 'f Proofs_verified.Prefix_mask.Checked.t
      ; domain_log2 : 'f Snarky_backendless.Cvar.t
      }

    val pack :
      'f Snarky_backendless.Snark.m -> 'f t -> 'f Snarky_backendless.Cvar.t
  end

  val typ :
       'f Snarky_backendless.Snark.m
    -> assert_16_bits:('f Snarky_backendless.Cvar.t -> unit)
    -> ( 'f Checked.t
       , t
       , 'f
       , 'f Snarky_backendless.Cvar.t )
       Snarky_backendless.Typ.t

  val packed_typ :
       'f Snarky_backendless.Snark.m
    -> ( 'f Snarky_backendless.Cvar.t
       , t
       , 'f
       , 'f Snarky_backendless.Cvar.t )
       Snarky_backendless.Typ.t

  val length_in_bits : int

  val domain : t -> Pickles_base.Domain.t
end
