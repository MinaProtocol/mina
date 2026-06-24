(* The kimchi linearization's constant term, evaluated by interpreting the RPN
   token stream exposed by the proof-systems FFI (in OCaml evaluation order; see
   `Expr::to_ocaml_ordered_polish`). This replaces the previously-generated
   encoding (gen_scalars): the same [Env] primitives are invoked in the same
   order, so the resulting verification key is unchanged. *)

(* turn off the fragile-match warning: the token matches intentionally use a
   catch-all to fail on constructors that cannot occur in a linearization. *)
[@@@warning "-4"]

type curr_or_next = Curr | Next [@@deriving hash, eq, compare, sexp]

module Gate_type = struct
  module T = struct
    type t = Kimchi_types.gate_type =
      | Zero
      | Generic
      | Poseidon
      | CompleteAdd
      | VarBaseMul
      | EndoMul
      | EndoMulScalar
      | Lookup
      | RangeCheck0
      | RangeCheck1
      | ForeignFieldAdd
      | ForeignFieldMul
      | Xor16
      | Rot64
    [@@deriving hash, eq, compare, sexp]
  end

  include Core_kernel.Hashable.Make (T)
  include T
end

module Lookup_pattern = struct
  module T = struct
    type t = Kimchi_types.lookup_pattern =
      | Xor
      | Lookup
      | RangeCheck
      | ForeignFieldMul
    [@@deriving hash, eq, compare, sexp]
  end

  include Core_kernel.Hashable.Make (T)
  include T
end

module Column = struct
  open Core_kernel

  module T = struct
    type t =
      | Witness of int
      | Index of Gate_type.t
      | Coefficient of int
      | LookupTable
      | LookupSorted of int
      | LookupAggreg
      | LookupKindIndex of Lookup_pattern.t
      | LookupRuntimeSelector
      | LookupRuntimeTable
    [@@deriving hash, eq, compare, sexp]
  end

  include Hashable.Make (T)
  include T
end

module Env = struct
  type 'a t =
    { add : 'a -> 'a -> 'a
    ; sub : 'a -> 'a -> 'a
    ; mul : 'a -> 'a -> 'a
    ; pow : 'a * int -> 'a
    ; square : 'a -> 'a
    ; zk_polynomial : 'a
    ; omega_to_minus_zk_rows : 'a
    ; zeta_to_n_minus_1 : 'a
    ; zeta_to_srs_length : 'a Lazy.t
    ; var : Column.t * curr_or_next -> 'a
    ; field : string -> 'a
    ; cell : 'a -> 'a
    ; alpha_pow : int -> 'a
    ; double : 'a -> 'a
    ; endo_coefficient : 'a
    ; mds : int * int -> 'a
    ; srs_length_log2 : int
    ; vanishes_on_zero_knowledge_and_previous_rows : 'a
    ; joint_combiner : 'a
    ; beta : 'a
    ; gamma : 'a
    ; unnormalized_lagrange_basis : bool * int -> 'a
    ; if_feature : Kimchi_types.feature_flag * (unit -> 'a) * (unit -> 'a) -> 'a
    }
end

module type S = sig
  val constant_term : 'a Env.t -> 'a
end

(* The FFI column type carries two variants ([Z], [Permutation]) that never
   appear in the linearization's scalars; the rest map one-to-one onto the
   [Env]'s column type ([Gate_type.t] / [Lookup_pattern.t] are shared with
   [Kimchi_types]). *)
let to_column (c : Kimchi_types.column) : Column.t =
  match c with
  | Witness i ->
      Witness i
  | Index g ->
      Index g
  | Coefficient i ->
      Coefficient i
  | LookupTable ->
      LookupTable
  | LookupSorted i ->
      LookupSorted i
  | LookupAggreg ->
      LookupAggreg
  | LookupKindIndex p ->
      LookupKindIndex p
  | LookupRuntimeSelector ->
      LookupRuntimeSelector
  | LookupRuntimeTable ->
      LookupRuntimeTable
  | Z ->
      failwith "Scalars: unexpected Z column in linearization scalar"
  | Permutation _ ->
      failwith "Scalars: unexpected Permutation column in linearization scalar"

let to_curr_or_next (r : Kimchi_types.curr_or_next) : curr_or_next =
  match r with Curr -> Curr | Next -> Next

(* Evaluate a token stream against an [Env], reproducing the operation order of
   the previously-generated code. *)
let interpret (type a) (env : a Env.t)
    (tokens : Kimchi_types.polish_token array) : a =
  let { Env.add
      ; sub
      ; mul
      ; pow
      ; var
      ; field
      ; cell
      ; alpha_pow
      ; endo_coefficient
      ; mds
      ; beta
      ; gamma
      ; joint_combiner
      ; vanishes_on_zero_knowledge_and_previous_rows
      ; unnormalized_lagrange_basis
      ; if_feature
      ; _
      } =
    env
  in
  (* Cached subexpressions ([Store]/[Load]) are addressed by slot. A [Store]'s
     slot is its position among all [Store]s, fixed by token order, so it is
     stable no matter how often a thunked [if_feature] branch is evaluated. *)
  let n_stores = ref 0 in
  let store_slot =
    Array.map tokens ~f:(function
      | Store ->
          let s = !n_stores in
          incr n_stores ;
          s
      | _ ->
          -1 )
  in
  let cache : a option array = Array.create ~len:!n_stores None in
  let rec eval ~start ~len : a =
    let stack = ref [] in
    let push x = stack := x :: !stack in
    let pop () =
      match !stack with
      | x :: rest ->
          stack := rest ;
          x
      | [] ->
          failwith "Scalars: stack underflow"
    in
    (* OCaml evaluates [first OP second] right-to-left, so the emitter pushed
       [second]'s tokens before [first]'s and [first] (the left operand) is on
       top. We pop [b] = first then [a] = second, and combine as [op b a] —
       i.e. [first OP second] in source order — so [Sub] is correct with no
       special case. *)
    let binop op =
      let b = pop () in
      let a = pop () in
      push (op b a)
    in
    let i = ref start in
    let stop = start + len in
    while !i < stop do
      ( match tokens.(!i) with
      | Constant EndoCoefficient ->
          push endo_coefficient
      | Constant (Mds (row, col)) ->
          push (mds (row, col))
      | Constant (Literal hex) ->
          push (field hex)
      | Challenge Alpha -> (
          (* alpha only ever appears as [Challenge Alpha; Pow n], the shared
             [alpha_pow n] of the generated code. *)
          match tokens.(!i + 1) with
          | Pow n ->
              push (alpha_pow n) ;
              incr i
          | _ ->
              failwith "Scalars: Challenge Alpha not followed by Pow" )
      | Challenge Beta ->
          push beta
      | Challenge Gamma ->
          push gamma
      | Challenge JointCombiner ->
          push joint_combiner
      | Cell (col, row) ->
          push (cell (var (to_column col, to_curr_or_next row)))
      | Dup ->
          push (match !stack with x :: _ -> x | [] -> failwith "empty Dup")
      | Pow n ->
          let base = pop () in
          push (pow (base, n))
      | Add ->
          binop add
      | Sub ->
          binop sub
      | Mul ->
          binop mul
      | VanishesOnZeroKnowledgeAndPreviousRows ->
          push vanishes_on_zero_knowledge_and_previous_rows
      | UnnormalizedLagrangeBasis (zk_rows, offset) ->
          push (unnormalized_lagrange_basis (zk_rows, offset))
      | Store ->
          (* Cache the top without consuming it (it is also part of the
             enclosing expression). *)
          cache.(store_slot.(!i)) <-
            Some (match !stack with x :: _ -> x | [] -> failwith "empty Store")
      | Load slot ->
          push (Option.value_exn cache.(slot))
      | SkipIfNot (feature, n_true) ->
          (* An [if_feature] is laid out as
             [SkipIfNot(f, n_true); <true>; SkipIf(f, n_false); <false>].
             We reconstruct the branches as thunks and let the [Env]'s
             [if_feature] decide which to force (matching the generated code). *)
          let true_start = !i + 1 in
          let after_true = true_start + n_true in
          let n_false =
            match tokens.(after_true) with
            | SkipIf (_, n_false) ->
                n_false
            | _ ->
                failwith "Scalars: malformed if_feature encoding"
          in
          let false_start = after_true + 1 in
          let thunk_true () = eval ~start:true_start ~len:n_true in
          let thunk_false () = eval ~start:false_start ~len:n_false in
          push (if_feature (feature, thunk_true, thunk_false)) ;
          i := false_start + n_false - 1
      | SkipIf _ ->
          failwith "Scalars: unexpected SkipIf" ) ;
      incr i
    done ;
    pop ()
  in
  eval ~start:0 ~len:(Array.length tokens)

(* These resolve to the `#[ocaml::func]` stubs in proof-systems
   `kimchi-stubs/src/linearization.rs`, returning the constant term (first) and
   the index terms (unused here, as in the generated code). *)
external fp_linearization_tokens :
     unit
  -> Kimchi_types.polish_token array
     * (string * Kimchi_types.polish_token array) array
  = "fp_linearization_tokens"

external fq_linearization_tokens :
     unit
  -> Kimchi_types.polish_token array
     * (string * Kimchi_types.polish_token array) array
  = "fq_linearization_tokens"

let tick_constant_term_tokens = lazy (fst (fp_linearization_tokens ()))

let tock_constant_term_tokens = lazy (fst (fq_linearization_tokens ()))

module Tick : S = struct
  let constant_term env = interpret env (Lazy.force tick_constant_term_tokens)
end

module Tock : S = struct
  let constant_term env = interpret env (Lazy.force tock_constant_term_tokens)
end
