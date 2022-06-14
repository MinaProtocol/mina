open Core_kernel
open Pickles_types
open Hlist
open Common
open Import

(* The data obtained from "compiling" an inductive rule into a circuit. *)
type ( 'a_var
     , 'a_value
     , 'max_proofs_verified
     , 'branches
     , 'prev_vars
     , 'prev_values
     , 'prev_ret_vars
     , 'prev_ret_values
     , 'local_widths
     , 'local_heights )
     t =
  | T :
      { proofs_verified :
          'proofs_verified Nat.t * ('prev_vars, 'proofs_verified) Hlist.Length.t
      ; index : int
      ; lte : ('proofs_verified, 'max_proofs_verified) Nat.Lte.t
      ; domains : Domains.t
      ; rule :
          ( 'prev_vars
          , 'prev_values
          , 'prev_ret_vars
          , 'prev_ret_values
          , 'local_widths
          , 'local_heights
          , 'a_avar
          , 'a_value )
          Inductive_rule.t
      ; main :
             step_domains:(Domains.t, 'branches) Vector.t
          -> unit
          -> ( (Unfinalized.t, 'max_proofs_verified) Vector.t
             , Impls.Step.Field.t
             , (Impls.Step.Field.t, 'max_proofs_verified) Vector.t )
             Types.Step.Statement.t
      ; requests :
          (module Requests.Step.S
             with type statement = 'a_value
              and type max_proofs_verified = 'max_proofs_verified
              and type prev_values = 'prev_values
              and type prev_ret_values = 'prev_ret_values
              and type local_signature = 'local_widths
              and type local_branches = 'local_heights )
      }
      -> ( 'a_var
         , 'a_value
         , 'max_proofs_verified
         , 'branches
         , 'prev_vars
         , 'prev_values
         , 'prev_ret_vars
         , 'prev_ret_values
         , 'local_widths
         , 'local_heights )
         t

(* Compile an inductive rule. *)
let create
    (type branches max_proofs_verified local_signature local_branches a_var
    a_value ret_var ret_value prev_vars prev_values ) ~index
    ~(self :
       (a_var, a_value, ret_var, ret_value, max_proofs_verified, branches) Tag.t
       ) ~wrap_domains ~(max_proofs_verified : max_proofs_verified Nat.t)
    ~(proofs_verifieds : (int, branches) Vector.t) ~(branches : branches Nat.t)
    ~typ var_to_field_elements value_to_field_elements
    (rule : _ Inductive_rule.t) =
  Timer.clock __LOC__ ;
  let module HT = H6.T (Tag) in
  let (T (self_width, proofs_verified)) = HT.length rule.prevs in
  let rec extract_lengths :
      type a b c d n m k.
         (a, b, c, d, n, m) HT.t
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
            (max_proofs_verified :: ns, branches :: ms, S len_ns, S len_ms)
        | None ->
            let (module M), branches =
              match t.kind with
              | Compiled ->
                  let d = Types_map.lookup_compiled t.id in
                  (d.max_proofs_verified, d.branches)
              | Side_loaded ->
                  let d = Types_map.lookup_side_loaded t.id in
                  (d.permanent.max_proofs_verified, d.permanent.branches)
            in
            let T = M.eq in
            (M.n :: ns, branches :: ms, S len_ns, S len_ms) )
  in
  Timer.clock __LOC__ ;
  let widths, heights, local_signature_length, local_branches_length =
    extract_lengths rule.prevs proofs_verified
  in
  let lte = Nat.lte_exn self_width max_proofs_verified in
  let requests = Requests.Step.create () in
  Timer.clock __LOC__ ;
  let step ~step_domains =
    Step_main.step_main requests
      (Nat.Add.create max_proofs_verified)
      rule
      ~basic:
        { typ
        ; proofs_verifieds
        ; var_to_field_elements
        ; value_to_field_elements
        ; wrap_domains
        ; step_domains
        }
      ~self_branches:branches ~proofs_verified ~local_signature:widths
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
      Impls.Step.input ~proofs_verified:max_proofs_verified
        ~wrap_rounds:Backend.Tock.Rounds.n
    in
    Fix_domains.domains
      (module Impls.Step)
      (T (Snarky_backendless.Typ.unit (), Fn.id, Fn.id))
      etyp main
  in
  Timer.clock __LOC__ ;
  T
    { proofs_verified = (self_width, proofs_verified)
    ; index
    ; lte
    ; rule
    ; domains = own_domains
    ; main = step
    ; requests
    }
