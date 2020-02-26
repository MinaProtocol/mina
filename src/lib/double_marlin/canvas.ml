open Tuple_lib
module D = Digest
open Core_kernel
module Digest = D
open Rugelach_types
open Hlist

open Rugelach_types

(* TODO: Expose prev as a type parmeter so we can use it in the compiled version.
   This compiles to a function prev -> a -> handler -> proof option
*)

(* For each thing in prev, should be able to look up a Spec in the map, which will enable us to
   build the pack function for the recursive inputs and thus let us build main. Also will look up
   the list of possible domain sizes which will make it possible to evaluate the polynomials we need to?
*)


module Prover = struct
  module Const = struct
    type (_, 'bool) t = 'bool
  end

  type ('prevs, _) t =
    | T : 
        ( 'prevs Hlist.HlistId.t
          -> ('prevs, 'proof) Hlist.Hlist2(Const).t
          -> 'a
          -> 'proof ) -> ('prevs, < statement: 'a; proof: 'proof >) t
end

type proof

module Verifiable : sig
  type t

  val verify : t list -> bool
end = struct
  type t 
  let verify _ = failwith ""
end

module type Proof_system_intf = sig
  type statement
  type prev_values

  module Proof : sig
    type t [@@deriving bin_io]

    val to_verifiable : t -> statement -> Verifiable.t
  end

  (* TODO: Handlers as well *)
  val provers
    : (prev_values, < statement: statement; proof: Proof.t >) Hlist.Hlist2(Prover).t
end

module Pairing_index = struct
  type t = Snarky_bn382_backend.G1.Affine.t Abc.t Matrix_evals.t
end

type dlog_index = Snarky_bn382_backend.G.Affine.t Abc.t Matrix_evals.t

open Snarky_bn382_backend

module P = Pairing_main

type fq = Impls.Dlog_based.Field.Constant.t

type g = Snarky_bn382_backend.G.Affine.t
type g1 =
  Impls.Dlog_based.Field.Constant.t * Impls.Dlog_based.Field.Constant.t
[@@deriving sexp, bin_io]


module Wrap_circuit_bulletproof_rounds = Nat.N17
type 'a bp_vec = ('a, Wrap_circuit_bulletproof_rounds.n) Vector.t

type dlog_opening = (fq, g) Types.Pairing_based.Openings.Bulletproof.t

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
        (g, fq) Rugelach_types.Pairing_marlin_types.Messages.t

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
    open Impls.Pairing_based
    type _ t +=
      | Prev_evals :
          (_, _) Request_tag.t ->
          (Field.Constant.t Pairing_marlin_types.Evals.t * Field.Constant.t)
            t
      | Statement
        : (_, 's) Request_tag.t
          -> 
          ( ( Challenge.Constant.t
                  , Snarky_bn382_backend.Fp.t
                  , bool
                  , Snarky_bn382_backend.Fq.t
                  , Digest.Constant.t
                  , Digest.Constant.t )
                  Types.Dlog_based.Proof_state.t
                * 's )
            t
      | Sg_old
        (* TODO: Make 'n a type parameter in the Request_tag somehow *)
        : 'n Nat.t * (_, _) Request_tag.t
          -> (g, 'n) Vector.t t
      | Proof
        : (_, _) Request_tag.t
          -> Dlog_proof.t t
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
        end

      end

module Length_1_to_2(F : T3) = struct
  let rec length1_to_2
    : type n xs ys e.
      (xs, ys, e) H2_1.T(F).t
      -> (xs, n) Length.t
      -> (ys, n) Length.t
    =
    fun xs n ->
      match xs, n with
      | [], Z -> Z
      | _ :: xs, S n -> S (length1_to_2 xs n)
end

let create_request_tags prevs =
    let module M =
      H2_1.Map(E23(Tag))(E23(Request_tag.F))(struct
        let f : type a b. (a, b) Tag.t -> (a, b) Request_tag.F.t =
          fun _ -> Request_tag.create ()
              end)
    in
    M.f prevs

module B = Inductive_rule.B

(* TODO: Pad public input to max_branching *)
let step
  : type length prev_vars prev_values a_var a_value max_branching.

    (module Nat.Add.Intf with type n = max_branching) ->

    length:(prev_vars, length) Hlist.Length.t ->

    lte:(length, max_branching) Nat.Lte.t ->

    univ:Types_map.t ->

    basic: (a_var, a_value) Types_map.Data.basic ->

    self:(a_var, a_value) Tag.t ->
    (prev_vars, prev_values,< statement:a_var ; .. > as 'env)
        Inductive_rule.t
    -> 
    ( ( (Unfinalized.t, max_branching ) Vector.t
       ,
       Impls.Pairing_based.Field.t, ( Impls.Pairing_based.Field.t, max_branching) Vector.t) Types.Pairing_based.Statement.t -> unit
    )
    *
    (prev_vars, prev_values, 'env) H2_1.T(E23(Request_tag.F)).t
  =
  fun (module Max_branching) ~length ~lte ~univ ~basic ~self
    (T (prevs, main, _)) ->
    let module T(F : T2) = struct
      type ('a, 'b) t =
        | Other of ('a, 'b) F.t
        | Self : (a_var, a_value) t
    end
    in
    let module P = H2_1.T(E23(Tag)) in
    let module D = T(Types_map.Data) in
    let module W = T(E02(struct type t = dlog_index end)) in
    let request_tags = create_request_tags prevs in
    let datas =
      let module M =
        H2_1.Map(E23(Tag)) 
          (E23(D))
          (struct
            let f : type a b. (a, b) Tag.t -> (a, b) D.t =
              fun tag ->
              match Type_equal.Id.same_witness self tag with
              | Some T -> D.Self
              | None ->
                let T (other_id, d) = Hashtbl.find_exn univ (Type_equal.Id.uid tag) in
                let T = Type_equal.Id.same_witness_exn tag other_id in
                Other d
        end)
      in
      M.f prevs
    in
    let wrap_keys =
      let module M =
        H2_1.Map (E23(D))
          (E23(W))
          (struct
            let f : type a b. (a, b) D.t -> (a, b)W.t =
              function
              | Self -> Self
              | Other d -> Other d.wrap_key
        end)
      in
      M.f datas
    in
    (* stmt unfinalized length should be max_branching probably, with some
       kind of dummy values... or perhaps that can be handled in the wrap.
    *)
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
      let unfinalized_proofs =
        let module M = H2_1.Of_vector(Unfinalized) in
        let length_values =
          let module L = Length_1_to_2(E23(Request_tag.F)) in
          L.length1_to_2 request_tags length
        in
        M.f
          length length_values
          (Vector.trim stmt.proof_state.unfinalized_proofs
            lte)
      in
      let module Packed_digest = Field in
      let prevs_with_state =
        let tags_and_datas =
          let pass_throughs = 
            let module M =
              H2_1.Of_vector(Packed_digest)
            in
            let length_values =
              let module L = Length_1_to_2(E23(Request_tag.F)) in
              L.length1_to_2 request_tags length
            in
            M.f
              length
              length_values
              (Vector.trim stmt.pass_through
                lte)
          in
          let module Z = H2_1.Zip3(E23(Request_tag.F))(E23(D))(E03(Packed_digest)) in
          Z.f request_tags datas pass_throughs
        in
        let module M =
          H2_1.Map(
            Tuple3
              (E23(Request_tag.F))
              (E23(D))
              (E03(Packed_digest))
          )
            (E13(Prev_statement))
            (struct
              let f : type a b. (a, b, _) Tuple3(E23(Request_tag.F))(E23(D))(E03(Packed_digest)).t
                -> a Prev_statement.t
              =
              fun ((module A), data, me_only) ->
                let typ : (a, b) Impls.Pairing_based.Typ.t =
                  match data with
                  | Self -> basic.typ
                  | Other d -> d.typ
                in
                let state, app_state = 
                  exists ~request:(fun () -> Statement A.T)
                  (Typ.tuple2
                    (Types.Dlog_based.Proof_state.typ Challenge.typ Fp.typ
                      Boolean.typ Fq.typ Digest.typ Digest.typ)
                    typ)
                in
                let me_only = Packed_digest.unpack me_only ~length:Digest.length in
                ({ state with me_only }, app_state)
          end)
        in
        M.f tags_and_datas
      in
      let prev_statements =
        let module M = 
          H2_1.Map(E13(Prev_statement))(Fst)(struct
            let f = snd
            end)
        in
        M.f prevs_with_state
      in
      let prev_proofs_finalized =
        let module M = 
          H2_1.Map(Tuple3(E23(D))(E23(Request_tag.F))(E13(Prev_statement)))(E03(B))(struct
            let f : type a b. ((a, b) D.t * (a, b) Request_tag.F.t * a Prev_statement.t) -> Boolean.var =
              fun (data, (module A), (state, _)) ->
              let prev_evals =
                let open Pairing_marlin_types in
                exists
                  (Typ.tuple2 (Evals.typ Field.typ) Field.typ)
                  ~request:(fun () -> Requests.Step.Prev_evals A.T)
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
                match data with
                | Self -> basic.step_domains
                | Other d -> d.step_domains
              in
              (* Need to get the domain_h and domain_k corresponding to the
                 "step" for this statement. *)
              Pmain.finalize_other_proof
                ~domain_k
                ~domain_h
                ~sponge
                deferred_values
                prev_evals
            end)
        in
        let module Z = 
          H2_1.Zip3(E23(D))(E23(Request_tag.F))(E13(Prev_statement))
        in
        M.f (Z.f datas request_tags prevs_with_state)
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
      let success, proofs_should_verify =
        main prev_statements me_only.app_state
      in
      let open Pairing_main_inputs in
      let open Pmain in
      (*
      let module Proof_result = struct
        type t = Boolean.var * Types.Pairing_based.Proof_state.Per_proof.t
      end in *)
      let prev_proofs =
        let inputs =
          let module Z =
            H2_1.Zip4
              (E23(Request_tag.F))
              (E23(D))
              (E03(Unfinalized))
              (E13(Prev_statement))
          in
          Z.f
            request_tags
            datas
            unfinalized_proofs
            prevs_with_state
        in
        let module M =
          H2_1.Map(
            Tuple4(E23(Request_tag.F))(E23(D))(E03(Unfinalized))(E13(Prev_statement))
          )(
            E03(B)
          )(struct
            let f : type a b. (a, b, _)
                Tuple4(E23(Request_tag.F))(E23(D))(E03(Unfinalized))(E13(Prev_statement)).t -> Boolean.var
              =
              fun ((module A), data, (unfinalized, should_verify), (proof_state, app_state)) ->
                let  (typ : (a, b) Impls.Pairing_based.Typ.t),
                     wrap_key,
                     wrap_domains,
                     (to_field_elements : a -> _),
                     (module Local_max_branching : Nat.Add.Intf)
                  =
                  match data with
                  | Self ->
                    basic.typ, me_only.dlog_marlin_index, basic.wrap_domains, basic.a_var_to_field_elements, 
                    (module Max_branching)
                  | Other d ->
                    d.typ, (Matrix_evals.map ~f:(Abc.map ~f:Pairing_main_inputs.G.constant)) d.wrap_key, d.wrap_domains, d.a_var_to_field_elements,
                    d.max_branching
                in
                let T = Local_max_branching.eq in
                let sg_old =
                  exists ~request:(fun () ->
                      Sg_old (Local_max_branching.n, A.T) )
                    (Vector.typ G.typ Local_max_branching.n)
                in
                let statement =
                  let prev_me_only =
                    (* TODO: Don't rehash when it's not necessary *)
                    unstage(
                    hash_me_only
                      ~index:wrap_key
                      to_field_elements )
                      { app_state
                      ; dlog_marlin_index=wrap_key
                      ; sg=sg_old
                      }
                  in
                  { Types.Dlog_based.Statement.pass_through= prev_me_only
                  ; proof_state
                  }
                in
                (* TODO: Need to assert that the top level me_only.sg at this index is
                   the same as this one. *)
                let (opening, messages) =
                  exists ~request:(fun () -> Proof A.T)
                    (Typ.tuple2
                      (Types.Pairing_based.Openings.Bulletproof.typ
                        ~length:(Nat.to_int Wrap_circuit_bulletproof_rounds.n)
                            Fq.typ
                            Pairing_main_inputs.G.typ)
                      (Rugelach_types.Pairing_marlin_types.Messages.typ
                        Pairing_main_inputs.G.typ
                        Fq.typ))
                in
                Pmain.verify
                  ~branching:(module Local_max_branching)
                  ~wrap_domains
                  ~is_base_case:should_verify
                  ~sg_old
                  ~opening
                  ~messages
                  ~wrap_verification_key:wrap_key
                  statement
                  unfinalized
          end)
        in
        M.f inputs
      in
      let () =
        let bs =
          let module Z =
            H2_1.Zip(E03(B))(E03(B))
          in
          Z.f
            proofs_should_verify
            prev_proofs
        in
        let module M =
          H2_1.Iter(Tuple2(E03(B))(E03(B))) (struct
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
      Impls.Pairing_based.Boolean.Assert.is_true
        success
    in
    (main,
    request_tags)
;;

module Pseudo = struct
  open Impls.Dlog_based

  type ('a, 'n) t = (Boolean.var, 'n) Vector.t * ('a, 'n) Vector.t

  let choose
    : type a n. (a, n) t -> f:(a -> Field.t) -> Field.t
      =
      fun (bits, xs) ~f ->
      Vector.map (Vector.zip bits xs) 
        ~f:(fun (b, x) -> Field.((b :> t) * f x))
      |> Vector.fold ~init:Field.zero ~f:Field.(+)

  module Degree_bound = struct
    type nonrec 'n t = (int, 'n) t

    let shifted_pow ~crs_max_degree t x =
      let pow = Field.(Pcs_batch.pow ~one ~mul ~add) in
      choose t ~f:(fun deg ->
        pow x (crs_max_degree - deg) )
  end

  module Domain = struct
    type nonrec 'n t = (Domain.t, 'n) t

    let to_domain (type n) ( t : n t) : Field.t Marlin_checks.domain =
      (* TODO: Special case when all the domains happen to be the same. *)
      let size =
        Dmain.seal (
        choose t ~f:(fun d ->
          Field.of_int (Domain.size d))) 
      in
      let max_log2 =
        let _, ds = t in
        List.fold (Vector.to_list ds) ~init:0 ~f:(fun acc d ->
            Int.max acc (Domain.log2_size d))
      in
      object
        method size = size
        method vanishing_polynomial x =
          let pow2_pows =
            let res = Array.create ~len:max_log2 x in
            for i = 1 to max_log2 - 1 do
              res.(i) <- Field.square res.(i - 1)
            done;
            res
          in
          let open Field in
          Dmain.seal (
          choose t ~f:(fun d ->
              pow2_pows.(Domain.log2_size d))
          -
          one )
      end
  end
end

let shifts domains =
  List.concat_map domains ~f:(fun (h, k) ->
      Domain.[size h - 1; size k - 1 ])
  |> Int.Set.of_list

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
    (type max_branching)
    (type branches)
    (type prev_varss)
    (type prev_valuess)
    (type env)
    (type max_local_max_branchings)

    (pi_branches : (prev_varss, branches) Hlist.Length.t)

    (pi_max_local_max_branchings : (max_local_max_branchings, max_branching) Hlist.Length.t)
    (actual_branchings_by_slot
     : ( (int, branches) Vector.t, max_branching) Vector.t)
    ( max_local_max_branchings
     : max_local_max_branchings H1.T(Nat).t )

    (step_keys : (Dlog_main_inputs.G1.Constant.t Abc.t Matrix_evals.t, branches) Vector.t)
    (step_domains: (Domains.t, branches) Vector.t)
    (prev_wrap_domains: (prev_varss, prev_valuess, env) H2_1.T(H2_1.T(E03(Domains))).t )
    (module Max_branching : Nat.Add.Intf with type n = max_branching)
  :
      (max_branching 
      , max_local_max_branchings)
      Requests.Wrap.t * 'a
  =
  let T = Max_branching.eq in
  let branches = Hlist.Length.to_nat pi_branches in
  let open Impls.Dlog_based in
  let (module Req) =
    Requests.Wrap.((create () : (max_branching, max_local_max_branchings) t))
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
                 (shifts (Vector.to_list step_domains))
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
        T.f max_local_max_branchings
      in
      let module Z = H1.Zip(Nat)(Challenges_vector) in
      let module M = H1.Map(H1.Tuple2(Nat)(Challenges_vector))(E01(Old_bulletproof_chals))(struct
          let f (type n) ((n, v) : n H1.Tuple2(Nat)(Challenges_vector).t) =
            Old_bulletproof_chals.T (n, v)
        end)
      in
      let module V = H1.To_vector(Old_bulletproof_chals) in
      Z.f max_local_max_branchings
        (exists typ ~request:(fun () -> Req.Old_bulletproof_challenges))
      |> M.f
      |> V.f pi_max_local_max_branchings
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
            (prev_varss, prev_valuess, env)
              H2_1.T(E03(Ds)).t
            =
            let dummy_domains =
              (* TODO: The dummy should really be equal to one of the already present domains. *)
              let d = Domain.Pow_2_roots_of_unity 1 in
              (d, d)
            in
            let module M = H2_1.Map(H2_1.T(E03(Domains)))(E03(Ds))(struct
                module H =H2_1.T(E03(Domains))
                let f : type a b e. (a, b, e)H2_1.T(E03(Domains)).t -> Ds.t =
                  fun domains ->
                    let (T (len, pi)) = H.length domains in
                    let module V = H2_1.To_vector(Domains) in
                    Vector.extend_exn
                      (V.f
                         pi 
                         domains )
                      Max_branching.n
                      dummy_domains
              end)
            in
            M.f prev_wrap_domains
          in
          let ds =
            let module V = H2_1.To_vector(Ds) in
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
          actual_branchings_by_slot
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

module Tags = H2_1.T(E23(Tag))

let rec lengths
  : type prev_varss prev_valuess env.
    (prev_varss, prev_valuess, env) H2_1.T(Inductive_rule).t
    -> (prev_varss, prev_valuess, env) Lengths.t
  =
  function
  | [] -> T []
  | T (prevs, _, _) :: rs ->
    let T lengths = lengths rs in
    let T (_, length) = Tags.length prevs in
    T (length :: lengths)

module Step_data = struct
  (* TODO: Get rid of the vector. Just use an Hlist with an E03 *)
  type ('prev_vars, 'prev_values, 'env, 'max_branching) t =
      T : 
        { branching: 'length Nat.t * ('prev_vars, 'length) Hlist.Length.t
        ; domains: Domains.t
        ; rule: ('prev_vars, 'prev_values, 'env) Inductive_rule.t
        ; main:
          ( ( (Unfinalized.t, 'max_branching ) Vector.t
            ,
            Impls.Pairing_based.Field.t, ( Impls.Pairing_based.Field.t, 'max_branching) Vector.t)
              Types.Pairing_based.Statement.t -> unit
          )
        ; request_tags: ('prev_vars, 'prev_values, 'env) H2_1.T(E23(Request_tag.F)).t
        ; keypair: Impls.Pairing_based.Keypair.t
        } -> ('prev_vars, 'prev_values, 'env, 'max_branching) t
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

module type Pred = sig
  type succ
  type n

  val eq : (succ, n Nat.s) Type_equal.t
end

let pred_exn (type n) (module N : Nat.Intf with type n = n)
  : (module Pred with type succ = n) =
  match N.n with
  | Z -> failwith "pred_exn: Z"
  | S pred ->
    let p : type k. k Nat.t -> (module Pred with type succ = k Nat.s) =
      fun k ->
        let module P = struct
          type n = k
          type succ = k Nat.s
          let eq = Type_equal.T
        end
        in
        (module P)
    in
    p pred

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
            (*
            (( Challenge.Constant.t
            , Fq.t
            , (Challenge.Constant.t, bool) Bulletproof_challenge.t Bp_vector.t
            , Digest.Constant.t )
            Types.Pairing_based.Proof_state.Per_proof.t
            * bool)
            Max_branching_v.t *)
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
      ; prev_evals: Fp.t Pairing_marlin_types.Evals.t
      ; prev_x_hat_beta_1: Fp.t
      ; proof: Dlog_based.Proof.t }
  end
end

module Proof(Max_branching_v :BS1)  = struct
  module Me_only = Reduced_me_only

  module Pairing_based = struct
    type ('s, 'max_local_max_branchings) t =
      ( 's,  (( Challenge.Constant.t
            , Fq.t
            , (Challenge.Constant.t, bool) Bulletproof_challenge.t Bp_vector.t
            , Digest.Constant.t )
            Types.Pairing_based.Proof_state.Per_proof.t
            * bool)
          Max_branching_v.t,
        g Max_branching_v.t,
        'max_local_max_branchings H1.T(Me_only.Dlog_based).t,
        (Fq.t Dlog_marlin_types.Evals.t * Fq.t) Triple.t Max_branching_v.t
      )
      Proof_.Pairing_based.t
  end

  module Dlog_based = struct
    type ('s, 'max_local_max_branchings) t =
      ( 's
      , 'max_local_max_branchings Me_only.Dlog_based.t
      , g Max_branching_v.t)
      Proof_.Dlog_based.t
  end
end

    (*
      { statement:
          ( (( Challenge.Constant.t
            , Fq.t
            , (Challenge.Constant.t, bool) Bulletproof_challenge.t Bp_vector.t
            , Digest.Constant.t )
            Types.Pairing_based.Proof_state.Per_proof.t
            * bool)
            Max_branching_v.t
          , ('s, g Max_branching_v.t ) Me_only.Pairing_based.t
          , 'max_local_max_branchings H1.T(Me_only.Dlog_based).t
          )
          Statement.Pairing_based.t
      ; index: int
      ; prev_evals:
          (Fq.t Dlog_marlin_types.Evals.t * Fq.t) Triple.t Max_branching_v.t
      ; proof: Pairing_based.Proof.t }
       *)
(*     [@@deriving bin_io] *)
(*
      { statement:
          ( Challenge.Constant.t
          , Fp.t
          , bool
          , Fq.t
              (* TODO *)
          , 'max_local_max_branchings Me_only.Dlog_based.t
          , Digest.Constant.t
          , ('s, g Max_branching_v.t) Me_only.Pairing_based.t )
          Statement.Dlog_based.t
      ; prev_evals: Fp.t Pairing_marlin_types.Evals.t
      ; prev_x_hat_beta_1: Fp.t
      ; proof: Dlog_based.Proof.t }
*)
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

module Generic_proof = Proof(List)

let max_local_max_branchings
    (type n) (module Max_branching : Nat.Intf with type n = n) univ branches choices
  =
    let module Local_max_branchings = struct
      type t = (int, Max_branching.n) Vector.t
    end
    in
    let module M = H2_1.Map(Inductive_rule)(E03(Local_max_branchings))(struct
        module V = H2_1.To_vector(Int)
        module HT = H2_1.T(E23(Tag))
        module M = H2_1.Map(E23(Tag))(E03(Int))(struct
            let f t =
              let (module N) = Types_map.max_branching univ t in
              Nat.to_int N.n
          end)

        let f : type a b c. (a, b, c) Inductive_rule.t -> Local_max_branchings.t =
          fun (T (prevs, _, _)) ->
            let T (_, l) = HT.length prevs in
            Vector.extend_exn
              (V.f l (M.f prevs))
              Max_branching.n
              0
      end)
    in
    let module V = H2_1.To_vector(Local_max_branchings) in
    let by_slot = 
      V.f branches (M.f choices)
      |> Vector.transpose
    in
    (by_slot, Maxes.m by_slot)
;;

let make_step_data ~univ ~self ~wrap_domains ~max_branching ~typ to_field_elements (Inductive_rule.T (prevs, _, _) as rule)
  =
    let T (branching, pi) =
      let module H = H2_1.T(E23(Tag)) in
      H.length prevs
    in
    let lte = Nat.lte_exn branching max_branching in
    let step ~step_domains =
      step
        ~basic:{
              typ;
              a_var_to_field_elements=to_field_elements;
              wrap_domains;
              step_domains;
        }
        ~lte
        ~length:pi
        ~univ
        ~self
        (Nat.Add.create max_branching)
        rule
    in
    let etyp =
          Impls.Pairing_based.input
            ~branching:max_branching
            ~bulletproof_log2:Wrap_circuit_bulletproof_rounds.n 
    in
    let step_domains =
      let main, _ =
        step ~step_domains:Fix_domains.rough_domains
      in
      Fix_domains.domains 
        (module Impls.Pairing_based)
        etyp
        main
    in
    let step, tags =
      step ~step_domains
    in
    let keypair =
      let T (typ, conv) = etyp in
      Impls.Pairing_based.generate_keypair
        ~exposing:[typ]
        (fun x () ->
            let y = conv x in
            step
              y)
    in
    Step_data.T { branching= (branching, pi)
                ; rule
      ; domains= step_domains
      ; main=step
      ; request_tags=tags; keypair }

(*
let steps 
    (type a_var a_value)
    to_field_elements
    ~choices
    ~univ
    ~self
    ~typ
    ~wrap_domains
  (type n) ((module Max) as max_branching : n Nat.m)
  : (_, _, _, Max.n) Step_data.t
  =
  let module Env = struct type t = < statement: a_var; statement_constant: a_value > end in
  let module Step_res = struct
    type ('a, 'b, 'c) t = ('a, 'b, 'c, Max.n )Step_data.t
  end
  in
  let module M = H2_1.Map_(Inductive_rule)(Step_res)(Env)(struct
      let f rule =
        make_step_data ~max_branching:Max.n ~univ ~self ~wrap_domains ~typ to_field_elements rule
    end
    )
  in
  M.f choices
;; *)

let prev_wrap_domains ~self ~(univ : Types_map.t) ~choices =
  let module M = H2_1.Map(Inductive_rule)(H2_1.T(E03(Domains)))(struct
      let f : type vars values env.
        (vars, values, env) Inductive_rule.t
        -> (vars, values, env) H2_1.T(E03(Domains)).t
        =
        fun (T (prevs, _, _)) ->
          let module M = H2_1.Map(E23(Tag))(E03(Domains))(struct
              let f : type v x. (v, x) Tag.t -> Domains.t =
                fun t ->
                  match Type_equal.Id.same_witness t self with
                  | Some _ -> Fix_domains.rough_domains
                  | None ->
                    let T (other_id, d) = Hashtbl.find_exn univ (Type_equal.Id.uid t) in
                    let T = Type_equal.Id.same_witness_exn t other_id in
                    d.wrap_domains
            end)
          in
          M.f prevs
    end)
  in
  M.f choices

let wrap_domains
    num_choices choices_length
    pi_max_local_max_branchings
    actual_branchings_by_slot
    max_local_max_branchings
    ~self
    ~univ
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
  let _, main =
    wrap_main
      choices_length
      pi_max_local_max_branchings
      actual_branchings_by_slot
      max_local_max_branchings
      dummy_step_keys
      dummy_step_domains
      (prev_wrap_domains ~self ~univ ~choices)
      max_branching
  in
  Fix_domains.domains (module Impls.Dlog_based)
    (Impls.Dlog_based.input ())
    main
;;

module Generic_proof = struct
  type 'a t = unit
end

module type Proof_intf = sig
  type statement
  type t [@@deriving bin_io]

  val to_generic : t -> statement Generic_proof.t
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
            let reduce = map2 ~f:G1.(+)
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
    ; statement= next_statement
    ; prev_evals= proof.openings.evals
    ; prev_x_hat_beta_1= x_hat_beta_1 }
    : _ Proof_.Dlog_based.t )

let compile
  : type prev_varss prev_valuess a_var a_value spec1 spec2 envv.
    name:string ->
    univ:Types_map.t ->
    typ:(a_var, a_value) Impls.Pairing_based.Typ.t ->
    statement_to_field_elements:(a_var -> Impls.Pairing_based.Field.t array) ->
    spec:(spec1, spec2 , envv) Spec.t ->
    (self:(a_var, a_value) Tag.t
     -> (prev_varss, prev_valuess, < statement:a_var; statement_constant: a_value> as 'env)
      H2_1.T(Inductive_rule).t
    )
    -> _
  =
  fun ~name ~univ ~typ ~statement_to_field_elements ~spec choices ->
  let self = Type_equal.Id.create ~name sexp_of_opaque in
  let choices = choices ~self in
  let T branchings = lengths choices in
  let (module Max_branching) = Hlist.max_exn (Lengths.extract branchings) in
  let max_branching = Nat.Add.create Max_branching.n in
  let module Branching_vector = Nvector(Max_branching) in
  let module Proof0 = Proof(Branching_vector) in
  let module Me_only = Proof0.Me_only in
  let T(branches_n, branches) =
    let module HI = H2_1.T(Inductive_rule) in
    HI.length choices
  in
  let branchings_by_slot, (module Max_local_max_branchings) =
    max_local_max_branchings (module Max_branching) univ branches choices
  in
  let wrap_domains =
    wrap_domains branches_n branches
      Max_local_max_branchings.length
      branchings_by_slot
      Max_local_max_branchings.maxes
      ~self ~univ ~choices ~max_branching
  in
  let module Env = struct type t = < statement: a_var; statement_constant: a_value > end in
  let module Step_res = struct
    type ('a, 'b, 'c) t = ('a, 'b, 'c, Max_branching.n )Step_data.t
  end
  in
  let steps =
    let module M = H2_1.Map_(Inductive_rule)(Step_res)(Env)(struct
        let f rule =
          make_step_data ~max_branching:Max_branching.n ~univ ~self ~wrap_domains ~typ statement_to_field_elements rule
      end
      )
    in
    M.f choices
  in
  let step_provers =
    let module M = H2_1.Map_(Step_res)(Prover)(Env)(struct
      end)
    in
    ()
  in
  ()
;;

module Make
    (Max_branching: Nat.Add.Intf_transparent)
    (Inputs : sig
   type prev_varss type prev_valuess type a_var type a_value
   val name:string
   val univ:Types_map.t
   val typ:(a_var, a_value) Impls.Pairing_based.Typ.t
   val statement_to_field_elements:(a_var -> Impls.Pairing_based.Field.t array)
   val choices : (self:(a_var, a_value) Tag.t
     -> (prev_varss, prev_valuess, < statement:a_var> as 'env)
      H2_1.T(Inductive_rule).t
    )
  end)
    ()
  : sig
    end
= struct

  open Inputs

  let self = Type_equal.Id.create ~name sexp_of_opaque
  let choices = choices ~self

  let branches =
    let module HI = H2_1.T(Inductive_rule) in
    HI.length choices

  module Env = struct type t = < statement: a_var; statement_constant: a_value > end

  let Core_kernel.Type_equal.T = Max_branching.eq

  module Bp_vector = Nvector (Wrap_circuit_bulletproof_rounds)

  module Step_data = Step_data(Max_branching)

  module Branching_vector = Nvector (Max_branching)

  module Proof0 = Proof(Branching_vector)
  module Me_only = Proof0.Me_only

  module Generic_proof = Proof(List)

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

let wrap
    (type max_local_max_branchings)
    (module Req : Requests.Wrap_intf
      with type max_branching = Max_branching.n
       and type max_local_max_branchings = max_local_max_branchings 
    )
    (pi_max_local_max_branchings : (max_local_max_branchings, Max_branching.n) Hlist.Length.t)
    ~dlog_marlin_index
    wrap_main 
    to_field_elements
    (*
    ~wrap_domains ~step_domains ~dlog_marlin_index
    which_index *)
    pairing_vk
    ~step_domains
    ~wrap_domains
    ~pairing_marlin_indices
    pk
    ({ statement=prev_statement 
    ; prev_evals
    ; proof
    ; index=which_index
    } : (_, max_local_max_branchings) Proof0.Pairing_based.t)
  =
  let pairing_marlin_index =
    (Vector.to_array pairing_marlin_indices).(which_index)
  in
  let prev_me_only =
    let module M = H1.Map(Me_only.Dlog_based)(Me_only.Dlog_based.Prepared)(struct
        let f = Me_only.Dlog_based.prepare
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
              (Me_only.Pairing_based.prepare
                 ~dlog_marlin_index
                  prev_statement.proof_state.me_only) }
    ; pass_through=
        (let module M = H1.Map(Me_only.Dlog_based.Prepared)(E01(Digest.Constant))(struct
             let f (type n) (m : n Me_only.Dlog_based.Prepared.t) =
               let T =
                 Nat.eq_exn Nat.N2.n 
                   (Vector.length m.old_bulletproof_challenges)
               in
               Common.hash_dlog_me_only m
          end)
        in
        let module V = H1.To_vector(Digest.Constant) in
        V.f pi_max_local_max_branchings (M.f prev_me_only))
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
      let module M = H1.Map(Me_only.Dlog_based.Prepared)(E01(Pairing_acc))(struct
          let f : type a. a Me_only.Dlog_based.Prepared.t -> Pairing_acc.t =
            fun t -> t.pairing_marlin_acc
        end)
      in
      let module V = H1.To_vector(Pairing_acc) in
      k (V.f pi_max_local_max_branchings (M.f prev_me_only))
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
    public_input_of_statement
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
        let module M = H1.Map_reduce(Proof0.Me_only.Dlog_based)(Pairing_acc.Projective)(struct
            let reduce = map2 ~f:G1.(+)
            let map (t : _ Proof0.Me_only.Dlog_based.t) =
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
    Me_only.Dlog_based.prepare
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
    ; statement= next_statement
    ; prev_evals= proof.openings.evals
    ; prev_x_hat_beta_1= x_hat_beta_1 }
    : _ Proof0.Dlog_based.t )

    let public_input_of_statement prev_statement =
      let input =
        let (T (typ, _conv)) = Impls.Dlog_based.input () in
        Impls.Dlog_based.generate_public_input [typ] prev_statement
      in
      Fq.one :: List.init (Fq.Vector.length input) ~f:(Fq.Vector.get input)

    let b_poly = Fq.(Dlog_main.b_poly ~add ~mul ~inv)

    (* TODO: Exclude the dummy unfinalized proofs. *)

  module Dlog_proof = struct
    type (_, 'value, _) t = 'value Generic_proof.Dlog_based.t
  end

let step (type statement_const statement prev_vars prev_values length)
(*
    (T (tags, _, main) : (prev_vars, prev_values, < statement: statement; statement_constant: statement_const >) Inductive_rule.t)
   *)
    dummy_unfinalized_proof
    (T { branching=(branching, length); rule=T (tags, _, main); request_tags; _ } : (prev_vars, prev_values, < statement: statement; statement_constant: statement_const >) Step_data.t)
    (next_state : statement_const)
      ~univ
      ~to_field_elements
        ~pairing_domains ~dlog_domains ~dlog_marlin_index ~pairing_marlin_index
        pk dlog_vk
        (prev_with_proofs : (prev_vars, prev_values, < statement: statement; statement_constant: statement_const >) H2_1.T(Dlog_proof).t)
        :
          statement
            Proof0.Pairing_based.t =
      let module Env =(struct type t = < statement: statement; statement_constant: statement_const > end) in
    let lte = Nat.lte_exn branching Max_branching.n in
    let (should_verify, inners_should_verify) =
      let prevs =
        let module M = H2_1.Map(Dlog_proof)(Snd)(struct
            let f : type a. a Generic_proof.Dlog_based.t -> a =
              fun s -> s.statement.pass_through.app_state
          end)
        in
        M.f prev_with_proofs
      in
      main
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
      let module T = 
        Tuple3(E03(Unfinalized.Constant))(E03(Statement_with_hashes))(E03(X_hat))
      in
      let unfinalized_proofs, prev_statements_with_hashes, x_hats =
        let module M = 
          H2_1.Map(Tuple2(Dlog_proof)(E23(Tag)))(
        Tuple3(E03(Unfinalized.Constant))(E03(Statement_with_hashes))(E03(X_hat))
                                              )(struct
            let f : type a b c. (a, b, c) Dlog_proof.t * (a, b) Tag.t -> (a, b, c) T.t =
              fun ({statement; prev_evals; prev_x_hat_beta_1; proof}, tag) ->
                let to_field_elements : b -> Fp.t array =
                  Univ.value_to_field_elements univ tag
                in
                let prev_challenges =
                  (* TODO: This is redone in the call to Dlog_based_reduced_me_only.prepare *)
                  Vector.map ~f:Concrete.compute_challenges
                    statement.proof_state.me_only.old_bulletproof_challenges
                in
                let prev_statement_with_hashes : _ Statement.Dlog_based.t =
                  { pass_through=
                      Common.hash_pairing_me_only
                        (Pairing_based_reduced_me_only.prepare ~dlog_marlin_index
                          statement.pass_through)
                        ~app_state:to_field_elements
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
                let module O = Snarky_bn382_backend.Dlog_based.Oracles in
                let o =
                  let public_input =
                    public_input_of_statement
                      prev_statement_with_hashes
                  in
                  O.create dlog_vk
                    Vector.(
                      map2 statement.pass_through.sg prev_challenges
                        ~f:(fun commitment chals ->
                          { Snarky_bn382_backend.Dlog_based_proof
                            .Challenge_polynomial
                            .commitment
                          ; challenges= Vector.to_array chals } )
                      |> to_list)
                    public_input proof
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
                  let e1, e2, e3 = proof.openings.evals in
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
                        (snd (Max_branching.add Nat.N19.n))
                    in
                    let open Fq in
                    let domain_h, domain_k = dlog_domains in
                    Pcs_batch.combine_evaluations
                      (Common.dlog_pcs_batch
                        (Max_branching.add Nat.N19.n)
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
                          { sigma_2= fst proof.messages.sigma_gh_2
                          ; sigma_3= fst proof.messages.sigma_gh_3
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
                , x_hat ) 
          end)
        in
        let module Z = Zip(Dlog_proof)(E23(Tag)) in
        let module U = 
          Unzip3(E03(Unfinalized.Constant))(E03(Statement_with_hashes))(E03(X_hat))
        in
        U.f
          (M.f
            (Z.f prev_with_proofs tags))
      in
      let module U = struct
        type t = Unfinalized.Constant.t * bool 
      end
      in
      let next_statement : _ Statement.Pairing_based.t =
        let unfinalized_proofs =
          let module Z = Zip(E03(Unfinalized.Constant))(E03(Bool)) in
          let module V = Vector_of_hlist(U) in
          let t =
            let module M = H2_1.Map(Tuple2(E03(Unfinalized.Constant))(E03(Bool)))(E03(U))(struct
                let f = Fn.id
              end)
            in
            M.f (Z.f unfinalized_proofs inners_should_verify)
          in
          extend
            (V.f
              length
              t)
            lte
            Max_branching.n
            (dummy_unfinalized_proof, false)
        in
        let me_only : statement_const Pairing_based_reduced_me_only.t =
          (* Have the sg be available in the opening proof and verify it. *)
          { app_state= next_state
          ; sg=
              Vector.mapn [unfinalized_proofs; prev_proofs; inners_should_verify] ~f:(fun [u; p; should_verify] ->
                  (* If it "is base case" we should recompute this based on
               the new_bulletproof_challenges
            *)
                  (* TODO: This is not right. Think harder about what these dummy bits should look like. *)
                  if not should_verify then
                    Concrete.compute_sg u.deferred_values.bulletproof_challenges
                  else p.proof.openings.proof.sg ) }
        in
        { proof_state= {
              unfinalized_proofs
            ; me_only }
        ; pass_through=
            Vector.map prev_proofs ~f:(fun {statement; _} ->
                statement.proof_state.me_only ) }
      in
      let next_me_only_prepared =
        Pairing_based_reduced_me_only.prepare ~dlog_marlin_index
          next_statement.proof_state.me_only
      in
      let module Handler =
      struct type t = Snarky.Request.request -> Snarky.Request.response
      end
      in
      let module Dp = struct type (_, 'value, _) t = 'value dlog_based_proof end in
      let handlers =
        let module Z = Zip(Dp)(E23(Request_tag.F)) in
        let module M = H2_1.Map_(Tuple2(Dp)(E23(Request_tag.F)))(E03(Handler))(Env)(struct
            let f : type a b c. (a, b, c) Dp.t * (a, b) Request_tag.F.t -> Handler.t
              =
              fun (p, (module A)) ->
              fun (Snarky.Request.With { request; respond}) ->
                let open Requests.Step in
                let k x = respond (Provide x ) in
                match request with
                | Prev_evals A.T -> k (p.prev_evals, p.prev_x_hat_beta_1)
                | Statement A.T ->
                  k (
                    p.statement.proof_state
                    , p.statement.pass_through.app_state )
                | Sg_old A.T ->
                  k p.statement.pass_through.sg
          end)
        in

        Z.f
          (H.f
             length
             (L.length1_to_2 request_tags length)
             (trim prev_proofs lte)
          )
          request_tags
      in
      let handler (Snarky.Request.With {request; respond}) =
        let open M.Requests in
        let k x = respond (Provide x) in
        match request with
        | Prev_evals ->
            k
              (Vector.map prev_proofs
                 ~f:(fun {prev_evals; prev_x_hat_beta_1; _} ->
                   (prev_evals, prev_x_hat_beta_1) ))
        | Prev_messages ->
            k (Vector.map prev_proofs ~f:(fun {proof; _} -> proof.messages))
        | Prev_openings_proof ->
            k
              (Vector.map2 prev_proofs next_statement.proof_state.me_only.sg
                 ~f:(fun {proof; _} sg -> {proof.openings.proof with sg}))
        | Prev_states State.Tag ->
            k
              (Vector.map2 prev_proofs prev_statements_with_hashes
                 ~f:(fun prev s ->
                   (s.proof_state, prev.statement.pass_through.app_state) ))
        | Prev_sg ->
            k
              (Vector.map prev_proofs ~f:(fun prev ->
                   prev.statement.pass_through.sg ))
        | Me_only State.Tag ->
            k next_me_only_prepared
        | _ ->
            Snarky.Request.unhandled
      in
      let (next_proof : Pairing_based.Proof.t) =
        let (T (input, conv)) =
          Impls.Pairing_based.input ~branching:Branching.n
            ~bulletproof_log2:Bp_rounds.n
        in
        let domain_h, domain_k = pairing_domains in
        Impls.Pairing_based.prove pk [input]
          (fun x () ->
            ( Impls.Pairing_based.handle
                (fun () : unit ->
                   M.main 
                     ~wrap_domains:(dlog_domains)
                     ~bulletproof_log2:(Nat.to_int Bp_rounds.n) ~domain_h
                    ~domain_k
                    (module State)
                    (conv x) )
                handler
              : unit ) )
          ()
          { proof_state=
              { next_statement.proof_state with
                me_only=
                  Common.hash_pairing_me_only
                    ~app_state:State.Constant.to_field_elements
                    next_me_only_prepared }
          ; pass_through=
              Vector.map prev_statements_with_hashes ~f:(fun s ->
                  s.proof_state.me_only ) }
      in
      { proof= next_proof
      ; statement= next_statement
      ; prev_evals=
          Vector.map2 prev_proofs x_hats ~f:(fun p x_hat ->
              triple_zip p.proof.openings.evals x_hat ) }
end

let compile
  : type prev_varss prev_valuess a_var a_value spec1 spec2 envv.
    name:string ->
    univ:Univ.t ->
    typ:(a_var, a_value) Impls.Pairing_based.Typ.t ->
    statement_to_field_elements:(a_var -> Impls.Pairing_based.Field.t array) ->
    spec:(spec1, spec2 , envv) Spec.t ->
    (self:(a_var, a_value) Tag.t
     -> (prev_varss, prev_valuess, < statement:a_var> as 'env)
      H2_1.T(Inductive_rule).t
    )
    -> 
    (a_var, a_value) Tag.t 
    * (module Proof_system_intf with type statement = a_value
                                 and type prev_values = prev_valuess)
  =
  fun ~name ~univ ~typ ~statement_to_field_elements ~spec choices ->

  let self = Type_equal.Id.create ~name sexp_of_opaque in
  let choices = choices ~self in

  let module Env =(struct type t = < statement: a_var > end) in
  let prev_wrap_domains self_wrap_domains =
    let module M = Map2_1_fixed(Inductive_rule)(H2_1.T(E03(Domains)))(Env)(struct
        let f : type vars values.
          (vars, values, 'a) Inductive_rule.t
          -> (vars, values, 'a) H2_1.T(E03(Domains)).t
          =
          fun (T (prevs, _)) ->
            let module M = Map2_1_fixed(E23(Tag))(E03(Domains))(Env)(struct
                let f : type v x. (v, x) Tag.t -> Domains.t =
                  fun t ->
                    match Type_equal.Id.same_witness t self with
                    | Some T -> self_wrap_domains
                    | None ->
                      let T (other_id, d) = Hashtbl.find_exn univ (Type_equal.Id.uid t) in
                      let T = Type_equal.Id.same_witness_exn t other_id in
                      d.wrap_domains
              end)
            in
            M.f prevs
      end)
    in
    M.f choices
  in
  let T branchings = lengths choices in
  let (module Max) =
    Hlist.max_exn
      (Lengths.extract branchings)
  in
  let max_branching = Nat.Add.create Max.n in
  let module Step_res = Step_data(Max) in
  let module HI = H2_1.T(Inductive_rule) in
  let T (_, choices_length) = HI.length choices in
  let wrap_domains =
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
    let _, main =
      wrap_main
        choices_length
        dummy_step_keys
        dummy_step_domains
        (prev_wrap_domains Fix_domains.rough_domains)
        max_branching
    in
    Fix_domains.domains (module Impls.Dlog_based)
      (Impls.Dlog_based.input ())
      main
  in
  let steps =
    let module M = Map2_1_fixed(Inductive_rule)(Step_res)(Env)(struct
        let f : type prev_vars prev_values.
          (prev_vars, prev_values, 'a) Inductive_rule.t
          ->
          (prev_vars, prev_values, 'a) Step_res.t
          =
          fun (T (prevs, _) as rule) ->
            let T (branching, pi) =
              let module H = H2_1.T(E23(Tag)) in
              H.length prevs
            in
            let lte = Nat.lte_exn branching Max.n in
            let step ~step_domains =
              step
                ~basic:{
                      typ;
                      a_var_to_field_elements=statement_to_field_elements;
                      wrap_domains;
                      step_domains;
                }
                ~lte
                ~length:pi
                ~univ
                ~self
                max_branching
                rule
            in
            let etyp =
                  Impls.Pairing_based.input
                    ~branching:Max.n
                    ~bulletproof_log2:Wrap_circuit_bulletproof_rounds.n 
            in
            let step_domains =
              let main, _ =
                step
                ~step_domains:Fix_domains.rough_domains
              in
              Fix_domains.domains 
                (module Impls.Pairing_based)
                etyp
                main
            in
            let step, tags =
              step ~step_domains
            in
            let keypair =
              let T (typ, conv) = etyp in
              Impls.Pairing_based.generate_keypair
                ~exposing:[typ]
                (fun x () ->
                   let y = conv x in
                   step
                     y)
            in
            T { branching= (branching, pi)
              ; domains= step_domains
              ; main=step
              ; request_tags=tags; keypair }
      end
      )
    in
    M.f choices
  in
  let module T = struct
    type t = Pairing_index.t * Domains.t
  end
  in
  let step_keys, step_domains =
    let module M = Map2_1_fixed(Step_res)(E03(T)) (Env)
        (struct
        let f : type a b. (a, b, Env.t) Step_res.t -> Pairing_index.t * Domains.t =
          fun (T { keypair; domains; _ }) ->
            ( Snarky_bn382_backend.Pairing_based.Keypair.vk_commitments
                (Impls.Pairing_based.Keypair.pk keypair),
              domains )
        end)
    in
    let module H = Vector_of_hlist(T) in
    let module L12 = Length_1_to_2(E03(T)) in
    let vks = M.f steps in
    H.f
      choices_length
      (L12.length1_to_2
         vks
         choices_length)
      vks
    |> Vector.unzip
  in
  let wrap_requests, wrap =
      wrap_main
        choices_length
        step_keys
        step_domains
        (prev_wrap_domains wrap_domains)
        max_branching
  in
  wrap_requests

  (*
  in
  let datas =
    let module M = Map2_1(Inductive_rule)(E23(Univ.Data))(struct
        let f 
  (* Now, the me_onlys will be parametrized over a merkle tree of
     keys of all the choices. *)
  let module T = struct type t = prev_vars end in
  () *)

(*

  ()
*)

(*
    * (prev_values, < statement: a_value; proof: proof >) Hlist.Hlist2(Prover).t
    (module Proof_intf) *
   *)
(*
module Snark_system = struct
  module type S = sig
    type statement

    module Proof : Binable.S

    val step : 'prev 
  end

    val negative_one : State.Constant.t Dlog_based_proof.t

    val step :
         State.Constant.t Dlog_based_proof.t Branching_vector.t
      -> State.Constant.t
      -> State.Constant.t Pairing_based_proof.t

    val wrap :
         State.Constant.t Pairing_based_proof.t
      -> State.Constant.t Dlog_based_proof.t
end *)
(*
      prev
      let module M = Map2_1_fixed(Inductive_rule)(H2_1.T(E03(Domains)))(Env)(struct
          let f : type vars values.
            (vars, values, 'a) Inductive_rule.t
            -> (vars, values, 'a) H2_1.T(E03(Domains)).t
            =
            fun (T (prevs, _)) ->
              let module M = Map2_1_fixed(E23(Tag))(E03(Domains))(Env)(struct
                  let f : type v x. (v, x) Tag.t -> Domains.t =
                    fun t ->
                      match Type_equal.Id.same_witness t self with
                      | Some self -> Fix_domains.rough_domains
                      | None ->
                        let T (other_id, d) = Hashtbl.find_exn univ (Type_equal.Id.uid t) in
                        let T = Type_equal.Id.same_witness_exn t other_id in
                        d.wrap_domains
                end)
              in
              M.f prevs
        end)
      in
      M.f choices
*)
