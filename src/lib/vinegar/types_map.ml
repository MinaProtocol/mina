open Core_kernel
open Pickles_types
open Import
open Backend

(* We maintain a global hash table which stores for each inductive proof system some
   data.
*)
type inner_curve_var =
  Tick.Field.t Snarky_backendless.Cvar.t
  * Tick.Field.t Snarky_backendless.Cvar.t

module Basic = struct
  type ('var, 'value, 'n1, 'n2) t =
    { max_proofs_verified : (module Nat.Add.Intf with type n = 'n1)
    ; public_input : ('var, 'value) Impls.Step.Typ.t
    ; branches : 'n2 Nat.t
    ; wrap_domains : Domains.t
    ; wrap_key : Tick.Inner_curve.Affine.t array Plonk_verification_key_evals.t
    ; wrap_vk : Impls.Wrap.Verification_key.t
    ; feature_flags : Opt.Flag.t Plonk_types.Features.Full.t
    ; num_chunks : int
    ; zk_rows : int
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
      ; feature_flags : Opt.Flag.t Plonk_types.Features.Full.t
      ; branches : 'n2 Nat.t
      ; num_chunks : int
      ; zk_rows : int
      }
  end

  type ('var, 'value, 'n1, 'n2) t =
    { ephemeral : Ephemeral.t option
    ; permanent : ('var, 'value, 'n1, 'n2) Permanent.t
    }

  type packed =
    | T : ('var, 'value, 'n1, 'n2) Tag.id * ('var, 'value, 'n1, 'n2) t -> packed

  let to_basic
      { permanent =
          { max_proofs_verified
          ; public_input
          ; branches
          ; feature_flags
          ; num_chunks
          ; zk_rows
          }
      ; ephemeral
      } =
    let wrap_key, wrap_vk =
      match ephemeral with
      | Some { index = `In_prover i | `In_both (i, _) } ->
          let wrap_index =
            Plonk_verification_key_evals.map i.wrap_index ~f:(fun x -> [| x |])
          in
          (wrap_index, i.wrap_vk)
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
    ; feature_flags
    ; num_chunks
    ; zk_rows
    }
end

module Compiled = struct
  type ('a_var, 'a_value, 'max_proofs_verified, 'branches) basic =
    { public_input : ('a_var, 'a_value) Impls.Step.Typ.t
    ; proofs_verifieds : (int, 'branches) Vector.t
          (* For each branch in this rule, how many predecessor proofs does it have? *)
    ; wrap_domains : Domains.t
    ; step_domains : (Domains.t, 'branches) Vector.t
    ; feature_flags : Opt.Flag.t Plonk_types.Features.Full.t
    ; num_chunks : int
    ; zk_rows : int
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
    ; wrap_key :
        Tick.Inner_curve.Affine.t array Plonk_verification_key_evals.t Promise.t
        Lazy.t
    ; wrap_vk : Impls.Wrap.Verification_key.t Promise.t Lazy.t
    ; wrap_domains : Domains.t
    ; step_domains : (Domains.t Promise.t, 'branches) Vector.t
    ; feature_flags : Opt.Flag.t Plonk_types.Features.Full.t
    ; num_chunks : int
    ; zk_rows : int
    }

  type packed =
    | T : ('var, 'value, 'n1, 'n2) Tag.id * ('var, 'value, 'n1, 'n2) t -> packed

  let to_basic
      { branches = _
      ; max_proofs_verified
      ; proofs_verifieds = _
      ; public_input
      ; wrap_vk
      ; wrap_domains
      ; step_domains
      ; wrap_key
      ; feature_flags
      ; num_chunks
      ; zk_rows
      } =
    let%bind.Promise wrap_key = Lazy.force wrap_key in
    let%map.Promise wrap_vk = Lazy.force wrap_vk in
    { Basic.max_proofs_verified
    ; wrap_domains
    ; public_input
    ; branches = Vector.length step_domains
    ; wrap_key
    ; wrap_vk
    ; feature_flags
    ; num_chunks
    ; zk_rows
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
    ; wrap_key : inner_curve_var array Plonk_verification_key_evals.t
    ; wrap_domain :
        [ `Known of Domain.t
        | `Side_loaded of
          Impls.Step.field Pickles_base.Proofs_verified.One_hot.Checked.t ]
    ; step_domains : [ `Known of (Domains.t, 'branches) Vector.t | `Side_loaded ]
    ; feature_flags : Opt.Flag.t Plonk_types.Features.Full.t
    ; num_chunks : int
    ; zk_rows : int
    }

  let of_side_loaded (type a b c d)
      ({ ephemeral
       ; permanent =
           { branches
           ; max_proofs_verified
           ; public_input
           ; feature_flags
           ; num_chunks
           ; zk_rows
           }
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
    let wrap_key =
      Plonk_verification_key_evals.map index.wrap_index ~f:(fun x -> [| x |])
    in
    { branches
    ; max_proofs_verified
    ; public_input
    ; proofs_verifieds = `Side_loaded
    ; wrap_key
    ; wrap_domain = `Side_loaded index.actual_wrap_domain_size
    ; step_domains = `Side_loaded
    ; feature_flags
    ; num_chunks
    ; zk_rows
    }

  module Optional_wrap_key = struct
    type 'branches known =
      { wrap_key :
          Tick.Inner_curve.Affine.t array Plonk_verification_key_evals.t
      ; step_domains : (Domains.t, 'branches) Vector.t
      }

    type 'branches t = 'branches known option
  end

  let of_compiled_with_known_wrap_key
      ({ wrap_key; step_domains } : _ Optional_wrap_key.known)
      ({ branches
       ; max_proofs_verified
       ; proofs_verifieds
       ; public_input
       ; wrap_key = _
       ; wrap_domains
       ; step_domains = _
       ; feature_flags
       ; wrap_vk = _
       ; num_chunks
       ; zk_rows
       } :
        _ Compiled.t ) =
    { branches
    ; max_proofs_verified
    ; proofs_verifieds =
        `Known (Vector.map proofs_verifieds ~f:Impls.Step.Field.of_int)
    ; public_input
    ; wrap_key =
        Plonk_verification_key_evals.map wrap_key
          ~f:(Array.map ~f:Step_main_inputs.Inner_curve.constant)
    ; wrap_domain = `Known wrap_domains.h
    ; step_domains = `Known step_domains
    ; feature_flags
    ; num_chunks
    ; zk_rows
    }

  let of_compiled ({ wrap_key; step_domains; _ } as t : _ Compiled.t) =
    let%map.Promise wrap_key = Lazy.force wrap_key
    and step_domains =
      let%map.Promise () =
        (* Wait for promises to resolve. *)
        Vector.fold ~init:(Promise.return ()) step_domains
          ~f:(fun acc step_domain ->
            let%bind.Promise _ = step_domain in
            acc )
      in
      Vector.map ~f:(fun x -> Option.value_exn @@ Promise.peek x) step_domains
    in
    of_compiled_with_known_wrap_key { wrap_key; step_domains } t
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
    (var, value, n, m) Tag.id -> (var, value, n, m) Compiled.t =
 fun t ->
  let (T (other_id, d)) = find univ.compiled (Type_equal.Id.uid t) in
  let T = Type_equal.Id.same_witness_exn t other_id in
  d

let lookup_side_loaded :
    type var value n m.
    (var, value, n, m) Tag.id -> (var, value, n, m) Side_loaded.t =
 fun t ->
  let (T (other_id, d)) = find univ.side_loaded (Type_equal.Id.uid t) in
  let T = Type_equal.Id.same_witness_exn t other_id in
  d

let lookup_basic :
    type var value n m.
    (var, value, n, m) Tag.t -> (var, value, n, m) Basic.t Promise.t =
 fun t ->
  match t.kind with
  | Compiled ->
      Compiled.to_basic (lookup_compiled t.id)
  | Side_loaded ->
      Promise.return @@ Side_loaded.to_basic (lookup_side_loaded t.id)

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

let feature_flags :
    type var value.
    (var, value, _, _) Tag.t -> Opt.Flag.t Plonk_types.Features.Full.t =
 fun tag ->
  match tag.kind with
  | Compiled ->
      (lookup_compiled tag.id).feature_flags
  | Side_loaded ->
      (lookup_side_loaded tag.id).permanent.feature_flags

let num_chunks : type var value. (var, value, _, _) Tag.t -> int =
 fun tag ->
  match tag.kind with
  | Compiled ->
      (lookup_compiled tag.id).num_chunks
  | Side_loaded ->
      (lookup_side_loaded tag.id).permanent.num_chunks

let _value_to_field_elements :
    type a. (_, a, _, _) Tag.t -> a -> Backend.Tick.Field.t array =
 fun t ->
  let (Typ typ) = public_input t in
  fun x -> fst (typ.value_to_fields x)

let _lookup_map (type var value c d) (t : (var, value, c, d) Tag.t) ~self
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
  let (Tag.{ id; _ } as tag) = Tag.(create ~kind:Side_loaded name) in
  Hashtbl.add_exn univ.side_loaded ~key:(Type_equal.Id.uid id)
    ~data:(T (id, { ephemeral = None; permanent })) ;
  tag

let set_ephemeral { Tag.kind; id } (eph : Side_loaded.Ephemeral.t) =
  assert (match kind with Side_loaded -> true | Compiled -> false) ;
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
