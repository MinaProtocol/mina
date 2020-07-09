open Core
open Pickles_types
open Hlist
open Common
open Import
open Types
open Wrap_main_inputs
open Impl

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

include Dlog_main.Make (struct
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
                      [%test_eq: Domain.t * Domain.t] (d.h, d.k) (d'.h, d'.k)
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
      {Domains.h= d; k= d; x= d}
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

let pack_statement max_branching =
  let pack_fq (x : Field.t) =
    let low_bits, high_bit =
      Util.split_last
        (Bitstring_lib.Bitstring.Lsb_first.to_list (Field.unpack_full x))
    in
    [|low_bits; [high_bit]|]
  in
  fun t ->
    Spec.pack
      (module Impl)
      pack_fq
      (Types.Pairing_based.Statement.spec max_branching Backend.Tock.Rounds.n)
      (Types.Pairing_based.Statement.to_data t)

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
    * ((_, _, _, _, _, _, _, _, _, _) Types.Dlog_based.Statement.t -> unit) =
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
  let {Full_signature.padded; maxes= (module Max_widths_by_slot)} =
    full_signature
  in
  Timer.clock __LOC__ ;
  let main
      ({ proof_state=
           { deferred_values=
               { marlin
               ; xi
               ; (* TODO:remove r; *) combined_inner_product
               ; b
               ; which_branch
               ; bulletproof_challenges
                   (* TODO: MUST ASSERT EQUALITY WITH ACTUAL *) }
           ; sponge_digest_before_evaluations
           ; me_only= me_only_digest
           ; was_base_case }
       ; pass_through } :
        _ Types.Dlog_based.Statement.t) =
    let which_branch = One_hot_vector.of_index which_branch ~length:branches in
    let prev_proof_state =
      let open Types.Pairing_based.Proof_state in
      let typ = typ (module Impl) Max_branching.n Field.typ in
      exists typ ~request:(fun () -> Req.Proof_state)
    in
    let pairing_marlin_index =
      choose_key which_branch
        (Vector.map (Lazy.force step_keys)
           ~f:
             (Matrix_evals.map
                ~f:(Abc.map ~f:(Array.map ~f:Inner_curve.constant))))
    in
    let prev_step_accs =
      exists (Vector.typ Inner_curve.typ Max_branching.n) ~request:(fun () ->
          Req.Step_accs )
    in
    let old_bp_chals =
      let typ =
        let module T =
          H1.Typ (Impls.Wrap) (Nat) (Challenges_vector)
            (Challenges_vector.Constant)
            (struct
              let f (type n) (n : n Nat.t) =
                Vector.typ (Vector.typ Field.typ Backend.Tock.Rounds.n) n
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
               let f (type n) ((n, v) : n H1.Tuple2(Nat)(Challenges_vector).t)
                   =
                 Old_bulletproof_chals.T (n, v)
             end)
      in
      let module V = H1.To_vector (Old_bulletproof_chals) in
      Z.f Max_widths_by_slot.maxes
        (exists typ ~request:(fun () -> Req.Old_bulletproof_challenges))
      |> M.f
      |> V.f Max_widths_by_slot.length
    in
    let domainses =
      pad_domains (module Max_branching) pi_branches prev_wrap_domains
    in
    let eval_lengths =
      Vector.map domainses ~f:(fun v ->
          Commitment_lengths.generic Vector.map
            ~h:(Vector.map v ~f:(fun {h; _} -> Domain.size h))
            ~k:(Vector.map v ~f:(fun {k; _} -> Domain.size k)) )
    in
    let new_bulletproof_challenges =
      let evals =
        let ty =
          let ty =
            Typ.tuple2
              (Dlog_marlin_types.Evals.typ ~default:Field.Constant.zero
                 (Commitment_lengths.of_domains wrap_domains
                    ~max_degree:Max_degree.wrap)
                 Field.typ)
              Field.typ
          in
          Vector.typ (Typ.tuple3 ty ty ty) Max_branching.n
        in
        exists ty ~request:(fun () -> Req.Evals)
      in
      let chals =
        let (wrap_domains : (_, Max_branching.n) Vector.t), hk_minus_1s =
          Vector.map domainses ~f:(fun ds ->
              ( Vector.map
                  Domains.[h; k; x]
                  ~f:(fun f ->
                    Pseudo.Domain.to_domain (which_branch, Vector.map ds ~f) )
              , ( ( which_branch
                  , Vector.map ds ~f:(fun d -> Domain.size d.h - 1) )
                , ( which_branch
                  , Vector.map ds ~f:(fun d -> Domain.size d.k - 1) ) ) ) )
          |> Vector.unzip
        in
        let actual_branchings =
          padded
          |> Vector.map ~f:(fun branchings_in_slot ->
                 Pseudo.choose
                   (which_branch, branchings_in_slot)
                   ~f:Field.of_int )
        in
        Vector.mapn
          [ (* This is padded to max_branching for the benefit of wrapping with dummy unfinalized proofs *)
            prev_proof_state.unfinalized_proofs
          ; old_bp_chals
          ; actual_branchings
          ; evals
          ; eval_lengths
          ; wrap_domains
          ; hk_minus_1s ]
          ~f:(fun [ ( {deferred_values; sponge_digest_before_evaluations}
                    , should_verify )
                  ; old_bulletproof_challenges
                  ; actual_branching
                  ; evals
                  ; eval_lengths
                  ; [domain_h; domain_k; input_domain]
                  ; (h_minus_1, k_minus_1) ]
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
            (* One way to fix this is to reverse the order of the summation and
               to mask out the sg_poly evaluations that aren't supposed to be there.

               Actually no need to reverse the order... just need to make sure to
               append the dummies to the LHS instead of the RHS.
            *)
            let (T (max_local_max_branching, old_bulletproof_challenges)) =
              old_bulletproof_challenges
            in
            let verified, chals =
              finalize_other_proof
                (Nat.Add.create max_local_max_branching)
                ~actual_branching ~h_minus_1 ~k_minus_1 ~input_domain ~domain_k
                ~domain_h ~sponge deferred_values ~old_bulletproof_challenges
                evals
            in
            Boolean.(Assert.any [not should_verify; verified]) ;
            chals )
      in
      chals
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
              {sg= sacc; old_bulletproof_challenges= chals} )
      in
      { Types.Pairing_based.Statement.pass_through= prev_me_onlys
      ; proof_state= prev_proof_state }
    in
    let openings_proof =
      exists
        (Dlog_marlin_types.Openings.Bulletproof.typ Other_field.Packed.typ
           Inner_curve.typ
           ~length:(Nat.to_int Backend.Tick.Rounds.n))
        ~request:(fun () -> Req.Openings_proof)
    in
    let ( sponge_digest_before_evaluations_actual
        , (`Success bulletproof_success, bulletproof_challenges_actual)
        , marlin_actual ) =
      let messages =
        exists
          (Dlog_marlin_types.Messages.typ ~dummy:Inner_curve.Params.one
             Other_field.Packed.typ Inner_curve.typ
             ~commitment_lengths:
               (let open Vector in
               Commitment_lengths.generic map ~max_degree:Max_degree.step
                 ~h:
                   (Vector.map step_domains
                      ~f:(Fn.compose Domain.size Domains.h))
                 ~k:
                   (Vector.map step_domains
                      ~f:(Fn.compose Domain.size Domains.k))))
          ~request:(fun () -> Req.Messages)
      in
      let sponge = Opt.create sponge_params in
      let xi =
        Pickles_types.Scalar_challenge.map xi
          ~f:(Field.unpack ~length:Challenge.length)
      in
      incrementally_verify_proof
        (module Max_branching)
        ~step_widths ~step_domains ~verification_key:pairing_marlin_index ~xi
        ~sponge
        ~public_input:
          (Array.append
             [|[Boolean.true_]|]
             (pack_statement Max_branching.n prev_statement))
        ~sg_old:prev_step_accs ~combined_inner_product ~advice:{b} ~messages
        ~which_branch ~openings_proof
      (*
      incrementally_verify_pairings ~step_domains ~pairing_acc:prev_pairing_acc
        ~xi ~r ~r_xi_sum ~verification_key:pairing_marlin_index ~sponge
        ~public_input:
          (Array.append
             [|[Boolean.true_]|]
             (pack_statement Max_branching.n prev_statement))
        ~messages ~opening_proofs *)
    in
    Boolean.Assert.is_true bulletproof_success ;
    assert_eq_marlin marlin marlin_actual ;
    Field.Assert.equal me_only_digest
      (hash_me_only Max_branching.n
         { Types.Dlog_based.Proof_state.Me_only.sg= openings_proof.sg
         ; old_bulletproof_challenges= new_bulletproof_challenges }) ;
    Field.Assert.equal sponge_digest_before_evaluations
      sponge_digest_before_evaluations_actual ;
    ()
  in
  Timer.clock __LOC__ ;
  ((module Req), main)
