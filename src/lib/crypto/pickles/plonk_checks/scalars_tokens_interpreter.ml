(* Stack-based interpreter for Polish notation linearization polynomials.
   This replaces the large tree-walking constant_term functions in scalars.ml
   with a compact interpreter that evaluates the token arrays from
   scalars_tokens.ml. *)

module ST = Scalars_tokens

(* --- Type conversions from Scalars_tokens to Scalars/Kimchi_types --- *)

let convert_curr_or_next : ST.curr_or_next -> Scalars.curr_or_next = function
  | ST.Curr -> Scalars.Curr
  | ST.Next -> Scalars.Next

let convert_gate_type : ST.Gate_type.t -> Scalars.Gate_type.t = function
  | ST.Gate_type.Zero -> Scalars.Gate_type.Zero
  | ST.Gate_type.Generic -> Scalars.Gate_type.Generic
  | ST.Gate_type.Poseidon -> Scalars.Gate_type.Poseidon
  | ST.Gate_type.CompleteAdd -> Scalars.Gate_type.CompleteAdd
  | ST.Gate_type.VarBaseMul -> Scalars.Gate_type.VarBaseMul
  | ST.Gate_type.EndoMul -> Scalars.Gate_type.EndoMul
  | ST.Gate_type.EndoMulScalar -> Scalars.Gate_type.EndoMulScalar
  | ST.Gate_type.Lookup -> Scalars.Gate_type.Lookup
  | ST.Gate_type.CairoClaim -> Scalars.Gate_type.CairoClaim
  | ST.Gate_type.CairoInstruction -> Scalars.Gate_type.CairoInstruction
  | ST.Gate_type.CairoFlags -> Scalars.Gate_type.CairoFlags
  | ST.Gate_type.CairoTransition -> Scalars.Gate_type.CairoTransition
  | ST.Gate_type.RangeCheck0 -> Scalars.Gate_type.RangeCheck0
  | ST.Gate_type.RangeCheck1 -> Scalars.Gate_type.RangeCheck1
  | ST.Gate_type.ForeignFieldAdd -> Scalars.Gate_type.ForeignFieldAdd
  | ST.Gate_type.ForeignFieldMul -> Scalars.Gate_type.ForeignFieldMul
  | ST.Gate_type.Xor16 -> Scalars.Gate_type.Xor16
  | ST.Gate_type.Rot64 -> Scalars.Gate_type.Rot64

let convert_lookup_pattern : ST.Lookup_pattern.t -> Scalars.Lookup_pattern.t =
  function
  | ST.Lookup_pattern.Xor -> Scalars.Lookup_pattern.Xor
  | ST.Lookup_pattern.Lookup -> Scalars.Lookup_pattern.Lookup
  | ST.Lookup_pattern.RangeCheck -> Scalars.Lookup_pattern.RangeCheck
  | ST.Lookup_pattern.ForeignFieldMul -> Scalars.Lookup_pattern.ForeignFieldMul

let convert_column : ST.column -> Scalars.Column.t = function
  | ST.Witness i -> Scalars.Column.Witness i
  | ST.Index g -> Scalars.Column.Index (convert_gate_type g)
  | ST.Coefficient i -> Scalars.Column.Coefficient i
  | ST.LookupTable -> Scalars.Column.LookupTable
  | ST.LookupSorted i -> Scalars.Column.LookupSorted i
  | ST.LookupAggreg -> Scalars.Column.LookupAggreg
  | ST.LookupKindIndex p -> Scalars.Column.LookupKindIndex (convert_lookup_pattern p)
  | ST.LookupRuntimeSelector -> Scalars.Column.LookupRuntimeSelector
  | ST.LookupRuntimeTable -> Scalars.Column.LookupRuntimeTable
  | ST.Z -> failwith "Scalars_tokens_interpreter: Column Z not in constant_term"
  | ST.Permutation _ ->
      failwith "Scalars_tokens_interpreter: Column Permutation not in constant_term"

let convert_feature_flag : ST.Feature_flag.t -> Kimchi_types.feature_flag =
  function
  | ST.Feature_flag.RangeCheck0 -> Kimchi_types.RangeCheck0
  | ST.Feature_flag.RangeCheck1 -> Kimchi_types.RangeCheck1
  | ST.Feature_flag.ForeignFieldAdd -> Kimchi_types.ForeignFieldAdd
  | ST.Feature_flag.ForeignFieldMul -> Kimchi_types.ForeignFieldMul
  | ST.Feature_flag.Xor -> Kimchi_types.Xor
  | ST.Feature_flag.Rot -> Kimchi_types.Rot
  | ST.Feature_flag.LookupTables -> Kimchi_types.LookupTables
  | ST.Feature_flag.RuntimeLookupTables -> Kimchi_types.RuntimeLookupTables
  | ST.Feature_flag.LookupPattern p ->
      Kimchi_types.LookupPattern (convert_lookup_pattern p)
  | ST.Feature_flag.TableWidth n -> Kimchi_types.TableWidth n
  | ST.Feature_flag.LookupsPerRow n -> Kimchi_types.LookupsPerRow n

(* --- Interpreter state --- *)

type 'a eval_state =
  { stack : 'a list (* head = top of stack *)
  ; store : 'a list (* insertion order; Load n = List.nth store n *)
  ; pos : int (* current position in token array *)
  }

(* --- Core interpreter --- *)

(** Evaluate a Polish notation token array using the given environment.
    This is the core interpreter loop, equivalent to the PureScript [evaluate]
    function in Pickles.Linearization.Interpreter. *)
let evaluate (tokens : ST.polish_token array) (env : 'a Scalars.Env.t) : 'a =
  (* Stack helpers *)
  let push v st = { st with stack = v :: st.stack } in
  let pop st =
    match st.stack with v :: rest -> Some (v, { st with stack = rest }) | [] -> None
  in
  let pop2 st =
    match st.stack with
    | b :: a :: rest -> Some (a, b, { st with stack = rest })
    | _ -> None
  in
  let advance st = { st with pos = st.pos + 1 } in
  (* Evaluate a constant term *)
  let eval_constant : ST.constant_term -> 'a = function
    | ST.EndoCoefficient -> env.endo_coefficient
    | ST.Mds (row, col) -> env.mds (row, col)
    | ST.Literal hex -> env.field hex
  in
  (* Main evaluation loop — processes tokens from pos until end of array *)
  let rec eval_loop (toks : ST.polish_token array) (tok_len : int)
      (state : 'a eval_state) : 'a eval_state =
    if state.pos >= tok_len then state
    else
      let token = toks.(state.pos) in
      let state' = eval_token toks tok_len state token in
      eval_loop toks tok_len state'
  (* Evaluate a single token, returning updated state *)
  and eval_token (toks : ST.polish_token array) (tok_len : int)
      (state : 'a eval_state) (token : ST.polish_token) : 'a eval_state =
    match token with
    | ST.Constant term -> push (eval_constant term) (advance state)
    (* Challenges — peephole: Challenge Alpha + Pow n → alpha_pow n *)
    | ST.Challenge ST.Alpha ->
        if state.pos + 1 < tok_len then (
          match toks.(state.pos + 1) with
          | ST.Pow k -> push (env.alpha_pow k) { state with pos = state.pos + 2 }
          | _ -> push (env.alpha_pow 1) (advance state))
        else push (env.alpha_pow 1) (advance state)
    | ST.Challenge ST.Beta -> push env.beta (advance state)
    | ST.Challenge ST.Gamma -> push env.gamma (advance state)
    | ST.Challenge ST.JointCombiner -> push env.joint_combiner (advance state)
    (* Cell access — convert token types to Scalars types for env.var *)
    | ST.Cell (col, row) ->
        let col' = convert_column col in
        let row' = convert_curr_or_next row in
        push (env.cell (env.var (col', row'))) (advance state)
    (* Stack: duplicate top *)
    | ST.Dup -> (
        match state.stack with
        | top :: _ -> push top (advance state)
        | [] -> advance state)
    (* Arithmetic *)
    | ST.Add -> (
        match pop2 state with
        | Some (a, b, st) -> push (env.add a b) (advance st)
        | None -> advance state)
    | ST.Mul -> (
        match pop2 state with
        | Some (a, b, st) -> push (env.mul a b) (advance st)
        | None -> advance state)
    | ST.Sub -> (
        match pop2 state with
        | Some (a, b, st) -> push (env.sub a b) (advance st)
        | None -> advance state)
    | ST.Pow k -> (
        match pop state with
        | Some (v, st) -> push (env.pow (v, k)) (advance st)
        | None -> advance state)
    (* Store: pop value, append to store, push back *)
    | ST.Store -> (
        match pop state with
        | Some (v, st) ->
            let st' = { st with store = st.store @ [ v ] } in
            push v (advance st')
        | None -> advance state)
    (* Load: retrieve stored value by index *)
    | ST.Load i -> (
        match List.nth state.store i with
        | Some v -> push v (advance state)
        | None -> advance state)
    (* Special terms *)
    | ST.VanishesOnZeroKnowledgeAndPreviousRows ->
        push env.vanishes_on_zero_knowledge_and_previous_rows (advance state)
    | ST.UnnormalizedLagrangeBasis (zk_rows, offset) ->
        push (env.unnormalized_lagrange_basis (zk_rows, offset)) (advance state)
    (* Conditional: SkipIfNot — if feature is NOT enabled, skip count tokens.
       Used for the true branch of IfFeature(feat, e1, e2):
         SkipIfNot(feat, len_e1) [e1 tokens] SkipIf(feat, len_e2) [e2 tokens]
       When enabled, e1 evaluates; when disabled, e1 is skipped. *)
    | ST.SkipIfNot (flag, count) ->
        let enabled = ref true in
        let _zero =
          env.if_feature
            ( convert_feature_flag flag
            , (fun () -> enabled := true ; env.field "0x0")
            , (fun () -> enabled := false ; env.field "0x0") )
        in
        if !enabled then advance state
        else { state with pos = state.pos + 1 + count }
    (* Conditional: SkipIf — if feature IS enabled, skip count tokens.
       Used for the false branch of IfFeature(feat, e1, e2):
         SkipIfNot(feat, len_e1) [e1 tokens] SkipIf(feat, len_e2) [e2 tokens]
       When enabled, e2 is skipped; when disabled, e2 evaluates. *)
    | ST.SkipIf (flag, count) ->
        let enabled = ref true in
        let _zero =
          env.if_feature
            ( convert_feature_flag flag
            , (fun () -> enabled := true ; env.field "0x0")
            , (fun () -> enabled := false ; env.field "0x0") )
        in
        if !enabled then { state with pos = state.pos + 1 + count }
        else advance state
  in
  let initial = { stack = []; store = []; pos = 0 } in
  let final_state = eval_loop tokens (Array.length tokens) initial in
  match final_state.stack with v :: _ -> v | [] -> env.field "0x0"

(* --- Drop-in replacements for Scalars.Tick and Scalars.Tock --- *)

module Tick : Scalars.S = struct
  let constant_term env = evaluate ST.Tick.constant_term_tokens env
end

module Tock : Scalars.S = struct
  let constant_term env = evaluate ST.Tock.constant_term_tokens env
end
