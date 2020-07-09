open Core
open Pickles_types
open Hlist
open Common
open Import

(* The data obtained from "compiling" an inductive rule into a circuit. *)
type ( 'a_var
     , 'a_value
     , 'max_branching
     , 'branches
     , 'prev_vars
     , 'prev_values
     , 'local_widths
     , 'local_heights )
     t =
  | T :
      { branching: 'branching Nat.t * ('prev_vars, 'branching) Hlist.Length.t
      ; index: Types.Index.t
      ; lte: ('branching, 'max_branching) Nat.Lte.t
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
             step_domains:(Domains.t, 'branches) Vector.t
          -> ( (Unfinalized.t, 'max_branching) Vector.t
             , Impls.Step.Field.t
             , (Impls.Step.Field.t, 'max_branching) Vector.t )
             Types.Pairing_based.Statement.t
          -> unit
      ; requests:
          (module Requests.Step.S
             with type statement = 'a_value
              and type max_branching = 'max_branching
              and type prev_values = 'prev_values
              and type local_signature = 'local_widths
              and type local_branches = 'local_heights) }
      -> ( 'a_var
         , 'a_value
         , 'max_branching
         , 'branches
         , 'prev_vars
         , 'prev_values
         , 'local_widths
         , 'local_heights )
         t

(* Compile an inductive rule. *)
let create
    (type branches max_branching local_signature local_branches a_var a_value
    prev_vars prev_values) ~index
    ~(self : (a_var, a_value, max_branching, branches) Tag.t) ~wrap_domains
    ~(max_branching : max_branching Nat.t)
    ~(branchings : (int, branches) Vector.t) ~(branches : branches Nat.t) ~typ
    a_var_to_field_elements a_value_to_field_elements
    (rule : _ Inductive_rule.t) =
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
        match Type_equal.Id.same_witness self t with
        | Some T ->
            (max_branching :: ns, branches :: ms, S len_ns, S len_ms)
        | None ->
            let d = Types_map.lookup t in
            let (module M) = d.max_branching in
            let T = M.eq in
            (M.n :: ns, d.branches :: ms, S len_ns, S len_ms) )
  in
  Timer.clock __LOC__ ;
  let widths, heights, local_signature_length, local_branches_length =
    extract_lengths rule.prevs branching
  in
  let lte = Nat.lte_exn self_width max_branching in
  let requests = Requests.Step.create () in
  Timer.clock __LOC__ ;
  let step ~step_domains =
    Step_main.step_main requests
      (Nat.Add.create max_branching)
      rule
      ~basic:
        { typ
        ; branchings
        ; a_var_to_field_elements
        ; a_value_to_field_elements
        ; wrap_domains
        ; step_domains }
      ~self_branches:branches ~branching ~local_signature:widths
      ~local_signature_length ~local_branches:heights ~local_branches_length
      ~lte ~self
    |> unstage
  in
  Timer.clock __LOC__ ;
  let own_domains =
    let main =
      step
        ~step_domains:
          (Vector.init branches ~f:(fun _ -> Fix_domains.rough_domains))
    in
    let etyp =
      Impls.Step.input ~branching:max_branching
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
