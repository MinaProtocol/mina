(* Module and type signatures helpful for Plonk *)

val hash_fold_array :
  'a Plonkish_prelude.Sigs.hashable -> 'a array Plonkish_prelude.Sigs.hashable

(** Features are custom gates, lookup tables or runtime tables *)
module Features : sig
  module Full : sig
    type 'bool t = private
      { range_check0 : 'bool
      ; range_check1 : 'bool
      ; foreign_field_add : 'bool
      ; foreign_field_mul : 'bool
      ; xor : 'bool
      ; rot : 'bool
      ; lookup : 'bool
      ; runtime_tables : 'bool
      ; uses_lookups : 'bool
      ; table_width_at_least_1 : 'bool
      ; table_width_at_least_2 : 'bool
      ; table_width_3 : 'bool
      ; lookups_per_row_3 : 'bool
      ; lookups_per_row_4 : 'bool
      ; lookup_pattern_xor : 'bool
      ; lookup_pattern_range_check : 'bool
      }
    [@@deriving sexp, compare, yojson, hash, equal, hlist]

    val get_feature_flag : 'bool t -> Kimchi_types.feature_flag -> 'bool option

    val map : 'a t -> f:('a -> 'b) -> 'b t

    val map2 : 'a t -> 'b t -> f:('a -> 'b -> 'c) -> 'c t

    val none : Plonkish_prelude.Opt.Flag.t t

    val maybe : Plonkish_prelude.Opt.Flag.t t

    val none_bool : bool t
  end

  [%%versioned:
  module Stable : sig
    module V1 : sig
      type 'bool t =
            'bool Mina_wire_types.Pickles_types.Plonk_types.Features.V1.t =
        { range_check0 : 'bool
        ; range_check1 : 'bool
        ; foreign_field_add : 'bool
        ; foreign_field_mul : 'bool
        ; xor : 'bool
        ; rot : 'bool
        ; lookup : 'bool
        ; runtime_tables : 'bool
        }
      [@@deriving sexp, compare, yojson, hash, equal, hlist]
    end
  end]

  val to_full :
       or_:('bool -> 'bool -> 'bool)
    -> ?any:('bool list -> 'bool)
    -> 'bool t
    -> 'bool Full.t

  val of_full : 'a Full.t -> 'a t

  (** {2 Type aliases} *)

  type options = Plonkish_prelude.Opt.Flag.t t

  type flags = bool t

  (** [to_data flags] takes the record defined above and deconstructs it in a
      list, in the field order *)
  val to_data :
       'a t
    -> ('a * ('a * ('a * ('a * ('a * ('a * ('a * ('a * unit))))))))
       Plonkish_prelude.Hlist.HlistId.t

  (** [of_data flags_list] constructs a record from the flags list *)
  val of_data :
       ('a * ('a * ('a * ('a * ('a * ('a * ('a * ('a * unit))))))))
       Plonkish_prelude.Hlist.HlistId.t
    -> 'a t

  val typ :
       ('var, bool) Kimchi_pasta_snarky_backend.Step_impl.Typ.t
    -> feature_flags:options
    -> ('var t, bool t) Kimchi_pasta_snarky_backend.Step_impl.Typ.t

  val none : options

  val maybe : options

  val none_bool : flags

  val map : 'a t -> f:('a -> 'b) -> 'b t

  val map2 : 'a t -> 'b t -> f:('a -> 'b -> 'c) -> 'c t
end

module Poly_comm : sig
  module Without_degree_bound : sig
    type 'a t = 'a Bounded_types.ArrayN16.Stable.V1.t
  end

  module With_degree_bound : sig
    type 'a t =
      { unshifted : 'a Bounded_types.ArrayN16.Stable.V1.t; shifted : 'a }
  end
end

(** The number of wires in the proving system *)
module Columns_vec = Plonkish_prelude.Vector.Vector_15

module Columns = Plonkish_prelude.Nat.N15

(** The number of wires that are considered in the permutation argument *)
module Permuts = Plonkish_prelude.Nat.N7

module Permuts_vec = Plonkish_prelude.Vector.Vector_7
module Permuts_minus_1 = Plonkish_prelude.Nat.N6
module Permuts_minus_1_vec = Plonkish_prelude.Vector.Vector_6
module Lookup_sorted_minus_1 = Plonkish_prelude.Nat.N4
module Lookup_sorted_minus_1_vec = Plonkish_prelude.Vector.Vector_4
module Lookup_sorted = Plonkish_prelude.Nat.N5
module Lookup_sorted_vec = Plonkish_prelude.Vector.Vector_5

(** Messages involved in the polynomial IOP *)
module Messages : sig
  module Poly : sig
    type ('w, 'z, 't) t = { w : 'w; z : 'z; t : 't }
  end

  (** The types of lookup tables. This should stay in line with the {{
  https://o1-labs.github.io/proof-systems/rfcs/extended-lookup-tables.html} RFC4
  - Extended lookup tables } in the kimchi book *)
  module Lookup : sig
    module Stable : sig
      module V1 : sig
        type 'g t =
              'g Mina_wire_types.Pickles_types.Plonk_types.Messages.Lookup.V1.t =
          { sorted : 'g array; aggreg : 'g; runtime : 'g option }
        [@@deriving fields, sexp, compare, yojson, hash, equal, hlist]
      end
    end

    type 'g t =
      { sorted : 'g Lookup_sorted_minus_1_vec.t
      ; sorted_5th_column : 'g option
      ; aggreg : 'g
      ; runtime : 'g option
      }

    module In_circuit : sig
      type ('g, 'bool) t =
        { sorted : 'g Lookup_sorted_minus_1_vec.t
        ; sorted_5th_column : ('g, 'bool) Plonkish_prelude.Opt.t
        ; aggreg : 'g
        ; runtime : ('g, 'bool) Plonkish_prelude.Opt.t
        }
    end
  end

  module Stable : sig
    module V2 : sig
      (** Commitments to the different polynomials.
          - [w_comm] is a vector containing the commitments to the wires. As
            usual, the vector size is encoded at the type level using
            {!Columns_vec} for compile time verification of vector properties.
          - [z_comm] is the commitment to the permutation polynomial
          - [t_comm] is the commitment to the quotient polynomial
          - [lookup] contains the commitments to the polynomials involved the
            lookup arguments.
      *)
      type 'g t = 'g Mina_wire_types.Pickles_types.Plonk_types.Messages.V2.t =
        { w_comm : 'g Poly_comm.Without_degree_bound.t Columns_vec.t
        ; z_comm : 'g Poly_comm.Without_degree_bound.t
        ; t_comm : 'g Poly_comm.Without_degree_bound.t
        ; lookup : 'g Poly_comm.Without_degree_bound.t Lookup.Stable.V1.t option
        }
    end
  end

  type 'g t =
    { w_comm : 'g Poly_comm.Without_degree_bound.t Columns_vec.t
    ; z_comm : 'g Poly_comm.Without_degree_bound.t
    ; t_comm : 'g Poly_comm.Without_degree_bound.t
    ; lookup : 'g Poly_comm.Without_degree_bound.t Lookup.t option
    }

  module In_circuit : sig
    type ('g, 'bool) t =
      { w_comm : 'g Poly_comm.Without_degree_bound.t Columns_vec.t
      ; z_comm : 'g Poly_comm.Without_degree_bound.t
      ; t_comm : 'g Poly_comm.Without_degree_bound.t
      ; lookup :
          ( ('g Poly_comm.Without_degree_bound.t, 'bool) Lookup.In_circuit.t
          , 'bool )
          Plonkish_prelude.Opt.t
      }
    [@@deriving fields]
  end

  val typ :
       ('a, 'b) Kimchi_pasta_snarky_backend.Step_impl.Typ.t
    -> Plonkish_prelude.Opt.Flag.t Features.Full.t
    -> dummy:'b
    -> commitment_lengths:
         ((int, 'n) Plonkish_prelude.Vector.vec, int, int) Poly.t
    -> ( ('a, Kimchi_pasta_snarky_backend.Step_impl.Boolean.var) In_circuit.t
       , 'b t )
       Kimchi_pasta_snarky_backend.Step_impl.Typ.t

  val wrap_typ :
       ('a, 'b) Kimchi_pasta_snarky_backend.Wrap_impl.Typ.t
    -> Plonkish_prelude.Opt.Flag.t Features.Full.t
    -> dummy:'b
    -> commitment_lengths:
         ((int, 'n) Plonkish_prelude.Vector.vec, int, int) Poly.t
    -> ( ('a, Kimchi_pasta_snarky_backend.Wrap_impl.Boolean.var) In_circuit.t
       , 'b t )
       Kimchi_pasta_snarky_backend.Wrap_impl.Typ.t
end

module Evals : sig
  module In_circuit : sig
    type ('f, 'bool) t =
      { w : 'f Columns_vec.t
      ; coefficients : 'f Columns_vec.t
      ; z : 'f
      ; s : 'f Permuts_minus_1_vec.t
      ; generic_selector : 'f
      ; poseidon_selector : 'f
      ; complete_add_selector : 'f
      ; mul_selector : 'f
      ; emul_selector : 'f
      ; endomul_scalar_selector : 'f
      ; range_check0_selector : ('f, 'bool) Plonkish_prelude.Opt.t
      ; range_check1_selector : ('f, 'bool) Plonkish_prelude.Opt.t
      ; foreign_field_add_selector : ('f, 'bool) Plonkish_prelude.Opt.t
      ; foreign_field_mul_selector : ('f, 'bool) Plonkish_prelude.Opt.t
      ; xor_selector : ('f, 'bool) Plonkish_prelude.Opt.t
      ; rot_selector : ('f, 'bool) Plonkish_prelude.Opt.t
      ; lookup_aggregation : ('f, 'bool) Plonkish_prelude.Opt.t
      ; lookup_table : ('f, 'bool) Plonkish_prelude.Opt.t
      ; lookup_sorted : ('f, 'bool) Plonkish_prelude.Opt.t Lookup_sorted_vec.t
      ; runtime_lookup_table : ('f, 'bool) Plonkish_prelude.Opt.t
      ; runtime_lookup_table_selector : ('f, 'bool) Plonkish_prelude.Opt.t
      ; xor_lookup_selector : ('f, 'bool) Plonkish_prelude.Opt.t
      ; lookup_gate_lookup_selector : ('f, 'bool) Plonkish_prelude.Opt.t
      ; range_check_lookup_selector : ('f, 'bool) Plonkish_prelude.Opt.t
      ; foreign_field_mul_lookup_selector : ('f, 'bool) Plonkish_prelude.Opt.t
      }
    [@@deriving fields]

    (** {4 Converters} *)

    val to_absorption_sequence :
      ('a, 'b) t -> ('a, 'b) Plonkish_prelude.Opt.Early_stop_sequence.t

    val map : ('f, 'bool) t -> f:('f -> 'g) -> ('g, 'bool) t

    val to_list : ('a, 'b) t -> ('a, 'b) Plonkish_prelude.Opt.t list

    (** {4 Generic helpers} *)

    val validate_feature_flags :
         true_:'boolean
      -> false_:'boolean
      -> or_:('boolean -> 'boolean -> 'boolean)
      -> assert_equal:('boolean -> 'boolean -> unit)
      -> feature_flags:'boolean Features.t
      -> (_, 'boolean) t
      -> unit
  end

  type 'a t = 'a Mina_wire_types.Pickles_types.Plonk_types.Evals.V2.t =
    { w : 'a Columns_vec.t
    ; coefficients : 'a Columns_vec.t
    ; z : 'a
    ; s : 'a Permuts_minus_1_vec.t
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
    ; lookup_sorted : 'a option Lookup_sorted_vec.t
    ; runtime_lookup_table : 'a option
    ; runtime_lookup_table_selector : 'a option
    ; xor_lookup_selector : 'a option
    ; lookup_gate_lookup_selector : 'a option
    ; range_check_lookup_selector : 'a option
    ; foreign_field_mul_lookup_selector : 'a option
    }

  (** {4 Generic helpers} *)

  val validate_feature_flags : feature_flags:bool Features.t -> 'a t -> bool

  (** {4 Iterators} *)

  val map : 'a t -> f:('a -> 'b) -> 'b t

  val map2 : 'a t -> 'b t -> f:('a -> 'b -> 'c) -> 'c t

  (** {4 Converters} *)

  val to_in_circuit : 'a t -> ('a, 'bool) In_circuit.t

  val to_list : 'a t -> 'a list

  val to_absorption_sequence : 'a t -> 'a list
end

module Openings : sig
  module Bulletproof : sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        type ('g, 'fq) t =
              ( 'g
              , 'fq )
              Mina_wire_types.Pickles_types.Plonk_types.Openings.Bulletproof.V1
              .t =
          { lr : ('g * 'g) array
          ; z_1 : 'fq
          ; z_2 : 'fq
          ; delta : 'g
          ; challenge_polynomial_commitment : 'g
          }
        [@@deriving compare, sexp, yojson, hash, equal]
      end
    end]

    val typ :
         ('a, 'b) Kimchi_pasta_snarky_backend.Step_impl.Typ.t
      -> ('d, 'e) Kimchi_pasta_snarky_backend.Step_impl.Typ.t
      -> length:int
      -> (('d, 'a) t, ('e, 'b) t) Kimchi_pasta_snarky_backend.Step_impl.Typ.t

    val wrap_typ :
         ('a, 'b) Kimchi_pasta_snarky_backend.Wrap_impl.Typ.t
      -> ('d, 'e) Kimchi_pasta_snarky_backend.Wrap_impl.Typ.t
      -> length:int
      -> (('d, 'a) t, ('e, 'b) t) Kimchi_pasta_snarky_backend.Wrap_impl.Typ.t
  end

  module Stable : sig
    module V2 : sig
      type ('g, 'fq, 'fqv) t =
            ( 'g
            , 'fq
            , 'fqv )
            Mina_wire_types.Pickles_types.Plonk_types.Openings.V2.t =
        { proof : ('g, 'fq) Bulletproof.t
        ; evals : ('fqv * 'fqv) Evals.t
        ; ft_eval1 : 'fq
        }
    end
  end

  type ('a, 'b, 'c) t = ('a, 'b, 'c) Stable.V2.t
end

module Proof : sig
  module Stable : sig
    module V2 : sig
      type ('g, 'fq, 'fqv) t =
            ('g, 'fq, 'fqv) Mina_wire_types.Pickles_types.Plonk_types.Proof.V2.t =
        { messages : 'g Messages.Stable.V2.t
        ; openings : ('g, 'fq, 'fqv) Openings.t
        }

      include
        Plonkish_prelude.Sigs.Full.S3 with type ('a, 'b, 'c) t := ('a, 'b, 'c) t
    end

    module Latest = V2
  end

  (** Represents a proof. A proof consists of messages and openings from the
      polynomial protocols *)
  type ('a, 'b, 'c) t =
    { messages : 'a Messages.t; openings : ('a, 'b, 'c) Openings.t }
  [@@deriving compare, sexp, yojson, hash, equal]
end

module All_evals : sig
  module With_public_input : sig
    type ('f, 'f_multi) t =
          ( 'f
          , 'f_multi )
          Mina_wire_types.Pickles_types.Plonk_types.All_evals.With_public_input
          .V1
          .t =
      { public_input : 'f; evals : 'f_multi Evals.t }

    module In_circuit : sig
      type ('f, 'f_multi, 'bool) t =
        { public_input : 'f; evals : ('f_multi, 'bool) Evals.In_circuit.t }

      val factor :
           ('f * 'f, 'f_multi * 'f_multi, 'bool) t
        -> ('f, 'f_multi, 'bool) t Tuple_lib.Double.t
    end
  end

  module Stable : sig
    module V1 : sig
      type ('f, 'f_multi) t =
        { evals : ('f * 'f, 'f_multi * 'f_multi) With_public_input.t
        ; ft_eval1 : 'f
        }

      include Plonkish_prelude.Sigs.Full.S2 with type ('a, 'b) t := ('a, 'b) t
    end

    module Latest = V1
  end

  module In_circuit : sig
    type ('f, 'f_multi, 'bool) t =
      { evals :
          ( 'f_multi * 'f_multi
          , 'f_multi * 'f_multi
          , 'bool )
          With_public_input.In_circuit.t
      ; ft_eval1 : 'f
      }
  end

  type ('f, 'f_multi) t =
        ('f, 'f_multi) Mina_wire_types.Pickles_types.Plonk_types.All_evals.V1.t =
    { evals : ('f_multi * 'f_multi, 'f_multi * 'f_multi) With_public_input.t
    ; ft_eval1 : 'f
    }
  [@@deriving sexp, compare, yojson, hash, equal]

  val map : ('a, 'b) t -> f1:('a -> 'c) -> f2:('b -> 'd) -> ('c, 'd) t

  val typ :
       num_chunks:int
    -> Plonkish_prelude.Opt.Flag.t Features.Full.t
    -> ( ( Kimchi_pasta_snarky_backend.Step_impl.Field.t
         , Kimchi_pasta_snarky_backend.Step_impl.Field.t array
         , Kimchi_pasta_snarky_backend.Step_impl.Boolean.var )
         In_circuit.t
       , ( Kimchi_pasta_snarky_backend.Step_impl.Field.Constant.t
         , Kimchi_pasta_snarky_backend.Step_impl.Field.Constant.t array )
         t )
       Kimchi_pasta_snarky_backend.Step_impl.Typ.t

  val wrap_typ :
       num_chunks:int
    -> Plonkish_prelude.Opt.Flag.t Features.Full.t
    -> ( ( Kimchi_pasta_snarky_backend.Wrap_impl.Field.t
         , Kimchi_pasta_snarky_backend.Wrap_impl.Field.t array
         , Kimchi_pasta_snarky_backend.Wrap_impl.Boolean.var )
         In_circuit.t
       , ( Kimchi_pasta_snarky_backend.Wrap_impl.Field.Constant.t
         , Kimchi_pasta_snarky_backend.Wrap_impl.Field.Constant.t array )
         t )
       Kimchi_pasta_snarky_backend.Wrap_impl.Typ.t
end

(** Shifts, related to the permutation argument in Plonk *)
module Shifts : sig
  type 'a t = 'a array
end
