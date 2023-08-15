(* Module and type signatures helpful for Plonk *)

val hash_fold_array : 'a Sigs.hashable -> 'a array Sigs.hashable

module Opt : sig
  type ('a, 'bool) t = Some of 'a | None | Maybe of 'bool * 'a
  [@@deriving sexp, compare, yojson, hash, equal]

  val map : ('a, 'bool) t -> f:('a -> 'b) -> ('b, 'bool) t

  (** [value_exn o] is v when [o] if [Some v] or [Maybe (_, v)].

     @raise Invalid_argument if [o] is [None]
  **)
  val value_exn : ('a, 'bool) t -> 'a

  (** [to_option_unsafe o] is [Some v] when [o] if [Some v] or [Maybe (_, v)],
      [None] otherwise.
  *)
  val to_option_unsafe : ('a, 'bool) t -> 'a option

  val to_option : ('a, bool) t -> 'a option

  module Flag : sig
    type t = Yes | No | Maybe [@@deriving sexp, compare, yojson, hash, equal]

    val ( ||| ) : t -> t -> t
  end

  val constant_layout_typ :
       ('b, bool, 'f) Snarky_backendless.Typ.t
    -> true_:'b
    -> false_:'b
    -> Flag.t
    -> ('a_var, 'a, 'f) Snarky_backendless.Typ.t
    -> dummy:'a
    -> dummy_var:'a_var
    -> (('a_var, 'b) t, 'a option, 'f) Snarky_backendless.Typ.t

  val typ :
       ('b, bool, 'f) Snarky_backendless.Typ.t
    -> Flag.t
    -> ('a_var, 'a, 'f) Snarky_backendless.Typ.t
    -> dummy:'a
    -> (('a_var, 'b) t, 'a option, 'f) Snarky_backendless.Typ.t

  (** A sequence that should be considered to have stopped at
       the first occurence of {!Flag.No} *)
  module Early_stop_sequence : sig
    type nonrec ('a, 'bool) t = ('a, 'bool) t list

    val fold :
         ('bool -> then_:'res -> else_:'res -> 'res)
      -> ('a, 'bool) t
      -> init:'acc
      -> f:('acc -> 'a -> 'acc)
      -> finish:('acc -> 'res)
      -> 'res
  end
end

module Features : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
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
      [@@deriving sexp, compare, yojson, hash, equal, hlist]
    end
  end]

  (** {2 Type aliases} *)

  type options = Opt.Flag.t t

  type flags = bool t

  val to_data :
       'a t
    -> ('a * ('a * ('a * ('a * ('a * ('a * ('a * ('a * unit))))))))
       Hlist.HlistId.t

  val of_data :
       ('a * ('a * ('a * ('a * ('a * ('a * ('a * ('a * unit))))))))
       Hlist.HlistId.t
    -> 'a t

  val typ :
       ('var, bool, 'f) Snarky_backendless.Typ.t
    -> feature_flags:options
    -> ('var t, bool t, 'f) Snarky_backendless.Typ.t

  val none : options

  val none_bool : flags

  val map : 'a t -> f:('a -> 'b) -> 'b t

  val map2 : 'a t -> 'b t -> f:('a -> 'b -> 'c) -> 'c t
end

module Poly_comm : sig
  module Without_degree_bound : sig
    type 'a t = 'a array
  end

  module With_degree_bound : sig
    type 'a t = { unshifted : 'a array; shifted : 'a }
  end
end

module Columns_vec = Vector.Vector_15
module Columns = Nat.N15
module Permuts_vec = Vector.Vector_7
module Permuts = Nat.N7
module Permuts_minus_1 = Nat.N6
module Permuts_minus_1_vec = Vector.Vector_6
module Lookup_sorted_vec = Vector.Vector_5

module Messages : sig
  module Poly : sig
    type ('w, 'z, 't) t = { w : 'w; z : 'z; t : 't }
  end

  module Lookup : sig
    type 'g t = { sorted : 'g array; aggreg : 'g; runtime : 'g option }

    module In_circuit : sig
      type ('g, 'bool) t =
        { sorted : 'g array; aggreg : 'g; runtime : ('g, 'bool) Opt.t }
    end
  end

  module Stable : sig
    module V2 : sig
      type 'g t =
        { w_comm : 'g Poly_comm.Without_degree_bound.t Columns_vec.t
        ; z_comm : 'g Poly_comm.Without_degree_bound.t
        ; t_comm : 'g Poly_comm.Without_degree_bound.t
        ; lookup : 'g Poly_comm.Without_degree_bound.t Lookup.t option
        }
    end
  end

  type 'g t = 'g Stable.V2.t =
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
          Opt.t
      }

    (** Field accessors *)

    val w_comm :
      ('g, 'bool) t -> 'g Poly_comm.Without_degree_bound.t Columns_vec.t

    val z_comm : ('g, 'bool) t -> 'g Poly_comm.Without_degree_bound.t

    val t_comm : ('g, 'bool) t -> 'g Poly_comm.Without_degree_bound.t
  end

  val typ :
       (module Snarky_backendless.Snark_intf.Run with type field = 'f)
    -> ('a, 'b, 'f) Snarky_backendless.Typ.t
    -> Opt.Flag.t Features.t
    -> dummy:'b
    -> commitment_lengths:((int, 'n) Vector.vec, int, int) Poly.t
    -> bool:('c, bool, 'f) Snarky_backendless.Typ.t
    -> ( ( 'a
         , 'f Snarky_backendless.Cvar.t Snarky_backendless.Boolean.t )
         In_circuit.t
       , 'b t
       , 'f )
       Snarky_backendless.Typ.t
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
      ; range_check0_selector : ('f, 'bool) Opt.t
      ; range_check1_selector : ('f, 'bool) Opt.t
      ; foreign_field_add_selector : ('f, 'bool) Opt.t
      ; foreign_field_mul_selector : ('f, 'bool) Opt.t
      ; xor_selector : ('f, 'bool) Opt.t
      ; rot_selector : ('f, 'bool) Opt.t
      ; lookup_aggregation : ('f, 'bool) Opt.t
      ; lookup_table : ('f, 'bool) Opt.t
      ; lookup_sorted : ('f, 'bool) Opt.t Lookup_sorted_vec.t
      ; runtime_lookup_table : ('f, 'bool) Opt.t
      ; runtime_lookup_table_selector : ('f, 'bool) Opt.t
      ; xor_lookup_selector : ('f, 'bool) Opt.t
      ; lookup_gate_lookup_selector : ('f, 'bool) Opt.t
      ; range_check_lookup_selector : ('f, 'bool) Opt.t
      ; foreign_field_mul_lookup_selector : ('f, 'bool) Opt.t
      }
    [@@deriving fields]

    (** {4 Converters} *)

    val to_absorption_sequence :
      ('a, 'b) t -> ('a, 'b) Opt.Early_stop_sequence.t

    val map : ('f, 'bool) t -> f:('f -> 'g) -> ('g, 'bool) t

    val to_list : ('a, 'b) t -> ('a, 'b) Opt.t list
  end

  type 'a t =
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
         ( 'a
         , 'b
         , 'c
         , (unit, 'c) Snarky_backendless.Checked_runner.Simple.t )
         Snarky_backendless.Types.Typ.typ
      -> ( 'd
         , 'e
         , 'c
         , (unit, 'c) Snarky_backendless.Checked_runner.Simple.t )
         Snarky_backendless.Types.Typ.typ
      -> length:int
      -> (('d, 'a) t, ('e, 'b) t, 'c) Snarky_backendless.Typ.t
  end

  module Stable : sig
    module V2 : sig
      type ('g, 'fq, 'fqv) t =
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
        { messages : 'g Messages.t; openings : ('g, 'fq, 'fqv) Openings.t }

      include Sigs.Full.S3 with type ('a, 'b, 'c) t := ('a, 'b, 'c) t
    end

    module Latest = V2
  end

  type ('a, 'b, 'c) t = ('a, 'b, 'c) Stable.V2.t =
    { messages : 'a Messages.t; openings : ('a, 'b, 'c) Openings.t }
end

module All_evals : sig
  module With_public_input : sig
    type ('f, 'f_multi) t = { public_input : 'f; evals : 'f_multi Evals.t }

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

      include Sigs.Full.S2 with type ('a, 'b) t := ('a, 'b) t
    end
  end

  module In_circuit : sig
    type ('f, 'f_multi, 'bool) t =
      { evals :
          ('f * 'f, 'f_multi * 'f_multi, 'bool) With_public_input.In_circuit.t
      ; ft_eval1 : 'f
      }
  end

  type ('f, 'f_multi) t = ('f, 'f_multi) Stable.V1.t =
    { evals : ('f * 'f, 'f_multi * 'f_multi) With_public_input.t
    ; ft_eval1 : 'f
    }
  [@@deriving sexp, compare, yojson, hash, equal]

  val map : ('a, 'b) t -> f1:('a -> 'c) -> f2:('b -> 'd) -> ('c, 'd) t

  val typ :
       (module Snarky_backendless.Snark_intf.Run with type field = 'f)
    -> Opt.Flag.t Features.t
    -> ( ( 'f Snarky_backendless.Cvar.t
         , 'f Snarky_backendless.Cvar.t array
         , 'f Snarky_backendless.Cvar.t Snarky_backendless.Boolean.t )
         In_circuit.t
       , ('f, 'f array) t
       , 'f
       , (unit, 'f) Snarky_backendless.Checked_runner.Simple.t )
       Snarky_backendless.Types.Typ.typ
end

module Shifts : sig
  type 'a t = 'a array
end
