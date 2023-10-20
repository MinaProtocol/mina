open Core_kernel
open Pickles_types
open Pickles_base
module Scalars = Scalars
module Domain = Domain
module Opt = Opt

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

type 'bool all_feature_flags = 'bool Lazy.t Plonk_types.Features.Full.t

let expand_feature_flags (type boolean)
    (module B : Bool_intf with type t = boolean)
    (features : boolean Plonk_types.Features.t) : boolean all_feature_flags =
  features
  |> Plonk_types.Features.map ~f:(fun x -> lazy x)
  |> Plonk_types.Features.to_full
       ~or_:(fun x y -> lazy B.(Lazy.force x ||| Lazy.force y))
       ~any:(fun x -> lazy (B.any (List.map ~f:Lazy.force x)))

let lookup_tables_used feature_flags =
  let module Bool = struct
    type t = Opt.Flag.t

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
  Lazy.force all_feature_flags.uses_lookups

let get_feature_flag (feature_flags : _ all_feature_flags)
    (feature : Kimchi_types.feature_flag) =
  let lazy_flag =
    Plonk_types.Features.Full.get_feature_flag feature_flags feature
  in
  Option.map ~f:Lazy.force lazy_flag

let scalars_env (type boolean t) (module B : Bool_intf with type t = boolean)
    (module F : Field_with_if_intf with type t = t and type bool = boolean)
    ~endo ~mds ~field_of_hex ~domain ~zk_rows ~srs_length_log2
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
    match[@warning "-4"] (col : Scalars.Column.t) with
    | Witness i ->
        get_eval witness.(i)
    | Index Poseidon ->
        get_eval e.poseidon_selector
    | Index Generic ->
        get_eval e.generic_selector
    | Index CompleteAdd ->
        get_eval e.complete_add_selector
    | Index VarBaseMul ->
        get_eval e.mul_selector
    | Index EndoMul ->
        get_eval e.emul_selector
    | Index EndoMulScalar ->
        get_eval e.endomul_scalar_selector
    | Index RangeCheck0 ->
        get_eval (Opt.value_exn e.range_check0_selector)
    | Index RangeCheck1 ->
        get_eval (Opt.value_exn e.range_check1_selector)
    | Index ForeignFieldAdd ->
        get_eval (Opt.value_exn e.foreign_field_add_selector)
    | Index ForeignFieldMul ->
        get_eval (Opt.value_exn e.foreign_field_mul_selector)
    | Index Xor16 ->
        get_eval (Opt.value_exn e.xor_selector)
    | Index Rot64 ->
        get_eval (Opt.value_exn e.rot_selector)
    | Index i ->
        failwithf
          !"Index %{sexp:Scalars.Gate_type.t}\n\
            %! should have been linearized away"
          i ()
    | Coefficient i ->
        get_eval coefficients.(i)
    | LookupTable ->
        get_eval (Opt.value_exn e.lookup_table)
    | LookupSorted i ->
        get_eval
          (Opt.value_exn (Option.value_exn (Vector.nth e.lookup_sorted i)))
    | LookupAggreg ->
        get_eval (Opt.value_exn e.lookup_aggregation)
    | LookupRuntimeTable ->
        get_eval (Opt.value_exn e.runtime_lookup_table)
    | LookupKindIndex Lookup ->
        get_eval (Opt.value_exn e.lookup_gate_lookup_selector)
    | LookupKindIndex Xor ->
        get_eval (Opt.value_exn e.xor_lookup_selector)
    | LookupKindIndex RangeCheck ->
        get_eval (Opt.value_exn e.range_check_lookup_selector)
    | LookupKindIndex ForeignFieldMul ->
        get_eval (Opt.value_exn e.foreign_field_mul_lookup_selector)
    | LookupRuntimeSelector ->
        get_eval (Opt.value_exn e.runtime_lookup_table_selector)
    | Z | Permutation _ ->
        failwith "TODO"
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
  let ( omega_to_zk_minus_1
      , omega_to_zk
      , omega_to_intermediate_powers
      , omega_to_zk_plus_1
      , omega_to_minus_1 ) =
    (* generator^{n - 3} *)
    let gen = domain#generator in
    (* gen_inv = gen^{n - 1} = gen^{-1} *)
    let omega_to_minus_1 = one / gen in
    let omega_to_minus_2 = square omega_to_minus_1 in
    let omega_to_intermediate_powers, omega_to_zk_plus_1 =
      let next_term = ref omega_to_minus_2 in
      let omega_to_intermediate_powers =
        Array.init
          Stdlib.(zk_rows - 3)
          ~f:(fun _ ->
            let term = !next_term in
            next_term := term * omega_to_minus_1 ;
            term )
      in
      (omega_to_intermediate_powers, !next_term)
    in
    let omega_to_zk = omega_to_zk_plus_1 * omega_to_minus_1 in
    let omega_to_zk_minus_1 = lazy (omega_to_zk * omega_to_minus_1) in
    ( omega_to_zk_minus_1
    , omega_to_zk
    , omega_to_intermediate_powers
    , omega_to_zk_plus_1
    , omega_to_minus_1 )
  in
  let zk_polynomial =
    (* Vanishing polynomial of
       [omega_to_minus_1, omega_to_zk_plus_1, omega_to_zk]
       evaluated at x = zeta
    *)
    (zeta - omega_to_minus_1)
    * (zeta - omega_to_zk_plus_1)
    * (zeta - omega_to_zk)
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
  ; omega_to_minus_zk_rows = omega_to_zk
  ; zeta_to_n_minus_1 = domain#vanishing_polynomial zeta
  ; zeta_to_srs_length = lazy (pow2pow (module F) zeta srs_length_log2)
  ; endo_coefficient = endo
  ; mds = (fun (row, col) -> mds.(row).(col))
  ; srs_length_log2
  ; vanishes_on_zero_knowledge_and_previous_rows =
      ( match joint_combiner with
      | None ->
          (* No need to compute anything when not using lookups *)
          F.one
      | Some _ ->
          Array.fold omega_to_intermediate_powers
            ~init:(zk_polynomial * (zeta - Lazy.force omega_to_zk_minus_1))
            ~f:(fun acc omega_pow -> acc * (zeta - omega_pow)) )
  ; joint_combiner = Option.value joint_combiner ~default:F.one
  ; beta
  ; gamma
  ; unnormalized_lagrange_basis =
      (fun i ->
        let w_to_i =
          match i with
          | false, 0 ->
              one
          | false, 1 ->
              domain#generator
          | false, -1 ->
              omega_to_minus_1
          | false, -2 ->
              omega_to_zk_plus_1
          | false, -3 | true, 0 ->
              omega_to_zk
          | true, -1 ->
              Lazy.force omega_to_zk_minus_1
          | b, i ->
              failwithf "TODO: unnormalized_lagrange_basis(%b, %i)" b i ()
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
  let ft_eval0 (type t) (module F : Field_intf with type t = t) ~constant
      ~optional_constraints ~domain ~(env : t Scalars.Env.t)
      ({ alpha = _; beta; gamma; zeta; joint_combiner = _; feature_flags = _ } :
        _ Minimal.t ) (e : (_ * _, _) Plonk_types.Evals.In_circuit.t) p_eval0 =
    let open Plonk_types.Evals.In_circuit in
    let e0 field = fst (field e) in
    let e1 field = snd (field e) in
    let e0_s = Vector.map e.s ~f:fst in
    let zkp = env.zk_polynomial in
    let alpha_pow = env.alpha_pow in
    let zeta1m1 = env.zeta_to_n_minus_1 in
    let p_eval0 =
      Option.value_exn
        (Array.fold_right ~init:None p_eval0 ~f:(fun p_eval0 acc ->
             match acc with
             | None ->
                 Some p_eval0
             | Some acc ->
                 let zeta1 = Lazy.force env.zeta_to_srs_length in
                 Some F.(p_eval0 + (zeta1 * acc)) ) )
    in
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
        * (zeta - env.omega_to_minus_zk_rows)
      + (zeta1m1 * alpha_pow Int.(perm_alpha0 + 2) * (zeta - one)) )
      * (one - e0 z)
    in
    let denominator = (zeta - env.omega_to_minus_zk_rows) * (zeta - one) in
    let ft_eval0 = ft_eval0 + (nominator / denominator) in
    let constant_term =
      match optional_constraints with
      | None ->
          Sc.constant_term env
      | Some optional_constraints ->
          let constant_term = Sc.constant_term env in
          let optional = Scalars.interpret ~constant env optional_constraints in
          constant_term + optional
    in
    ft_eval0 - constant_term

  (** Computes the list of scalars used in the linearization. *)
  let derive_plonk (type t) ?(with_label = fun _ (f : unit -> t) -> f ())
      (module F : Field_intf with type t = t) ~(env : t Scalars.Env.t) ~shift =
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
      In_circuit.map_fields
        ~f:(Shifted_value.of_field (module F) ~shift)
        { alpha
        ; beta
        ; gamma
        ; zeta
        ; zeta_to_domain_size = env.zeta_to_n_minus_1 + F.one
        ; zeta_to_srs_length = Lazy.force env.zeta_to_srs_length
        ; perm
        ; joint_combiner = Opt.of_option joint_combiner
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
      ~shift ~env (plonk : (_, _, _, _ Opt.t, _ Opt.t, _) In_circuit.t) evals =
    let actual =
      derive_plonk ~with_label:Impl.with_label
        (module Impl.Field)
        ~shift ~env
        { alpha = plonk.alpha
        ; beta = plonk.beta
        ; gamma = plonk.gamma
        ; zeta = plonk.zeta
        ; joint_combiner = Opt.to_option_unsafe plonk.joint_combiner
        ; feature_flags = plonk.feature_flags
        }
        evals
    in
    let open Impl in
    let open In_circuit in
    with_label __LOC__ (fun () ->
        with_label __LOC__ (fun () ->
            List.map
              ~f:(fun f -> Shifted_value.equal Field.equal (f plonk) (f actual))
              [ perm ] )
        |> Boolean.all )
end
