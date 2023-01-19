(* Undocumented *)

module Optional_columns : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type 'a t =
        { range_check0 : 'a
        ; range_check1 : 'a
        ; foreign_field_add : 'a
        ; foreign_field_mul : 'a
        ; xor : 'a
        ; rot : 'a
        ; lookup_gate : 'a
        ; runtime_tables : 'a
        }
      [@@deriving sexp, compare, hlist, hash, equal, fields]
    end
  end]

  type 'a t = 'a Stable.Latest.t =
    { range_check0 : 'a
    ; range_check1 : 'a
    ; foreign_field_add : 'a
    ; foreign_field_mul : 'a
    ; xor : 'a
    ; rot : 'a
    ; lookup_gate : 'a
    ; runtime_tables : 'a
    }
  [@@deriving sexp, compare, yojson, hlist, hash, equal, fields]

  (** [typ] serializer *)
  val typ :
       (module Snarky_backendless.Snark_intf.Run with type field = 'f)
    -> ( 'fp
       , 'a
       , 'f
       , (unit, 'f) Snarky_backendless.Checked_runner.Simple.t )
       Snarky_backendless.Types.Typ.typ
    -> dummy:'a
    -> Plonk_types.Features.options
    -> ( ('fp, 'f Snarky_backendless.Cvar.t Snarky_backendless.Boolean.t) Opt.t t
       , 'a option t
       , 'f )
       Snarky_backendless.Typ.t

  (** [init v] initializes a value of type {!type:t} with value [v] for all the fields. *)
  val init : 'a -> 'a t

  val to_list : 'a t -> 'a list

  val map : f:('a -> 'b) -> 'a t -> 'b t

  val map2 : f:('a -> 'b -> 'c) -> 'a t -> 'b t -> 'c t
end

module Stable : sig
  module V2 : sig
    type ('comm, 'comm_opt) t =
      { sigma_comm : 'comm Plonk_types.Permuts_vec.Stable.V1.t
      ; coefficients_comm : 'comm Plonk_types.Columns_vec.Stable.V1.t
      ; generic_comm : 'comm
      ; psm_comm : 'comm
      ; complete_add_comm : 'comm
      ; mul_comm : 'comm
      ; emul_comm : 'comm
      ; endomul_scalar_comm : 'comm
      ; optional_columns_comm : 'comm_opt Optional_columns.Stable.V1.t
      }

    include Sigs.Full.S2 with type ('a, 'b) t := ('a, 'b) t
  end

  module Latest = V2
end

(** {2 Types} *)

type ('comm, 'comm_opt) t = ('comm, 'comm_opt) Stable.Latest.t =
  { sigma_comm : 'comm Plonk_types.Permuts_vec.t
  ; coefficients_comm : 'comm Plonk_types.Columns_vec.t
  ; generic_comm : 'comm
  ; psm_comm : 'comm
  ; complete_add_comm : 'comm
  ; mul_comm : 'comm
  ; emul_comm : 'comm
  ; endomul_scalar_comm : 'comm
  ; optional_columns_comm : 'comm_opt Optional_columns.t
  }
[@@deriving sexp, equal, compare, hash, yojson, hlist]

(** Specialized instance of t for in-circuit representations. *)
type ('a, 'bool) in_circuit = ('a, ('a, 'bool) Opt.t) t

(** Specialized instance of t for out-of-circuit representations. *)
type 'a out_circuit = ('a, 'a Option.t) t

(** {2 Converters} *)

(** [in_of_out oc_v] converts values from their out-of-circuit representation
    [oc_v] to their in-circuit one. *)
val in_of_out : 'a out_circuit -> ('a, 'b) in_circuit

(** [out_of_in ic_v] converts values from their in-circuit representation [ic_v]
    to their out-of-circuit one.*)
val out_of_in : ('a, 'b) in_circuit -> 'a out_circuit

(** [to_kimchi_verification_evals oc_v] converts values from their
    out-of-circuit representation to the flattened type
    {!type:Kimchi_types.VerifierIndex.verification_evals}. *)
val to_kimchi_verification_evals :
  'a out_circuit -> 'a Kimchi_types.VerifierIndex.verification_evals

(** {2 Iterators} *)

(** [map t ~f ~f_opt] applies [f] on fields ot type ['a], [f_opt] on fields of
    type ['b], that is the subfields of field [t.optional_columns_comm]. *)
val map : ('a, 'b) t -> f:('a -> 'c) -> f_opt:('b -> 'd) -> ('c, 'd) t

(** [in_circuit_map] is a specialized version of {!val:map} to {!type:in_circuit}. *)
val in_circuit_map : ('a, 'b) in_circuit -> f:('a -> 'c) -> ('c, 'b) in_circuit

(** [out_circuit_map] is a specialized version of {!val:map} to {!type:out_circuit}. *)
val out_circuit_map : 'a out_circuit -> f:('a -> 'c) -> 'c out_circuit

val map2 :
     ('a, 'b) t
  -> ('c, 'd) t
  -> f:('a -> 'c -> 'e)
  -> f_opt:('b -> 'd -> 'f)
  -> ('e, 'f) t

val typ :
     (module Snarky_backendless.Snark_intf.Run with type field = 'f)
  -> dummy:'a
  -> Plonk_types.Features.options
  -> ('b, 'a, 'f) Snarky_backendless.Typ.t
  -> ( ( 'b
       , ('b, 'f Snarky_backendless.Cvar.t Snarky_backendless.Boolean.t) Opt.t
       )
       t
     , ('a, 'a Option.t) t
     , 'f )
     Snarky_backendless.Typ.t

val opt_typ :
     (module Snarky_backendless.Snark_intf.Run with type field = 'f)
  -> dummy:'a
  -> Plonk_types.Features.options
  -> ('b, 'a, 'f) Snarky_backendless.Typ.t
  -> ( ( 'b
       , ('b, 'f Snarky_backendless.Cvar.t Snarky_backendless.Boolean.t) Opt.t
       )
       t
     , ('a, 'a Option.t) t
     , 'f )
     Snarky_backendless.Typ.t
