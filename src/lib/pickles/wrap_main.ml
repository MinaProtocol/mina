open Core_kernel
open Pickles_types
open Hlist
open Common
open Import
open Types
open Wrap_main_inputs
open Impl
module SC = Scalar_challenge

(* Let's define an OCaml encoding for inductive NP sets. Let A be an inductive NP set.

   To encode A, we require types [var(A)] and [value(A)] corresponding to
   \mathcal{U}(A) the underlying set of A.

   Let r_1, ..., r_n be the inductive rules of A.
   For each i, let (A_{i, 1}, ..., A_{i, k_i}) be the predecessor inductive sets for rule i.

   We define a few type level lists.

   - For each rule r_i,
     [prev_vars(r_i) := var(A_{i, 1}) * (var(A_{i, 2}) * (... * var(A_{i, k_i})))]
     [prev_values(r_i) := value(A_{i, 1}) * (value(A_{i, 2}) * (... * value(A_{i, k_i})))]

   - [prev_varss(A) := map prev_vars (r_1, ..., r_n)]
   - [prev_valuess(A) := map prev_values (r_1, ..., r_n)]

   We use corresponding type variable names throughout this file.
*)

include Wrap_verifier.Make (struct
  include Wrap_main_inputs
  module Branching_pred = Nat.N0
end)

let check_wrap_domains ds =
  (* Assume all wraps have the same domain sizes *)
  let module I =
    H4.Iter
      (H4.T
         (E04
            (Domains)))
            (H4.Iter
               (E04
                  (Domains))
                  (struct
                    let f (d : Domains.t) =
                      let d' = Common.wrap_domains in
                      [%test_eq: Domain.t] d.h d'.h
                  end))
  in
  I.f ds

(* This function is kinda pointless since right now we're assuming all wrap domains
   are the same, but it will be useful when switch to the dlog-dlog system.

   The input is a list of Domains.t's [ ds_1; ...; ds_branches ].
   It pads each list with "dummy domains" to have length equal to Max_branching.n.
   Then it transposes that matrix.
*)
let pad_domains (type prev_varss prev_valuess branches n)
    (module Max_branching : Nat.Intf with type n = n)
    (pi_branches : (prev_varss, branches) Length.t)
    (prev_wrap_domains :
      (prev_varss, prev_valuess, _, _) H4.T(H4.T(E04(Domains))).t) =
  let module Ds = struct
    type t = (Domains.t, Max_branching.n) Vector.t
  end in
  let ds : (prev_varss, prev_valuess, _, _) H4.T(E04(Ds)).t =
    let dummy_domains =
      (* TODO: The dummy should really be equal to one of the already present domains. *)
      let d = Domain.Pow_2_roots_of_unity 1 in
      { Domains.h = d; x = d }
    in
    let module M =
      H4.Map
        (H4.T
           (E04
              (Domains)))
              (E04 (Ds))
              (struct
                module H = H4.T (E04 (Domains))

                let f : type a b c d. (a, b, c, d) H4.T(E04(Domains)).t -> Ds.t
                    =
                 fun domains ->
                  let (T (len, pi)) = H.length domains in
                  let module V = H4.To_vector (Domains) in
                  Vector.extend_exn (V.f pi domains) Max_branching.n
                    dummy_domains
              end)
    in
    M.f prev_wrap_domains
  in
  let ds =
    let module V = H4.To_vector (Ds) in
    V.f pi_branches ds
  in
  Vector.transpose ds

module Old_bulletproof_chals = struct
  type t =
    | T :
        'max_local_max_branching Nat.t
        * 'max_local_max_branching Challenges_vector.t
        -> t
end

let pack_statement max_branching t =
  with_label __LOC__ (fun () ->
      Spec.pack
        (module Impl)
        (Types.Step.Statement.spec max_branching Backend.Tock.Rounds.n)
        (Types.Step.Statement.to_data t))

let shifts ~log2_size =
  Common.tock_shifts ~log2_size |> Plonk_types.Shifts.map ~f:Impl.Field.constant

let domain_generator ~log2_size =
  Backend.Tock.Field.domain_generator ~log2_size |> Impl.Field.constant

let split_field_typ : (Field.t * Boolean.var, Field.Constant.t) Typ.t =
  Typ.transport
    Typ.(field * Boolean.typ)
    ~there:(fun (x : Field.Constant.t) ->
      let n = Bigint.of_field x in
      let is_odd = Bigint.test_bit n 0 in
      let y = Field.Constant.((if is_odd then x - one else x) / of_int 2) in
      (y, is_odd))
    ~back:(fun (hi, is_odd) ->
      let open Field.Constant in
      let x = hi + hi in
      if is_odd then x + one else x)

(* Split a field element into its high bits (packed) and the low bit.

   It does not check that the "high bits" actually fit into n - 1 bits,
   this is deferred to a call to scale_fast2, which performs this check.
*)
let split_field (x : Field.t) : Field.t * Boolean.var =
  let ((y, is_odd) as res) =
    exists
      Typ.(field * Boolean.typ)
      ~compute:(fun () ->
        let x = As_prover.read_var x in
        let n = Bigint.of_field x in
        let is_odd = Bigint.test_bit n 0 in
        let y = Field.Constant.((if is_odd then x - one else x) / of_int 2) in
        (y, is_odd))
  in
  Field.(Assert.equal ((of_int 2 * y) + (is_odd :> t)) x) ;
  res

(* The SNARK function for wrapping any proof coming from the given set of keys *)
let wrap_main
    (type max_branching branches prev_varss prev_valuess env
    max_local_max_branchings)
    (full_signature :
      (max_branching, branches, max_local_max_branchings) Full_signature.t)
    (pi_branches : (prev_varss, branches) Hlist.Length.t)
    (step_keys :
      (Wrap_main_inputs.Inner_curve.Constant.t index, branches) Vector.t Lazy.t)
    (step_widths : (int, branches) Vector.t)
    (step_domains : (Domains.t, branches) Vector.t)
    (prev_wrap_domains :
      (prev_varss, prev_valuess, _, _) H4.T(H4.T(E04(Domains))).t)
    (module Max_branching : Nat.Add.Intf with type n = max_branching) :
    (max_branching, max_local_max_branchings) Requests.Wrap.t
    * (   ( _
          , _
          , _ Shifted_value.Type1.t
          , _
          , _
          , _
          , _
          , _
          , _ )
          Types.Wrap.Statement.In_circuit.t
       -> unit) =
  Timer.clock __LOC__ ;
  let wrap_domains =
    check_wrap_domains prev_wrap_domains ;
    Common.wrap_domains
  in
  Timer.clock __LOC__ ;
  let T = Max_branching.eq in
  let branches = Hlist.Length.to_nat pi_branches in
  Timer.clock __LOC__ ;
  let (module Req) =
    Requests.Wrap.((create () : (max_branching, max_local_max_branchings) t))
  in
  Timer.clock __LOC__ ;
  let { Full_signature.padded; maxes = (module Max_widths_by_slot) } =
    full_signature
  in
  Timer.clock __LOC__ ;
  let main
      ({ proof_state =
           { deferred_values =
               { plonk
               ; xi
               ; combined_inner_product
               ; b
               ; which_branch
               ; bulletproof_challenges
               }
           ; sponge_digest_before_evaluations
           ; me_only = me_only_digest
           }
       ; pass_through
       } :
        ( _
        , _
        , _ Shifted_value.Type1.t
        , _
        , _
        , _
        , _
        , _
        , _ )
        Types.Wrap.Statement.In_circuit.t) =
    with_label __LOC__ (fun () ->
        let which_branch =
          One_hot_vector.of_index which_branch ~length:branches
        in
        let prev_proof_state =
          with_label __LOC__ (fun () ->
              let open Types.Step.Proof_state in
              let typ =
                typ
                  (module Impl)
                  Max_branching.n
                  (Shifted_value.Type2.typ Field.typ)
              in
              exists typ ~request:(fun () -> Req.Proof_state))
        in
        let step_plonk_index =
          with_label __LOC__ (fun () ->
              choose_key which_branch
                (Vector.map (Lazy.force step_keys)
                   ~f:(Plonk_verification_key_evals.map ~f:Inner_curve.constant)))
        in
        let prev_step_accs =
          with_label __LOC__ (fun () ->
              exists (Vector.typ Inner_curve.typ Max_branching.n)
                ~request:(fun () -> Req.Step_accs))
        in
        let old_bp_chals =
          with_label __LOC__ (fun () ->
              let typ =
                let module T =
                  H1.Typ (Impls.Wrap) (Nat) (Challenges_vector)
                    (Challenges_vector.Constant)
                    (struct
                      let f (type n) (n : n Nat.t) =
                        Vector.typ
                          (Vector.typ Field.typ Backend.Tock.Rounds.n)
                          n
                    end)
                in
                T.f Max_widths_by_slot.maxes
              in
              let module Z = H1.Zip (Nat) (Challenges_vector) in
              let module M =
                H1.Map
                  (H1.Tuple2 (Nat) (Challenges_vector))
                     (E01 (Old_bulletproof_chals))
                     (struct
                       let f (type n)
                           ((n, v) : n H1.Tuple2(Nat)(Challenges_vector).t) =
                         Old_bulletproof_chals.T (n, v)
                     end)
              in
              let module V = H1.To_vector (Old_bulletproof_chals) in
              Z.f Max_widths_by_slot.maxes
                (exists typ ~request:(fun () -> Req.Old_bulletproof_challenges))
              |> M.f
              |> V.f Max_widths_by_slot.length)
        in
        let domainses =
          with_label __LOC__ (fun () ->
              pad_domains (module Max_branching) pi_branches prev_wrap_domains)
        in
        let new_bulletproof_challenges =
          with_label __LOC__ (fun () ->
              let evals =
                let ty =
                  let ty =
                    Plonk_types.All_evals.typ
                      (Evaluation_lengths.create ~of_int:Fn.id)
                      Field.typ ~default:Field.Constant.zero
                  in
                  Vector.typ ty Max_branching.n
                in
                exists ty ~request:(fun () -> Req.Evals)
              in
              let chals =
                let ( (wrap_domains : (_, Max_branching.n) Vector.t)
                    , max_quot_sizes ) =
                  Vector.map domainses ~f:(fun ds ->
                      let h =
                        Plonk_checks.domain
                          (module Field)
                          ~shifts ~domain_generator wrap_domains.h
                      in
                      ( h
                      , ( which_branch
                        , Vector.map ds ~f:(fun d ->
                              Common.max_quot_size_int (Domain.size d.h)) ) ))
                  |> Vector.unzip
                in
                let actual_branchings =
                  padded
                  |> Vector.map ~f:(fun branchings_in_slot ->
                         Pseudo.choose
                           (which_branch, branchings_in_slot)
                           ~f:Field.of_int)
                in
                Vector.mapn
                  [ (* This is padded to max_branching for the benefit of wrapping with dummy unfinalized proofs *)
                    prev_proof_state.unfinalized_proofs
                  ; old_bp_chals
                  ; actual_branchings
                  ; evals
                  ; wrap_domains
                  ; max_quot_sizes
                  ]
                  ~f:(fun
                       [ { deferred_values
                         ; sponge_digest_before_evaluations
                         ; should_finalize
                         }
                       ; old_bulletproof_challenges
                       ; actual_branching
                       ; evals
                       ; domain
                       ; max_quot_size
                       ]
                     ->
                    let sponge =
                      let s = Sponge.create sponge_params in
                      Sponge.absorb s sponge_digest_before_evaluations ;
                      s
                    in

                    (* the type of the local max branching depends on
                       which kind of step proof we are wrapping. *)
                    (* For each i in [0..max_branching-1], we have
                       Max_local_max_branching, which is the largest
                       Local_max_branching which is the i^th inner proof of a step proof.

                       Need to compute this value from the which_branch.
                    *)
                    let (T
                          (max_local_max_branching, old_bulletproof_challenges))
                        =
                      old_bulletproof_challenges
                    in
                    let finalized, chals =
                      with_label __LOC__ (fun () ->
                          finalize_other_proof
                            (Nat.Add.create max_local_max_branching)
                            ~max_quot_size ~actual_branching
                            ~domain:(domain :> _ Plonk_checks.plonk_domain)
                            ~sponge ~old_bulletproof_challenges deferred_values
                            evals)
                    in
                    Boolean.(Assert.any [ finalized; not should_finalize ]) ;
                    chals)
              in
              chals)
        in
        let prev_statement =
          let prev_me_onlys =
            Vector.map2 prev_step_accs old_bp_chals
              ~f:(fun sacc (T (max_local_max_branching, chals)) ->
                (* This is a hack. Assuming that the max number of recursive verifications for
                     every rule is exactly 2 simplified the implementation. In the future we
                     will have to fix this. *)
                let T = Nat.eq_exn max_local_max_branching Max_branching.n in
                hash_me_only Max_branching.n
                  { sg = sacc; old_bulletproof_challenges = chals })
          in
          { Types.Step.Statement.pass_through = prev_me_onlys
          ; proof_state = prev_proof_state
          }
        in
        let openings_proof =
          let shift = Shifts.tick1 in
          exists
            (Plonk_types.Openings.Bulletproof.typ
               ( Typ.transport Other_field.Packed.typ
                   ~there:(fun x ->
                     (* When storing, make it a shifted value *)
                     match
                       Shifted_value.Type1.of_field
                         (module Backend.Tick.Field)
                         ~shift x
                     with
                     | Shifted_value x ->
                         x)
                   ~back:(fun x ->
                     Shifted_value.Type1.to_field
                       (module Backend.Tick.Field)
                       ~shift (Shifted_value x))
               (* When reading, unshift *)
               |> Typ.transport_var
                  (* For the var, we just wrap the now shifted underlying value. *)
                    ~there:(fun (Shifted_value.Type1.Shifted_value x) -> x)
                    ~back:(fun x -> Shifted_value x) )
               Inner_curve.typ
               ~length:(Nat.to_int Backend.Tick.Rounds.n))
            ~request:(fun () -> Req.Openings_proof)
        in
        let ( sponge_digest_before_evaluations_actual
            , (`Success bulletproof_success, bulletproof_challenges_actual) ) =
          let messages =
            with_label __LOC__ (fun () ->
                exists
                  (Plonk_types.Messages.typ ~dummy:Inner_curve.Params.one
                     Inner_curve.typ ~bool:Boolean.typ
                     ~commitment_lengths:
                       (Commitment_lengths.create ~of_int:Fn.id))
                  ~request:(fun () -> Req.Messages))
          in
          let sponge = Opt.create sponge_params in
          with_label __LOC__ (fun () ->
              incrementally_verify_proof
                (module Max_branching)
                ~step_widths ~step_domains ~verification_key:step_plonk_index
                ~xi ~sponge
                ~public_input:
                  (Array.map (pack_statement Max_branching.n prev_statement)
                     ~f:(function
                    | `Field (Shifted_value x) ->
                        `Field (split_field x)
                    | `Packed_bits (x, n) ->
                        `Packed_bits (x, n)))
                ~sg_old:prev_step_accs ~combined_inner_product ~advice:{ b }
                ~messages ~which_branch ~openings_proof ~plonk)
        in
        with_label __LOC__ (fun () ->
            Boolean.Assert.is_true bulletproof_success) ;
        with_label __LOC__ (fun () ->
            Field.Assert.equal me_only_digest
              (hash_me_only Max_branching.n
                 { Types.Wrap.Proof_state.Me_only.sg = openings_proof.sg
                 ; old_bulletproof_challenges = new_bulletproof_challenges
                 })) ;
        with_label __LOC__ (fun () ->
            Field.Assert.equal sponge_digest_before_evaluations
              sponge_digest_before_evaluations_actual) ;
        Array.iter2_exn bulletproof_challenges_actual
          (Vector.to_array bulletproof_challenges)
          ~f:(fun
               { prechallenge = { inner = x1 } }
               ({ prechallenge = { inner = x2 } } :
                 _ SC.t Bulletproof_challenge.t)
             -> with_label __LOC__ (fun () -> Field.Assert.equal x1 x2)) ;
        ())
  in
  Timer.clock __LOC__ ;
  ((module Req), main)
