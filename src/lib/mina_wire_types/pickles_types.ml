module Nat = struct
  type z = Z of z

  type 'a s = Z | S of 'a

  type _ t = Z : z t | S : 'n t -> 'n s t

  type two = z s s

  type four = z s s s s

  type five = z s s s s s

  type six = z s s s s s s

  type seven = z s s s s s s s

  type eight = z s s s s s s s s

  type fifteen = z s s s s s s s s s s s s s s s

  type sixteen = z s s s s s s s s s s s s s s s s
end

module Vector = struct
  type ('a, _) t =
    | [] : ('a, Nat.z) t
    | ( :: ) : 'a * ('a, 'n) t -> ('a, 'n Nat.s) t
end

module Shifted_value = struct
  module Type1 = struct
    module V1 = struct
      type 'f t = Shifted_value of 'f
    end
  end
end

module Plonk_types = struct
  module Features = struct
    module V1 = struct
      type 'bool t =
        { range_check0 : 'bool
        ; range_check1 : 'bool
        ; foreign_field_add : 'bool
        ; foreign_field_mul : 'bool
        ; xor : 'bool
        ; rot : 'bool
        ; lookup : 'bool
        ; runtime_tables : 'bool
        }
    end
  end

  module Evals = struct
    module V2 = struct
      type 'a t =
        { w : ('a, Nat.fifteen) Vector.t
        ; coefficients : ('a, Nat.fifteen) Vector.t
        ; z : 'a
        ; s : ('a, Nat.six) Vector.t
        ; generic_selector : 'a
        ; poseidon_selector : 'a
        ; complete_add_selector : 'a
        ; mul_selector : 'a
        ; emul_selector : 'a
        ; endomul_scalar_selector : 'a
        ; range_check0_selector : 'a option
        ; range_check1_selector : 'a option
        ; foreign_field_add_selector : 'a option
        ; foreign_field_mul_selector : 'a option
        ; xor_selector : 'a option
        ; rot_selector : 'a option
        ; lookup_aggregation : 'a option
        ; lookup_table : 'a option
        ; lookup_sorted : ('a option, Nat.five) Vector.t
        ; runtime_lookup_table : 'a option
        ; runtime_lookup_table_selector : 'a option
        ; xor_lookup_selector : 'a option
        ; lookup_gate_lookup_selector : 'a option
        ; range_check_lookup_selector : 'a option
        ; foreign_field_mul_lookup_selector : 'a option
        }
    end
  end

  module All_evals = struct
    module With_public_input = struct
      module V1 = struct
        type ('f, 'f_multi) t =
          { public_input : 'f; evals : 'f_multi Evals.V2.t }
      end
    end

    module V1 = struct
      type ('f, 'f_multi) t =
        { evals :
            ('f_multi * 'f_multi, 'f_multi * 'f_multi) With_public_input.V1.t
        ; ft_eval1 : 'f
        }
    end
  end

  module Openings = struct
    module Bulletproof = struct
      module V1 = struct
        type ('g, 'fq) t =
          { lr : ('g * 'g) array
          ; z_1 : 'fq
          ; z_2 : 'fq
          ; delta : 'g
          ; challenge_polynomial_commitment : 'g
          }
      end
    end

    module V2 = struct
      type ('g, 'fq, 'fqv) t =
        { proof : ('g, 'fq) Bulletproof.V1.t
        ; evals : ('fqv * 'fqv) Evals.V2.t
        ; ft_eval1 : 'fq
        }
    end
  end

  module Poly_comm = struct
    module Without_degree_bound = struct
      module V1 = struct
        type 'g t = 'g array
      end
    end
  end

  module Messages = struct
    module Lookup = struct
      module V1 = struct
        type 'g t = { sorted : 'g array; aggreg : 'g; runtime : 'g option }
      end
    end

    module V2 = struct
      type 'g t =
        { w_comm :
            ('g Poly_comm.Without_degree_bound.V1.t, Nat.fifteen) Vector.t
        ; z_comm : 'g Poly_comm.Without_degree_bound.V1.t
        ; t_comm : 'g Poly_comm.Without_degree_bound.V1.t
        ; lookup : 'g Poly_comm.Without_degree_bound.V1.t Lookup.V1.t option
        }
    end
  end

  module Proof = struct
    module V2 = struct
      type ('g, 'fq, 'fqv) t =
        { messages : 'g Messages.V2.t
        ; openings : ('g, 'fq, 'fqv) Openings.V2.t
        }
    end
  end
end

module Plonk_verification_key_evals = struct
  module V2 = struct
    type 'comm t =
      { sigma_comm : ('comm, Nat.seven) Vector.t
      ; coefficients_comm : ('comm, Nat.fifteen) Vector.t
      ; generic_comm : 'comm
      ; psm_comm : 'comm
      ; complete_add_comm : 'comm
      ; mul_comm : 'comm
      ; emul_comm : 'comm
      ; endomul_scalar_comm : 'comm
      }
  end
end
