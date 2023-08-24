open Core_kernel
open Pickles_types
open Hlist
open Import

(* The data obtained from "compiling" an inductive rule into a circuit. *)
type ( 'a_var
     , 'a_value
     , 'ret_var
     , 'ret_value
     , 'auxiliary_var
     , 'auxiliary_value
     , 'max_proofs_verified
     , 'branches
     , 'prev_vars
     , 'prev_values
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
          , 'local_widths
          , 'local_heights
          , 'a_var
          , 'a_value
          , 'ret_var
          , 'ret_value
          , 'auxiliary_var
          , 'auxiliary_value )
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
              and type proofs_verified = 'proofs_verified
              and type prev_values = 'prev_values
              and type local_signature = 'local_widths
              and type local_branches = 'local_heights
              and type return_value = 'ret_value
              and type auxiliary_value = 'auxiliary_value )
      ; feature_flags : bool Plonk_types.Features.t
      }
      -> ( 'a_var
         , 'a_value
         , 'ret_var
         , 'ret_value
         , 'auxiliary_var
         , 'auxiliary_value
         , 'max_proofs_verified
         , 'branches
         , 'prev_vars
         , 'prev_values
         , 'local_widths
         , 'local_heights )
         t

(* Compile an inductive rule. *)
let create
    (type branches max_proofs_verified var value a_var a_value ret_var ret_value)
    ~index ~(self : (var, value, max_proofs_verified, branches) Tag.t)
    ~wrap_domains
    ~(feature_flags : Plonk_types.Opt.Flag.t Plonk_types.Features.t)
    ~(actual_feature_flags : bool Plonk_types.Features.t)
    ~(max_proofs_verified : max_proofs_verified Nat.t)
    ~(proofs_verifieds : (int, branches) Vector.t) ~(branches : branches Nat.t)
    ~(public_input :
       ( var
       , value
       , a_var
       , a_value
       , ret_var
       , ret_value )
       Inductive_rule.public_input ) ~auxiliary_typ _var_to_field_elements
    _value_to_field_elements (rule : _ Inductive_rule.t) =
  Timer.clock __LOC__ ;
  let module HT = H4.T (Tag) in
  let (T (self_width, proofs_verified)) = HT.length rule.prevs in
  let rec extract_lengths :
      type a b n m k.
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
  let (typ : (var, value) Impls.Step.Typ.t) =
    match public_input with
    | Input typ ->
        typ
    | Output typ ->
        typ
    | Input_and_output (input_typ, output_typ) ->
        Impls.Step.Typ.(input_typ * output_typ)
  in
  Timer.clock __LOC__ ;
  let step ~step_domains =
    Step_main.step_main requests
      (Nat.Add.create max_proofs_verified)
      rule
      ~basic:
        { public_input = typ
        ; proofs_verifieds
        ; wrap_domains
        ; step_domains
        ; feature_flags
        }
      ~public_input ~auxiliary_typ ~self_branches:branches ~proofs_verified
      ~local_signature:widths ~local_signature_length ~local_branches:heights
      ~local_branches_length ~lte ~self
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
      (* TODO *)
    in
    let lookup_table_length_log2 =
      let { Plonk_types.Features.range_check0
          ; range_check1
          ; foreign_field_add = _
          ; foreign_field_mul
          ; xor
          ; rot
          ; lookup
          ; runtime_tables
          } =
        actual_feature_flags
      in
      let total_length =
        ( if range_check0 || range_check1 || foreign_field_mul || rot then
          Int.pow 2 12
        else 0 )
        + (if xor then 3 else Int.pow 2 8)
        + (if lookup then 0 (* TODO: Need more info. *) else 0)
        + if runtime_tables then 0 (* TODO: Need more info. *) else 0
      in
      let zk_rows = 3 in
      Int.ceil_log2 (total_length + zk_rows + 1)
    in
    Fix_domains.domains ~min_log2:lookup_table_length_log2
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
    ; feature_flags = actual_feature_flags
    }
