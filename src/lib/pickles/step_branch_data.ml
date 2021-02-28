open Core
open Pickles_types
open Hlist
open Common
open Import

(* The data obtained from "compiling" an inductive rule into a circuit. *)
type ( 'a_var
     , 'a_value
     , 'max_num_parents
     , 'num_rules
     , 'prev_vars
     , 'prev_values
     , 'local_widths
     , 'local_heights )
     t =
  | T :
      { branching: 'branching Nat.t * ('prev_vars, 'branching) Hlist.Length.t
      ; index: Types.Index.t
      ; lte: ('branching, 'max_num_parents) Nat.Lte.t
      ; domains: Domains.t
      ; rule:
          ( 'prev_vars
          , 'prev_values
          , 'local_widths
          , 'local_heights
          , 'a_avar
          , 'a_value )
          Inductive_rule.t
      ; main:
             step_domains:(Domains.t, 'num_rules) Vector.t
          -> ( (Unfinalized.t, 'max_num_parents) Vector.t
             , Impls.Step.Field.t
             , (Impls.Step.Field.t, 'max_num_parents) Vector.t )
             Types.Pairing_based.Statement.t
          -> unit
      ; requests:
          (module Requests.Step.S
             with type statement = 'a_value
              and type max_num_parents = 'max_num_parents
              and type prev_values = 'prev_values
              and type local_signature = 'local_widths
              and type local_branches = 'local_heights) }
      -> ( 'a_var
         , 'a_value
         , 'max_num_parents
         , 'num_rules
         , 'prev_vars
         , 'prev_values
         , 'local_widths
         , 'local_heights )
         t

(* Compile an inductive rule. *)
let create
    (type num_rules max_num_parents local_signature local_branches a_var
    a_value prev_vars prev_values) ~index
    ~(self : (a_var, a_value, max_num_parents, num_rules) Tag.t) ~wrap_domains
    ~(max_num_parents : max_num_parents Nat.t)
    ~(rules_num_parents : (int, num_rules) Vector.t)
    ~(num_rules : num_rules Nat.t) ~typ var_to_field_elements
    value_to_field_elements (rule : _ Inductive_rule.t) =
  Timer.clock __LOC__ ;
  let module HT = H4.T (Tag) in
  let (T (self_width, branching)) = HT.length rule.prevs in
  let rec extract_lengths : type a b n m k.
         (a, b, n, m) HT.t
      -> (a, k) Length.t
      -> n H1.T(Nat).t * m H1.T(Nat).t * (n, k) Length.t * (m, k) Length.t =
   fun ts len ->
    match (ts, len) with
    | [], Z ->
        ([], [], Z, Z)
    | t :: ts, S len -> (
        let ns, ms, len_ns, len_ms = extract_lengths ts len in
        match Type_equal.Id.same_witness self.id t.id with
        | Some T ->
            (max_num_parents :: ns, num_rules :: ms, S len_ns, S len_ms)
        | None ->
            let (module M), num_rules =
              match t.kind with
              | Compiled ->
                  let d = Types_map.lookup_compiled t.id in
                  (d.max_num_parents, d.num_rules)
              | Side_loaded ->
                  let d = Types_map.lookup_side_loaded t.id in
                  (d.permanent.max_num_parents, d.permanent.num_rules)
            in
            let T = M.eq in
            (M.n :: ns, num_rules :: ms, S len_ns, S len_ms) )
  in
  Timer.clock __LOC__ ;
  let widths, heights, local_signature_length, local_branches_length =
    extract_lengths rule.prevs branching
  in
  let lte = Nat.lte_exn self_width max_num_parents in
  let requests = Requests.Step.create () in
  Timer.clock __LOC__ ;
  let step ~step_domains =
    Step_main.step_main requests
      (Nat.Add.create max_num_parents)
      rule
      ~basic:
        { typ
        ; rules_num_parents
        ; var_to_field_elements
        ; value_to_field_elements
        ; wrap_domains
        ; step_domains }
      ~self_num_rules:num_rules ~branching ~local_signature:widths
      ~local_signature_length ~local_branches:heights ~local_branches_length
      ~lte ~self
    |> unstage
  in
  Timer.clock __LOC__ ;
  let own_domains =
    let main =
      step
        ~step_domains:
          (Vector.init num_rules ~f:(fun _ -> Fix_domains.rough_domains))
    in
    let etyp =
      Impls.Step.input ~num_parents:max_num_parents
        ~wrap_rounds:Backend.Tock.Rounds.n
    in
    Fix_domains.domains (module Impls.Step) etyp main
  in
  Timer.clock __LOC__ ;
  T
    { branching= (self_width, branching)
    ; index
    ; lte
    ; rule
    ; domains= own_domains
    ; main= step
    ; requests }
