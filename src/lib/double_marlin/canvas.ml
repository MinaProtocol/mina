open Tuple_lib
module D = Digest
open Core_kernel
module Digest = D
open Rugelach_types
open Hlist

open Rugelach_types

(* Making this dynamic was a bit complicated. *)
let permitted_domains =
  [ Domain.Pow_2_roots_of_unity 14
  ; Domain.Pow_2_roots_of_unity 17
  ; Pow_2_roots_of_unity 18
  ; Pow_2_roots_of_unity 19
  ]

let check_step_domains step_domains =
  Vector.iter step_domains ~f:(fun (h, k) ->
      List.iter [h;k] ~f:(fun d ->
          printf "Domain %d\n%!" (Domain.log2_size d);
        assert
          (List.mem permitted_domains d ~equal:Domain.equal)))


let permitted_shifts =
  List.map permitted_domains ~f:(fun d ->
      Domain.size d - 1)
  |> Int.Set.of_list


module Full_signature = struct
  type ('max_width, 'branches, 'maxes) t =
    { padded : ((int, 'branches) Vector.t, 'max_width) Vector.t
    ; maxes: (module Maxes.S with type length = 'max_width and type ns = 'maxes)
    }
end

module Verifiable : sig
  type t

  val verify : t list -> bool
end = struct
  type t 
  let verify _ = failwith ""
end

module Pairing_index = struct
  type t = Snarky_bn382_backend.G1.Affine.t Abc.t Matrix_evals.t
end

type dlog_index = Snarky_bn382_backend.G.Affine.t Abc.t Matrix_evals.t

open Snarky_bn382_backend

type g = 
  Impls.Pairing_based.Field.Constant.t * Impls.Pairing_based.Field.Constant.t
[@@deriving sexp, bin_io]
type g1 =
  Impls.Dlog_based.Field.Constant.t * Impls.Dlog_based.Field.Constant.t
[@@deriving sexp, bin_io]


module Wrap_circuit_bulletproof_rounds = Nat.N17
type 'a bp_vec = ('a, Wrap_circuit_bulletproof_rounds.n) Vector.t

type dlog_opening = (Fq.t, g) Types.Pairing_based.Openings.Bulletproof.t

  module Pmain = Pairing_main.Make(struct
      include Pairing_main_inputs
      module Branching_pred = Nat.N0
  end)

  let crs_max_degree = 1 lsl Rugelach_types.Nat.to_int Wrap_circuit_bulletproof_rounds.n
  module Dmain = Dlog_main.Make(struct
      include Dlog_main_inputs
      module Bulletproof_rounds = Wrap_circuit_bulletproof_rounds
  let crs_max_degree = crs_max_degree
      module Branching_pred = Nat.N0
  end)

module Dlog_proof = struct
  type t  =
        dlog_opening
        *
        (g, Fq.t) Rugelach_types.Pairing_marlin_types.Messages.t

  type var = 
      (Impls.Pairing_based.Fq.t, Pairing_main_inputs.G.t) Types.Pairing_based.Openings.Bulletproof.t
        *
        (Pairing_main_inputs.G.t, Impls.Pairing_based.Fq.t) Rugelach_types.Pairing_marlin_types.Messages.t
end

module Challenges_vector = struct
  type 'n t = (Impls.Dlog_based.Field.t bp_vec , 'n ) Vector.t

  module Constant = struct
    type 'n t = (Impls.Dlog_based.Field.Constant.t bp_vec , 'n ) Vector.t
  end
end

module Pairing_acc = struct
  type t = (g1, g1 Int.Map.t ) Pairing_marlin_types.Accumulator.t
  module Projective = struct
    type t = (G1.t, G1.t Int.Map.t ) Pairing_marlin_types.Accumulator.t
  end
end

module One_hot_vector = One_hot_vector.Make(Impls.Pairing_based)

module Per_proof_witness = struct
  type ('local_statement, 'local_max_branching, 'local_num_branches) t =
    'local_statement
    * 'local_num_branches One_hot_vector.t
    * ( Pmain.Challenge.t
      , Pmain.Fp.t
      , Impls.Pairing_based.Boolean.var
      , Pmain.Fq.t
      , Pmain.Digest.t
      , Pmain.Digest.t )
      Types.Dlog_based.Proof_state.t
    * (Impls.Pairing_based.Field.t Pairing_marlin_types.Evals.t * Impls.Pairing_based.Field.t)
    * (Pairing_main_inputs.G.t, 'local_max_branching) Vector.t
    * Dlog_proof.var

  module Constant = struct
    type ('local_statement, 'local_max_branching, _) t =
      'local_statement
      * One_hot_vector.Constant.t
      * ( Challenge.Constant.t
        , Fp.t
        , bool
        , Fq.t
        , Digest.Constant.t
        , Digest.Constant.t )
        Types.Dlog_based.Proof_state.t
      * (Fp.t Pairing_marlin_types.Evals.t * Fp.t)
      * (g, 'local_max_branching) Vector.t
      * Dlog_proof.t
  end

  let typ (type n avar aval m)
      (statement : (avar, aval) Impls.Pairing_based.Typ.t)
      (local_max_branching : n Nat.t)
      (local_branches : m Nat.t)
      : ( (avar, n, m) t, (aval, n, m) Constant.t) Impls.Pairing_based.Typ.t
    =
    let open Impls.Pairing_based in
    let open Pairing_main_inputs in
    let open Pmain in
    Snarky.Typ.tuple6
      statement
      (One_hot_vector.typ local_branches)
      (Types.Dlog_based.Proof_state.typ Challenge.typ Fp.typ
        Boolean.typ Fq.typ Digest.typ Digest.typ)
      (Typ.tuple2 (Pairing_marlin_types.Evals.typ Field.typ) Field.typ)
      (Vector.typ G.typ local_max_branching)
      (Typ.tuple2
        (Types.Pairing_based.Openings.Bulletproof.typ
          ~length:(Nat.to_int Wrap_circuit_bulletproof_rounds.n)
              Fq.typ
              Pairing_main_inputs.G.typ)
        (Rugelach_types.Pairing_marlin_types.Messages.typ
          Pairing_main_inputs.G.typ
          Fq.typ))
end

module Requests = struct
  open Snarky.Request

  module Wrap = struct
    module type S = sig
      type max_branching
      type max_local_max_branchings

      open Impls.Dlog_based
      open Dlog_main_inputs

      open Snarky.Request

      type _ t +=
        | Evals :
            ((Field.Constant.t Dlog_marlin_types.Evals.t * Field.Constant.t)
            Tuple_lib.Triple.t, max_branching)
            Vector.t
            t
        | Index : int t
        | Pairing_accs
          : ( Pairing_acc.t
            , max_branching)
              Vector.t t
        | Old_bulletproof_challenges
          : max_local_max_branchings H1.T(Challenges_vector.Constant).t t
        | Proof_state
          : 
          ( ((( Challenge.Constant.t
            , Field.Constant.t
            , 
            ((Challenge.Constant.t, bool) Bulletproof_challenge.t,
              Wrap_circuit_bulletproof_rounds.n
            )Vector.t
            , Digest.Constant.t )
            Types.Pairing_based.Proof_state.Per_proof.t
            * bool), max_branching) Vector.t
          , Digest.Constant.t )
          Types.Pairing_based.Proof_state.t
          t
        | Messages:
            (G1.Constant.t, Snarky_bn382_backend.Fp.t) Pairing_marlin_types.Messages.t t
        | Openings_proof : G1.Constant.t Tuple_lib.Triple.t t
    end

    type ('mb, 'ml) t = 
      (module S
        with type max_branching = 'mb
         and type max_local_max_branchings = 'ml)

    let create : type mb ml. unit -> (mb, ml) t =
      fun () ->
      let module R = struct
        type nonrec max_branching = mb
        type nonrec max_local_max_branchings = ml 
        open Snarky_bn382_backend
        open Snarky.Request

        type 'a vec = ('a, max_branching) Vector.t

        type _ t +=
          | Evals :
              (Fq.t Dlog_marlin_types.Evals.t * Fq.t)
              Tuple_lib.Triple.t
              vec
              t
          | Index : int t
          | Pairing_accs
            : (g1, g1 Int.Map.t ) Pairing_marlin_types.Accumulator.t vec t
          | Old_bulletproof_challenges
            : max_local_max_branchings H1.T(Challenges_vector.Constant).t t
          | Proof_state
            : 
            ( ((( Challenge.Constant.t
              , Fq.t
              , 
              ((Challenge.Constant.t, bool) Bulletproof_challenge.t,
                Wrap_circuit_bulletproof_rounds.n
              )Vector.t
              , Digest.Constant.t )
              Types.Pairing_based.Proof_state.Per_proof.t
              * bool), max_branching) Vector.t
            , Digest.Constant.t )
            Types.Pairing_based.Proof_state.t
            t
          | Messages:
              (g1, Fp.t) Pairing_marlin_types.Messages.t t
          | Openings_proof : g1 Tuple_lib.Triple.t t
      end
      in
     (module R)
  end

  module Step = struct
    module type S = sig
      type statement
      type prev_values
      type branching
      type local_signature
      type local_branches

      type _ t +=
        | Prev_proofs: (prev_values, local_signature, local_branches) H3.T(Per_proof_witness.Constant).t t
        | Me_only :
            ( g
            , statement
            , (g, branching) Vector.t
            )
            Types.Pairing_based.Proof_state.Me_only.t
            t
    end

    let create:
      type local_signature local_branches statement prev_values branching.
     unit  ->
    (module S
      with type local_signature = local_signature
       and type local_branches = local_branches
       and type statement = statement
       and type prev_values = prev_values
       and type branching = branching)
      =
      fun () ->
        let module R  = struct

          type nonrec statement       =statement
          type nonrec prev_values     =prev_values
          type nonrec branching       =branching
          type nonrec local_signature =local_signature
          type nonrec local_branches  =local_branches

          type _ t +=
            | Prev_proofs: (prev_values, local_signature, local_branches) H3.T(Per_proof_witness.Constant).t t
            | Me_only :
                ( g
                , statement
                , (g, branching) Vector.t
                )
                Types.Pairing_based.Proof_state.Me_only.t
                t
        end
        in
        (module R)
  end
end
      module Unfinalized = struct
        open Impls.Pairing_based

        type t =
          ( Field.t
          , Fq.t
          , 
((Boolean.var list, Boolean.var)
  Bulletproof_challenge.t, Wrap_circuit_bulletproof_rounds.n)
 Rugelach_types.Vector.t
          , Impls.Pairing_based.Field.t
          )
          Types.Pairing_based.Proof_state.Per_proof.t
          * Boolean.var

        module Constant = struct
          open Snarky_bn382_backend

          type t =
          ( Challenge.Constant.t,
            Fq.t,
            (( Challenge.Constant.t, bool) Bulletproof_challenge.t,
             Wrap_circuit_bulletproof_rounds.n
            ) Vector.t,
            Digest.Constant.t
          )
          Types.Pairing_based.Proof_state.Per_proof.t

          let dummy : t = 
            let ro lab length f =
              let r = ref 0 in
              fun () ->
                incr r ;
                f (Common.bits_random_oracle ~length (sprintf "%s_%d" lab !r))
            in
            let fq = ro "fq" Digest.Constant.length Fq.of_bits in
            let chal =
              ro "chal" Challenge.Constant.length Challenge.Constant.of_bits
            in
            let one_chal = Challenge.Constant.of_fq Fq.one in
            { deferred_values=
                { marlin=
                    { sigma_2=fq ()
                    ; sigma_3=fq ()
                    ; alpha=chal()
                    ; eta_a=chal()
                    ; eta_b=chal()
                    ; eta_c=chal()
                    ; beta_1=chal()
                    ; beta_2=chal()
                    ; beta_3=chal()
                    }
                ; combined_inner_product = fq ()
                ; xi                     = one_chal
                ; r                      = one_chal
                ; bulletproof_challenges =
                    Vector.init Wrap_circuit_bulletproof_rounds.n
                      ~f:(fun _ ->
                          let prechallenge = chal () in
                          { Bulletproof_challenge.is_square=
                              Fq.is_square
                                (Fq.of_bits 
                                   (Challenge.Constant.to_bits prechallenge))
                          ; prechallenge
                          } )
                ; b = fq ()
                }
            ; sponge_digest_before_evaluations=Digest.Constant.of_fq Fq.zero
            }

          let corresponding_dummy_sg =
            lazy (Concrete.compute_sg dummy.deferred_values.bulletproof_challenges)
        end

      end

module B = Inductive_rule.B

module Dummy = struct
  let pairing_acc : _ Pairing_marlin_types.Accumulator.t =
      let opening_check : _ Pairing_marlin_types.Accumulator.Opening_check.t =
        (* TODO: Leaky *)
        let t =
          Snarky_bn382.Fp_urs.dummy_opening_check
            (Snarky_bn382_backend.Pairing_based.Keypair.load_urs ())
        in
        { r_f_minus_r_v_plus_rz_pi=
            Snarky_bn382.G1.Affine.Pair.f0 t |> G1.Affine.of_backend
        ; r_pi= Snarky_bn382.G1.Affine.Pair.f1 t |> G1.Affine.of_backend }
      in
      let degree_bound_checks :
          _ Pairing_marlin_types.Accumulator.Degree_bound_checks.t =
        let shifts = Int.Set.to_list permitted_shifts in
        (* TODO: Leaky *)
        let t =
          let v =
            let open Snarky_bn382.Usize_vector in
            let v = create () in
            List.iter shifts ~f:(fun i ->
                emplace_back v (Unsigned.Size_t.of_int i)) ;
            v
          in
          Snarky_bn382.Fp_urs.dummy_degree_bound_checks
            (Snarky_bn382_backend.Pairing_based.Keypair.load_urs ())
            v
        in
        { shifted_accumulator=
            Snarky_bn382.G1.Affine.Vector.get t 0 |> G1.Affine.of_backend
        ; unshifted_accumulators=
            List.mapi shifts ~f:(fun i s -> 
              (s, 
              G1.Affine.of_backend (Snarky_bn382.G1.Affine.Vector.get t i) )
              ) |> Int.Map.of_alist_exn
        }
      in
      { opening_check; degree_bound_checks
      }

  let evals =
    let e =
      Dlog_marlin_types.Evals.of_vectors
        (Vector.init Nat.N18.n ~f:(fun _ -> Fq.one),
         Vector.init Nat.N3.n ~f:(fun _ -> Fq.one)
        )
    in
    let ex = (e, Fq.zero) in
    (ex, ex, ex)

end

(* TODO: Pad public input to max_branching *)
let step
  : type branching self_branches prev_vars prev_values a_var a_value max_branching
      local_branches
      local_signature.

    (module Requests.Step.S
      with type local_signature = local_signature
       and type local_branches = local_branches
       and type statement = a_value
       and type prev_values = prev_values
       and type branching = branching)
    ->
    (module Nat.Add.Intf with type n = max_branching) ->
    self_branches: self_branches Nat.t ->

    local_signature: local_signature H1.T(Nat).t ->
    local_signature_length: (local_signature, branching) Hlist.Length.t ->

    (* For each inner proof of type T , the number of branches that type T has. *)
    local_branches: local_branches H1.T(Nat).t ->
    local_branches_length: (local_branches, branching) Hlist.Length.t ->

    branching:(prev_vars, branching) Hlist.Length.t ->

    lte:(branching, max_branching) Nat.Lte.t ->

    basic: (a_var, a_value, max_branching, self_branches) Types_map.Data.basic ->

    self:(a_var, a_value, max_branching, self_branches) Tag.t ->
    ( prev_vars, prev_values, local_signature, local_branches, a_var, a_value)
        Inductive_rule.t
    -> 
    ( ( (Unfinalized.t, max_branching ) Vector.t
       ,
       Impls.Pairing_based.Field.t, ( Impls.Pairing_based.Field.t, max_branching) Vector.t) Types.Pairing_based.Statement.t -> unit
    )
  =
  fun (module Req) (module Max_branching) ~self_branches  ~local_signature  ~local_signature_length ~local_branches ~local_branches_length ~branching ~lte ~basic ~self
    rule ->
    let module T(F : T4) = struct
      type ('a, 'b, 'n, 'm) t =
        | Other of ('a, 'b, 'n, 'm) F.t
        | Self : (a_var, a_value, max_branching, self_branches) t
    end
    in
    let branching_n = Hlist.Length.to_nat branching in
    let module D = T(Types_map.Data) in
(*
    let module P = H2_1.T(E23(Tag)) in
    let module W = T(E02(struct type t = dlog_index end)) in *)
(*     let request_tags = create_request_tags prevs in *)
    let open Impls.Pairing_based in
    let module Typ_with_max_branching = struct
      type ('var, 'value, 'local_max_branching, 'local_branches) t =
        (('var, 'local_max_branching, 'local_branches) Per_proof_witness.t,
         ('value, 'local_max_branching, 'local_branches) Per_proof_witness.Constant.t ) Typ.t 
(*         ('var, 'value) * 'local_max_branching Nat.t *)
    end
    in
    let prev_typs =
      let rec join
        : type e pvars pvals ns1 ns2 br.
          (pvars, pvals, ns1, ns2) H4.T(Tag).t
          -> ns1 H1.T(Nat).t
          -> ns2 H1.T(Nat).t
          -> (pvars, br) Length.t
          -> (ns1, br) Length.t
          -> (ns2, br) Length.t
          -> (pvars, pvals, ns1, ns2) H4.T(Typ_with_max_branching).t
        =
        fun ds ns1 ns2 ld ln1 ln2 ->
          match ds, ns1, ns2, ld, ln1, ln2 with
          | [], [], [], Z, Z, Z -> []
          | (d :: ds), (n1 :: ns1), (n2 :: ns2), S ld, S ln1, S ln2 ->
            let typ =
              (fun (type var value n m) (d : (var, value, n, m) Tag.t) : (var, value) Typ.t ->
                match Type_equal.Id.same_witness self d with
                | Some T -> basic.typ
                | None ->(Types_map.lookup d).typ
              ) d
            in
            let t =
              Per_proof_witness.typ
                typ
                n1
                n2
            in
            t :: join ds ns1 ns2 ld ln1 ln2
          | [], _, _, _, _, _ -> .
          | _::_, _, _, _, _, _ -> .
      in
      join rule.prevs local_signature local_branches
        branching
        local_signature_length
        local_branches_length
    in
    let module Prev_typ = H4.Typ(Impls.Pairing_based)(Typ_with_max_branching)(Per_proof_witness)(Per_proof_witness.Constant)(struct
        let f = Fn.id
      end)
    in
    (* stmt unfinalized length should be max_branching probably, with some
       kind of dummy values... or perhaps that can be handled in the wrap.
    *)
    let module Pseudo = Pseudo.Make(Impls.Pairing_based) in
    let main (stmt : _ Types.Pairing_based.Statement.t) =
      let open Requests.Step in
      let open Impls.Pairing_based in
      let module Prev_statement = struct
        open Impls.Pairing_based
        type 'a t =
          (Challenge.t,
          Fp.t,
          Boolean.var, unit,
          Digest.t,
          Digest.t)
          Types.Dlog_based.Proof_state.t * 'a
      end
      in
      (* TODO: Pad this to have length max_branching!
         and then don't include in the gs that have length shorter than max_branching?
         that would be perhaps simpler in the long run.
      *)
      let me_only =
        exists
          ~request:(fun () -> Req.Me_only)
          (Types.Pairing_based.Proof_state.Me_only.typ
            Pairing_main_inputs.G.typ
            basic.typ
            branching_n)
      in
      let datas =
        let self_data : (a_var, a_value, max_branching, self_branches) Types_map.Data.For_step.t =
          { branches=self_branches
          ; max_branching = (module Max_branching)
          ; typ = basic.typ
          ; a_var_to_field_elements = basic.a_var_to_field_elements
          ; a_value_to_field_elements = basic.a_value_to_field_elements
          ; wrap_domains = basic.wrap_domains
          ; step_domains= basic.step_domains
          ; wrap_key=me_only.dlog_marlin_index
          }
        in
        let module M =
          H4.Map(Tag) 
            (Types_map.Data.For_step)
            (struct
              let f : type a b n m. (a, b, n,m ) Tag.t -> (a, b, n,m ) Types_map.Data.For_step.t =
                fun tag ->
                match Type_equal.Id.same_witness self tag with
                | Some T -> self_data
                | None ->
                  Types_map.Data.For_step.create (Types_map.lookup tag)
          end)
        in
        M.f rule.prevs
      in
      let prevs =
        (* TODO: Should clobber the internal 'me_only's with stmt.pass_through *)
        exists
          (Prev_typ.f prev_typs)
          ~request:(fun () -> Req.Prev_proofs)
      in
      let unfinalized_proofs =
        let module H = H1.Of_vector(Unfinalized) in
        H.f
          branching
          (Vector.trim stmt.proof_state.unfinalized_proofs
            lte)
      in
      let module Packed_digest = Field in
      let prev_statements =
        let module M = 
          H3.Map1_to_H1(Per_proof_witness)(Id)(struct
            let f : type a b c. (a, b, c) Per_proof_witness.t -> a =
              fun (x, _, _, _, _, _) -> x
            end)
        in
        M.f prevs
      in
      let prev_proofs_finalized =
        let rec go
          : type vars vals ns1 ns2.
            (vars, ns1, ns2) H3.T(Per_proof_witness).t
            -> (vars, vals, ns1, ns2) H4.T(Types_map.Data.For_step).t
            -> Boolean.var list
          =
          fun proofs datas ->
            match proofs, datas with
            | [], [] -> []
            | p :: proofs, d :: datas ->
              let (_, which_index, state, prev_evals, _sgs, _opening)  =
                p
              in
              let sponge_digest = Fp.pack state.sponge_digest_before_evaluations in
              let deferred_values = Types.Dlog_based.Proof_state.Deferred_values.map_challenges
                  ~f:Fp.pack state.deferred_values
              in
              let sponge =
                let open Pairing_main_inputs in
                let sponge = Sponge.create sponge_params in
                Sponge.absorb sponge (`Field sponge_digest) ;
                sponge
              in
              let domain_h, domain_k =
                let hs, ks = Vector.unzip d.step_domains in
                Pseudo.Domain.(to_domain (which_index, hs)
                              , to_domain (which_index, ks))
              in
              Pmain.finalize_other_proof
                ~domain_k
                ~domain_h
                ~sponge
                deferred_values
                prev_evals
              ::
              go proofs datas
        in
        go prevs datas
      in
      let module Proof = struct
        type t = Dlog_proof.var
      end
      in
      let me_only =
        exists
          (Types.Pairing_based.Proof_state.Me_only.typ
            Pairing_main_inputs.G.typ
            basic.typ
            Max_branching.n )
      in
      let proofs_should_verify =
        rule.main 
          prev_statements
          me_only.app_state
      in
      let open Pairing_main_inputs in
      let open Pmain in
      let prevs_verified =
        let rec go :
          type vars vals ns1 ns2.
          (vars, ns1, ns2) H3.T(Per_proof_witness).t
          -> (vars, vals, ns1, ns2) H4.T(Types_map.Data.For_step).t
          -> vars H1.T(E01(Unfinalized)).t
          -> vars H1.T(E01(B)).t
          -> vars H1.T(E01(B)).t
          =
          fun proofs datas unfinalizeds should_verifys ->
            match proofs, datas, unfinalizeds, should_verifys with
            | [], [], [], [] -> []
            | p :: proofs, d :: datas, (unfinalized, b) :: unfinalizeds, should_verify :: should_verifys ->
              Boolean.Assert.(b = should_verify) ;
              let (app_state, which_index, state, _prev_evals, sg_old, (opening, messages))  =
                p
              in
              (* TODO Use a pseudo sg old which masks out the extraneous sgs
                 for the index of this internal proof... *)
              let statement =
                let prev_me_only =
                  (* TODO: Don't rehash when it's not necessary *)
                  unstage(
                  hash_me_only
                    ~index:d.wrap_key
                    d.a_var_to_field_elements )
                    { app_state
                    ; dlog_marlin_index=d.wrap_key
                    ; sg=sg_old
                    }
                in
                { Types.Dlog_based.Statement.pass_through= prev_me_only
                ; proof_state=state
                }
              in
              Pmain.verify
                ~branching:d.max_branching
                ~wrap_domains:d.wrap_domains
                ~is_base_case:should_verify
                ~sg_old
                ~opening
                ~messages
                ~wrap_verification_key:d.wrap_key
                statement
                unfinalized
              :: go proofs datas unfinalizeds should_verifys
        in
        go prevs datas unfinalized_proofs
          proofs_should_verify
      in
      let () =
        let bs =
          let module Z =
            H1.Zip(E01(B))(E01(B))
          in
          Z.f
            proofs_should_verify
            prevs_verified
        in
        let module M =
          H1.Iter(H1.Tuple2(E01(B))(E01(B))) (struct
            let f (should_verify, verified) =
              Boolean.(Assert.(any [not should_verify ; verified ]))
          end)
        in
        M.f bs
      in
      let () =
        let hash_me_only =
          unstage
            (Pmain.hash_me_only
               ~index:me_only.dlog_marlin_index
               basic.a_var_to_field_elements)
        in
        Field.Assert.equal stmt.proof_state.me_only
          (Field.pack (hash_me_only me_only)) 
      in
      ()
    in
    main
;;

let pad_local_max_branchings
    (type prev_varss prev_valuess env)
    (type max_branching branches)
    (max_branching : max_branching Nat.t)
    (length : (prev_varss, branches) Hlist.Length.t)
    (local_max_branchings
     : (prev_varss, prev_valuess, env) H2_1.T(H2_1.T(E03(Int))).t)
  :
    (( int, max_branching ) Vector.t , branches ) Vector.t
  =
  let module Vec = struct
    type t = (int, max_branching) Vector.t
  end
  in
  let module M =
    H2_1.Map(H2_1.T(E03(Int)))(E03(Vec))(struct
      module HI = H2_1.T(E03(Int)) 
      let f : type a b e. (a, b, e) H2_1.T(E03(Int)).t -> Vec.t =
        fun xs ->
        let T (branching, pi) = HI.length xs in
        let module V = H2_1.To_vector(Int) in
        let v = V.f pi xs in
        Vector.extend_exn v max_branching 0
    end)
  in
  let module V = H2_1.To_vector(Vec) in
  V.f length (M.f local_max_branchings)

(* TODO: For now just assert that all slots have the same max branching
   (actually it should all be 2)
*)
(*

    (tags : (prev_varss, prev_valuess, env) H2_1.T(E23(Tag)).t)
   *)
(*     H2_1.T(H2_1.T(E03(Domains))).t ) *)

let wrap_main
(*
    (pi_branches : (prev_varss, branches) Hlist.Length.t)
    (widthss_length : (widthss, branches) Hlist.Length.t)
    (widthss : widthss H1.T(H1.T(Nat)).t)
*)
    (type max_branching)
    (type branches)
    (type prev_varss)
    (type prev_valuess)
    (type env)
    (type max_local_max_branchings)
    (full_signature : (max_branching, branches, max_local_max_branchings) Full_signature.t )

    (pi_branches : (prev_varss, branches) Hlist.Length.t)

    (step_keys : (Dlog_main_inputs.G1.Constant.t Abc.t Matrix_evals.t, branches) Vector.t)
    (step_domains: (Domains.t, branches) Vector.t)

    (prev_wrap_domains: (prev_varss, prev_valuess, _, _) H4.T(H4.T(E04(Domains))).t )
    (module Max_branching : Nat.Add.Intf with type n = max_branching)
  :
      (max_branching 
      , max_local_max_branchings)
      Requests.Wrap.t * 'a
  =
  let module Pseudo = Pseudo.Make(Impls.Dlog_based) in
  let T = Max_branching.eq in
  let branches = Hlist.Length.to_nat pi_branches in
  let open Impls.Dlog_based in
  let (module Req) =
    Requests.Wrap.((create () : (max_branching, max_local_max_branchings) t))
  in
  let { Full_signature.padded; maxes= (module Max_widths_by_slot) } = full_signature
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
    (* Pick tag in 0..(num_disjuncts - 1).
       Ehh. Honestly better just to make it uniform in the step circuit,
       less complicated I think.
    *)
    let open Dmain in
    let prev_proof_state =
      let open Types.Pairing_based.Proof_state in
      let typ = typ (module Impl) Max_branching.n Wrap_circuit_bulletproof_rounds.n Fq.typ in
      exists
        typ
        ~request:(fun () -> Req.Proof_state)
    in
    let which_branch =
      exists
        (One_hot_vector.typ branches)
        ~request:(fun () -> Req.Index)
    in
    let pairing_marlin_index = 
      choose_key
        which_branch
        (Vector.map step_keys
           ~f:(Matrix_evals.map ~f:(Abc.map ~f:G1.constant)))
    in
    let prev_pairing_accs =
      exists
        (Vector.typ
              (Pairing_marlin_types.Accumulator.typ
                 permitted_shifts
                 G1.typ
              )
           Max_branching.n)
        ~request:(fun () -> Req.Pairing_accs)
    in
    let module Old_bulletproof_chals = struct
      type t =
          T : 'max_local_max_branching Nat.t
              * ('max_local_max_branching) Challenges_vector.t
            ->
            t
    end
    in
    let old_bp_chals =
      let typ =
        let module T = H1.Typ(Impls.Dlog_based)(Nat)(Challenges_vector)(Challenges_vector.Constant)(struct
          let f (type n) (n : n Nat.t) =
            Vector.typ (Vector.typ Field.typ Wrap_circuit_bulletproof_rounds.n) n
        end)
        in
        T.f Max_widths_by_slot.maxes
      in
      let module Z = H1.Zip(Nat)(Challenges_vector) in
      let module M = H1.Map(H1.Tuple2(Nat)(Challenges_vector))(E01(Old_bulletproof_chals))(struct
          let f (type n) ((n, v) : n H1.Tuple2(Nat)(Challenges_vector).t) =
            Old_bulletproof_chals.T (n, v)
        end)
      in
      let module V = H1.To_vector(Old_bulletproof_chals) in
      Z.f Max_widths_by_slot.maxes
        (exists typ ~request:(fun () -> Req.Old_bulletproof_challenges))
      |> M.f
      |> V.f Max_widths_by_slot.length
    in
    let prev_pairing_acc = combine_pairing_accs prev_pairing_accs in
    let new_bulletproof_challenges =
      let evals =
        let ty =
          let ty = Typ.tuple2 (Dlog_marlin_types.Evals.typ Fq.typ) Fq.typ in
          Typ.tuple3 ty ty ty
        in
        exists (Vector.typ ty Max_branching.n) ~request:(fun () ->
            Req.Evals )
      in
      let chals =
        let (wrap_domains : (Marlin_checks.domain * Marlin_checks.domain,  Max_branching.n ) Vector.t), hk_minus_1s =
          let module Ds = struct type t = (Domains.t , Max_branching.n) Vector.t end in
          let ds:
            (prev_varss, prev_valuess, _, _)
              H4.T(E04(Ds)).t
            =
            let dummy_domains =
              (* TODO: The dummy should really be equal to one of the already present domains. *)
              let d = Domain.Pow_2_roots_of_unity 1 in
              (d, d)
            in
            let module M = H4.Map(H4.T(E04(Domains)))(E04(Ds))(struct
                module H =H4.T(E04(Domains))
                let f : type a b c d. (a, b, c, d)H4.T(E04(Domains)).t -> Ds.t =
                  fun domains ->
                    let (T (len, pi)) = H.length domains in
                    let module V = H4.To_vector(Domains) in
                    Vector.extend_exn
                      (V.f
                         pi 
                         domains )
                      Max_branching.n
                      dummy_domains
              end)
            in
            M.f
              prev_wrap_domains
          in
          let ds =
            let module V = H4.To_vector(Ds) in
            V.f
              pi_branches
              ds
          in
          Vector.map (Vector.transpose ds) ~f:(fun ds ->
              let hs, ks = Vector.unzip ds in
              ( ( Pseudo.Domain.to_domain (which_branch, hs),
                  Pseudo.Domain.to_domain (which_branch, ks) ),
                (
                    (which_branch, Vector.map hs ~f:(fun h -> Domain.size h - 1)),
                    (which_branch, Vector.map ks ~f:(fun k -> Domain.size k - 1))
                ) 
              )
            )
          |> Vector.unzip
        in
        let actual_branchings =
          padded
          |> Vector.map ~f:(fun branchings_in_slot ->
              Pseudo.choose (which_branch, branchings_in_slot)
                ~f:Field.of_int )
        in
        Vector.mapn
          [ prev_proof_state.unfinalized_proofs
          ; old_bp_chals
          ; actual_branchings
          ; evals 
          ; wrap_domains
          ; hk_minus_1s
          ]
          ~f:(fun [ ({deferred_values; sponge_digest_before_evaluations}, should_verify)
                  ; old_bulletproof_challenges
                  ; actual_branching
                  ; evals 
                  ; domain_h, domain_k
                  ; h_minus_1, k_minus_1
                  ]
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
            let T (max_local_max_branching, old_bulletproof_challenges) = old_bulletproof_challenges in
            let verified, chals =
              finalize_other_proof
              (Nat.Add.create
                max_local_max_branching)
                ~actual_branching
                ~h_minus_1 ~k_minus_1
                ~shifted_pow:(
                  Pseudo.Degree_bound.shifted_pow ~crs_max_degree)
                ~domain_k
                ~domain_h
                ~sponge
              (map_challenges deferred_values ~f:Fq.pack)
              ~old_bulletproof_challenges
              evals 
            in
            Boolean.(Assert.any [ not should_verify ; verified ]) ;
            chals
            )
      in
      chals
    in
    let prev_statement =
      (* TODO: A lot of repeated hashing happening here on the dlog_marlin_index *)
      let prev_me_onlys =
        Vector.map2 prev_pairing_accs old_bp_chals ~f:(fun pacc (T ( max_local_max_branching, chals)) ->
            let T = Nat.eq_exn max_local_max_branching Nat.N2.n in
            (* This is a bit problematic because of the divergence from max_branching.
               Need to mask out the irrelevant chals. *)
            hash_me_only
              { pairing_marlin_acc= pacc
              ; old_bulletproof_challenges= chals
              } )
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
            Common.split_last
              (Bitstring_lib.Bitstring.Lsb_first.to_list (Fq.unpack_full x))
          in
          [|low_bits; [high_bit]|]
        in
        fun t ->
          Spec.pack
            (module Impl)
            pack_fq
            (Types.Pairing_based.Statement.spec Max_branching.n
               Wrap_circuit_bulletproof_rounds.n)
            (Types.Pairing_based.Statement.to_data t)
      in
      let xi = Field.unpack xi ~length:Challenge.length in
      let r = Field.unpack r ~length:Challenge.length in
      let r_xi_sum =
        Field.choose_preimage_var r_xi_sum ~length:Field.size_in_bits
      in
      let step_domains =
        ( Pseudo.Domain.to_domain
          (which_branch, Vector.map ~f:fst step_domains)
        , Pseudo.Domain.to_domain
          (which_branch, Vector.map ~f:snd step_domains)
        )
      in
      incrementally_verify_pairings 
        ~step_domains
        ~pairing_acc:prev_pairing_acc ~xi ~r
        ~r_xi_sum ~verification_key:pairing_marlin_index ~sponge
        ~public_input:(Array.append [|[Boolean.true_]|] (pack prev_statement))
        ~messages ~opening_proofs
    in
    (* TODO: assertion on marlin_actual and pairing_marlin_acc *)
    Field.Assert.equal me_only_digest
      (Field.pack
         (hash_me_only
            { Types.Dlog_based.Proof_state.Me_only.
              pairing_marlin_acc
            ; old_bulletproof_challenges= new_bulletproof_challenges })) ;
    Field.Assert.equal 
      sponge_digest_before_evaluations
      (Field.pack sponge_digest_before_evaluations_actual) ;
    ()
  in
  ((module Req), main)

module Step_branch_data = struct
  (* TODO: Get rid of the vector. Just use an Hlist with an E03 *)
  type ('a_var
       , 'a_value
       , 'max_branching
       , 'branches
      , 'prev_vars, 'prev_values, 'local_widths, 'local_heights) t =
      T : 
        { branching: 'branching Nat.t * ('prev_vars, 'branching) Hlist.Length.t
        ; index: int
        ; lte: ('branching,'max_branching) Nat.Lte.t
        ; domains: Domains.t
        ; rule: ( 'prev_vars, 'prev_values, 'local_widths, 'local_heights, 'a_avar, 'a_value) Inductive_rule.t
        ; main:
            (step_domains:(Domains.t, 'branches) Vector.t
                 ->
              ( (Unfinalized.t, 'max_branching ) Vector.t
            ,
            Impls.Pairing_based.Field.t, ( Impls.Pairing_based.Field.t, 'max_branching) Vector.t)
              Types.Pairing_based.Statement.t
            -> unit
          )
        ; requests:
            (module Requests.Step.S
              with type statement = 'a_value
               and type branching = 'branching 
               and type prev_values = 'prev_values
               and type local_signature= 'local_widths
               and type local_branches = 'local_heights
            )
        } -> 
(
    'a_var, 'a_value, 'max_branching, 'branches,
    'prev_vars, 'prev_values, 'local_widths, 'local_heights) t 
end

(* 
Ultimate result:

   module Proof : sig
     type t [@@deriving bin_io]

     val to_verifiable_components : t -> ?
   end


For each branch of type (prev_vars, prev_values) Inductive_rule.t, we get
   - prover (combines step and wrap)
   : a_value
   -> prev_values Hlist.t
   -> handler
   -> Proof.t
*)

open Snarky_bn382_backend

module Proof_state = struct
  module Dlog_based = Types.Dlog_based.Proof_state
  module Pairing_based = Types.Pairing_based.Proof_state
end

module Me_only = struct
  module Dlog_based = Types.Dlog_based.Proof_state.Me_only
  module Pairing_based = Types.Pairing_based.Proof_state.Me_only
end

module Statement = struct
  module Dlog_based = Types.Dlog_based.Statement
  module Pairing_based = Types.Pairing_based.Statement
end

module Nvector (N : Nat.Intf) = struct
  type 'a t = ('a, N.n) Vector.t

  include Vector.Binable (N)
  include Vector.Sexpable (N)
  let map (t : 'a t) = Vector.map t
end

(* TODO: Just use lists but for the bin_io use the vector. *)
module type BS1 = sig type _ t [@@deriving bin_io, sexp] end
module type BV = sig include BS1 val map: 'a t -> f:('a -> 'b) -> 'b t end

module Bp_vector = Nvector (Wrap_circuit_bulletproof_rounds)

module Reduced_me_only = struct
  module Pairing_based = struct
    type ('s, 'sgs) t =
      { app_state: 's
      ; sg: 'sgs 
      }
    [@@deriving sexp, bin_io]

    let prepare ~dlog_marlin_index {app_state; sg} =
      {Me_only.Pairing_based.app_state; sg; dlog_marlin_index}
  end

  module Dlog_based = struct
    module Challenges_vector = struct
      type t =
        ((Challenge.Constant.t, bool) Bulletproof_challenge.t, Wrap_circuit_bulletproof_rounds.n) Vector.t

      module Prepared = struct
        type t = (Fq.t, Wrap_circuit_bulletproof_rounds.n) Vector.t
      end
    end

    type 'max_local_max_branching t =
      (g1, g1 Int.Map.t, (Challenges_vector.t, 'max_local_max_branching) Vector.t ) Me_only.Dlog_based.t

    module Prepared = struct
      type 'max_local_max_branching t =
        (g1, g1 Int.Map.t, (Challenges_vector.Prepared.t, 'max_local_max_branching) Vector.t )
          Me_only.Dlog_based.t
    end

    let prepare
        ({pairing_marlin_acc; old_bulletproof_challenges} : _ t)  =
      { Me_only.Dlog_based.
        pairing_marlin_acc
      ; old_bulletproof_challenges= 
          Vector.map ~f:Concrete.compute_challenges old_bulletproof_challenges
      }
  end
end

module Proof_ = struct
  module Me_only = Reduced_me_only

  module Pairing_based = struct
    type ('s, 'unfinalized_proofs, 'sgs, 'dlog_me_onlys, 'prev_evals) t =
      { statement:
          ( 'unfinalized_proofs
          , ('s, 'sgs ) Me_only.Pairing_based.t
          , 'dlog_me_onlys
          )
          Statement.Pairing_based.t
      ; index: int
      ; prev_evals: 'prev_evals
      ; proof: Pairing_based.Proof.t }
  end

  module Dlog_based = struct
    type ('s, 'dlog_me_only, 'sgs) t =
      { statement:
          ( Challenge.Constant.t
          , Fp.t
          , bool
          , Fq.t
              (* TODO *)
          , 'dlog_me_only
          , Digest.Constant.t
          , ('s, 'sgs) Me_only.Pairing_based.t )
          Statement.Dlog_based.t
      ; index : int
      ; prev_evals: Fp.t Pairing_marlin_types.Evals.t
      ; prev_x_hat_beta_1: Fp.t
      ; proof: Dlog_based.Proof.t }
  end
end

let fp_public_input_of_statement
  ~max_branching
    (prev_statement : _ Statement.Pairing_based.t) =
  let input =
    let (T (input, conv)) =
      Impls.Pairing_based.input
        ~branching:max_branching
        ~bulletproof_log2:Wrap_circuit_bulletproof_rounds.n
    in
    Impls.Pairing_based.generate_public_input [input] prev_statement
  in
  Fp.one :: List.init (Fp.Vector.length input) ~f:(Fp.Vector.get input)

let crs_max_degree = 1 lsl Rugelach_types.Nat.to_int Wrap_circuit_bulletproof_rounds.n

let combined_evaluation (proof : Pairing_based.Proof.t) ~r ~xi ~beta_1
    ~beta_2 ~beta_3 ~x_hat_beta_1 =
  let { Pairing_marlin_types.Evals.w_hat
      ; z_hat_a
      ; z_hat_b
      ; h_1
      ; h_2
      ; h_3
      ; g_1
      ; g_2
      ; g_3
      ; row= {a= row_0; b= row_1; c= row_2}
      ; col= {a= col_0; b= col_1; c= col_2}
      ; value= {a= val_0; b= val_1; c= val_2} } =
    proof.openings.evals
  in
  let combine t (pt : Fp.t) =
    let open Fp in
    Pcs_batch.combine_evaluations
      ~crs_max_degree ~mul ~add ~one
      ~evaluation_point:pt ~xi t
  in
  let f_1 =
    combine Common.pairing_beta_1_pcs_batch beta_1
      [x_hat_beta_1; w_hat; z_hat_a; z_hat_b; g_1; h_1]
      []
  in
  let f_2 = combine Common.pairing_beta_2_pcs_batch beta_2 [g_2; h_2] [] in
  let f_3 =
    combine Common.pairing_beta_3_pcs_batch beta_3
      [ g_3
      ; h_3
      ; row_0
      ; row_1
      ; row_2
      ; col_0
      ; col_1
      ; col_2
      ; val_0
      ; val_1
      ; val_2 ]
      []
  in
  Fp.(r * (f_1 + (r * (f_2 + (r * f_3)))))

let combined_polynomials ~xi
    ~pairing_marlin_index:(index : _ Abc.t Matrix_evals.t) public_input
    (proof : Pairing_based.Proof.t) =
  let combine t v =
    let open G1 in
    let open Rugelach_types in
    Pcs_batch.combine_commitments t ~scale ~add ~xi
      (Vector.map v ~f:G1.of_affine)
  in
  let { Pairing_marlin_types.Messages.w_hat
      ; z_hat_a
      ; z_hat_b
      ; gh_1= (g1, _), h1
      ; sigma_gh_2= _, ((g2, _), h2)
      ; sigma_gh_3= _, ((g3, _), h3) } =
    proof.messages
  in
  let x_hat =
    let v = Fp.Vector.create () in
    List.iter public_input ~f:(Fp.Vector.emplace_back v) ;
    let domain_size =
      Int.ceil_pow2 (List.length public_input )
    in
    Snarky_bn382.Fp_urs.commit_evaluations
      (Snarky_bn382_backend.Pairing_based.Keypair.load_urs ())
      (Unsigned.Size_t.of_int domain_size)
      v
    |> Snarky_bn382_backend.G1.Affine.of_backend
  in
  ( combine Common.pairing_beta_1_pcs_batch
      [x_hat; w_hat; z_hat_a; z_hat_b; g1; h1]
      []
  , combine Common.pairing_beta_2_pcs_batch [g2; h2] []
  , combine Common.pairing_beta_3_pcs_batch
      [ g3
      ; h3
      ; index.row.a
      ; index.row.b
      ; index.row.c
      ; index.col.a
      ; index.col.b
      ; index.col.c
      ; index.value.a
      ; index.value.b
      ; index.value.c ]
      [] )

let accumulate_pairing_checks (proof : Pairing_based.Proof.t)
    (prev_acc : _ Pairing_marlin_types.Accumulator.t)
    ~domain_h ~domain_k
    ~r ~r_k ~r_xi_sum
    ~beta_1 ~beta_2 ~beta_3 (f_1, f_2, f_3) =
  let open G1 in
  let prev_acc =
    Pairing_marlin_types.Accumulator.map ~f:of_affine prev_acc
  in
  let proof1, proof2, proof3 =
    Triple.map proof.openings.proofs ~f:of_affine
  in
  let conv = Double.map ~f:of_affine in
  let g1 = conv (fst proof.messages.gh_1) in
  let g2 = conv (fst (snd proof.messages.sigma_gh_2)) in
  let g3 = conv (fst (snd proof.messages.sigma_gh_3)) in
  Pairing_marlin_types.Accumulator.map ~f:to_affine_exn
    { degree_bound_checks=
        Dlog_main.accumulate_degree_bound_checks'
          ~domain_h ~domain_k
          prev_acc.degree_bound_checks ~add ~scale ~r_h:r ~r_k g1 g2 g3
    ; opening_check= (
        Core.printf !"Obetas: %{sexp:Impls.Pairing_based.Field.Constant.t} %{sexp:Impls.Pairing_based.Field.Constant.t} %{sexp:Impls.Pairing_based.Field.Constant.t}\n%!"
          beta_1
          beta_2
          beta_3 ;
        Core.printf !"Ofs: %{sexp:Impls.Dlog_based.Field.Constant.t * Impls.Dlog_based.Field.Constant.t}  %{sexp:Impls.Dlog_based.Field.Constant.t * Impls.Dlog_based.Field.Constant.t}  %{sexp:Impls.Dlog_based.Field.Constant.t * Impls.Dlog_based.Field.Constant.t}\n%!"
          (G1.to_affine_exn f_1)
          (G1.to_affine_exn f_2)
          (G1.to_affine_exn f_3) ;
        Dlog_main.accumulate_opening_check ~add ~negate ~scale
          ~generator:one ~r ~r_xi_sum prev_acc.opening_check
          (f_1, beta_1, proof1) (f_2, beta_2, proof2) (f_3, beta_3, proof3)
      )
    }

let make_step_data
    (type branches)
    (type max_branching)
    (type local_signature)
    (type local_branches)
    (type a_var a_value)
    (type prev_vars prev_values)
    ~index
    ~(self : (a_var, a_value, max_branching, branches) Tag.t) ~wrap_domains
    ~(max_branching : max_branching Nat.t)
    ~(branches : branches Nat.t)
    ~typ
    a_var_to_field_elements
    a_value_to_field_elements
    (rule : _ Inductive_rule.t)
  =
    let module HT = H4.T(Tag) in
    let T (self_width, branching) =
      HT.length rule.prevs
    in
    let rec extract_lengths
      : type a b n m k.
        (a, b, n, m) HT.t
        -> (a, k) Length.t
        -> n H1.T(Nat).t * m H1.T(Nat).t * (n, k) Length.t * (m, k) Length.t
      =
      fun ts len ->
      match ts, len with
      | [], Z -> ([], [], Z, Z)
      | t :: ts, S  len ->
        let (ns, ms, len_ns, len_ms) = extract_lengths ts len in
        match Type_equal.Id.same_witness self t with
        | Some T ->
          (max_branching :: ns, branches :: ms, S len_ns, S len_ms) 
        | None ->
          let d = Types_map.lookup t in
          let (module M) = d.max_branching in
          let T = M.eq in
          ( M.n :: ns, d.branches :: ms, S len_ns, S len_ms) 
    in
    let (widths, heights, local_signature_length, local_branches_length) =
      extract_lengths rule.prevs branching
    in
    let lte = Nat.lte_exn self_width max_branching in
    let requests = Requests.Step.create () in
    let step ~step_domains =
      step
        requests
        (Nat.Add.create max_branching)
        rule
        ~basic:{
              typ;
              a_var_to_field_elements;
              a_value_to_field_elements;
              wrap_domains;
              step_domains;
        }
        ~self_branches:branches
        ~branching
        ~local_signature:widths
        ~local_signature_length
        ~local_branches:heights
        ~local_branches_length
        ~lte
        ~self
    in
    let own_domains =
      let main =
        step
          ~step_domains:(
            Vector.init branches ~f:(fun _ -> Fix_domains.rough_domains
                                    )
          )
      in
      let etyp =
            Impls.Pairing_based.input
              ~branching:max_branching
              ~bulletproof_log2:Wrap_circuit_bulletproof_rounds.n 
      in
      Fix_domains.domains 
        (module Impls.Pairing_based)
        etyp
        main
    in
    Step_branch_data.T
      { branching= (self_width, branching)
      ; index
      ; lte
      ; rule
      ; domains= own_domains
      ; main=step
      ; requests
      }
;;

module Prev_wrap_domains (A :T0)(A_value: T0) = struct
  module I = Inductive_rule.T(A)(A_value)

  let f
      (type xs ys ws hs)
      ~self
      ~(choices : (xs, ys, ws, hs) H4.T(I).t)
      =
    let module M_inner = H4.Map(Tag)(E04(Domains))(struct
        let f : type a b c d. (a, b, c, d) Tag.t -> Domains.t =
          fun t ->
            Types_map.lookup_map t ~self ~default:Fix_domains.rough_domains
              ~f:(fun d -> d.wrap_domains)
      end)
    in
    let module M = H4.Map(I)(H4.T(E04(Domains)))(struct
        let f : type vars values env widths heights.
          (vars, values, widths, heights) I.t
          -> (vars, values, widths, heights) H4.T(E04(Domains)).t
          =
          fun rule -> M_inner.f rule.prevs
      end)
    in
    M.f choices
end

module Wrap_domains (A : T0)(A_value: T0)  = struct
  module Prev = Prev_wrap_domains(A)(A_value)
let f
    full_signature
    num_choices
    choices_length
    ~self
    ~choices
    ~max_branching
  =
  let num_choices = Hlist.Length.to_nat choices_length in
  let dummy_step_keys =
    Vector.init num_choices
      ~f:(fun _ ->
          let g = Snarky_bn382_backend.G1.(to_affine_exn one) in
          let t : _ Abc.t = { a=g; b=g; c=g } in
          { Matrix_evals.row=t;col=t;value=t;rc=t } )
  in
  let dummy_step_domains =
    Vector.init num_choices ~f:(fun _ ->
        Fix_domains.rough_domains)
  in
  let prev_domains =
    Prev.f
         ~self ~choices
  in
  let _, main =
    wrap_main
      full_signature
      choices_length
      dummy_step_keys
      dummy_step_domains
      prev_domains
      max_branching
  in
  Fix_domains.domains (module Impls.Dlog_based)
    (Impls.Dlog_based.input ())
    main
end

let wrap (type max_branching max_local_max_branchings)
    max_branching
    (module Max_local_max_branchings
        : Hlist.Maxes.S with type ns =  max_local_max_branchings
                         and type length = max_branching)
    ((module Req) : (max_branching, max_local_max_branchings) Requests.Wrap.t)
    ~dlog_marlin_index
    wrap_main 
    to_field_elements
    ~pairing_vk
    ~step_domains
    ~wrap_domains
    ~pairing_marlin_indices
    pk
    ({ statement=prev_statement 
    ; prev_evals
    ; proof
    ; index=which_index
  } : ( _
      , _
      , _
      , max_local_max_branchings H1.T(Proof_.Me_only.Dlog_based).t
      , ((Fq.t Dlog_marlin_types.Evals.t * Fq.t) Triple.t,  max_branching) Vector.t
      ) Proof_.Pairing_based.t)
  =
  let pairing_marlin_index =
    (Vector.to_array pairing_marlin_indices).(which_index)
  in
  let prev_me_only =
    let module M = H1.Map(Proof_.Me_only.Dlog_based)(Proof_.Me_only.Dlog_based.Prepared)(struct
        let f = Proof_.Me_only.Dlog_based.prepare
      end)
    in
    M.f prev_statement.pass_through
  in
  let prev_statement_with_hashes
    : _ Statement.Pairing_based.t =
    { proof_state=
        { prev_statement.proof_state with
          me_only=
            Common.hash_pairing_me_only
              ~app_state:to_field_elements
              (Proof_.Me_only.Pairing_based.prepare
                ~dlog_marlin_index
                  prev_statement.proof_state.me_only) }
    ; pass_through=
        (let module M = H1.Map(Proof_.Me_only.Dlog_based.Prepared)(E01(Digest.Constant))(struct
            let f (type n) (m : n Proof_.Me_only.Dlog_based.Prepared.t) =
              let T =
                Nat.eq_exn Nat.N2.n 
                  (Vector.length m.old_bulletproof_challenges)
              in
              Common.hash_dlog_me_only m
          end)
        in
        let module V = H1.To_vector(Digest.Constant) in
        V.f Max_local_max_branchings.length (M.f prev_me_only))
    }
  in
  let handler (Snarky.Request.With {request; respond}) =
    let open Req in
    let k x = respond (Provide x) in
    match request with
    | Evals ->
        k prev_evals
    | Index ->
        k which_index
    | Pairing_accs ->
      let module M = H1.Map(Proof_.Me_only.Dlog_based.Prepared)(E01(Pairing_acc))(struct
          let f : type a. a Proof_.Me_only.Dlog_based.Prepared.t -> Pairing_acc.t =
            fun t -> t.pairing_marlin_acc
        end)
      in
      let module V = H1.To_vector(Pairing_acc) in
      k (V.f Max_local_max_branchings.length (M.f prev_me_only))
    | Messages ->
        k proof.messages
    | Openings_proof ->
        k proof.openings.proofs
    | Proof_state ->
        k prev_statement_with_hashes.proof_state
    | _ ->
        Snarky.Request.unhandled
  in
  let module O = Snarky_bn382_backend.Pairing_based.Oracles in
  let public_input =
    fp_public_input_of_statement
      ~max_branching
      prev_statement_with_hashes
  in
  let o = O.create pairing_vk public_input proof in
  let x_hat_beta_1 = O.x_hat_beta1 o in
  let next_statement : _ Statement.Dlog_based.t =
    let sponge_digest_before_evaluations = O.digest_before_evaluations o in
    let r = O.r o in
    let r_k = O.r_k o in
    let xi = O.batch o in
    let beta_1 = O.beta1 o in
    let beta_2 = O.beta2 o in
    let beta_3 = O.beta3 o in
    let alpha = O.alpha o in
    let eta_a = O.eta_a o in
    let eta_b = O.eta_b o in
    let eta_c = O.eta_c o in
    let r_xi_sum =
      combined_evaluation ~x_hat_beta_1 ~r ~xi ~beta_1 ~beta_2 ~beta_3
        proof
    in
    let me_only : _ Types.Dlog_based.Proof_state.Me_only.t =
      let combined_polys =
        combined_polynomials ~xi ~pairing_marlin_index public_input proof
      in
      let prev_pairing_acc =
        let open Pairing_marlin_types.Accumulator in
        let module M = H1.Map_reduce(Proof_.Me_only.Dlog_based)(Pairing_acc.Projective)(struct
            let reduce into t = accumulate t G1.(+) ~into
            let map (t : _ Proof_.Me_only.Dlog_based.t) =
                map ~f:G1.of_affine t.pairing_marlin_acc
        end)
        in
        map ~f:G1.to_affine_exn
        (M.f prev_statement.pass_through)
      in
      (*
          printf !"Ocombined_acc  %{sexp:(Impls.Dlog_based.Field.Constant.t * Impls.Dlog_based.Field.Constant.t, (Impls.Dlog_based.Field.Constant.t * Impls.Dlog_based.Field.Constant.t) Int.Map.t) Pairing_marlin_types.Accumulator.t}\n%!"
            prev_pairing_acc ; *)
      { pairing_marlin_acc=
          (let (domain_h, domain_k) = step_domains in
          accumulate_pairing_checks ~domain_h ~domain_k
            proof prev_pairing_acc ~r ~r_k
            ~r_xi_sum ~beta_1 ~beta_2 ~beta_3 combined_polys )
      ; old_bulletproof_challenges=
          Vector.map prev_statement.proof_state.unfinalized_proofs
            ~f:(fun (t, _) -> t.deferred_values.bulletproof_challenges) }
    in
          printf !"Opost_accumulatieon %{sexp:(Impls.Dlog_based.Field.Constant.t * Impls.Dlog_based.Field.Constant.t, (Impls.Dlog_based.Field.Constant.t * Impls.Dlog_based.Field.Constant.t) Int.Map.t) Pairing_marlin_types.Accumulator.t}\n%!"
            me_only.pairing_marlin_acc ;
    let chal = Challenge.Constant.of_fp in
    { proof_state=
        { deferred_values=
            { xi= chal xi
            ; r= chal r
            ; r_xi_sum
            ; marlin=
                { sigma_2= fst proof.messages.sigma_gh_2
                ; sigma_3= fst proof.messages.sigma_gh_3
                ; alpha= chal alpha
                ; eta_a= chal eta_a
                ; eta_b= chal eta_b
                ; eta_c= chal eta_c
                ; beta_1= chal beta_1
                ; beta_2= chal beta_2
                ; beta_3= chal beta_3 } }
        ; was_base_case=
            List.for_all ~f:(fun (_, should_verify) -> not should_verify)
              (Vector.to_list prev_statement.proof_state.unfinalized_proofs)
        ; sponge_digest_before_evaluations=
            D.Constant.of_fp sponge_digest_before_evaluations
        ; me_only }
    ; pass_through= prev_statement.proof_state.me_only }
  in
  let me_only_prepared =
    Proof_.Me_only.Dlog_based.prepare
      next_statement.proof_state.me_only
  in
  let next_proof =
    let (T (input, conv)) = Impls.Dlog_based.input () in
    Impls.Dlog_based.prove pk
      ~message:
        ( Vector.map2 prev_statement.proof_state.me_only.sg
            me_only_prepared.old_bulletproof_challenges ~f:(fun sg chals ->
              { Snarky_bn382_backend.Dlog_based_proof.Challenge_polynomial
                .commitment= sg
              ; challenges= Vector.to_array chals } )
        |> Vector.to_list )
      [input]
      (fun x () ->
        ( Impls.Dlog_based.handle
            (fun ()  : unit ->
                wrap_main
                  (conv x))
            handler
          : unit ) )
      ()
      { pass_through= prev_statement_with_hashes.proof_state.me_only
      ; proof_state=
          { next_statement.proof_state with
            me_only= Common.hash_dlog_me_only me_only_prepared } }
  in
  ( { proof= next_proof
    ; index=which_index
    ; statement= next_statement
    ; prev_evals= proof.openings.evals
    ; prev_x_hat_beta_1= x_hat_beta_1 }
    : _ Proof_.Dlog_based.t )

module Prev_proof = struct
  type ('s, 'max_width, 'max_height) t =
    ( 's
    , 
      ( 'max_width
      ) Proof_.Me_only.Dlog_based.t

    , (g, 'max_width) Vector.t
    ) Proof_.Dlog_based.t
end

module Step 
    (A : T0)
    (A_value : sig
       type t
       val to_field_elements: t -> Fp.t array
           end)
    (Max_branching : Nat.Add.Intf_transparent)
= struct

  let public_input_of_statement prev_statement =
    let input =
      let (T (typ, _conv)) = Impls.Dlog_based.input () in
      Impls.Dlog_based.generate_public_input [typ] prev_statement
    in
    Fq.one :: List.init (Fq.Vector.length input) ~f:(Fq.Vector.get input)

  let triple_zip (a1, a2, a3) (b1, b2, b3) = ((a1, b1), (a2, b2), (a3, b3))

  module E = struct
    type t = Fq.t Dlog_marlin_types.Evals.t Triple.t
  end

  let f
      (type self_branches prev_vars prev_values local_widths local_heights)
      ((T branch_data) :
         (A.t, A_value.t, Max_branching.n, self_branches,
          prev_vars, prev_values, local_widths, local_heights) Step_branch_data.t)
      (next_state : A_value.t)
          ~self
          ~step_domains
          ~dlog_marlin_index
          pk
          self_dlog_vk
          (prev_with_proofs :
             (prev_values, local_widths, local_heights)
               H3.T(Prev_proof).t )
          :
            _
              Proof_.Pairing_based.t
  =
  let (_, prev_vars_length) = branch_data.branching in
  let (module Req) = branch_data.requests in
  let T =
    Hlist.Length.contr (snd branch_data.branching)
      prev_vars_length
  in
  let prev_values_length =
    let module L12 = H4.Length_1_to_2(Tag) in
    (L12.f
        branch_data.rule.prevs
        prev_vars_length)
  in
  let lte = branch_data.lte in
  let inners_should_verify =
    let prevs =
      let module M = H3.Map1_to_H1(Prev_proof)(Id)(struct
          let f : type a. (a, _, _) Prev_proof.t -> a =
            fun t -> t.statement.pass_through.app_state
        end)
      in
      M.f
        prev_with_proofs
    in
    branch_data.rule.main_value
      prevs
      next_state
  in
  let module X_hat = struct
    type t = Fq.t Triple.t
  end
  in
  let module Statement_with_hashes = struct
    type t =
      ( Challenge.Constant.t,
      Snarky_bn382_backend.Fp.t,
      bool,
    Snarky_bn382_backend.Fq.t,
    Digest.Constant.t ,
    Digest.Constant.t,
    Digest.Constant.t)
    Statement.Dlog_based.t
  end
  in
  let b_poly = Fq.(Dlog_main.b_poly ~add ~mul ~inv) in
  let unfinalized_proofs, statements_with_hashes, x_hats, witnesses =
    let f : type var value n m.
      Impls.Dlog_based.Verification_key.t
      -> (value, n, m) Prev_proof.t
      -> (var, value, n, m) Tag.t
      -> 
      Unfinalized.Constant.t
      * Statement_with_hashes.t
      * X_hat.t
      * (value, n, m) Per_proof_witness.Constant.t
      =
        fun dlog_vk t tag ->
          let data = Types_map.lookup tag in
          let statement = t.statement in
          let prev_challenges =
            (* TODO: This is redone in the call to Dlog_based_reduced_me_only.prepare *)
            Vector.map ~f:Concrete.compute_challenges
              statement.proof_state.me_only.old_bulletproof_challenges
          in
          let prev_statement_with_hashes : _ Statement.Dlog_based.t =
            { pass_through=
                Common.hash_pairing_me_only
                  (Reduced_me_only.Pairing_based.prepare
                      ~dlog_marlin_index
                      statement.pass_through
                  )
                  ~app_state:data.a_value_to_field_elements
            ; proof_state=
                { statement.proof_state with
                  me_only=
                    Common.hash_dlog_me_only
                      { 
                        old_bulletproof_challenges= prev_challenges
                      ; pairing_marlin_acc=
                          statement.proof_state.me_only.pairing_marlin_acc }
                } }
          in
          let witness =
            ( t.Proof_.Dlog_based.statement.pass_through.app_state
            , t.index
            , prev_statement_with_hashes.proof_state
            , (t.prev_evals, t.prev_x_hat_beta_1)
            , t.statement.pass_through.sg
            , (t.proof.openings.proof, t.proof.messages)
            )
          in
          let module O = Snarky_bn382_backend.Dlog_based.Oracles in
          let o =
            let public_input =
              public_input_of_statement
                prev_statement_with_hashes
            in
            O.create dlog_vk
              Vector.(
                map2
                  statement.pass_through.sg (* This should indeed have length max_branching... No! It should have type max_branching_a. That is, the max_branching specific to a proof of this type...*)
                  prev_challenges
                  ~f:(fun commitment chals ->
                    { Snarky_bn382_backend.Dlog_based_proof
                      .Challenge_polynomial
                      .commitment
                    ; challenges= Vector.to_array chals } )
                |> to_list)
              public_input
              t.proof
          in
          let ((x_hat_1, x_hat_2, x_hat_3) as x_hat) = O.x_hat o in
          let beta_1 = O.beta1 o in
          let beta_2 = O.beta2 o in
          let beta_3 = O.beta3 o in
          let alpha = O.alpha o in
          let eta_a = O.eta_a o in
          let eta_b = O.eta_b o in
          let eta_c = O.eta_c o in
          let xi = O.polys o in
          let r = O.evals o in
          let sponge_digest_before_evaluations =
            O.digest_before_evaluations o
          in
          let combined_inner_product =
            let (module Local_max_branching) = data.max_branching in
            let T = Local_max_branching.eq in
            let e1, e2, e3 = t.proof.openings.evals in
            let b_polys =
              Vector.map
                ~f:(Fn.compose b_poly Vector.to_array)
                prev_challenges
            in
            let combine x_hat pt e =
              let a, b = Dlog_marlin_types.Evals.to_vectors e in
              let v =
                Vector.append
                  (Vector.map b_polys ~f:(fun f -> f pt))
                  (x_hat :: a)
                  (snd 
                     (Local_max_branching.add Nat.N19.n))
              in
              let open Fq in
              let domain_h, domain_k = data.wrap_domains in
              Pcs_batch.combine_evaluations
                (Common.dlog_pcs_batch
                  (Local_max_branching.add Nat.N19.n)
                  ~h_minus_1:Int.(Domain.size domain_h - 1)
                  ~k_minus_1:Int.(Domain.size domain_k - 1) 
                )
                ~crs_max_degree 
                ~xi ~mul ~add ~one
                ~evaluation_point:pt
                v b
            in
            let open Fq in
            combine x_hat_1 beta_1 e1
            + r
              * (combine x_hat_2 beta_2 e2 + (r * combine x_hat_3 beta_3 e3))
          in
          let new_bulletproof_challenges, b =
            let prechals =
              Array.map (O.opening_prechallenges o) ~f:(fun x ->
                  (x, Fq.is_square x) )
            in
            let chals =
              Array.map prechals ~f:(fun (x, is_square) ->
                  Concrete.compute_challenge ~is_square x )
            in
            let b_poly = b_poly chals in
            let b =
              let open Fq in
              b_poly beta_1 + (r * (b_poly beta_2 + (r * b_poly beta_3)))
            in
            let prechals =
              Array.map prechals ~f:(fun (x, is_square) ->
                  { Bulletproof_challenge.prechallenge=
                      Challenge.Constant.of_fq x
                  ; is_square } )
            in
            (prechals, b)
          in
          let chal = Challenge.Constant.of_fq in
          ( { Types.Pairing_based.Proof_state.Per_proof.deferred_values=
                { marlin=
                    { sigma_2= fst t.proof.messages.sigma_gh_2
                    ; sigma_3= fst t.proof.messages.sigma_gh_3
                    ; alpha= chal alpha
                    ; eta_a= chal eta_a
                    ; eta_b= chal eta_b
                    ; eta_c= chal eta_c
                    ; beta_1= chal beta_1
                    ; beta_2= chal beta_2
                    ; beta_3= chal beta_3 }
                ; combined_inner_product
                ; xi= chal xi
                ; r= chal r
                ; bulletproof_challenges=
                    Vector.of_list_and_length_exn
                      (Array.to_list new_bulletproof_challenges)
                      Wrap_circuit_bulletproof_rounds.n
                ; b }
            ; sponge_digest_before_evaluations=
                Digest.Constant.of_fq sponge_digest_before_evaluations }
          , prev_statement_with_hashes
          , x_hat
          , witness
          ) 
    in
    let rec go
      : type vars values ns ms k.
        (values, ns, ms) H3.T(Prev_proof).t
        -> (vars, values, ns, ms) H4.T(Tag).t
        -> (vars, k) Length.t
        -> (Unfinalized.Constant.t, k) Vector.t
        * (Statement_with_hashes.t, k) Vector.t
        * (X_hat.t, k) Vector.t
        * (values, ns, ms) H3.T(Per_proof_witness.Constant).t
      =
      fun ps ts l ->
        match ps, ts, l with
        | [], [], Z -> ([], [], [], [])
        | p::ps, t::ts, S l ->
          let dlog_vk =
            if Type_equal.Id.same self t
            then self_dlog_vk
            else (Types_map.lookup t).wrap_vk
          in
          let (u, s, x, w) = f dlog_vk p t
          and (us, ss, xs, ws) = go ps ts l in
          (u::us, s::ss, x::xs, w::ws)
    in
    go
      prev_with_proofs
      branch_data.rule.prevs
      prev_vars_length
  in
  let inners_should_verify =
      let module V = H1.To_vector(Bool) in
          V.f prev_vars_length inners_should_verify
  in
  let next_statement : _ Statement.Pairing_based.t =
    let unfinalized_proofs =
        (Vector.zip unfinalized_proofs
          inners_should_verify)
    in
    let unfinalized_proofs_extended =
      Vector.extend
        unfinalized_proofs
        lte
        Max_branching.n
        (Unfinalized.Constant.dummy, false)
    in
    let pass_through =
      let f : type a b c. (a, b, c) Prev_proof.t -> b Proof_.Me_only.Dlog_based.t =
        fun t -> 
          t.statement.proof_state.me_only
      in
      let module M = H3.Map2_to_H1(Prev_proof)(Proof_.Me_only.Dlog_based)(struct
          let f = f
        end)
      in
      M.f prev_with_proofs
    in
    let sgs =
      let module M = H3.Map(Prev_proof)(E03(G.Affine))(struct
        let f (t : _ Prev_proof.t) = 
          t.proof.openings.proof.sg
        end)
      in
      let module V = H3.To_vector(G.Affine) in
      V.f 
        prev_values_length
        (M.f prev_with_proofs)
    in
    let me_only : _
        Reduced_me_only.Pairing_based.t =
      (* Have the sg be available in the opening proof and verify it. *)
      { app_state= next_state
      ; sg=
          Vector.extend
            (Vector.mapn
              [ unfinalized_proofs
              ; sgs
              ] ~f:(fun [(u, should_verify); sg] ->
              (* If it "is base case" we should recompute this based on
                the new_bulletproof_challenges
              *)
                if not should_verify then
                  Concrete.compute_sg u.deferred_values.bulletproof_challenges
                else sg ) )
            lte
            Max_branching.n
            (Lazy.force (Unfinalized.Constant.corresponding_dummy_sg))
      }
    in
    { proof_state= {
          unfinalized_proofs=unfinalized_proofs_extended
        ; me_only }
    ; pass_through
    }
  in
  let next_me_only_prepared =
    let T = Nat.eq_exn Max_branching.n (Length.to_nat prev_vars_length) in
    (* TODO The me_only should be extended before hashing! *)
    Reduced_me_only.Pairing_based.prepare
      ~dlog_marlin_index
      next_statement.proof_state.me_only
  in
  let handler (Snarky.Request.With { request; respond}) =
    let k x = respond (Provide x) in
    match request with
    | Req.Prev_proofs ->
      k witnesses
    | Req.Me_only ->
      k 
        { next_me_only_prepared
          with sg= 
                 Vector.trim next_me_only_prepared.sg lte
        }
  in
  let (next_proof : Pairing_based.Proof.t) =
    let (T (input, conv)) =
      Impls.Pairing_based.input
        ~branching:Max_branching.n
        ~bulletproof_log2:Wrap_circuit_bulletproof_rounds.n
    in
    Impls.Pairing_based.prove pk [input]
      (fun x () ->
        ( Impls.Pairing_based.handle
            (fun () : unit ->
              branch_data.main
                ~step_domains
                (conv x) )
            handler
          : unit ) )
      ()
      { proof_state=
          { next_statement.proof_state with
            me_only=
              Common.hash_pairing_me_only
                ~app_state:A_value.to_field_elements
                next_me_only_prepared }
      ; pass_through=
          Vector.extend
            (Vector.map statements_with_hashes ~f:(fun s ->
                s.proof_state.me_only
              ) )
            lte
            Max_branching.n
            (Digest.Constant.of_fp Fp.zero)
      }
  in
  let prev_evals =
    let module M = H3.Map(Prev_proof)(E03(E))(struct
        let f (t : _ Prev_proof.t) = 
          t.proof.openings.evals
      end)
    in
    let module V = H3.To_vector(E) in
    V.f prev_values_length
      (M.f prev_with_proofs)
  in
  { proof= next_proof
  ; statement= next_statement
  ; index= branch_data.index
  ; prev_evals=
      Vector.extend
        (Vector.map2 prev_evals x_hats ~f:(fun es x_hat ->
             triple_zip es x_hat ) )
        lte
        Max_branching.n
        Dummy.evals
  }

end

module type Statement_intf = sig
  type field
  type t
  val to_field_elements : t -> field array
end
module type Statement_var_intf =
  Statement_intf with type field := Impls.Pairing_based.Field.t
module type Statement_value_intf =
  Statement_intf with type field := Fp.t

module Prover = struct
type ('prev_values, 'local_widths, 'local_heights, 'a_value, 'max_branching, 'branches) t =
  ('prev_values, 'local_widths, 'local_heights)
    H3.T(Prev_proof).t
  -> 'a_value
  -> ('a_value, 'max_branching, 'branches) Prev_proof.t
end

module Make(A : Statement_var_intf)(A_value: Statement_value_intf)
= struct
  module IR = Inductive_rule.T(A)(A_value)
  module HIR = H4.T(IR)

  let max_local_max_branchings
    ~self
      (type n) (module Max_branching : Nat.Intf with type n = n)
      branches choices
    =
      let module Local_max_branchings = struct
        type t = (int, Max_branching.n) Vector.t
      end
      in
      let module M = H4.Map(IR)(E04(Local_max_branchings))(struct
          module V = H4.To_vector(Int)
          module HT = H4.T(Tag)
          module M = H4.Map(Tag)(E04(Int))(struct
              let f (type a b c d) (t : (a,b,c,d) Tag.t) : int =
                if Type_equal.Id.same t self 
                then Nat.to_int Max_branching.n
                else
                  let (module M) = Types_map.max_branching t in
                  Nat.to_int M.n
            end)

          let f : type a b c d. (a, b, c, d) IR.t -> Local_max_branchings.t =
            fun rule ->
              let T (_, l) = HT.length rule.prevs in
              Vector.extend_exn
                (V.f l (M.f rule.prevs))
                Max_branching.n
                0
        end)
      in
      let module V = H4.To_vector(Local_max_branchings) in
      let padded = 
        V.f branches (M.f choices)
        |> Vector.transpose
      in
      (padded, Maxes.m padded)

  let pad_pass_throughs
    (type local_max_branchings max_local_max_branchings max_branching)
    (module M
        : Hlist.Maxes.S with type ns =  max_local_max_branchings
                         and type length = max_branching)
    (pass_throughs :
      local_max_branchings H1.T(Proof_.Me_only.Dlog_based).t)
    =
    let dummy_chals =Unfinalized.Constant.dummy.deferred_values.bulletproof_challenges in
    let rec go
      : type len ms ns.
        ms H1.T(Nat).t
        -> ns H1.T(Proof_.Me_only.Dlog_based).t
        -> ms H1.T(Proof_.Me_only.Dlog_based).t
      =
      fun maxes me_onlys ->
        match maxes, me_onlys with
        | [] , _::_ -> assert false
        | [], [] -> []
        | m :: maxes, [] ->
          { pairing_marlin_acc=
              Dummy.pairing_acc
          ; old_bulletproof_challenges=
              Vector.init m ~f:(fun _ -> dummy_chals)
          }
          :: go maxes []
        | m :: maxes, me_only::me_onlys ->
          let me_only =
            { me_only with
              old_bulletproof_challenges =
              Vector.extend_exn
                me_only.old_bulletproof_challenges
                m
                dummy_chals
            }
          in
          me_only :: go maxes me_onlys
    in
    go M.maxes pass_throughs

  let compile
    : type prev_varss prev_valuess widthss heightss max_branching branches.
      branches:(module Nat.Intf with type n = branches)
      -> max_branching:(module Nat.Add.Intf with type n = max_branching)
      -> name:string
      -> typ:(A.t, A_value.t) Impls.Pairing_based.Typ.t
      -> choices:(
        self:(A.t, A_value.t, max_branching, branches) Tag.t
        -> (prev_varss, prev_valuess, widthss, heightss) H4.T(IR).t
      )
      ->
      (A.t, A_value.t, max_branching, branches) Tag.t
        *
      (prev_valuess, widthss, heightss, A_value.t, max_branching, branches) H3_3.T(Prover).t
    =
    fun ~branches:(module Branches) ~max_branching:(module Max_branching) ~name ~typ ~choices  ->
      let T = Max_branching.eq in
    let self = Type_equal.Id.create ~name sexp_of_opaque in
    let choices = choices ~self in
    let T (prev_varss_n, prev_varss_length) =
      HIR.length choices
    in
    let T = Nat.eq_exn prev_varss_n Branches.n in
    let padded, (module Maxes) =
      max_local_max_branchings 
        (module Max_branching)
        prev_varss_length
        choices
        ~self
    in
    let full_signature =
      { Full_signature.padded; maxes= (module Maxes) }
    in
    let wrap_domains =
      let module M = Wrap_domains(A)(A_value) in
      let rec f:  type a b c d.
                (a, b, c, d) H4.T(IR).t
                  ->
                (a, b, c, d) H4.T(M.Prev.I).t
        =
        function
        | [] -> []
        | x :: xs -> x :: f xs
      in
      M.f
        full_signature
        prev_varss_n
        prev_varss_length
        ~self
        ~choices:(f choices)
        ~max_branching:(module Max_branching)
    in
    let module Branch_data = struct
      type ('vars, 'vals, 'n, 'm) t =
        ( A.t, A_value.t,
          Max_branching.n,
          Branches.n,'vars, 'vals, 'n, 'm
        )
        Step_branch_data.t
    end
    in
    let step_data =
      let i = ref 0 in
      let module M = H4.Map(IR)(Branch_data)(struct
          let f : type a b c d. (a, b, c, d) IR.t -> (a, b, c, d) Branch_data.t =
            fun rule ->
              let res = make_step_data
                ~index:(!i)
                ~max_branching:Max_branching.n
                ~branches:Branches.n
                ~self
                ~typ
                A.to_field_elements
                A_value.to_field_elements
                rule
                ~wrap_domains
              in
              incr i;
              res
        end)
      in
      M.f choices
    in
    let step_keypairs =
      let module M = H4.Map(Branch_data)(E04(Impls.Pairing_based.Keypair))(struct
          let etyp =
            Impls.Pairing_based.input
              ~branching:Max_branching.n
              ~bulletproof_log2:Wrap_circuit_bulletproof_rounds.n 

          let f ((T b) : _ Branch_data.t) =
            Core.printf "HIHI %d\n%!" b.index;
            let T (typ, conv) = etyp in
            let main x () = b.main (conv x) in
            Impls.Pairing_based.generate_keypair
              ~exposing:[ typ ]
              main
        end)
      in
        (M.f step_data)
    in
    let step_vks =
      let module V = H4.To_vector(Impls.Pairing_based.Keypair) in
      Vector.map (V.f prev_varss_length step_keypairs)~f:(fun kp ->
          Snarky_bn382_backend.Pairing_based.Keypair.vk_commitments
            (Impls.Pairing_based.Keypair.pk kp))
    in
    let step_domains =
      let module M = H4.Map(Branch_data)(E04(Domains))(struct
          let f ((T b) : _ Branch_data.t) =
            b.domains
        end)
      in
      let module V = H4.To_vector(Domains) in
      V.f
        prev_varss_length
        (M.f step_data)
    in
    check_step_domains step_domains ;
    let wrap_requests, wrap_main =
      let prev_wrap_domains =
        let module M = H4.Map(IR)(H4.T(E04(Domains)))(struct
            let f : type a b c d. (a, b, c, d) IR.t -> (a, b, c, d) H4.T(E04(Domains)).t =
              fun rule ->
                let module M = H4.Map(Tag)(E04(Domains))(struct
                    let f (type a b c d) (t : (a, b, c, d) Tag.t) : Domains.t =
                      Types_map.lookup_map t ~self ~default:wrap_domains
                        ~f:(fun d -> d.wrap_domains)
                  end)
                in
                M.f rule.Inductive_rule.prevs
          end)
        in
        M.f choices
      in
      wrap_main
        full_signature
        prev_varss_length
        step_vks
        step_domains
        prev_wrap_domains
        (module Max_branching)
    in
    let wrap_keypair =
      let T (typ, conv)  =
        Impls.Dlog_based.input ()
      in
      Impls.Dlog_based.generate_keypair
        ~exposing:[typ]
        (fun x () -> wrap_main (conv x))
    in
    let wrap_pk, wrap_vk = Impls.Dlog_based.Keypair.(pk wrap_keypair, vk wrap_keypair) in
    let dlog_marlin_index =
      Snarky_bn382_backend.Dlog_based.Keypair.vk_commitments
        wrap_pk
    in
    let module S = Step(A)(A_value)(Max_branching) in
    let provers =
      let module Z = H4.Zip(Branch_data)(E04(Impls.Pairing_based.Keypair)) in
      let t = Z.f step_data step_keypairs in
      let f : type prev_vars prev_values local_widths local_heights.
        (prev_vars,prev_values,local_widths,local_heights) Branch_data.t
        -> Impls.Pairing_based.Keypair.t
        ->
          ( (prev_values, local_widths, local_heights)
              H3.T(Prev_proof).t
            -> A_value.t 
            -> (A_value.t, Max_branching.n, Branches.n) Prev_proof.t
          )
        =
        fun ((T b) as branch_data) keypair ->
          let (module Requests) = b.requests in
          let step prevs next_state =
            S.f
              branch_data
              next_state
              ~self
              ~step_domains
              ~dlog_marlin_index
              (Impls.Pairing_based.Keypair.pk keypair)
              wrap_vk
              prevs
          in
          let pairing_vk = Impls.Pairing_based.Keypair.vk keypair in
          let wrap prevs next_state =
            let proof = step prevs next_state in
            let proof = 
              { proof with
                statement =
                  { proof.statement with
                    pass_through = pad_pass_throughs
                      (module Maxes)
                      proof.statement.pass_through
                  }
              }
            in
            wrap
              Max_branching.n
              full_signature.maxes
              wrap_requests
              ~dlog_marlin_index
              wrap_main
              A_value.to_field_elements
              ~pairing_vk
              ~step_domains:b.domains
              ~pairing_marlin_indices:step_vks
              ~wrap_domains
              (Impls.Dlog_based.Keypair.pk wrap_keypair)
              proof
          in
          wrap
      in
      let rec go : type xs1 xs2 xs3 xs4.
        (xs1, xs2, xs3, xs4) H4.T(Branch_data).t
        -> (xs1, xs2, xs3, xs4) H4.T(E04(Impls.Pairing_based.Keypair)).t
        -> (xs2, xs3, xs4, A_value.t, Max_branching.n, Branches.n) H3_3.T(Prover).t
           =
           fun bs ks ->
             match bs, ks with
             | [], [] -> []
             | b::bs, k::ks ->
               f b k :: go bs ks
      in
      go step_data step_keypairs
    in
    let data : _ Types_map.Data.t =
      { branches =Branches.n
      ; max_branching=(module Max_branching)
      ; typ
      ; a_value_to_field_elements =A_value.to_field_elements
      ; a_var_to_field_elements   =A.to_field_elements
      ; wrap_key                  =dlog_marlin_index
      ; wrap_vk                   =wrap_vk
      ; wrap_domains              =wrap_domains
      ; step_domains              =step_domains
      }
    in
    Types_map.add_exn self data ;
    (self, provers)
end

let compile
  : type a_var a_value prev_varss prev_valuess widthss heightss max_branching branches.
    (module Statement_var_intf with type t = a_var)
    -> (module Statement_value_intf with type t = a_value)
    -> typ:(a_var, a_value) Impls.Pairing_based.Typ.t
    -> branches:(module Nat.Intf with type n = branches)
    -> max_branching:(module Nat.Add.Intf with type n = max_branching)
    -> name:string
    -> choices:(
      self:(a_var, a_value, max_branching, branches) Tag.t
      -> (prev_varss, prev_valuess, widthss, heightss, a_var, a_value) H4_2.T(Inductive_rule).t
    )
    ->
    (a_var, a_value, max_branching, branches) Tag.t
      *
    (prev_valuess, widthss, heightss, a_value, max_branching, branches) H3_3.T(Prover).t
  =
  fun (module A_var) (module A_value) ~typ ~branches ~max_branching
    ~name ~choices
    ->
      let module M = Make(A_var)(A_value) in
      let rec conv_irs : type v1ss v2ss wss hss.
        (v1ss, v2ss, wss, hss, a_var, a_value) H4_2.T(Inductive_rule).t
        -> (v1ss, v2ss, wss, hss) H4.T(M.IR).t
        =
        function
        | [] -> []
        | r :: rs -> r :: conv_irs rs
      in
      M.compile ~branches ~max_branching ~name ~typ
        ~choices:(fun ~self -> conv_irs (choices ~self))

module Provers = H3_3.T(Prover)

let%test_module "test" =
(module (struct
  open Impls.Pairing_based

  module Txn_snark = struct

    module Statement = struct
      type t = Field.t
      let to_field_elements x = [|x|]
      module Constant = struct
        type t = Field.Constant.t
        let to_field_elements x = [|x|]
      end
    end

    let tag, Provers.[base; merge] =
      compile 
        (module Statement) (module Statement.Constant)
        ~typ:Field.typ
        ~branches:(module Nat.N2)
        ~max_branching:(module Nat.N2)
        ~name:"txn-snark"
        ~choices:(fun ~self ->
            [ { prevs= []
              ; main= (fun [] x ->
                    let t = (Field.is_square x :> Field.t) in
                    for i = 0 to 1000 do
                      assert_r1cs t t t ;
                    done;
                    [])
              ; main_value = (fun [] _ -> [])
              }
            ; { prevs=[ self; self ]
              ; main= (fun [ l; r ] res ->
                    assert_r1cs l r res ;
                    [ Boolean.true_; Boolean.true_ ] )
              ; main_value= (fun _ _ -> [true; true])
              }
            ]  )
  end

  module Blockchain_snark = struct
    module Statement = Txn_snark.Statement

    let tag, Provers.[step] =
      compile 
        (module Statement) (module Statement.Constant)
        ~typ:Field.typ
        ~branches:(module Nat.N1)
        ~max_branching:(module Nat.N2)
        ~name:"blockchain-snark"
        ~choices:(fun ~self ->
            [ { prevs= [self; Txn_snark.tag]
              ; main= (fun [prev; txn_snark] self ->
                    let is_base_case = Field.equal Field.zero self in
                    let proof_should_verify = Boolean.not is_base_case in
                    Field.(Assert.equal (one + prev) self);
                    Boolean.Assert.is_true (Field.is_square txn_snark);
                    [proof_should_verify; proof_should_verify]
                  )
              ; main_value = (fun _ self ->
                  let is_base_case = Field.Constant.(equal zero self) in
                  let proof_should_verify = not is_base_case in
                  [ proof_should_verify; proof_should_verify ])
              }
            ]  )
  end

  let b1 =
    let base1 = Field.Constant.of_int 4 in
    let base2 = Field.Constant.of_int 9 in
    let base12 = Field.Constant.(base1 * base2) in
    let t1 = Txn_snark.base [] base1 in
    let t2 = Txn_snark.base [] base2 in
    let t12 = Txn_snark.merge [t1; t2] base12 in
    let b0 =
      let b_neg_one = failwith "" in
      Blockchain_snark.step
        [ b_neg_one; t12] 
        Field.Constant.zero
    in
    let b1 =
      Blockchain_snark.step
        [ b0; t12] 
        Field.Constant.one
    in
    b1
end))

(* For each thing in prev, should be able to look up a Spec in the map, which will enable us to
   build the pack function for the recursive inputs and thus let us build main. Also will look up
   the list of possible domain sizes which will make it possible to evaluate the polynomials we need to?
*)

(* Associated to each type T is a sequence of rules.
   Let branching_{T,i} be the number of proofs composed in rule i.
   Let max_branching_T = max_i branching_{T, i}.

   Since we want the public inputs for all the rules in T to be the same
   and the public inputs exposes the sgs used internally, our public input
   will have max_branching_T many sgs as well as max_branching_T many "old_bulletproof_challenges".

   Say the composed proofs inside of rule i have types
   A_{i,1}, ..., A_{i, branching_{T, i}}.

   Let local_max_branching_{i, j} = max_branching_{A_{i, j}}.
   It is the "max branching" for the type which is the j^th composed proof in
   rule i.

   Let
   max_local_max_branching_{T, j}
   = max_{i, j <= branching_{T, i}} local_max_branching_{i, j}

   It is the largest local_max_branching in the j^th slot of a branch in the type T.

   max_{j <= branching_{T, i}} local
*)

(* 
   In a branch i, for each of the branching_{T, i} inner proofs,

   After verifying that proof, I get one sg value and one set of corresponding challenges.

   I thus expose branching_{T, i} of each.

   Also, each PC opening j in 1..branching_{T, i} itself includes 
   local_max_branching_{i, j} local old sgs, which then requires
   local_max_branching_{i, j} arrays of old BP challenges.


   Also, to compute the combined inner products
*)

(*
module type Proof_intf = sig
  type statement
  type t [@@deriving bin_io]

  val to_generic : t -> statement Generic_proof.Dlog_based.t
end

module type Prover_intf = sig
  type statement
  type prev_values

  val prove
    :  handler:Snarky.Request.Handler.t
    -> prev_values H1.T(Generic_proof).t
    -> statement
    -> statement Generic_proof.t
end
*)

(*
let (transaction_snark,
     (module Proof : sig type _ t [@@deriving bin_io] end),
     [ (module Base : sig
         val prove
           : handler:Handler.t
           -> (unit, unit, _) H2_1.T(E13_on_second(Proof)).t
           -> TxnSnarkStatement.t 
           -> TxnSnarkStatement.t Proof.t

         val verify
           : TxnSnarkStatement.t Proof.t
           -> Verifiable_component.t list
       end)
     ; (module Merge)
     ]
    )
  =
  let base =
    T ( [], (fun [] stmt -> (failwith "todo", [])), fun _ -> failwith "todo" )
  in
  let merge self  =
    T ( [ self; self ]
      , (fun [ l; r ] stmt -> failwith "todo")
      , (fun [ l; r ] stmt -> failwith "todo") )
  in
  compile (fun ~self ->
    [ T ([
    ] 
    )
*)

