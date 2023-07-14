open Core_kernel
open Pickles_types
open Pickles_base
module Scalars = Scalars
module Domain = Domain
module Opt = Plonk_types.Opt

type 'field vanishing_polynomial_domain =
  < vanishing_polynomial : 'field -> 'field >

type 'field plonk_domain =
  < vanishing_polynomial : 'field -> 'field
  ; shifts : 'field Plonk_types.Shifts.t
  ; generator : 'field >

type 'field domain = < size : 'field ; vanishing_polynomial : 'field -> 'field >

module type Bool_intf = sig
  type t

  val true_ : t

  val false_ : t

  val ( &&& ) : t -> t -> t

  val ( ||| ) : t -> t -> t

  val any : t list -> t
end

module type Field_intf = sig
  type t

  val size_in_bits : int

  val zero : t

  val one : t

  val of_int : int -> t

  val ( * ) : t -> t -> t

  val ( / ) : t -> t -> t

  val ( + ) : t -> t -> t

  val ( - ) : t -> t -> t

  val inv : t -> t

  val negate : t -> t
end

module type Field_with_if_intf = sig
  include Field_intf

  type bool

  val if_ : bool -> then_:(unit -> t) -> else_:(unit -> t) -> t
end

type 'f field = (module Field_intf with type t = 'f)

let pow2pow (type t) ((module F) : t field) (x : t) n : t =
  let rec go acc i = if i = 0 then acc else go F.(acc * acc) (i - 1) in
  go x n

(* x^{2 ^ k} - 1 *)
let vanishing_polynomial (type t) ((module F) : t field) domain x =
  let k = Domain.log2_size domain in
  F.(pow2pow (module F) x k - one)

let domain (type t) ((module F) : t field) ~shifts ~domain_generator
    (domain : Domain.t) : t plonk_domain =
  let log2_size = Domain.log2_size domain in
  let shifts = shifts ~log2_size in
  let generator = domain_generator ~log2_size in
  object
    method shifts = shifts

    method vanishing_polynomial x = vanishing_polynomial (module F) domain x

    method generator = generator
  end

let actual_evaluation (type f) (module Field : Field_intf with type t = f)
    (e : Field.t array) (pt : Field.t) ~rounds : Field.t =
  let pt_n =
    let rec go acc i = if i = 0 then acc else go Field.(acc * acc) (i - 1) in
    go pt rounds
  in
  match List.rev (Array.to_list e) with
  | e :: es ->
      List.fold ~init:e es ~f:(fun acc fx -> Field.(fx + (pt_n * acc)))
  | [] ->
      Field.of_int 0

let evals_of_split_evals field ~zeta ~zetaw (es : _ Plonk_types.Evals.t) ~rounds
    =
  let e = Fn.flip (actual_evaluation field ~rounds) in
  Plonk_types.Evals.map es ~f:(fun (x1, x2) -> (e zeta x1, e zetaw x2))

open Composition_types.Wrap.Proof_state.Deferred_values.Plonk

type 'bool all_feature_flags =
  { lookup_tables : 'bool Lazy.t
  ; table_width_at_least_1 : 'bool Lazy.t
  ; table_width_at_least_2 : 'bool Lazy.t
  ; table_width_3 : 'bool Lazy.t
  ; lookups_per_row_3 : 'bool Lazy.t
  ; lookups_per_row_4 : 'bool Lazy.t
  ; lookup_pattern_xor : 'bool Lazy.t
  ; lookup_pattern_range_check : 'bool Lazy.t
  ; features : 'bool Plonk_types.Features.t
  }

let expand_feature_flags (type boolean)
    (module B : Bool_intf with type t = boolean)
    ({ range_check0
     ; range_check1
     ; foreign_field_add = _
     ; foreign_field_mul
     ; xor
     ; rot
     ; lookup
     ; runtime_tables = _
     } as features :
      boolean Plonk_types.Features.t ) : boolean all_feature_flags =
  let lookup_tables =
    lazy (B.any [ range_check0; range_check1; foreign_field_mul; xor; rot ])
  in
  let lookup_pattern_range_check =
    (* RangeCheck, Rot gates use RangeCheck lookup pattern *)
    lazy B.(range_check0 ||| range_check1 ||| rot)
  in
  let lookup_pattern_xor =
    (* Xor lookup pattern *)
    lazy xor
  in
  (* Make sure these stay up-to-date with the layouts!! *)
  let table_width_3 =
    (* Xor have max_joint_size = 3 *)
    lookup_pattern_xor
  in
  let table_width_at_least_2 =
    (* Lookup has max_joint_size = 2 *)
    lazy (B.( ||| ) (Lazy.force table_width_3) lookup)
  in
  let table_width_at_least_1 =
    (* RangeCheck, ForeignFieldMul have max_joint_size = 1 *)
    lazy
      (B.any
         [ Lazy.force table_width_at_least_2
         ; Lazy.force lookup_pattern_range_check
         ; foreign_field_mul
         ] )
  in
  let lookups_per_row_4 =
    (* Xor, RangeCheckGate, ForeignFieldMul, have max_lookups_per_row = 4 *)
    lazy
      (B.any
         [ Lazy.force lookup_pattern_xor
         ; Lazy.force lookup_pattern_range_check
         ; foreign_field_mul
         ] )
  in
  let lookups_per_row_3 =
    (* Lookup has max_lookups_per_row = 3 *)
    lazy (B.( ||| ) (Lazy.force lookups_per_row_4) lookup)
  in

  { lookup_tables
  ; table_width_at_least_1
  ; table_width_at_least_2
  ; table_width_3
  ; lookups_per_row_2
  ; lookups_per_row_3
  ; lookups_per_row_4
  ; lookup_pattern_xor
  ; lookup_pattern_range_check
  ; features
  }

let lookup_tables_used feature_flags =
  let module Bool = struct
    type t = Plonk_types.Opt.Flag.t

    let (true_ : t) = Yes

    let (false_ : t) = No

    let ( &&& ) (x : t) (y : t) : t =
      match (x, y) with
      | Yes, Yes ->
          Yes
      | Maybe, _ | _, Maybe ->
          Maybe
      | No, _ | _, No ->
          No

    let ( ||| ) (x : t) (y : t) : t =
      match (x, y) with
      | Yes, _ | _, Yes ->
          Yes
      | Maybe, _ | _, Maybe ->
          Maybe
      | No, No ->
          No

    let any = List.fold_left ~f:( ||| ) ~init:false_
  end in
  let all_feature_flags = expand_feature_flags (module Bool) feature_flags in
  Lazy.force all_feature_flags.lookup_tables

let get_feature_flag (feature_flags : _ all_feature_flags)
    (feature : Kimchi_types.feature_flag) =
  match feature with
  | RangeCheck0 ->
      Some feature_flags.features.range_check0
  | RangeCheck1 ->
      Some feature_flags.features.range_check1
  | ForeignFieldAdd ->
      Some feature_flags.features.foreign_field_add
  | ForeignFieldMul ->
      Some feature_flags.features.foreign_field_mul
  | Xor ->
      Some feature_flags.features.xor
  | Rot ->
      Some feature_flags.features.rot
  | LookupTables ->
      Some (Lazy.force feature_flags.lookup_tables)
  | RuntimeLookupTables ->
      Some feature_flags.features.runtime_tables
  | TableWidth 3 ->
      Some (Lazy.force feature_flags.table_width_3)
  | TableWidth 2 ->
      Some (Lazy.force feature_flags.table_width_at_least_2)
  | TableWidth i when i <= 1 ->
      Some (Lazy.force feature_flags.table_width_at_least_1)
  | TableWidth _ ->
      None
  | LookupsPerRow 4 ->
      Some (Lazy.force feature_flags.lookups_per_row_4)
  | LookupsPerRow i when i <= 3 ->
      Some (Lazy.force feature_flags.lookups_per_row_3)
  | LookupsPerRow _ ->
      None
  | LookupPattern Lookup ->
      Some feature_flags.features.lookup
  | LookupPattern Xor ->
      Some (Lazy.force feature_flags.lookup_pattern_xor)
  | LookupPattern RangeCheck ->
      Some (Lazy.force feature_flags.lookup_pattern_range_check)
  | LookupPattern ForeignFieldMul ->
      Some feature_flags.features.foreign_field_mul

let scalars_env (type boolean t) (module B : Bool_intf with type t = boolean)
    (module F : Field_with_if_intf with type t = t and type bool = boolean)
    ~endo ~mds ~field_of_hex ~domain ~srs_length_log2
    ({ alpha; beta; gamma; zeta; joint_combiner; feature_flags } :
      (t, _, boolean) Minimal.t ) (e : (_ * _, _) Plonk_types.Evals.In_circuit.t)
    =
  let feature_flags = expand_feature_flags (module B) feature_flags in
  let witness = Vector.to_array e.w in
  let coefficients = Vector.to_array e.coefficients in
  let var (col, row) =
    let get_eval =
      match (row : Scalars.curr_or_next) with Curr -> fst | Next -> snd
    in
    match (col : Scalars.Column.t) with
    | Witness i ->
        get_eval witness.(i)
    | Index Poseidon ->
        get_eval e.poseidon_selector
    | Index Generic ->
        get_eval e.generic_selector
    | Index i ->
        failwithf
          !"Index %{sexp:Scalars.Gate_type.t}\n\
            %! should have been linearized away"
          i ()
    | Coefficient i ->
        get_eval coefficients.(i)
    | LookupTable ->
        get_eval (Opt.value_exn e.lookup).table
    | LookupSorted i ->
        let sorted = (Opt.value_exn e.lookup).sorted in
        if i < Array.length sorted then get_eval sorted.(i)
        else
          (* Return zero padding when the index is larger than sorted *)
          F.zero
    | LookupAggreg ->
        get_eval (Opt.value_exn e.lookup).aggreg
    | LookupRuntimeTable ->
        get_eval (Opt.value_exn (Opt.value_exn e.lookup).runtime)
    | LookupKindIndex (Lookup | Xor | RangeCheck | ForeignFieldMul) ->
        failwith "Lookup kind index should have been linearized away"
    | LookupRuntimeSelector ->
        failwith "Lookup runtime selector should have been linearized away"
  in
  let open F in
  let square x = x * x in
  let rec pow x n =
    if n = 0 then one
    else if n = 1 then x
    else
      let y = pow (square x) Int.(n / 2) in
      if n mod 2 = 0 then y else x * y
  in
  let alpha_pows =
    let arr = Array.create ~len:71 one in
    arr.(1) <- alpha ;
    for i = 2 to Int.(Array.length arr - 1) do
      arr.(i) <- alpha * arr.(Int.(i - 1))
    done ;
    arr
  in
  let w4, w3, w2, w1 =
    (* generator^{n - 3} *)
    let gen = domain#generator in
    (* gen_inv = gen^{n - 1} = gen^{-1} *)
    let w1 = one / gen in
    let w2 = square w1 in
    let w3 = w2 * w1 in
    let w4 = lazy (w3 * w1) in
    (w4, w3, w2, w1)
  in
  let zk_polynomial =
    (* Vanishing polynomial of [w1, w2, w3]
        evaluated at x = zeta
    *)
    (zeta - w1) * (zeta - w2) * (zeta - w3)
  in
  let zeta_to_n_minus_1 = lazy (domain#vanishing_polynomial zeta) in
  { Scalars.Env.add = ( + )
  ; sub = ( - )
  ; mul = ( * )
  ; square
  ; alpha_pow = (fun i -> alpha_pows.(i))
  ; var
  ; pow = Tuple2.uncurry pow
  ; field = field_of_hex
  ; cell = Fn.id
  ; double = (fun x -> of_int 2 * x)
  ; zk_polynomial
  ; omega_to_minus_3 = w3
  ; zeta_to_n_minus_1 = domain#vanishing_polynomial zeta
  ; endo_coefficient = endo
  ; mds = (fun (row, col) -> mds.(row).(col))
  ; srs_length_log2
  ; vanishes_on_last_4_rows =
      ( match joint_combiner with
      | None ->
          (* No need to compute anything when not using lookups *)
          F.one
      | Some _ ->
          zk_polynomial * (zeta - Lazy.force w4) )
  ; joint_combiner = Option.value joint_combiner ~default:F.one
  ; beta
  ; gamma
  ; unnormalized_lagrange_basis =
      (fun i ->
        let w_to_i =
          match i with
          | 0 ->
              one
          | 1 ->
              domain#generator
          | -1 ->
              w1
          | -2 ->
              w2
          | -3 ->
              w3
          | -4 ->
              Lazy.force w4
          | _ ->
              failwith "TODO"
        in
        Lazy.force zeta_to_n_minus_1 / (zeta - w_to_i) )
  ; if_feature =
      (fun (feature, e1, e2) ->
        let if_ b ~then_ ~else_ =
          match b with None -> e2 () | Some b -> F.if_ b ~then_ ~else_
        in
        let b = get_feature_flag feature_flags feature in
        if_ b ~then_:e1 ~else_:e2 )
  }

(* TODO: not true anymore if lookup is used *)

(** The offset of the powers of alpha for the permutation.
(see https://github.com/o1-labs/proof-systems/blob/516b16fc9b0fdcab5c608cd1aea07c0c66b6675d/kimchi/src/index.rs#L190) *)
let perm_alpha0 : int = 21

module Make (Shifted_value : Shifted_value.S) (Sc : Scalars.S) = struct
  (** Computes the ft evaluation at zeta.
  (see https://o1-labs.github.io/mina-book/crypto/plonk/maller_15.html#the-evaluation-of-l)
  *)
  let ft_eval0 (type t) (module F : Field_intf with type t = t) ~domain
      ~(env : t Scalars.Env.t)
      ({ alpha = _; beta; gamma; zeta; joint_combiner = _; feature_flags = _ } :
        _ Minimal.t ) (e : (_ * _, _) Plonk_types.Evals.In_circuit.t) p_eval0 =
    let open Plonk_types.Evals.In_circuit in
    let e0 field = fst (field e) in
    let e1 field = snd (field e) in
    let e0_s = Vector.map e.s ~f:fst in
    let zkp = env.zk_polynomial in
    let alpha_pow = env.alpha_pow in
    let zeta1m1 = env.zeta_to_n_minus_1 in
    let open F in
    let w0 = Vector.to_array e.w |> Array.map ~f:fst in
    let ft_eval0 =
      let a0 = alpha_pow perm_alpha0 in
      let w_n = w0.(Nat.to_int Plonk_types.Permuts_minus_1.n) in
      let init = (w_n + gamma) * e1 z * a0 * zkp in
      (* TODO: This shares some computation with the permutation scalar in
         derive_plonk. Could share between them. *)
      Vector.foldi e0_s ~init ~f:(fun i acc s ->
          ((beta * s) + w0.(i) + gamma) * acc )
    in
    let shifts = domain#shifts in
    let ft_eval0 = ft_eval0 - p_eval0 in
    let ft_eval0 =
      ft_eval0
      - Array.foldi shifts
          ~init:(alpha_pow perm_alpha0 * zkp * e0 z)
          ~f:(fun i acc s -> acc * (gamma + (beta * zeta * s) + w0.(i)))
    in
    let nominator =
      ( zeta1m1
        * alpha_pow Int.(perm_alpha0 + 1)
        * (zeta - env.omega_to_minus_3)
      + (zeta1m1 * alpha_pow Int.(perm_alpha0 + 2) * (zeta - one)) )
      * (one - e0 z)
    in
    let denominator = (zeta - env.omega_to_minus_3) * (zeta - one) in
    let ft_eval0 = ft_eval0 + (nominator / denominator) in
    let constant_term = Sc.constant_term env in
    ft_eval0 - constant_term

  (** Computes the list of scalars used in the linearization. *)
  let derive_plonk (type t) ?(with_label = fun _ (f : unit -> t) -> f ())
      (module F : Field_intf with type t = t) ~(env : t Scalars.Env.t) ~shift
      ~(feature_flags : _ Plonk_types.Features.t) =
    let _ = with_label in
    let open F in
    fun ({ alpha
         ; beta
         ; gamma
         ; zeta
         ; joint_combiner
         ; feature_flags = actual_feature_flags
         } :
          _ Minimal.t )
        (e : (_ * _, _) Plonk_types.Evals.In_circuit.t)
          (*((e0, e1) : _ Plonk_types.Evals.In_circuit.t Double.t) *) ->
      let open Plonk_types.Evals.In_circuit in
      let e1 field = snd (field e) in
      let zkp = env.zk_polynomial in
      let index_terms = Sc.index_terms env in
      let alpha_pow = env.alpha_pow in
      let w0 = Vector.map e.w ~f:fst in
      let perm =
        let w0 = Vector.to_array w0 in
        with_label __LOC__ (fun () ->
            Vector.foldi e.s
              ~init:(e1 z * beta * alpha_pow perm_alpha0 * zkp)
              ~f:(fun i acc (s, _) -> acc * (gamma + (beta * s) + w0.(i)))
            |> negate )
      in
      let compute_feature column feature_flag actual_feature_flag =
        match feature_flag with
        | Opt.Flag.Yes ->
            Opt.Some (Lazy.force (Hashtbl.find_exn index_terms column))
        | Opt.Flag.Maybe ->
            let res = Lazy.force (Hashtbl.find_exn index_terms column) in
            Opt.Maybe (actual_feature_flag, res)
        | Opt.Flag.No ->
            Opt.None
      in
      In_circuit.map_fields
        ~f:(Shifted_value.of_field (module F) ~shift)
        { alpha
        ; beta
        ; gamma
        ; zeta
        ; zeta_to_domain_size = env.zeta_to_n_minus_1 + F.one
        ; zeta_to_srs_length = pow2pow (module F) zeta env.srs_length_log2
        ; vbmul = Lazy.force (Hashtbl.find_exn index_terms (Index VarBaseMul))
        ; complete_add =
            Lazy.force (Hashtbl.find_exn index_terms (Index CompleteAdd))
        ; endomul = Lazy.force (Hashtbl.find_exn index_terms (Index EndoMul))
        ; endomul_scalar =
            Lazy.force (Hashtbl.find_exn index_terms (Index EndoMulScalar))
        ; perm
        ; lookup =
            ( match joint_combiner with
            | None ->
                Plonk_types.Opt.None
            | Some joint_combiner ->
                Some { joint_combiner } )
        ; optional_column_scalars =
            { range_check0 =
                compute_feature (Index RangeCheck0) feature_flags.range_check0
                  actual_feature_flags.range_check0
            ; range_check1 =
                compute_feature (Index RangeCheck1) feature_flags.range_check1
                  actual_feature_flags.range_check1
            ; foreign_field_add =
                compute_feature (Index ForeignFieldAdd)
                  feature_flags.foreign_field_add
                  actual_feature_flags.foreign_field_add
            ; foreign_field_mul =
                compute_feature (Index ForeignFieldMul)
                  feature_flags.foreign_field_mul
                  actual_feature_flags.foreign_field_mul
            ; xor =
                compute_feature (Index Xor16) feature_flags.xor
                  actual_feature_flags.xor
            ; rot =
                compute_feature (Index Rot64) feature_flags.rot
                  actual_feature_flags.rot
            ; lookup_gate =
                compute_feature (LookupKindIndex Lookup) feature_flags.lookup
                  actual_feature_flags.lookup
            ; runtime_tables =
                compute_feature LookupRuntimeSelector
                  feature_flags.runtime_tables
                  actual_feature_flags.runtime_tables
            }
        ; feature_flags = actual_feature_flags
        }

  (** Check that computed proof scalars match the expected ones,
    using the native field.
    Note that the expected scalars are used to check
    the linearization in a proof over the other field
    (where those checks are more efficient),
    but we deferred the arithmetic checks until here
    so that we have the efficiency of the native field.
  *)
  let checked (type t)
      (module Impl : Snarky_backendless.Snark_intf.Run with type field = t)
      ~shift ~env ~feature_flags
      (plonk : (_, _, _, _ Opt.t, _ Opt.t, _) In_circuit.t) evals =
    let actual =
      derive_plonk ~with_label:Impl.with_label
        (module Impl.Field)
        ~shift ~env ~feature_flags
        { alpha = plonk.alpha
        ; beta = plonk.beta
        ; gamma = plonk.gamma
        ; zeta = plonk.zeta
        ; joint_combiner =
            ( match plonk.lookup with
            | Plonk_types.Opt.None ->
                None
            | Some l | Maybe (_, l) ->
                Some l.In_circuit.Lookup.joint_combiner )
        ; feature_flags = plonk.feature_flags
        }
        evals
    in
    let open Impl in
    let equal_opt ~equal ((expected : _ Opt.t), (actual : _ Opt.t)) =
      match (expected, actual) with
      | None, None ->
          None
      | Some expected, Some actual ->
          Some (equal expected actual)
      | Maybe (is_some, expected), Some actual ->
          Some (Boolean.( &&& ) is_some (equal expected actual))
      | Maybe (is_some, expected), Maybe (is_some_actual, actual) ->
          Some
            (Boolean.( &&& )
               (Boolean.equal is_some is_some_actual)
               (Boolean.( ||| ) (Boolean.not is_some) (equal expected actual)) )
      | Some _, Maybe _ ->
          assert false
      | None, (Some _ | Maybe _) ->
          assert false
      | (Some _ | Maybe _), None ->
          assert false
    in
    let open In_circuit in
    with_label __LOC__ (fun () ->
        with_label __LOC__ (fun () ->
            List.map
              ~f:(fun f -> Shifted_value.equal Field.equal (f plonk) (f actual))
              [ vbmul; complete_add; endomul; perm ] )
        @ List.filter_map
            ~f:(equal_opt ~equal:(Shifted_value.equal Field.equal))
            (List.zip_exn
               (In_circuit.Optional_column_scalars.to_list
                  plonk.optional_column_scalars )
               (In_circuit.Optional_column_scalars.to_list
                  actual.optional_column_scalars ) )
        |> Boolean.all )
end
