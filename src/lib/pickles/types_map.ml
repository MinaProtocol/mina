open Core_kernel
open Pickles_types
open Import
open Backend

(* We maintain a global hash table which stores for each inductive proof system some
   data.
*)
type inner_curve_var =
  Step.Field.t Snarky_backendless.Cvar.t
  * Step.Field.t Snarky_backendless.Cvar.t

module Basic = struct
  type ('var, 'value, 'n1, 'n2) t =
    { max_proofs_verified : (module Nat.Add.Intf with type n = 'n1)
    ; public_input : ('var, 'value) Impls.Step.Typ.t
    ; branches : 'n2 Nat.t
    ; wrap_domains : Domains.t
    ; wrap_key : Step.Inner_curve.Affine.t Plonk_verification_key_evals.t
    ; wrap_vk : Impls.Wrap.Verification_key.t
    ; step_uses_lookup : Plonk_types.Opt.Flag.t
    }
end

module Side_loaded = struct
  module Ephemeral = struct
    type t =
      { index :
          [ `In_circuit of Side_loaded_verification_key.Checked.t
          | `In_prover of Side_loaded_verification_key.t
          | `In_both of
            Side_loaded_verification_key.t
            * Side_loaded_verification_key.Checked.t ]
      }
  end

  module Permanent = struct
    type ('var, 'value, 'n1, 'n2) t =
      { max_proofs_verified : (module Nat.Add.Intf with type n = 'n1)
      ; public_input : ('var, 'value) Impls.Step.Typ.t
      ; step_uses_lookup : Plonk_types.Opt.Flag.t
      ; branches : 'n2 Nat.t
      }
  end

  type ('var, 'value, 'n1, 'n2) t =
    { ephemeral : Ephemeral.t option
    ; permanent : ('var, 'value, 'n1, 'n2) Permanent.t
    }

  type packed =
    | T :
        ('var, 'value, 'n1, 'n2) Tag.tag * ('var, 'value, 'n1, 'n2) t
        -> packed

  let to_basic
      { permanent =
          { max_proofs_verified; public_input; branches; step_uses_lookup }
      ; ephemeral
      } =
    let wrap_key, wrap_vk =
      match ephemeral with
      | Some { index = `In_prover i | `In_both (i, _) } ->
          (i.wrap_index, i.wrap_vk)
      | _ ->
          failwithf "Side_loaded.to_basic: Expected `In_prover (%s)" __LOC__ ()
    in
    let proofs_verified = Nat.to_int (Nat.Add.n max_proofs_verified) in
    let wrap_vk = Option.value_exn ~here:[%here] wrap_vk in
    { Basic.max_proofs_verified
    ; wrap_vk
    ; public_input
    ; branches
    ; wrap_domains = Common.wrap_domains ~proofs_verified
    ; wrap_key
    ; step_uses_lookup
    }
end

module Compiled = struct
  type f = Impls.Wrap.field

  type ('a_var, 'a_value, 'max_proofs_verified, 'branches) basic =
    { public_input : ('a_var, 'a_value) Impls.Step.Typ.t
    ; proofs_verifieds : (int, 'branches) Vector.t
          (* For each branch in this rule, how many predecessor proofs does it have? *)
    ; wrap_domains : Domains.t
    ; step_domains : (Domains.t, 'branches) Vector.t
    ; step_uses_lookup : Plonk_types.Opt.Flag.t
    }

  (* This is the data associated to an inductive proof system with statement type
     ['a_var], which has ['branches] many "variants" each of which depends on at most
     ['max_proofs_verified] many previous statements. *)
  type ('a_var, 'a_value, 'max_proofs_verified, 'branches) t =
    { branches : 'branches Nat.t
    ; max_proofs_verified :
        (module Nat.Add.Intf with type n = 'max_proofs_verified)
    ; proofs_verifieds : (int, 'branches) Vector.t
          (* For each branch in this rule, how many predecessor proofs does it have? *)
    ; public_input : ('a_var, 'a_value) Impls.Step.Typ.t
    ; wrap_key : Step.Inner_curve.Affine.t Plonk_verification_key_evals.t Lazy.t
    ; wrap_vk : Impls.Wrap.Verification_key.t Lazy.t
    ; wrap_domains : Domains.t
    ; step_domains : (Domains.t, 'branches) Vector.t
    ; step_uses_lookup : Plonk_types.Opt.Flag.t
    }

  type packed =
    | T :
        ('var, 'value, 'n1, 'n2) Tag.tag * ('var, 'value, 'n1, 'n2) t
        -> packed

  let to_basic
      { branches
      ; max_proofs_verified
      ; proofs_verifieds
      ; public_input
      ; wrap_vk
      ; wrap_domains
      ; step_domains
      ; wrap_key
      ; step_uses_lookup
      } =
    { Basic.max_proofs_verified
    ; wrap_domains
    ; public_input
    ; branches = Vector.length step_domains
    ; wrap_key = Lazy.force wrap_key
    ; wrap_vk = Lazy.force wrap_vk
    ; step_uses_lookup
    }
end

module For_step = struct
  type ('a_var, 'a_value, 'max_proofs_verified, 'branches) t =
    { branches : 'branches Nat.t
    ; max_proofs_verified :
        (module Nat.Add.Intf with type n = 'max_proofs_verified)
    ; proofs_verifieds :
        [ `Known of (Impls.Step.Field.t, 'branches) Vector.t | `Side_loaded ]
    ; public_input : ('a_var, 'a_value) Impls.Step.Typ.t
    ; wrap_key : inner_curve_var Plonk_verification_key_evals.t
    ; wrap_domain :
        [ `Known of Domain.t
        | `Side_loaded of
          Impls.Step.field Pickles_base.Proofs_verified.One_hot.Checked.t ]
    ; step_domains : [ `Known of (Domains.t, 'branches) Vector.t | `Side_loaded ]
    ; step_uses_lookup : Plonk_types.Opt.Flag.t
    }

  let of_side_loaded (type a b c d e f)
      ({ ephemeral
       ; permanent =
           { branches; max_proofs_verified; public_input; step_uses_lookup }
       } :
        (a, b, c, d) Side_loaded.t ) : (a, b, c, d) t =
    let index =
      match ephemeral with
      | Some { index = `In_circuit i | `In_both (_, i) } ->
          i
      | _ ->
          failwithf "For_step.side_loaded: Expected `In_circuit (%s)" __LOC__ ()
    in
    let T = Nat.eq_exn branches Side_loaded_verification_key.Max_branches.n in
    { branches
    ; max_proofs_verified
    ; public_input
    ; proofs_verifieds = `Side_loaded
    ; wrap_key = index.wrap_index
    ; wrap_domain = `Side_loaded index.max_proofs_verified
    ; step_domains = `Side_loaded
    ; step_uses_lookup
    }

  let of_compiled
      ({ branches
       ; max_proofs_verified
       ; proofs_verifieds
       ; public_input
       ; wrap_key
       ; wrap_domains
       ; step_domains
       ; step_uses_lookup
       } :
        _ Compiled.t ) =
    { branches
    ; max_proofs_verified
    ; proofs_verifieds =
        `Known (Vector.map proofs_verifieds ~f:Impls.Step.Field.of_int)
    ; public_input
    ; wrap_key =
        Plonk_verification_key_evals.map (Lazy.force wrap_key)
          ~f:Step_main_inputs.Inner_curve.constant
    ; wrap_domain = `Known wrap_domains.h
    ; step_domains = `Known step_domains
    ; step_uses_lookup
    }
end

type t =
  { compiled : Compiled.packed Type_equal.Id.Uid.Table.t
  ; side_loaded : Side_loaded.packed Type_equal.Id.Uid.Table.t
  }

let univ : t =
  { compiled = Type_equal.Id.Uid.Table.create ()
  ; side_loaded = Type_equal.Id.Uid.Table.create ()
  }

let find t k =
  match Hashtbl.find t k with None -> failwith "key not found" | Some x -> x

let lookup_compiled :
    type var value n m.
    (var, value, n, m) Tag.tag -> (var, value, n, m) Compiled.t =
 fun t ->
  let (T (other_id, d)) = find univ.compiled (Type_equal.Id.uid t) in
  let T = Type_equal.Id.same_witness_exn t other_id in
  d

let lookup_side_loaded :
    type var value n m.
    (var, value, n, m) Tag.tag -> (var, value, n, m) Side_loaded.t =
 fun t ->
  let (T (other_id, d)) = find univ.side_loaded (Type_equal.Id.uid t) in
  let T = Type_equal.Id.same_witness_exn t other_id in
  d

let lookup_basic :
    type var value n m. (var, value, n, m) Tag.t -> (var, value, n, m) Basic.t =
 fun t ->
  match t.kind with
  | Compiled ->
      Compiled.to_basic (lookup_compiled t.id)
  | Side_loaded ->
      Side_loaded.to_basic (lookup_side_loaded t.id)

let max_proofs_verified :
    type n1. (_, _, n1, _) Tag.t -> (module Nat.Add.Intf with type n = n1) =
 fun tag ->
  match tag.kind with
  | Compiled ->
      (lookup_compiled tag.id).max_proofs_verified
  | Side_loaded ->
      (lookup_side_loaded tag.id).permanent.max_proofs_verified

let public_input :
    type var value. (var, value, _, _) Tag.t -> (var, value) Impls.Step.Typ.t =
 fun tag ->
  match tag.kind with
  | Compiled ->
      (lookup_compiled tag.id).public_input
  | Side_loaded ->
      (lookup_side_loaded tag.id).permanent.public_input

let uses_lookup :
    type var value. (var, value, _, _) Tag.t -> Plonk_types.Opt.Flag.t =
 fun tag ->
  match tag.kind with
  | Compiled ->
      (lookup_compiled tag.id).step_uses_lookup
  | Side_loaded ->
      (lookup_side_loaded tag.id).permanent.step_uses_lookup

let value_to_field_elements :
    type a. (_, a, _, _) Tag.t -> a -> Step.Field.t array =
 fun t ->
  let (Typ typ) = public_input t in
  fun x -> fst (typ.value_to_fields x)

let lookup_map (type var value c d) (t : (var, value, c, d) Tag.t) ~self
    ~default
    ~(f :
          [ `Compiled of (var, value, c, d) Compiled.t
          | `Side_loaded of (var, value, c, d) Side_loaded.t ]
       -> _ ) =
  match Type_equal.Id.same_witness t.id self with
  | Some _ ->
      default
  | None -> (
      match t.kind with
      | Compiled ->
          let (T (other_id, d)) = find univ.compiled (Type_equal.Id.uid t.id) in
          let T = Type_equal.Id.same_witness_exn t.id other_id in
          f (`Compiled d)
      | Side_loaded ->
          let (T (other_id, d)) =
            find univ.side_loaded (Type_equal.Id.uid t.id)
          in
          let T = Type_equal.Id.same_witness_exn t.id other_id in
          f (`Side_loaded d) )

let add_side_loaded ~name permanent =
  let id = Type_equal.Id.create ~name sexp_of_opaque in
  Hashtbl.add_exn univ.side_loaded ~key:(Type_equal.Id.uid id)
    ~data:(T (id, { ephemeral = None; permanent })) ;
  { Tag.kind = Side_loaded; id }

let set_ephemeral { Tag.kind; id } (eph : Side_loaded.Ephemeral.t) =
  (match kind with Side_loaded -> () | _ -> failwith "Expected Side_loaded") ;
  Hashtbl.update univ.side_loaded (Type_equal.Id.uid id) ~f:(function
    | None ->
        assert false
    | Some (T (id, d)) ->
        let ephemeral =
          match (d.ephemeral, eph.index) with
          | None, _ | Some _, `In_prover _ ->
              (* Giving prover only always resets. *)
              Some eph
          | Some { index = `In_prover prover }, `In_circuit circuit
          | Some { index = `In_both (prover, _) }, `In_circuit circuit ->
              (* In-circuit extends prover if one was given. *)
              Some { index = `In_both (prover, circuit) }
          | _ ->
              (* Otherwise, just use the given value. *)
              Some eph
        in
        T (id, { d with ephemeral }) )

let add_exn (type var value c d) (tag : (var, value, c, d) Tag.t)
    (data : (var, value, c, d) Compiled.t) =
  Hashtbl.add_exn univ.compiled ~key:(Type_equal.Id.uid tag.id)
    ~data:(Compiled.T (tag.id, data))
