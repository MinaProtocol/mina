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

let debug = false

module type Field_intf = sig
  type t

  val size_in_bits : int

  val one : t

  val of_int : int -> t

  val ( * ) : t -> t -> t

  val ( / ) : t -> t -> t

  val ( + ) : t -> t -> t

  val ( - ) : t -> t -> t

  val inv : t -> t

  val negate : t -> t
end

type 'f field = (module Field_intf with type t = 'f)

let map_reduce reduce xs map = List.reduce_exn (List.map xs ~f:map) ~f:reduce

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

let all_but m =
  List.filter Abc.Label.all ~f:(fun label -> not (Abc.Label.equal label m))

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

let scalars_env (type t) (module F : Field_intf with type t = t) ~endo ~mds
    ~field_of_hex ~domain ~srs_length_log2
    ({ alpha; beta; gamma; zeta; joint_combiner } : (t, _) Minimal.t)
    (e : (_ * _, _) Plonk_types.Evals.In_circuit.t) =
  let ww = Vector.to_array e.w in
  let w0 = Array.map ww ~f:fst in
  let w1 = Array.map ww ~f:snd in
  let var (col, row) =
    let get_eval, w =
      match (row : Scalars.curr_or_next) with
      | Curr ->
          (fst, w0)
      | Next ->
          (snd, w1)
    in
    match (col : Scalars.Column.t) with
    | Witness i ->
        w.(i)
    | Index Poseidon ->
        get_eval e.poseidon_selector
    | Index i ->
        failwithf
          !"Index %{sexp:Scalars.Gate_type.t}\n\
            %! should have been linearized away"
          i ()
    | Coefficient i ->
        failwithf
          !"Coefficient index %d\n%! should have been linearized away"
          i ()
    | LookupTable ->
        get_eval (Opt.value_exn e.lookup).table
    | LookupSorted i ->
        get_eval (Opt.value_exn e.lookup).sorted.(i)
    | LookupAggreg ->
        get_eval (Opt.value_exn e.lookup).aggreg
    | LookupRuntimeTable ->
        get_eval (Opt.value_exn (Opt.value_exn e.lookup).runtime)
    | LookupKindIndex LookupGate ->
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
  }

(* TODO: not true anymore if lookup is used *)

(** The offset of the powers of alpha for the permutation. 
(see https://github.com/o1-labs/proof-systems/blob/516b16fc9b0fdcab5c608cd1aea07c0c66b6675d/kimchi/src/index.rs#L190) *)
let perm_alpha0 : int = 21

let step_lookup_constant_term_part (type a)
    ({ add = ( + )
     ; sub = ( - )
     ; mul = ( * )
     ; square = _
     ; mds = _
     ; endo_coefficient = _
     ; pow
     ; var
     ; field
     ; cell
     ; alpha_pow
     ; double = _
     ; zk_polynomial = _
     ; omega_to_minus_3 = _
     ; zeta_to_n_minus_1 = _
     ; srs_length_log2 = _
     ; vanishes_on_last_4_rows
     ; joint_combiner
     ; beta
     ; gamma
     ; unnormalized_lagrange_basis
     } :
      a Scalars.Env.t ) =
  alpha_pow 24
  * ( vanishes_on_last_4_rows
    * ( cell (var (LookupAggreg, Next))
        * ( ( gamma
              * ( beta
                + field
                    "0x0000000000000000000000000000000000000000000000000000000000000001"
                )
            + cell (var (LookupSorted 0, Curr))
            + (beta * cell (var (LookupSorted 0, Next))) )
          * ( gamma
              * ( beta
                + field
                    "0x0000000000000000000000000000000000000000000000000000000000000001"
                )
            + cell (var (LookupSorted 1, Next))
            + (beta * cell (var (LookupSorted 1, Curr))) )
          * ( gamma
              * ( beta
                + field
                    "0x0000000000000000000000000000000000000000000000000000000000000001"
                )
            + cell (var (LookupSorted 2, Curr))
            + (beta * cell (var (LookupSorted 2, Next))) )
          * ( gamma
              * ( beta
                + field
                    "0x0000000000000000000000000000000000000000000000000000000000000001"
                )
            + cell (var (LookupSorted 3, Next))
            + (beta * cell (var (LookupSorted 3, Curr))) ) )
      - cell (var (LookupAggreg, Curr))
        * ( ( gamma
            + pow (joint_combiner, 2)
              * field
                  "0x0000000000000000000000000000000000000000000000000000000000000000"
            )
          * ( gamma
            + pow (joint_combiner, 2)
              * field
                  "0x0000000000000000000000000000000000000000000000000000000000000000"
            )
          * ( gamma
            + pow (joint_combiner, 2)
              * field
                  "0x0000000000000000000000000000000000000000000000000000000000000000"
            )
          * pow
              ( field
                  "0x0000000000000000000000000000000000000000000000000000000000000001"
                + beta
              , 3 )
          * ( gamma
              * ( beta
                + field
                    "0x0000000000000000000000000000000000000000000000000000000000000001"
                )
            + cell (var (LookupTable, Curr))
            + (beta * cell (var (LookupTable, Next))) ) ) ) )
  + alpha_pow 25
    * ( unnormalized_lagrange_basis 0
      * ( cell (var (LookupAggreg, Curr))
        - field
            "0x0000000000000000000000000000000000000000000000000000000000000001"
        ) )
  + alpha_pow 26
    * ( unnormalized_lagrange_basis (-4)
      * ( cell (var (LookupAggreg, Curr))
        - field
            "0x0000000000000000000000000000000000000000000000000000000000000001"
        ) )
  + alpha_pow 27
    * ( unnormalized_lagrange_basis (-4)
      * (cell (var (LookupSorted 0, Curr)) - cell (var (LookupSorted 1, Curr)))
      )
  + alpha_pow 28
    * ( unnormalized_lagrange_basis 0
      * (cell (var (LookupSorted 1, Curr)) - cell (var (LookupSorted 2, Curr)))
      )
  + alpha_pow 29
    * ( unnormalized_lagrange_basis (-4)
      * (cell (var (LookupSorted 2, Curr)) - cell (var (LookupSorted 3, Curr)))
      )

module Make (Shifted_value : Shifted_value.S) (Sc : Scalars.S) = struct
  (** Computes the ft evaluation at zeta. 
  (see https://o1-labs.github.io/mina-book/crypto/plonk/maller_15.html#the-evaluation-of-l)
  *)
  let ft_eval0 (type t) (module F : Field_intf with type t = t) ~domain
      ~(env : t Scalars.Env.t)
      ({ alpha = _; beta; gamma; zeta; joint_combiner = _ } : _ Minimal.t)
      (e : (_ * _, _) Plonk_types.Evals.In_circuit.t) p_eval0
      ~(lookup_constant_term_part : (F.t Scalars.Env.t -> F.t) option) =
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
    let constant_term =
      let c = Sc.constant_term env in
      Option.value_map lookup_constant_term_part ~default:c ~f:(fun x ->
          c + x env )
    in
    ft_eval0 - constant_term

  (** Computes the list of scalars used in the linearization. *)
  let derive_plonk (type t) ?(with_label = fun _ (f : unit -> t) -> f ())
      (module F : Field_intf with type t = t) ~(env : t Scalars.Env.t) ~shift =
    let _ = with_label in
    let open F in
    fun ({ alpha; beta; gamma; zeta; joint_combiner } : _ Minimal.t)
        (e : (_ * _, _) Plonk_types.Evals.In_circuit.t)
          (*((e0, e1) : _ Plonk_types.Evals.In_circuit.t Double.t) *) ->
      let open Plonk_types.Evals.In_circuit in
      let e0 field = fst (field e) in
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
      let generic =
        let open Vector in
        let (l1 :: r1 :: o1 :: l2 :: r2 :: o2 :: _) = w0 in
        let m1 = l1 * r1 in
        let m2 = l2 * r2 in
        [ e0 generic_selector; l1; r1; o1; m1; l2; r2; o2; m2 ]
      in
      In_circuit.map_fields
        ~f:(Shifted_value.of_field (module F) ~shift)
        { alpha
        ; beta
        ; gamma
        ; zeta
        ; zeta_to_domain_size = env.zeta_to_n_minus_1 + F.one
        ; zeta_to_srs_length = pow2pow (module F) zeta env.srs_length_log2
        ; poseidon_selector = e0 poseidon_selector
        ; vbmul = Lazy.force (Hashtbl.find_exn index_terms (Index VarBaseMul))
        ; complete_add =
            Lazy.force (Hashtbl.find_exn index_terms (Index CompleteAdd))
        ; endomul = Lazy.force (Hashtbl.find_exn index_terms (Index EndoMul))
        ; endomul_scalar =
            Lazy.force (Hashtbl.find_exn index_terms (Index EndoMulScalar))
        ; perm
        ; generic
        ; lookup =
            ( match joint_combiner with
            | None ->
                Plonk_types.Opt.None
            | Some joint_combiner ->
                Some
                  { joint_combiner
                  ; lookup_gate =
                      Lazy.force
                        (Hashtbl.find_exn index_terms
                           (LookupKindIndex LookupGate) )
                  } )
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
      ~shift ~env (plonk : (_, _, _, _ Opt.t) In_circuit.t) evals =
    let actual =
      derive_plonk ~with_label:Impl.with_label
        (module Impl.Field)
        ~shift ~env
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
        }
        evals
    in
    let open Impl in
    let open In_circuit in
    with_label __LOC__ (fun () ->
        ( Vector.to_list
            (with_label __LOC__ (fun () ->
                 Vector.map2 plonk.generic actual.generic
                   ~f:(Shifted_value.equal Field.equal) ) )
        @ with_label __LOC__ (fun () ->
              List.map
                ~f:(fun f ->
                  Shifted_value.equal Field.equal (f plonk) (f actual) )
                [ poseidon_selector; vbmul; complete_add; endomul; perm ] )
        @
        match (plonk.lookup, actual.lookup) with
        | None, None ->
            []
        | Some plonk, Some actual ->
            [ Shifted_value.equal Field.equal plonk.lookup_gate
                actual.lookup_gate
            ]
        | Maybe (is_some, plonk), (Some actual | Maybe (_, actual)) ->
            [ Boolean.( ||| ) (Boolean.not is_some)
                (Shifted_value.equal Field.equal plonk.lookup_gate
                   actual.lookup_gate )
            ]
        | Some _, Maybe _ | None, (Some _ | Maybe _) | (Some _ | Maybe _), None
          ->
            assert false )
        |> Boolean.all )
end
