open Core_kernel
open Rugelach_types
open Snarky_bn382_backend

module Data = struct
  type f = Impls.Dlog_based.field

  type ('a_var, 'a_value) basic =
    { typ: ('a_var, 'a_value) Impls.Pairing_based.Typ.t
    ; a_var_to_field_elements : 'a_var -> Impls.Pairing_based.Field.t array
    ; wrap_domains : Domain.t * Domain.t 
    ; step_domains : Domain.t * Domain.t
    }

  type ('a_var, 'a_value) t =
    { verification_keys :  G1.Affine.t Abc.t Matrix_evals.t list
    ; typ: ('a_var, 'a_value) Impls.Pairing_based.Typ.t
    ; a_value_to_field_elements : 'a_value -> Fp.t array
    ; a_var_to_field_elements : 'a_var -> Impls.Pairing_based.Field.t array
    ; wrap_key : G.Affine.t Abc.t Matrix_evals.t
    ; wrap_domains : Domain.t * Domain.t
    ; step_domains : Domain.t * Domain.t
    ; max_branching : (module Nat.Add.Intf)
    }
end

module Packed  =struct
  type t =
      T : ('var * 'value) Type_equal.Id.t 
          * ('var, 'value) Data.t
        -> t
end

type t = Packed.t Type_equal.Id.Uid.Table.t

let lookup : type a b. t -> (a, b) Tag.t -> (a, b) Data.t =
  fun univ t ->
  let T (other_id, d) = Hashtbl.find_exn univ (Type_equal.Id.uid t) in
  let T = Type_equal.Id.same_witness_exn t other_id in
  d

let max_branching : t ->  (_, _) Tag.t -> (module Nat.Add.Intf) =
  fun t tag -> (lookup t tag).max_branching

let value_to_field_elements : type a. t -> (_, a) Tag.t -> a -> Fp.t array =
  fun t tag -> (lookup t tag).a_value_to_field_elements

                      (* TODO
    ; spec :
('a_value, 'a_var,
< bool1 : bool; bool2 : f Snarky.Cvar.t Snarky.Snark_intf.Boolean0.t;
  bulletproof_challenge1 : ((int64,
                            Rugelach_types.Nat.N2.n Core_kernel.sexp_opaque)
                            Rugelach_types.Vector.t, bool)
                          Bulletproof_challenge.t;
  bulletproof_challenge2 : (f Snarky.Cvar.t Snarky.Snark_intf.Boolean0.t
                            list,
                            f Snarky.Cvar.t Snarky.Snark_intf.Boolean0.t)
                          Bulletproof_challenge.t;
  challenge1 : (int64, Rugelach_types.Nat.N2.n Core_kernel.sexp_opaque)
              Rugelach_types.Vector.t;
  challenge2 : f Snarky.Cvar.t Snarky.Snark_intf.Boolean0.t list;
  digest1 : (int64, Rugelach_types.Nat.N4.n Core_kernel.sexp_opaque)
            Rugelach_types.Vector.t;
  digest2 : f Snarky.Cvar.t Snarky.Snark_intf.Boolean0.t list; field1 : f;
  field2 : f Snarky.Cvar.t >) Spec.t *)
