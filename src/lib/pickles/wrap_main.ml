open Core
open Pickles_types
open Hlist
open Common
open Import
open Types

module Dmain = Dlog_main.Make (struct
  include Dlog_main_inputs
  module Bulletproof_rounds = Rounds

  let crs_max_degree = crs_max_degree

  module Branching_pred = Nat.N0
end)

module Pseudo_dlog = Pseudo.Make (Impls.Dlog_based)

(* The SNARK function for wrapping any proof coming from the given set of keys *)
let wrap_main
    (type max_branching branches prev_varss prev_valuess env
    max_local_max_branchings)
    (full_signature :
      (max_branching, branches, max_local_max_branchings) Full_signature.t)
    (pi_branches : (prev_varss, branches) Hlist.Length.t)
    (step_keys :
      (Dlog_main_inputs.G1.Constant.t Abc.t Matrix_evals.t, branches) Vector.t
      Lazy.t) (step_domains : (Domains.t, branches) Vector.t)
    (prev_wrap_domains :
      (prev_varss, prev_valuess, _, _) H4.T(H4.T(E04(Domains))).t)
    (module Max_branching : Nat.Add.Intf with type n = max_branching) :
    (max_branching, max_local_max_branchings) Requests.Wrap.t * 'a =
  let wrap_domains =
    let r = ref None in
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
                        match !r with
                        | None ->
                            r := Some d
                        | Some d' ->
                            assert (Domain.equal d.h d'.h) ;
                            assert (Domain.equal d.k d'.k)
                    end))
    in
    I.f prev_wrap_domains ; Option.value_exn !r
  in
  let module Pseudo = Pseudo_dlog in
  let T = Max_branching.eq in
  let branches = Hlist.Length.to_nat pi_branches in
  let open Impls.Dlog_based in
  let (module Req) =
    Requests.Wrap.((create () : (max_branching, max_local_max_branchings) t))
  in
  let {Full_signature.padded; maxes= (module Max_widths_by_slot)} =
    full_signature
  in
  let main
      ({ proof_state=
           { deferred_values= {marlin; xi; r; r_xi_sum}
           ; sponge_digest_before_evaluations
           ; me_only= me_only_digest
           ; was_base_case }
       ; pass_through } :
        _ Types.Dlog_based.Statement.t) =
    let open Dlog_main_inputs in
    let open Dmain in
    let prev_proof_state =
      let open Types.Pairing_based.Proof_state in
      let typ = typ (module Impl) Max_branching.n Rounds.n Fq.typ in
      exists typ ~request:(fun () -> Req.Proof_state)
    in
    let which_branch =
      exists (One_hot_vector.typ branches) ~request:(fun () -> Req.Index)
    in
    let pairing_marlin_index =
      choose_key which_branch
        (Vector.map (Lazy.force step_keys)
           ~f:(Matrix_evals.map ~f:(Abc.map ~f:G1.constant)))
    in
    let prev_pairing_accs =
      exists (Vector.typ Pairing_acc.typ Max_branching.n) ~request:(fun () ->
          Req.Pairing_accs )
    in
    let module Old_bulletproof_chals = struct
      type t =
        | T :
            'max_local_max_branching Nat.t
            * 'max_local_max_branching Challenges_vector.t
            -> t
    end in
    let old_bp_chals =
      let typ =
        let module T =
          H1.Typ (Impls.Dlog_based) (Nat) (Challenges_vector)
            (Challenges_vector.Constant)
            (struct
              let f (type n) (n : n Nat.t) =
                Vector.typ (Vector.typ Field.typ Rounds.n) n
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
    let prev_pairing_acc = combine_pairing_accs prev_pairing_accs in
    let domainses =
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

                    let f : type a b c d.
                        (a, b, c, d) H4.T(E04(Domains)).t -> Ds.t =
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
              (Dlog_marlin_types.Evals.typ
                 (Commitment_lengths.of_domains wrap_domains)
                 Fq.typ)
              Fq.typ
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
          [ prev_proof_state.unfinalized_proofs
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
              Sponge.absorb s (Fq.pack sponge_digest_before_evaluations) ;
              s
            in
            (* the type of the local max branching depends on
               which kind of step proof we are wrapping :/ *)
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
      (* TODO: A lot of repeated hashing happening here on the dlog_marlin_index *)
      let prev_me_onlys =
        Vector.map2 prev_pairing_accs old_bp_chals
          ~f:(fun pacc (T (max_local_max_branching, chals)) ->
            let T = Nat.eq_exn max_local_max_branching Nat.N2.n in
            (* This is a bit problematic because of the divergence from max_branching.
               Need to mask out the irrelevant chals. *)
            hash_me_only
              {pairing_marlin_acc= pacc; old_bulletproof_challenges= chals} )
      in
      { Types.Pairing_based.Statement.pass_through= prev_me_onlys
      ; proof_state= prev_proof_state }
    in
    let ( sponge_digest_before_evaluations_actual
        , pairing_marlin_acc
        , marlin_actual ) =
      let messages =
        exists (Pairing_marlin_types.Messages.typ PC.typ Fp.Packed.typ)
          ~request:(fun () -> Req.Messages)
      in
      let opening_proofs =
        exists (Typ.tuple3 G1.typ G1.typ G1.typ) ~request:(fun () ->
            Req.Openings_proof )
      in
      let sponge = Sponge.create sponge_params in
      let pack =
        let pack_fq (x : Fq.t) =
          let low_bits, high_bit =
            Util.split_last
              (Bitstring_lib.Bitstring.Lsb_first.to_list (Fq.unpack_full x))
          in
          [|low_bits; [high_bit]|]
        in
        fun t ->
          Spec.pack
            (module Impl)
            pack_fq
            (Types.Pairing_based.Statement.spec Max_branching.n Rounds.n)
            (Types.Pairing_based.Statement.to_data t)
      in
      let xi =
        Pickles_types.Scalar_challenge.map xi
          ~f:(Field.unpack ~length:Challenge.length)
      in
      let r =
        Pickles_types.Scalar_challenge.map r
          ~f:(Field.unpack ~length:Challenge.length)
      in
      let r_xi_sum =
        Field.choose_preimage_var r_xi_sum ~length:Field.size_in_bits
      in
      let step_domains =
        ( Pseudo.Domain.to_domain
            (which_branch, Vector.map ~f:Domains.h step_domains)
        , Pseudo.Domain.to_domain
            (which_branch, Vector.map ~f:Domains.k step_domains) )
      in
      incrementally_verify_pairings ~step_domains ~pairing_acc:prev_pairing_acc
        ~xi ~r ~r_xi_sum ~verification_key:pairing_marlin_index ~sponge
        ~public_input:(Array.append [|[Boolean.true_]|] (pack prev_statement))
        ~messages ~opening_proofs
    in
    assert_eq_marlin marlin marlin_actual ;
    Field.Assert.equal me_only_digest
      (Field.pack
         (hash_me_only
            { Types.Dlog_based.Proof_state.Me_only.pairing_marlin_acc
            ; old_bulletproof_challenges= new_bulletproof_challenges })) ;
    Field.Assert.equal sponge_digest_before_evaluations
      (Field.pack sponge_digest_before_evaluations_actual) ;
    ()
  in
  ((module Req), main)
