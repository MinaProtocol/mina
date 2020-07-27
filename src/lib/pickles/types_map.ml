open Core_kernel
open Pickles_types
open Backend

(* TODO: max_branching is a terrible name. It should be max_width. *)

(* We maintain a global hash table which stores for each inductive proof system some
   data.
*)
type inner_curve_var = Tick.Field.t Snarky.Cvar.t * Tick.Field.t Snarky.Cvar.t

module Basic = struct
  type ('var, 'value, 'n1, 'n2) t =
    { max_branching: (module Nat.Add.Intf with type n = 'n1)
    ; value_to_field_elements: 'value -> Impls.Step.Field.Constant.t array
    ; var_to_field_elements: 'var -> Impls.Step.Field.t array
    ; typ: ('var, 'value) Impls.Step.Typ.t
    ; branches: 'n2 Nat.t
    ; wrap_domains: Domains.t
    ; wrap_key:
        Tick.Inner_curve.Affine.t
        Dlog_marlin_types.Poly_comm.Without_degree_bound.t
        Abc.t
        Matrix_evals.t
    ; wrap_vk: Impls.Wrap.Verification_key.t }
end

module Side_loaded = struct
  module Ephemeral = struct
    type t =
      { index:
          [ `In_circuit of Side_loaded_verification_key.Checked.t
          | `In_prover of Side_loaded_verification_key.t ] }
  end

  module Permanent = struct
    type ('var, 'value, 'n1, 'n2) t =
      { max_branching: (module Nat.Add.Intf with type n = 'n1)
      ; value_to_field_elements: 'value -> Impls.Step.Field.Constant.t array
      ; var_to_field_elements: 'var -> Impls.Step.Field.t array
      ; typ: ('var, 'value) Impls.Step.Typ.t
      ; branches: 'n2 Nat.t }
  end

  type ('var, 'value, 'n1, 'n2) t =
    { ephemeral: Ephemeral.t option
    ; permanent: ('var, 'value, 'n1, 'n2) Permanent.t }

  type packed =
    | T :
        ('var, 'value, 'n1, 'n2) Tag.tag * ('var, 'value, 'n1, 'n2) t
        -> packed

  let to_basic
      { permanent=
          { max_branching
          ; value_to_field_elements
          ; var_to_field_elements
          ; typ
          ; branches }
      ; ephemeral } =
    let wrap_key, wrap_vk =
      match ephemeral with
      | Some {index= `In_prover i} ->
          (i.wrap_index, i.wrap_vk)
      | _ ->
          failwithf "Side_loaded.to_basic: Expected `In_prover (%s)" __LOC__ ()
    in
    { Basic.max_branching
    ; wrap_vk
    ; value_to_field_elements
    ; var_to_field_elements
    ; typ
    ; branches
    ; wrap_domains= Common.wrap_domains
    ; wrap_key }
end

module Compiled = struct
  type f = Impls.Wrap.field

  type ('a_var, 'a_value, 'max_branching, 'branches) basic =
    { typ: ('a_var, 'a_value) Impls.Step.Typ.t
    ; branchings: (int, 'branches) Vector.t
          (* For each branch in this rule, how many predecessor proofs does it have? *)
    ; var_to_field_elements: 'a_var -> Impls.Step.Field.t array
    ; value_to_field_elements: 'a_value -> Tick.Field.t array
    ; wrap_domains: Domains.t
    ; step_domains: (Domains.t, 'branches) Vector.t }

  (* This is the data associated to an inductive proof system with statement type
   ['a_var], which has ['branches] many "variants" each of which depends on at most
   ['max_branching] many previous statements. *)
  type ('a_var, 'a_value, 'max_branching, 'branches) t =
    { branches: 'branches Nat.t
    ; max_branching: (module Nat.Add.Intf with type n = 'max_branching)
    ; branchings: (int, 'branches) Vector.t
          (* For each branch in this rule, how many predecessor proofs does it have? *)
    ; typ: ('a_var, 'a_value) Impls.Step.Typ.t
    ; value_to_field_elements: 'a_value -> Tick.Field.t array
    ; var_to_field_elements: 'a_var -> Impls.Step.Field.t array
    ; wrap_key:
        Tick.Inner_curve.Affine.t
        Dlog_marlin_types.Poly_comm.Without_degree_bound.t
        Abc.t
        Matrix_evals.t
        Lazy.t
    ; wrap_vk: Impls.Wrap.Verification_key.t Lazy.t
    ; wrap_domains: Domains.t
    ; step_domains: (Domains.t, 'branches) Vector.t }

  type packed =
    | T :
        ('var, 'value, 'n1, 'n2) Tag.tag * ('var, 'value, 'n1, 'n2) t
        -> packed

  let to_basic
      { branches
      ; max_branching
      ; branchings
      ; typ
      ; value_to_field_elements
      ; var_to_field_elements
      ; wrap_vk
      ; wrap_domains
      ; step_domains
      ; wrap_key } =
    { Basic.max_branching
    ; wrap_domains
    ; value_to_field_elements
    ; var_to_field_elements
    ; typ
    ; branches= Vector.length step_domains
    ; wrap_key= Lazy.force wrap_key
    ; wrap_vk= Lazy.force wrap_vk }
end

module For_step = struct
  type ('a_var, 'a_value, 'max_branching, 'branches) t =
    { branches: 'branches Nat.t
    ; max_branching: (module Nat.Add.Intf with type n = 'max_branching)
    ; branchings: (Impls.Step.Field.t, 'branches) Vector.t
    ; typ: ('a_var, 'a_value) Impls.Step.Typ.t
    ; value_to_field_elements: 'a_value -> Tick.Field.t array
    ; var_to_field_elements: 'a_var -> Impls.Step.Field.t array
    ; wrap_key:
        inner_curve_var Dlog_marlin_types.Poly_comm.Without_degree_bound.t
        Abc.t
        Matrix_evals.t
    ; wrap_domains: Domains.t
    ; step_domains:
        [ `Known of (Domains.t, 'branches) Vector.t
        | `Side_loaded of
          ( Impls.Step.Field.t Side_loaded_verification_key.Domain.t
            Side_loaded_verification_key.Domains.t
          , 'branches )
          Vector.t ]
    ; max_width: Side_loaded_verification_key.Width.Checked.t option }

  let of_side_loaded (type a b c d)
      ({ ephemeral
       ; permanent=
           { branches
           ; max_branching
           ; typ
           ; value_to_field_elements
           ; var_to_field_elements } } :
        (a, b, c, d) Side_loaded.t) : (a, b, c, d) t =
    let index =
      match ephemeral with
      | Some {index= `In_circuit i} ->
          i
      | _ ->
          failwithf "For_step.side_loaded: Expected `In_circuit (%s)" __LOC__
            ()
    in
    let T = Nat.eq_exn branches Side_loaded_verification_key.Max_branches.n in
    { branches
    ; max_branching
    ; branchings=
        Vector.map index.step_widths
          ~f:Side_loaded_verification_key.Width.Checked.to_field
    ; typ
    ; value_to_field_elements
    ; var_to_field_elements
    ; wrap_key= index.wrap_index
    ; wrap_domains= Common.wrap_domains
    ; step_domains= `Side_loaded index.step_domains
    ; max_width= Some index.max_width }

  let of_compiled
      ({ branches
       ; max_branching
       ; branchings
       ; typ
       ; value_to_field_elements
       ; var_to_field_elements
       ; wrap_key
       ; wrap_domains
       ; step_domains } :
        _ Compiled.t) =
    { branches
    ; max_width= None
    ; max_branching
    ; branchings= Vector.map branchings ~f:Impls.Step.Field.of_int
    ; typ
    ; value_to_field_elements
    ; var_to_field_elements
    ; wrap_key=
        Matrix_evals.map (Lazy.force wrap_key)
          ~f:(Abc.map ~f:(Array.map ~f:Step_main_inputs.Inner_curve.constant))
    ; wrap_domains
    ; step_domains= `Known step_domains }
end

type t =
  { compiled: Compiled.packed Type_equal.Id.Uid.Table.t
  ; side_loaded: Side_loaded.packed Type_equal.Id.Uid.Table.t }

let univ : t =
  { compiled= Type_equal.Id.Uid.Table.create ()
  ; side_loaded= Type_equal.Id.Uid.Table.create () }

let lookup_compiled : type a b n m.
    (a, b, n, m) Tag.tag -> (a, b, n, m) Compiled.t =
 fun t ->
  let (T (other_id, d)) =
    Hashtbl.find_exn univ.compiled (Type_equal.Id.uid t)
  in
  let T = Type_equal.Id.same_witness_exn t other_id in
  d

let lookup_side_loaded : type a b n m.
    (a, b, n, m) Tag.tag -> (a, b, n, m) Side_loaded.t =
 fun t ->
  let (T (other_id, d)) =
    Hashtbl.find_exn univ.side_loaded (Type_equal.Id.uid t)
  in
  let T = Type_equal.Id.same_witness_exn t other_id in
  d

let lookup_basic : type a b n m. (a, b, n, m) Tag.t -> (a, b, n, m) Basic.t =
 fun t ->
  match t.kind with
  | Compiled ->
      Compiled.to_basic (lookup_compiled t.id)
  | Side_loaded ->
      Side_loaded.to_basic (lookup_side_loaded t.id)

let max_branching : type n1.
    (_, _, n1, _) Tag.t -> (module Nat.Add.Intf with type n = n1) =
 fun tag ->
  match tag.kind with
  | Compiled ->
      (lookup_compiled tag.id).max_branching
  | Side_loaded ->
      (lookup_side_loaded tag.id).permanent.max_branching

let typ : type var value.
    (var, value, _, _) Tag.t -> (var, value) Impls.Step.Typ.t =
 fun tag ->
  match tag.kind with
  | Compiled ->
      (lookup_compiled tag.id).typ
  | Side_loaded ->
      (lookup_side_loaded tag.id).permanent.typ

let value_to_field_elements : type a.
    (_, a, _, _) Tag.t -> a -> Tick.Field.t array =
 fun t ->
  match t.kind with
  | Compiled ->
      (lookup_compiled t.id).value_to_field_elements
  | Side_loaded ->
      (lookup_side_loaded t.id).permanent.value_to_field_elements

let lookup_map (type a b c d) (t : (a, b, c, d) Tag.t) ~self ~default
    ~(f :
          [ `Compiled of (a, b, c, d) Compiled.t
          | `Side_loaded of (a, b, c, d) Side_loaded.t ]
       -> _) =
  match Type_equal.Id.same_witness t.id self with
  | Some _ ->
      default
  | None -> (
    match t.kind with
    | Compiled ->
        let (T (other_id, d)) =
          Hashtbl.find_exn univ.compiled (Type_equal.Id.uid t.id)
        in
        let T = Type_equal.Id.same_witness_exn t.id other_id in
        f (`Compiled d)
    | Side_loaded ->
        let (T (other_id, d)) =
          Hashtbl.find_exn univ.side_loaded (Type_equal.Id.uid t.id)
        in
        let T = Type_equal.Id.same_witness_exn t.id other_id in
        f (`Side_loaded d) )

let add_side_loaded ~name permanent =
  let id = Type_equal.Id.create ~name sexp_of_opaque in
  Hashtbl.add_exn univ.side_loaded ~key:(Type_equal.Id.uid id)
    ~data:(T (id, {ephemeral= None; permanent})) ;
  {Tag.kind= Side_loaded; id}

let set_ephemeral {Tag.kind; id} eph =
  (match kind with Side_loaded -> () | _ -> failwith "Expected Side_loaded") ;
  Hashtbl.update univ.side_loaded (Type_equal.Id.uid id) ~f:(function
    | None ->
        assert false
    | Some (T (id, d)) ->
        T (id, {d with ephemeral= Some eph}) )

let add_exn (type a b c d) (tag : (a, b, c, d) Tag.t)
    (data : (a, b, c, d) Compiled.t) =
  Hashtbl.add_exn univ.compiled ~key:(Type_equal.Id.uid tag.id)
    ~data:(Compiled.T (tag.id, data))
