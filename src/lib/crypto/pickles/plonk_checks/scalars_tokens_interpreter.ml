(* Stack-based interpreter for Polish notation linearization polynomials.
   This replaces the large tree-walking constant_term functions in scalars.ml
   with a compact interpreter that evaluates the token arrays from
   scalars_tokens.ml. *)

module ST = Scalars_tokens

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
    (* Peephole: Challenge Alpha is always followed by Pow n in the
       generated token streams (Rust's to_polish only emits Alpha as
       part of Expr::Pow(alpha, n)). The fallback to alpha_pow 1 is
       defensive and never fires in practice. *)
    | ST.Challenge ST.Alpha ->
        if state.pos + 1 < tok_len then (
          match toks.(state.pos + 1) with
          | ST.Pow k -> push (env.alpha_pow k) { state with pos = state.pos + 2 }
          | _ -> push (env.alpha_pow 1) (advance state))
        else push (env.alpha_pow 1) (advance state)
    | ST.Challenge ST.Beta -> push env.beta (advance state)
    | ST.Challenge ST.Gamma -> push env.gamma (advance state)
    | ST.Challenge ST.JointCombiner -> push env.joint_combiner (advance state)
    (* Cell access *)
    | ST.Cell (col, row) -> push (env.cell (env.var (col, row))) (advance state)
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
    (* Conditional: IfFeature is encoded as a pair:
         SkipIfNot(flag, len_e1) [e1 tokens] SkipIf(flag, len_e2) [e2 tokens]
       We evaluate both branches as bounded sub-sequences, extract their
       top-of-stack values, and let env.if_feature select the result.
       This works correctly with Maybe feature flags: when the flag is
       Some bool_var, F.if_ creates an in-circuit conditional over both
       branch values. When concrete (None = disabled), only the false
       branch thunk is called; when Some(true), both are called and
       F.if_ selects the true-branch value. *)
    | ST.SkipIfNot (flag, count_true) ->
        let true_end = state.pos + 1 + count_true in
        let count_false =
          match toks.(true_end) with
          | ST.SkipIf (_, c) -> c
          | _ -> failwith "SkipIfNot: expected matching SkipIf"
        in
        let false_end = true_end + 1 + count_false in
        let zero = "0x0000000000000000000000000000000000000000000000000000000000000000" in
        let extract_top s =
          match s.stack with v :: _ -> v | [] -> env.field zero
        in
        let result =
          env.if_feature
            ( flag
            , (fun () ->
                let s = eval_loop toks true_end { state with pos = state.pos + 1 } in
                extract_top s)
            , (fun () ->
                let s = eval_loop toks false_end { state with pos = true_end + 1 } in
                extract_top s) )
        in
        push result { state with pos = false_end }
    (* SkipIf is consumed by the SkipIfNot handler above. If we reach here,
       it means the token stream has a standalone SkipIf, which shouldn't
       happen in well-formed output from to_polish(). *)
    | ST.SkipIf (_, count) ->
        { state with pos = state.pos + 1 + count }
  in
  let initial = { stack = []; store = []; pos = 0 } in
  let final_state = eval_loop tokens (Array.length tokens) initial in
  match final_state.stack with v :: _ -> v | [] -> env.field "0x0000000000000000000000000000000000000000000000000000000000000000"

(* --- Drop-in replacements for Scalars.Tick and Scalars.Tock --- *)

module Tick : Scalars.S = struct
  let constant_term env = evaluate ST.Tick.constant_term_tokens env
end

module Tock : Scalars.S = struct
  let constant_term env = evaluate ST.Tock.constant_term_tokens env
end
