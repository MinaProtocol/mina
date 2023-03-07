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
    type ('f, 'field_var) t =
      { proofs_verified_mask : 'f Proofs_verified.Prefix_mask.Checked.t
      ; domain_log2 : 'field_var
      }

    val pack :
         (module Snarky_backendless.Snark_intf.Run
            with type field = 'f
             and type field_var = 'field_var )
      -> ('f, 'field_var) t
      -> 'field_var
  end

  val typ :
       (module Snarky_backendless.Snark_intf.Run
          with type field = 'f
           and type field_var = 'field_var
           and type run_state = 'state )
    -> assert_16_bits:('field_var -> unit)
    -> ( ('f, 'field_var) Checked.t
       , t
       , 'f
       , 'field_var
       , 'state )
       Snarky_backendless.Typ.t

  val packed_typ :
       (module Snarky_backendless.Snark_intf.Run
          with type field = 'f
           and type field_var = 'field_var
           and type run_state = 'state )
    -> ('field_var, t, 'f, 'field_var, 'state) Snarky_backendless.Typ.t

  val length_in_bits : int

  val domain : t -> Pickles_base.Domain.t
end
