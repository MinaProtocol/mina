open Core_kernel
open Pickles_types
open Zexe_backend

(* TODO: max_branching is a terrible name. It should be max_width. *)

module Data = struct
  type f = Impls.Dlog_based.field

  type ('a_var, 'a_value, 'max_branching, 'branches) basic =
    { typ: ('a_var, 'a_value) Impls.Pairing_based.Typ.t
    ; a_var_to_field_elements: 'a_var -> Impls.Pairing_based.Field.t array
    ; a_value_to_field_elements: 'a_value -> Fp.t array
    ; wrap_domains: Domains.t
    ; step_domains: (Domains.t, 'branches) Vector.t }

  type ('a_var, 'a_value, 'max_branching, 'branches) t =
    { branches: 'branches Nat.t
    ; max_branching: (module Nat.Add.Intf with type n = 'max_branching)
          (*         ; verification_keys :  G1.Affine.t Abc.t Matrix_evals.t list *)
    ; typ: ('a_var, 'a_value) Impls.Pairing_based.Typ.t
    ; a_value_to_field_elements: 'a_value -> Fp.t array
    ; a_var_to_field_elements: 'a_var -> Impls.Pairing_based.Field.t array
    ; wrap_key:
        G.Affine.t Dlog_marlin_types.Poly_comm.Without_degree_bound.t Abc.t
        Matrix_evals.t
    ; wrap_vk: Impls.Dlog_based.Verification_key.t
    ; wrap_domains: Domains.t
    ; step_domains: (Domains.t, 'branches) Vector.t }

  type ('a, 'b, 'c, 'd) data = ('a, 'b, 'c, 'd) t

  module For_step = struct
    type ('a_var, 'a_value, 'max_branching, 'branches) t =
      { branches: 'branches Nat.t
      ; max_branching: (module Nat.Add.Intf with type n = 'max_branching)
      ; typ: ('a_var, 'a_value) Impls.Pairing_based.Typ.t
      ; a_value_to_field_elements: 'a_value -> Fp.t array
      ; a_var_to_field_elements: 'a_var -> Impls.Pairing_based.Field.t array
      ; wrap_key:
          Pairing_main_inputs.G.t
          Dlog_marlin_types.Poly_comm.Without_degree_bound.t
          Abc.t
          Matrix_evals.t
      ; wrap_domains: Domains.t
      ; step_domains: (Domains.t, 'branches) Vector.t }

    let create
        ({ branches
         ; max_branching (*         ; verification_keys          *)
         ; typ
         ; a_value_to_field_elements
         ; a_var_to_field_elements
         ; wrap_key
         ; wrap_domains
         ; step_domains } :
          _ data) =
      { branches
      ; max_branching
      ; typ
      ; a_value_to_field_elements
      ; a_var_to_field_elements
      ; wrap_key=
          Matrix_evals.map wrap_key
            ~f:(Abc.map ~f:(Array.map ~f:Pairing_main_inputs.G.constant))
      ; wrap_domains
      ; step_domains }
  end
end

module Packed = struct
  type t =
    | T :
        (*('var * 'value * 'n1 * 'n2) Type_equal.Id.t  *)
        ('var, 'value, 'n1, 'n2) Tag.t
        * ('var, 'value, 'n1, 'n2) Data.t
        -> t
end

type t = Packed.t Type_equal.Id.Uid.Table.t

let univ : t = Type_equal.Id.Uid.Table.create ()

let lookup : type a b n m. (a, b, n, m) Tag.t -> (a, b, n, m) Data.t =
 fun t ->
  let (T (other_id, d)) = Hashtbl.find_exn univ (Type_equal.Id.uid t) in
  let T = Type_equal.Id.same_witness_exn t other_id in
  d

let max_branching : type n1.
    (_, _, n1, _) Tag.t -> (module Nat.Add.Intf with type n = n1) =
 fun tag -> (lookup tag).max_branching

let value_to_field_elements : type a. (_, a, _, _) Tag.t -> a -> Fp.t array =
 fun tag -> (lookup tag).a_value_to_field_elements

let lookup_map (type a b c d) (t : (a, b, c, d) Tag.t) ~self ~default
    ~(f : (a, b, c, d) Data.t -> _) =
  match Type_equal.Id.same_witness t self with
  | Some _ ->
      default
  | None ->
      let (T (other_id, d)) = Hashtbl.find_exn univ (Type_equal.Id.uid t) in
      let T = Type_equal.Id.same_witness_exn t other_id in
      f d

let add_exn (type a b c d) (tag : (a, b, c, d) Tag.t)
    (data : (a, b, c, d) Data.t) =
  Hashtbl.add_exn univ ~key:(Type_equal.Id.uid tag)
    ~data:(Packed.T (tag, data))
