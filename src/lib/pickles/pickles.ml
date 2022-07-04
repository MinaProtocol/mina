module Endo = Endo
module P = Proof

module type Statement_intf = Intf.Statement

module type Statement_var_intf = Intf.Statement_var

module type Statement_value_intf = Intf.Statement_value

module Common = Common
open Tuple_lib
module Scalar_challenge = Scalar_challenge
module SC = Scalar_challenge
open Core_kernel
open Async_kernel
open Import
open Pickles_types
open Poly_types
open Hlist
open Common
open Backend
module Backend = Backend
module Sponge_inputs = Sponge_inputs
module Util = Util
module Tick_field_sponge = Tick_field_sponge
module Impls = Impls
module Inductive_rule = Inductive_rule
module Tag = Tag
module Types_map = Types_map
module Dirty = Dirty
module Cache_handle = Cache_handle
module Step_main_inputs = Step_main_inputs
module Step_verifier = Step_verifier

let profile_constraints = false

let verify_promise = Verify.verify

let verify max_proofs_verified statement key proofs =
  verify_promise max_proofs_verified statement key proofs |> Promise.to_deferred

(* This file (as you can see from the mli) defines a compiler which turns an inductive
   definition of a set into an inductive SNARK system for proving using those rules.

   The two ingredients we use are two SNARKs.
   - A step based SNARK for a field Fp, using the group G1/Fq (whose scalar field is Fp)
   - A DLOG based SNARK for a field Fq, using the group G/Fp (whose scalar field is Fq)

   For convenience in this discussion, let's define
    (F_0, G_0) := (Fp, G1)
    (F_1, G_1) := (Fq, G)
   So ScalarField(G_i) = F_i and G_i / F_{1-i}.

   An inductive set A is defined by a sequence of inductive rules.
   An inductive rule is intuitively described by something of the form

   a1 ∈ A1, ..., an ∈ An
     f [ a0, ... a1 ] a
   ----------------------
           a ∈ A

   where f is a snarky function defined over an Impl with Field.t = Fp
   and each Ai is itself an inductive rule (possibly equal to A itself).

   We pursue the "step" then "wrap" approach for proof composition.

   The main source of complexity is that we must "wrap" proofs whose verifiers are
   slightly different.

   The main sources of complexity are twofold:
   1. Each SNARK verifier includes group operations and scalar field operations.
      This is problematic because the group operations use the base field, which is
      not equal to the scalar field.

      Schematically, from the circuit point-of-view, we can say a proof is
      - a sequence of F_0 elements xs_0
      - a sequence of F_1 elelements xs_1
      and a verifier is a pair of "snarky functions"
      - check_0 : F_0 list -> F_1 list -> unit which uses the Impl with Field.t = F_0
      - check_1 : F_0 list -> F_1 list -> unit which uses the Impl with Field.t = F_1
      - subset_00 : 'a list -> 'a list
      - subset_01 : 'a list -> 'a list
      - subset_10 : 'a list -> 'a list
      - subset_11 : 'a list -> 'a list
      and a proof verifies if
      ( check_0 (subset_00 xs_0) (subset_01 xs_1)  ;
        check_1 (subset_10 xs_0) (subset_11 xs_1) )

      When verifying a proof, we perform the parts of the verifier involving group operations
      and expose as public input the scalar-field elements we need to perform the final checks.

      In the F_0 circuit, we witness xs_0 and xs_1,
      execute `check_0 (subset_00 xs_0) (subset_01 xs_1)` and
      expose `subset_10 xs_0` and `subset_11 xs_1` as public inputs.

      So the "public inputs" contain within them an "unfinalized proof".

      Then, the next time we verify that proof within an F_1 circuit we "finalize" those
      unfinalized proofs by running `check_1 xs_0_subset xs_1_subset`.

      I didn't implement it exactly this way (although in retrospect probably I should have) but
      that's the basic idea.

      **The complexity this causes:**
      When you prove a rule that includes k recursive verifications, you expose k unfinalized
      proofs. So, the shape of a statement depends on how many "predecessor statements" it has
      or in other words, how many verifications were performed within it.

      Say we have an inductive set given by inductive rules R_1, ... R_n such that
      each rule R_i has k_i predecessor statements.

      In the "wrap" circuit, we must be able to verify a proof coming from any of the R_i.
      So, we must pad the statement for the proof we're wrapping to have `max_i k_i`
      unfinalized proof components.

   2. The verifier for each R_i looks a little different depending on the complexity of the "step"
      circuit corresponding to R_i has. Namely, it is dependent on the "domains" H and K for this
      circuit.

      So, when the "wrap" circuit proves the statement,
      "there exists some index i in 1,...,n and a proof P such that verifies(P)"
      "verifies(P)" must also take the index "i", compute the correct domain sizes correspond to rule "i"
      and use *that* in the "verifies" computation.
*)

let pad_local_max_proofs_verifieds
    (type prev_varss prev_valuess env max_proofs_verified branches)
    (max_proofs_verified : max_proofs_verified Nat.t)
    (length : (prev_varss, branches) Hlist.Length.t)
    (local_max_proofs_verifieds :
      (prev_varss, prev_valuess, env) H2_1.T(H2_1.T(E03(Int))).t ) :
    ((int, max_proofs_verified) Vector.t, branches) Vector.t =
  let module Vec = struct
    type t = (int, max_proofs_verified) Vector.t
  end in
  let module M =
    H2_1.Map
      (H2_1.T
         (E03 (Int))) (E03 (Vec))
         (struct
           module HI = H2_1.T (E03 (Int))

           let f : type a b e. (a, b, e) H2_1.T(E03(Int)).t -> Vec.t =
            fun xs ->
             let (T (_proofs_verified, pi)) = HI.length xs in
             let module V = H2_1.To_vector (Int) in
             let v = V.f pi xs in
             Vector.extend_exn v max_proofs_verified 0
         end)
  in
  let module V = H2_1.To_vector (Vec) in
  V.f length (M.f local_max_proofs_verifieds)

open Kimchi_backend

module Me_only = struct
  module Wrap = Types.Wrap.Proof_state.Me_only
  module Step = Types.Step.Proof_state.Me_only
end

module Proof_ = P.Base
module Proof = P

module Statement_with_proof = struct
  type ('s, 'max_width, _) t =
    (* TODO: use Max local max proofs verified instead of max_width *)
    's * ('max_width, 'max_width) Proof.t
end

let pad_pass_throughs
    (type local_max_proofs_verifieds max_local_max_proofs_verifieds
    max_proofs_verified )
    (module M : Hlist.Maxes.S
      with type ns = max_local_max_proofs_verifieds
       and type length = max_proofs_verified )
    (pass_throughs : local_max_proofs_verifieds H1.T(Proof_.Me_only.Wrap).t) =
  let dummy_chals = Dummy.Ipa.Wrap.challenges in
  let rec go :
      type len ms ns.
         ms H1.T(Nat).t
      -> ns H1.T(Proof_.Me_only.Wrap).t
      -> ms H1.T(Proof_.Me_only.Wrap).t =
   fun maxes me_onlys ->
    match (maxes, me_onlys) with
    | [], _ :: _ ->
        assert false
    | [], [] ->
        []
    | m :: maxes, [] ->
        { challenge_polynomial_commitment = Lazy.force Dummy.Ipa.Step.sg
        ; old_bulletproof_challenges = Vector.init m ~f:(fun _ -> dummy_chals)
        }
        :: go maxes []
    | m :: maxes, me_only :: me_onlys ->
        let me_only =
          { me_only with
            old_bulletproof_challenges =
              Vector.extend_exn me_only.old_bulletproof_challenges m dummy_chals
          }
        in
        me_only :: go maxes me_onlys
  in
  go M.maxes pass_throughs

module Verification_key = struct
  include Verification_key

  module Id = struct
    include Cache.Wrap.Key.Verification

    let dummy_id = Type_equal.Id.(uid (create ~name:"dummy" sexp_of_opaque))

    let dummy : unit -> t =
      let header =
        { Snark_keys_header.header_version = Snark_keys_header.header_version
        ; kind = { type_ = "verification key"; identifier = "dummy" }
        ; constraint_constants =
            { sub_windows_per_window = 0
            ; ledger_depth = 0
            ; work_delay = 0
            ; block_window_duration_ms = 0
            ; transaction_capacity = Log_2 0
            ; pending_coinbase_depth = 0
            ; coinbase_amount = Unsigned.UInt64.of_int 0
            ; supercharged_coinbase_factor = 0
            ; account_creation_fee = Unsigned.UInt64.of_int 0
            ; fork = None
            }
        ; commits = { mina = ""; marlin = "" }
        ; length = 0
        ; commit_date = ""
        ; constraint_system_hash = ""
        ; identifying_hash = ""
        }
      in
      let t = lazy (dummy_id, header, Md5.digest_string "") in
      fun () -> Lazy.force t
  end

  (* TODO: Make async *)
  let load ~cache id =
    Key_cache.Sync.read cache
      (Key_cache.Sync.Disk_storable.of_binable Id.to_string
         (module Verification_key.Stable.Latest) )
      id
    |> Deferred.return
end

module type Proof_intf = sig
  type statement

  type t

  val verification_key : Verification_key.t Lazy.t

  val id : Verification_key.Id.t Lazy.t

  val verify : (statement * t) list -> bool Deferred.t

  val verify_promise : (statement * t) list -> bool Promise.t
end

module Prover = struct
  type ('prev_values, 'local_widths, 'local_heights, 'a_value, 'proof) t =
       ?handler:
         (   Snarky_backendless.Request.request
          -> Snarky_backendless.Request.response )
    -> ( 'prev_values
       , 'local_widths
       , 'local_heights )
       H3.T(Statement_with_proof).t
    -> 'a_value
    -> 'proof
end

module Make
    (Arg_var : Statement_var_intf)
    (Arg_value : Statement_value_intf)
    (Ret_var : T0)
    (Ret_value : T0)
    (Auxiliary_var : T0)
    (Auxiliary_value : T0) =
struct
  module IR =
    Inductive_rule.T (Arg_var) (Arg_value) (Ret_var) (Ret_value) (Auxiliary_var)
      (Auxiliary_value)
  module HIR = H4.T (IR)

  let max_local_max_proofs_verifieds ~self (type n)
      (module Max_proofs_verified : Nat.Intf with type n = n) branches choices =
    let module Local_max_proofs_verifieds = struct
      type t = (int, Max_proofs_verified.n) Vector.t
    end in
    let module M =
      H4.Map (IR) (E04 (Local_max_proofs_verifieds))
        (struct
          module V = H4.To_vector (Int)
          module HT = H4.T (Tag)

          module M =
            H4.Map (Tag) (E04 (Int))
              (struct
                let f (type a b c d) (t : (a, b, c, d) Tag.t) : int =
                  if Type_equal.Id.same t.id self then
                    Nat.to_int Max_proofs_verified.n
                  else
                    let (module M) = Types_map.max_proofs_verified t in
                    Nat.to_int M.n
              end)

          let f :
              type a b c d. (a, b, c, d) IR.t -> Local_max_proofs_verifieds.t =
           fun rule ->
            let (T (_, l)) = HT.length rule.prevs in
            Vector.extend_exn (V.f l (M.f rule.prevs)) Max_proofs_verified.n 0
        end)
    in
    let module V = H4.To_vector (Local_max_proofs_verifieds) in
    let padded = V.f branches (M.f choices) |> Vector.transpose in
    (padded, Maxes.m padded)

  module Lazy_ (A : T0) = struct
    type t = A.t Lazy.t
  end

  module Lazy_keys = struct
    type t =
      (Impls.Step.Keypair.t * Dirty.t) Lazy.t
      * (Kimchi_bindings.Protocol.VerifierIndex.Fp.t * Dirty.t) Lazy.t

    (* TODO Think this is right.. *)
  end

  let log_step main typ name index =
    let module Constraints = Snarky_log.Constraints (Impls.Step.Internal_Basic) in
    let log =
      let weight =
        let sys = Backend.Tick.R1CS_constraint_system.create () in
        fun (c : Impls.Step.Constraint.t) ->
          let prev = sys.next_row in
          List.iter c ~f:(fun { annotation; basic } ->
              Backend.Tick.R1CS_constraint_system.add_constraint sys
                ?label:annotation basic ) ;
          let next = sys.next_row in
          next - prev
      in
      Constraints.log ~weight (Impls.Step.make_checked main)
    in
    if profile_constraints then
      Snarky_log.to_file (sprintf "step-snark-%s-%d.json" name index) log

  let log_wrap main typ name id =
    let module Constraints = Snarky_log.Constraints (Impls.Wrap.Internal_Basic) in
    let log =
      let sys = Backend.Tock.R1CS_constraint_system.create () in
      let weight (c : Impls.Wrap.Constraint.t) =
        let prev = sys.next_row in
        List.iter c ~f:(fun { annotation; basic } ->
            Backend.Tock.R1CS_constraint_system.add_constraint sys
              ?label:annotation basic ) ;
        let next = sys.next_row in
        next - prev
      in
      let log =
        Constraints.log ~weight
          Impls.Wrap.(
            make_checked (fun () : unit ->
                let x = with_label __LOC__ (fun () -> exists typ) in
                main x () ))
      in
      log
    in
    if profile_constraints then
      Snarky_log.to_file
        (sprintf
           !"wrap-%s-%{sexp:Type_equal.Id.Uid.t}.json"
           name (Type_equal.Id.uid id) )
        log

  let compile :
      type var value prev_varss prev_valuess widthss heightss max_proofs_verified branches.
         self:(var, value, max_proofs_verified, branches) Tag.t
      -> cache:Key_cache.Spec.t list
      -> ?disk_keys:
           (Cache.Step.Key.Verification.t, branches) Vector.t
           * Cache.Wrap.Key.Verification.t
      -> branches:(module Nat.Intf with type n = branches)
      -> max_proofs_verified:
           (module Nat.Add.Intf with type n = max_proofs_verified)
      -> name:string
      -> constraint_constants:Snark_keys_header.Constraint_constants.t
      -> public_input:
           ( var
           , value
           , Arg_var.t
           , Arg_value.t
           , Ret_var.t
           , Ret_value.t )
           Inductive_rule.public_input
      -> auxiliary_typ:(Auxiliary_var.t, Auxiliary_value.t) Impls.Step.Typ.t
      -> choices:
           (   self:(var, value, max_proofs_verified, branches) Tag.t
            -> (prev_varss, prev_valuess, widthss, heightss) H4.T(IR).t )
      -> unit
      -> ( prev_valuess
         , widthss
         , heightss
         , Arg_value.t
         , ( Ret_value.t
           * Auxiliary_value.t
           * (max_proofs_verified, max_proofs_verified) Proof.t )
           Promise.t )
         H3_2.T(Prover).t
         * _
         * _
         * _ =
   fun ~self ~cache ?disk_keys ~branches:(module Branches) ~max_proofs_verified
       ~name ~constraint_constants ~public_input ~auxiliary_typ ~choices () ->
    let snark_keys_header kind constraint_system_hash =
      { Snark_keys_header.header_version = Snark_keys_header.header_version
      ; kind
      ; constraint_constants
      ; commits =
          { mina = Mina_version.commit_id
          ; marlin = Mina_version.marlin_commit_id
          }
      ; length = (* This is a dummy, it gets filled in on read/write. *) 0
      ; commit_date = Mina_version.commit_date
      ; constraint_system_hash
      ; identifying_hash =
          (* TODO: Proper identifying hash. *)
          constraint_system_hash
      }
    in
    Timer.start __LOC__ ;
    let module Max_proofs_verified = ( val max_proofs_verified : Nat.Add.Intf
                                         with type n = max_proofs_verified )
    in
    let T = Max_proofs_verified.eq in
    let choices = choices ~self in
    let (T (prev_varss_n, prev_varss_length)) = HIR.length choices in
    let T = Nat.eq_exn prev_varss_n Branches.n in
    let padded, (module Maxes) =
      max_local_max_proofs_verifieds
        ( module struct
          include Max_proofs_verified
        end )
        prev_varss_length choices ~self:self.id
    in
    let full_signature = { Full_signature.padded; maxes = (module Maxes) } in
    Timer.clock __LOC__ ;
    let wrap_domains =
      let module M =
        Wrap_domains.Make (Arg_var) (Arg_value) (Ret_var) (Ret_value)
          (Auxiliary_var)
          (Auxiliary_value)
      in
      let rec f :
          type a b c d. (a, b, c, d) H4.T(IR).t -> (a, b, c, d) H4.T(M.I).t =
        function
        | [] ->
            []
        | x :: xs ->
            x :: f xs
      in
      M.f full_signature prev_varss_n prev_varss_length ~self
        ~choices:(f choices) ~max_proofs_verified
    in
    Timer.clock __LOC__ ;
    let module Branch_data = struct
      type ('vars, 'vals, 'n, 'm) t =
        ( Arg_var.t
        , Arg_value.t
        , Ret_var.t
        , Ret_value.t
        , Auxiliary_var.t
        , Auxiliary_value.t
        , Max_proofs_verified.n
        , Branches.n
        , 'vars
        , 'vals
        , 'n
        , 'm )
        Step_branch_data.t
    end in
    let proofs_verifieds =
      let module M =
        H4.Map (IR) (E04 (Int))
          (struct
            module M = H4.T (Tag)

            let f : type a b c d. (a, b, c, d) IR.t -> int =
             fun r ->
              let (T (n, _)) = M.length r.prevs in
              Nat.to_int n
          end)
      in
      let module V = H4.To_vector (Int) in
      V.f prev_varss_length (M.f choices)
    in
    let step_uses_lookup =
      let rec go :
          type a b c d. (a, b, c, d) H4.T(IR).t -> Plonk_types.Opt.Flag.t =
       fun rules ->
        match rules with
        | [] ->
            No
        | r :: rules -> (
            let rest_usage = go rules in
            match (r.uses_lookup, rest_usage) with
            | true, Yes ->
                Yes
            | false, No ->
                No
            | _, Maybe | true, No | false, Yes ->
                Maybe )
      in
      go choices
    in
    let step_data =
      let i = ref 0 in
      Timer.clock __LOC__ ;
      let module M =
        H4.Map (IR) (Branch_data)
          (struct
            let f :
                type a b c d. (a, b, c, d) IR.t -> (a, b, c, d) Branch_data.t =
             fun rule ->
              Timer.clock __LOC__ ;
              let res =
                Common.time "make step data" (fun () ->
                    Step_branch_data.create ~index:!i ~step_uses_lookup
                      ~max_proofs_verified:Max_proofs_verified.n
                      ~branches:Branches.n ~self ~public_input ~auxiliary_typ
                      Arg_var.to_field_elements Arg_value.to_field_elements rule
                      ~wrap_domains ~proofs_verifieds )
              in
              Timer.clock __LOC__ ; incr i ; res
          end)
      in
      M.f choices
    in
    Timer.clock __LOC__ ;
    let step_domains =
      let module M =
        H4.Map (Branch_data) (E04 (Domains))
          (struct
            let f (T b : _ Branch_data.t) = b.domains
          end)
      in
      let module V = H4.To_vector (Domains) in
      V.f prev_varss_length (M.f step_data)
    in
    let cache_handle = ref (Lazy.return `Cache_hit) in
    let accum_dirty t = cache_handle := Cache_handle.(!cache_handle + t) in
    Timer.clock __LOC__ ;
    let step_keypairs =
      let disk_keys =
        Option.map disk_keys ~f:(fun (xs, _) -> Vector.to_array xs)
      in
      let module M =
        H4.Map (Branch_data) (E04 (Lazy_keys))
          (struct
            let etyp =
              Impls.Step.input ~proofs_verified:Max_proofs_verified.n
                ~wrap_rounds:Tock.Rounds.n ~uses_lookup:Maybe
            (* TODO *)

            let f (T b : _ Branch_data.t) =
              let (T (typ, _conv, conv_inv)) = etyp in
              let main () =
                let res = b.main ~step_domains () in
                Impls.Step.with_label "conv_inv" (fun () -> conv_inv res)
              in
              let () = if true then log_step main typ name b.index in
              let open Impls.Step in
              let k_p =
                lazy
                  (let cs =
                     constraint_system ~exposing:[] ~return_typ:typ main
                   in
                   let cs_hash =
                     Md5.to_hex (R1CS_constraint_system.digest cs)
                   in
                   ( Type_equal.Id.uid self.id
                   , snark_keys_header
                       { type_ = "step-proving-key"
                       ; identifier = name ^ "-" ^ b.rule.identifier
                       }
                       cs_hash
                   , b.index
                   , cs ) )
              in
              let k_v =
                match disk_keys with
                | Some ks ->
                    Lazy.return ks.(b.index)
                | None ->
                    lazy
                      (let id, _header, index, cs = Lazy.force k_p in
                       let digest = R1CS_constraint_system.digest cs in
                       ( id
                       , snark_keys_header
                           { type_ = "step-verification-key"
                           ; identifier = name ^ "-" ^ b.rule.identifier
                           }
                           (Md5.to_hex digest)
                       , index
                       , digest ) )
              in
              let ((pk, vk) as res) =
                Common.time "step read or generate" (fun () ->
                    Cache.Step.read_or_generate cache k_p k_v
                      (Snarky_backendless.Typ.unit ()) typ (fun () -> main) )
              in
              accum_dirty (Lazy.map pk ~f:snd) ;
              accum_dirty (Lazy.map vk ~f:snd) ;
              res
          end)
      in
      M.f step_data
    in
    Timer.clock __LOC__ ;
    let step_vks =
      let module V = H4.To_vector (Lazy_keys) in
      lazy
        (Vector.map (V.f prev_varss_length step_keypairs) ~f:(fun (_, vk) ->
             Tick.Keypair.vk_commitments (fst (Lazy.force vk)) ) )
    in
    Timer.clock __LOC__ ;
    let wrap_requests, wrap_main =
      Timer.clock __LOC__ ;
      let prev_wrap_domains =
        let module M =
          H4.Map (IR) (H4.T (E04 (Domains)))
            (struct
              let f :
                  type a b c d.
                  (a, b, c, d) IR.t -> (a, b, c, d) H4.T(E04(Domains)).t =
               fun rule ->
                let module M =
                  H4.Map (Tag) (E04 (Domains))
                    (struct
                      let f (type a b c d) (t : (a, b, c, d) Tag.t) : Domains.t
                          =
                        Types_map.lookup_map t ~self:self.id
                          ~default:wrap_domains ~f:(function
                          | `Compiled d ->
                              d.wrap_domains
                          | `Side_loaded d ->
                              Common.wrap_domains
                                ~proofs_verified:
                                  ( d.permanent.max_proofs_verified |> Nat.Add.n
                                  |> Nat.to_int ) )
                    end)
                in
                M.f rule.Inductive_rule.prevs
            end)
        in
        M.f choices
      in
      Timer.clock __LOC__ ;
      Wrap_main.wrap_main full_signature prev_varss_length step_vks
        proofs_verifieds step_domains prev_wrap_domains max_proofs_verified
    in
    Timer.clock __LOC__ ;
    let (wrap_pk, wrap_vk), disk_key =
      let open Impls.Wrap in
      let (T (typ, conv, _conv_inv)) = input () in
      let main x () : unit = wrap_main (conv x) in
      let () = if true then log_wrap main typ name self.id in
      let self_id = Type_equal.Id.uid self.id in
      let disk_key_prover =
        lazy
          (let cs =
             constraint_system ~exposing:[ typ ]
               ~return_typ:(Snarky_backendless.Typ.unit ())
               main
           in
           let cs_hash = Md5.to_hex (R1CS_constraint_system.digest cs) in
           ( self_id
           , snark_keys_header
               { type_ = "wrap-proving-key"; identifier = name }
               cs_hash
           , cs ) )
      in
      let disk_key_verifier =
        match disk_keys with
        | None ->
            lazy
              (let id, _header, cs = Lazy.force disk_key_prover in
               let digest = R1CS_constraint_system.digest cs in
               ( id
               , snark_keys_header
                   { type_ = "wrap-verification-key"; identifier = name }
                   (Md5.to_hex digest)
               , digest ) )
        | Some (_, (_id, header, digest)) ->
            Lazy.return (self_id, header, digest)
      in
      let r =
        Common.time "wrap read or generate " (fun () ->
            Cache.Wrap.read_or_generate cache disk_key_prover disk_key_verifier
              typ
              (Snarky_backendless.Typ.unit ())
              main )
      in
      (r, disk_key_verifier)
    in
    Timer.clock __LOC__ ;
    accum_dirty (Lazy.map wrap_pk ~f:snd) ;
    accum_dirty (Lazy.map wrap_vk ~f:snd) ;
    let wrap_vk = Lazy.map wrap_vk ~f:fst in
    let module S =
      Step.Make (Arg_var) (Arg_value)
        (struct
          include Max_proofs_verified
        end)
    in
    let (typ : (var, value) Impls.Step.Typ.t) =
      match public_input with
      | Input typ ->
          typ
      | Output typ ->
          typ
      | Input_and_output (input_typ, output_typ) ->
          Impls.Step.Typ.(input_typ * output_typ)
    in
    let provers =
      let module Z = H4.Zip (Branch_data) (E04 (Impls.Step.Keypair)) in
      let f :
          type prev_vars prev_values local_widths local_heights.
             (prev_vars, prev_values, local_widths, local_heights) Branch_data.t
          -> Lazy_keys.t
          -> ?handler:
               (   Snarky_backendless.Request.request
                -> Snarky_backendless.Request.response )
          -> ( prev_values
             , local_widths
             , local_heights )
             H3.T(Statement_with_proof).t
          -> Arg_value.t
          -> ( Ret_value.t
             * Auxiliary_value.t
             * (Max_proofs_verified.n, Max_proofs_verified.n) Proof.t )
             Promise.t =
       fun (T b as branch_data) (step_pk, step_vk) ->
        let (module Requests) = b.requests in
        let _, prev_vars_length = b.proofs_verified in
        let step handler prev_values prev_proofs next_state =
          let wrap_vk = Lazy.force wrap_vk in
          S.f ?handler branch_data next_state ~prevs_length:prev_vars_length
            ~self ~step_domains ~self_dlog_plonk_index:wrap_vk.commitments
            ~public_input ~auxiliary_typ
            ~uses_lookup:(if b.rule.uses_lookup then Yes else No)
            (Impls.Step.Keypair.pk (fst (Lazy.force step_pk)))
            wrap_vk.index prev_values prev_proofs
        in
        let step_vk = fst (Lazy.force step_vk) in
        let wrap ?handler prevs next_state =
          let wrap_vk = Lazy.force wrap_vk in
          let app_states, prevs =
            let rec go :
                type prev_values local_widths local_heights.
                   ( prev_values
                   , local_widths
                   , local_heights )
                   H3.T(Statement_with_proof).t
                -> prev_values H1.T(Id).t
                   * (local_widths, local_widths) H2.T(Proof).t = function
              | [] ->
                  ([], [])
              | (app_state, proof) :: tl ->
                  let app_states, proofs = go tl in
                  (app_state :: app_states, proof :: proofs)
            in
            go prevs
          in
          let%bind.Promise proof, return_value, auxiliary_value =
            step handler ~maxes:(module Maxes) app_states prevs next_state
          in
          let proof =
            { proof with
              statement =
                { proof.statement with
                  pass_through =
                    pad_pass_throughs
                      (module Maxes)
                      proof.statement.pass_through
                }
            }
          in
          let%map.Promise proof =
            Wrap.wrap ~max_proofs_verified:Max_proofs_verified.n
              full_signature.maxes wrap_requests
              ~dlog_plonk_index:wrap_vk.commitments wrap_main ~typ ~step_vk
              ~step_plonk_indices:(Lazy.force step_vks) ~wrap_domains
              (Impls.Wrap.Keypair.pk (fst (Lazy.force wrap_pk)))
              proof
          in
          ( return_value
          , auxiliary_value
          , Proof.T
              { proof with
                statement =
                  { proof.statement with
                    pass_through =
                      { proof.statement.pass_through with app_state = () }
                  }
              } )
        in
        wrap
      in
      let rec go :
          type xs1 xs2 xs3 xs4 xs5 xs6.
             (xs1, xs2, xs3, xs4) H4.T(Branch_data).t
          -> (xs1, xs2, xs3, xs4) H4.T(E04(Lazy_keys)).t
          -> ( xs2
             , xs3
             , xs4
             , Arg_value.t
             , ( Ret_value.t
               * Auxiliary_value.t
               * (max_proofs_verified, max_proofs_verified) Proof.t )
               Promise.t )
             H3_2.T(Prover).t =
       fun bs ks ->
        match (bs, ks) with
        | [], [] ->
            []
        | b :: bs, k :: ks ->
            f b k :: go bs ks
      in
      go step_data step_keypairs
    in
    Timer.clock __LOC__ ;
    let data : _ Types_map.Compiled.t =
      { branches = Branches.n
      ; proofs_verifieds
      ; max_proofs_verified
      ; public_input = typ
      ; wrap_key = Lazy.map wrap_vk ~f:Verification_key.commitments
      ; wrap_vk = Lazy.map wrap_vk ~f:Verification_key.index
      ; wrap_domains
      ; step_domains
      ; step_uses_lookup
      }
    in
    Timer.clock __LOC__ ;
    Types_map.add_exn self data ;
    (provers, wrap_vk, disk_key, !cache_handle)
end

module Side_loaded = struct
  module V = Verification_key

  module Verification_key = struct
    include Side_loaded_verification_key

    let to_input (t : t) =
      to_input ~field_of_int:Impls.Step.Field.Constant.of_int t

    let of_compiled tag : t =
      let d = Types_map.lookup_compiled tag.Tag.id in
      { wrap_vk = Some (Lazy.force d.wrap_vk)
      ; wrap_index = Lazy.force d.wrap_key
      ; max_proofs_verified =
          Pickles_base.Proofs_verified.of_nat (Nat.Add.n d.max_proofs_verified)
      }

    module Max_width = Width.Max
  end

  let in_circuit tag vk = Types_map.set_ephemeral tag { index = `In_circuit vk }

  let in_prover tag vk = Types_map.set_ephemeral tag { index = `In_prover vk }

  let create ~name ~max_proofs_verified ~uses_lookup ~typ =
    Types_map.add_side_loaded ~name
      { max_proofs_verified
      ; public_input = typ
      ; branches = Verification_key.Max_branches.n
      ; step_uses_lookup = uses_lookup
      }

  module Proof = struct
    include Proof.Proofs_verified_max

    let of_proof : _ Proof.t -> t = Wrap_hack.pad_proof
  end

  let verify_promise (type t) ~(typ : (_, t) Impls.Step.Typ.t)
      (ts : (Verification_key.t * t * Proof.t) list) =
    let m =
      ( module struct
        type nonrec t = t

        let to_field_elements =
          let (Typ typ) = typ in
          fun x -> fst (typ.value_to_fields x)
      end : Intf.Statement_value
        with type t = t )
    in
    (* TODO: This should be the actual max width on a per proof basis *)
    let max_proofs_verified =
      (module Verification_key.Max_width : Nat.Intf
        with type n = Verification_key.Max_width.n )
    in
    with_return (fun { return } ->
        List.map ts ~f:(fun (vk, x, p) ->
            let vk : V.t =
              { commitments = vk.wrap_index
              ; index =
                  ( match vk.wrap_vk with
                  | None ->
                      return (Promise.return false)
                  | Some x ->
                      x )
              ; data =
                  (* This isn't used in verify_heterogeneous, so we can leave this dummy *)
                  { constraints = 0 }
              }
            in
            Verify.Instance.T (max_proofs_verified, m, vk, x, p) )
        |> Verify.verify_heterogenous )

  let verify ~typ ts = verify_promise ~typ ts |> Promise.to_deferred

  let srs_precomputation () : unit =
    let srs = Tock.Keypair.load_urs () in
    List.iter [ 0; 1; 2 ] ~f:(fun i ->
        Kimchi_bindings.Protocol.SRS.Fq.add_lagrange_basis srs
          (Domain.log2_size (Common.wrap_domains ~proofs_verified:i).h) )
end

let compile_promise :
    type var value a_var a_value ret_var ret_value auxiliary_var auxiliary_value prev_varss prev_valuess prev_ret_varss prev_ret_valuess widthss heightss max_proofs_verified branches.
       ?self:(var, value, max_proofs_verified, branches) Tag.t
    -> ?cache:Key_cache.Spec.t list
    -> ?disk_keys:
         (Cache.Step.Key.Verification.t, branches) Vector.t
         * Cache.Wrap.Key.Verification.t
    -> (module Statement_var_intf with type t = a_var)
    -> (module Statement_value_intf with type t = a_value)
    -> public_input:
         ( var
         , value
         , a_var
         , a_value
         , ret_var
         , ret_value )
         Inductive_rule.public_input
    -> auxiliary_typ:(auxiliary_var, auxiliary_value) Impls.Step.Typ.t
    -> branches:(module Nat.Intf with type n = branches)
    -> max_proofs_verified:
         (module Nat.Add.Intf with type n = max_proofs_verified)
    -> name:string
    -> constraint_constants:Snark_keys_header.Constraint_constants.t
    -> choices:
         (   self:(var, value, max_proofs_verified, branches) Tag.t
          -> ( prev_varss
             , prev_valuess
             , widthss
             , heightss
             , a_var
             , a_value
             , ret_var
             , ret_value
             , auxiliary_var
             , auxiliary_value )
             H4_6.T(Inductive_rule).t )
    -> (var, value, max_proofs_verified, branches) Tag.t
       * Cache_handle.t
       * (module Proof_intf
            with type t = (max_proofs_verified, max_proofs_verified) Proof.t
             and type statement = value )
       * ( prev_valuess
         , widthss
         , heightss
         , a_value
         , ( ret_value
           * auxiliary_value
           * (max_proofs_verified, max_proofs_verified) Proof.t )
           Promise.t )
         H3_2.T(Prover).t =
 fun ?self ?(cache = []) ?disk_keys (module A_var) (module A_value)
     ~public_input ~auxiliary_typ ~branches ~max_proofs_verified ~name
     ~constraint_constants ~choices ->
  let self =
    match self with
    | None ->
        { Tag.id = Type_equal.Id.create ~name sexp_of_opaque; kind = Compiled }
    | Some self ->
        self
  in
  let module Ret_var = struct
    type t = ret_var
  end in
  let module Ret_value = struct
    type t = ret_value
  end in
  let module Auxiliary_var = struct
    type t = auxiliary_var
  end in
  let module Auxiliary_value = struct
    type t = auxiliary_value
  end in
  let module M =
    Make (A_var) (A_value) (Ret_var) (Ret_value) (Auxiliary_var)
      (Auxiliary_value)
  in
  let rec conv_irs :
      type v1ss v2ss v3ss v4ss wss hss.
         ( v1ss
         , v2ss
         , wss
         , hss
         , a_var
         , a_value
         , ret_var
         , ret_value
         , auxiliary_var
         , auxiliary_value )
         H4_6.T(Inductive_rule).t
      -> (v1ss, v2ss, wss, hss) H4.T(M.IR).t = function
    | [] ->
        []
    | r :: rs ->
        r :: conv_irs rs
  in
  let provers, wrap_vk, wrap_disk_key, cache_handle =
    M.compile ~self ~cache ?disk_keys ~branches ~max_proofs_verified ~name
      ~public_input ~auxiliary_typ ~constraint_constants
      ~choices:(fun ~self -> conv_irs (choices ~self))
      ()
  in
  let (module Max_proofs_verified) = max_proofs_verified in
  let T = Max_proofs_verified.eq in
  let module Value = struct
    type t = value

    let typ : (var, value) Impls.Step.Typ.t =
      match public_input with
      | Input typ ->
          typ
      | Output typ ->
          typ
      | Input_and_output (input_typ, output_typ) ->
          Impls.Step.Typ.(input_typ * output_typ)

    let to_field_elements =
      let (Typ typ) = typ in
      fun x -> fst (typ.value_to_fields x)
  end in
  let module P = struct
    type statement = value

    type return_type = ret_value

    module Max_local_max_proofs_verified = Max_proofs_verified

    module Max_proofs_verified_vec = Nvector (struct
      include Max_proofs_verified
    end)

    include
      Proof.Make
        (struct
          include Max_proofs_verified
        end)
        (struct
          include Max_local_max_proofs_verified
        end)

    let id = wrap_disk_key

    let verification_key = wrap_vk

    let verify_promise ts =
      verify_promise
        ( module struct
          include Max_proofs_verified
        end )
        (module Value)
        (Lazy.force verification_key)
        ts

    let verify ts = verify_promise ts |> Promise.to_deferred

    let statement (T p : t) = p.statement.pass_through.app_state
  end in
  (self, cache_handle, (module P), provers)

let compile ?self ?cache ?disk_keys a_var a_value ~public_input ~auxiliary_typ
    ~branches ~max_proofs_verified ~name ~constraint_constants ~choices =
  let self, cache_handle, proof_module, provers =
    compile_promise ?self ?cache ?disk_keys a_var a_value ~public_input
      ~auxiliary_typ ~branches ~max_proofs_verified ~name ~constraint_constants
      ~choices
  in
  let rec adjust_provers :
      type a1 a2 a3 a4 s1 s2_inner.
         (a1, a2, a3, s1, s2_inner Promise.t) H3_2.T(Prover).t
      -> (a1, a2, a3, s1, s2_inner Deferred.t) H3_2.T(Prover).t = function
    | [] ->
        []
    | prover :: tl ->
        (fun ?handler stmt_with_proof public_input ->
          Promise.to_deferred (prover ?handler stmt_with_proof public_input) )
        :: adjust_provers tl
  in
  (self, cache_handle, proof_module, adjust_provers provers)

module Provers = H3_2.T (Prover)
module Proof0 = Proof

let%test_module "test no side-loaded" =
  ( module struct
    let () = Tock.Keypair.set_urs_info []

    let () = Tick.Keypair.set_urs_info []

    (*
    let%test_unit "test deserialization and verification for side-loaded keys" =
      Side_loaded.srs_precomputation () ;
      let pi =
        match
          "KChzdGF0ZW1lbnQoKHByb29mX3N0YXRlKChkZWZlcnJlZF92YWx1ZXMoKHBsb25rKChhbHBoYSgoaW5uZXIoNTI4Y2RiZjE2NzA4YTUzYSAxZjkwYTdlZWEyZTA2ZjZhKSkpKShiZXRhKDYxN2U1YTdmZDZiZTM2NmEgZGUxOTcxMjJhNDQxNTE3NSkpKGdhbW1hKDNjYTM1ZDQ0NTIxODFjOTkgMTBmMDg1NDBiYTYxYjBlYykpKHpldGEoKGlubmVyKDliOWNiM2ViODlmOTk4NjAgZmMzZjJhNTU2YjNkYTNiOCkpKSkpKShjb21iaW5lZF9pbm5lcl9wcm9kdWN0KFNoaWZ0ZWRfdmFsdWUgMHgwODIzRTU2NzkzQjU1OTI2MTRBREJBNEQwRTVGRTcxODJDMzYwNTlFRkE2N0I2MkZGMzQ4QzI5ODAyNUVEM0IxKSkoYihTaGlmdGVkX3ZhbHVlIDB4MTVFNkU1ODMwODhGMzgzOUEwQTI0QkEwOTYwNThEMzExRjgwRTYzREM3QzVGOTY5NjFFREYwRTg0MzFCM0E4OSkpKHhpKChpbm5lcig1Yzc4YjUxMDZkYzkxOTZiIGRkOTIzNjA4ZjNhMmQ3YzcpKSkpKGJ1bGxldHByb29mX2NoYWxsZW5nZXMoKChwcmVjaGFsbGVuZ2UoKGlubmVyKDAyNzdmNmFhZDlkODM1YTUgZDdjZTY0NGFmMWUwYTYyMykpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDcxNTVjOGNhMjcwODkwYTkgODgyMTBlZjUwNWQ3NDYzYSkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDY2ZGQwOWNmOGM3NjdjYTggNDlhMWYzZjBkMDJjMjdkMSkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKGIzYWY1YjdmZmY3N2QzZGQgN2UzZDUzYjJkNjk5ZDIxMCkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDFhNzAzNDcyMmYzOWM2ODAgZGFjMGI5MjA3MTBhM2JhZikpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDMxYTM5MTk2M2ExZWRhMjIgMTc2OGY5NjNmZGEzMGRiZCkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKGNhNjk3N2JjMmNkMDhmMDIgOGNjYTA4MGEzZWVhOTFkZSkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKGNhMWM0NDU5YzZkYjkwZTAgNWRjOTc0NDQyMjQ2OTJiOCkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDVhODY5MWZlOTM4ZDc3NjYgZmZhN2I3NmQ1MDU0NTMwMCkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKGUyOGE2YmQ3ODg1ZTJkY2UgY2ZmYzcxMGZkMDIzZmNmMikpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDY3YzljYWNkYmVjMTAxNTIgZGJiYmIxNzQ0NjUxNGNkYykpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKGI5NjI2OTBkNGM2MTQ3ZmUgMDQ3ZWQyYjY0MzJhZTlhOCkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKDI0N2EzYzAyNmZkNDJhMWYgMzBmZmQzZWIyZTkyZjZlMCkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKGZiMDQwYTVmN2FlMTY4MmEgNjdlODhjMDNiNDY0MjlmYikpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKGRhN2FhZWI5OTE0MmQ0OTAgZTZkZjFlZjJhMjdiZDVkZCkpKSkpKChwcmVjaGFsbGVuZ2UoKGlubmVyKGM5NTkwYmEyZDY1ZTc3NGMgNjUxM2JlOTc2ZGJiZDAxNCkpKSkpKSkoYnJhbmNoX2RhdGEoKHByb29mc192ZXJpZmllZCBOMCkoZG9tYWluX2xvZzIiXG4iKSkpKSkoc3BvbmdlX2RpZ2VzdF9iZWZvcmVfZXZhbHVhdGlvbnMoMzQ1YmNhODlhMThiZTZlYiAzMmIzMmJlYTk4NTNjZTUxIGU0Yjc4YmQwOWJiYjY4YTUgMGM2NzkxZmIwOGUwY2E1NykpKG1lX29ubHkoKGNoYWxsZW5nZV9wb2x5bm9taWFsX2NvbW1pdG1lbnQoMHgwRjY5QjY1QTU4NTVGM0EzOThEMERGRDBDMTMxQjk2MTJDOUYyMDYxRDJGMDZFNjc2RjYxMkM0OEQ4MjdFMUU2IDB4MENDQUYzRjAzRjlEMkMzQzNENDRFMDlBMTIxMDY5MTFGQTY5OURGOTM0RjcwNkU2MjEzMUJBRDYzOUYzMDE1NSkpKG9sZF9idWxsZXRwcm9vZl9jaGFsbGVuZ2VzKCgoKHByZWNoYWxsZW5nZSgoaW5uZXIoMzM4MmIzYzlhY2U2YmY2ZiA3OTk3NDM1OGY5NzYxODYzKSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoZGQzYTJiMDZlOTg4ODc5NyBkZDdhZTY0MDI5NDRhMWM3KSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoYzZlOGU1MzBmNDljOWZjYiAwN2RkYmI2NWNkYTA5Y2RkKSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoNTMyYzU5YTI4NzY5MWExMyBhOTIxYmNiMDJhNjU2ZjdiKSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoZTI5Yzc3YjE4ZjEwMDc4YiBmODVjNWYwMGRmNmIwY2VlKSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoMWRiZGE3MmQwN2IwOWM4NyA0ZDFiOTdlMmU5NWYyNmEwKSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoOWM3NTc0N2M1NjgwNWYxMSBhMWZlNjM2OWZhY2VmMWU4KSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoNWMyYjhhZGZkYmU5NjA0ZCA1YThjNzE4Y2YyMTBmNzliKSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoMjJjMGIzNWM1MWUwNmI0OCBhNjg4OGI3MzQwYTk2ZGVkKSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoOTAwN2Q3YjU1ZTc2NjQ2ZSBjMWM2OGIzOWRiNGU4ZTEyKSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoNDQ0NWUzNWUzNzNmMmJjOSA5ZDQwYzcxNWZjOGNjZGU1KSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoNDI5ODgyODQ0YmJjYWE0ZSA5N2E5MjdkN2QwYWZiN2JjKSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoOTljYTNkNWJmZmZkNmU3NyBlZmU2NmE1NTE1NWM0Mjk0KSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoNGI3ZGIyNzEyMTk3OTk1NCA5NTFmYTJlMDYxOTNjODQwKSkpKSkoKHByZWNoYWxsZW5nZSgoaW5uZXIoMmNkMWNjYmViMjA3NDdiMyA1YmQxZGUzY2YyNjQwMjFkKSkpKSkpKCgocHJlY2hhbGxlbmdlKChpbm5lcigzMzgyYjNjOWFjZTZiZjZmIDc5OTc0MzU4Zjk3NjE4NjMpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcihkZDNhMmIwNmU5ODg4Nzk3IGRkN2FlNjQwMjk0NGExYzcpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcihjNmU4ZTUzMGY0OWM5ZmNiIDA3ZGRiYjY1Y2RhMDljZGQpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcig1MzJjNTlhMjg3NjkxYTEzIGE5MjFiY2IwMmE2NTZmN2IpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcihlMjljNzdiMThmMTAwNzhiIGY4NWM1ZjAwZGY2YjBjZWUpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcigxZGJkYTcyZDA3YjA5Yzg3IDRkMWI5N2UyZTk1ZjI2YTApKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcig5Yzc1NzQ3YzU2ODA1ZjExIGExZmU2MzY5ZmFjZWYxZTgpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcig1YzJiOGFkZmRiZTk2MDRkIDVhOGM3MThjZjIxMGY3OWIpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcigyMmMwYjM1YzUxZTA2YjQ4IGE2ODg4YjczNDBhOTZkZWQpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcig5MDA3ZDdiNTVlNzY2NDZlIGMxYzY4YjM5ZGI0ZThlMTIpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcig0NDQ1ZTM1ZTM3M2YyYmM5IDlkNDBjNzE1ZmM4Y2NkZTUpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcig0Mjk4ODI4NDRiYmNhYTRlIDk3YTkyN2Q3ZDBhZmI3YmMpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcig5OWNhM2Q1YmZmZmQ2ZTc3IGVmZTY2YTU1MTU1YzQyOTQpKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcig0YjdkYjI3MTIxOTc5OTU0IDk1MWZhMmUwNjE5M2M4NDApKSkpKSgocHJlY2hhbGxlbmdlKChpbm5lcigyY2QxY2NiZWIyMDc0N2IzIDViZDFkZTNjZjI2NDAyMWQpKSkpKSkpKSkpKSkocGFzc190aHJvdWdoKChhcHBfc3RhdGUoKSkoY2hhbGxlbmdlX3BvbHlub21pYWxfY29tbWl0bWVudHMoKSkob2xkX2J1bGxldHByb29mX2NoYWxsZW5nZXMoKSkpKSkpKHByZXZfZXZhbHMoKGV2YWxzKCgocHVibGljX2lucHV0IDB4MUQ1MDUwQUJDMTkzRkQ4Mjg4RkU4QjA5REE5QTJBQThDNEE5NUU3OTZDMzNERkI3MTJFOENDQUQ3MzY3MjY2QSkoZXZhbHMoKHcoKDB4MkMzM0MxNzNCREU5MzQwQkU5NDFFQ0QyMDlBQjZFOTlFQ0E4QkRDQTFDQThCREE4REFDM0U0MEMzMzE1RjY5NikoMHgwMkFFOTI5NjgzNDREMUY1OTYwM0JBMDE1QzI5RDc4MDE4OTdGNkI1OUU1RUQ0M0EzQkVFMzE2RDZBODc2QzNCKSgweDNENEZERDI0MDI4NEYwOTZCMEQ5Q0U0MDVDMjAxNkU3Q0FFNDk5MzFEMDU3MUYyN0RBN0EzRERCMjAyRkM0MzcpKDB4MUQ4QTlBMTdBQkRGRjU5NzU4MzJCMkVBNEFFQjk0QkFERTYzNDZBNTU0RUIyNEE1MUIzRUNGRjU2MEQzMzc0OCkoMHgzNkY4MDZGMDQzRDhGMzNGN0ZEODk3MzBGQjY5RTVEQUYzMjNFODYzN0QyM0Q5NTY5NDY2NUFCMUIyOUFEMTk0KSgweDIxQ0U2NzdFOTQxNjc4M0RCQTczMTBFMjgxM0QyMDAxMDRBMDMyOERDQTVDRjJDMEU2MzJCRkQ3MTk5NTFDQkQpKDB4MEEzNDY0RDVBQkJERjFDMUZBNkMzQ0Y1QzUzMjhDQkVEN0QxNDAyQUQ0OTkwQUYyRDA3Q0Y2OTU4NzAwRTA3OSkoMHgzMDY3OTIzQUY5M0M4NUJDNjc3NzE1Rjc4RUZFRTJCNzY1RjQ3MTJEOTJBMThERDY5MUIyRDYxNzI0NUQyODM3KSgweDFENzVFMUNDRTQxNjVGRDE5QkJGMUQ4MzRGMDM2NkUzMzMwQTkxNkYyNTI4MDFBQ0MyQTlGQ0NGRTE5QkIwM0YpKDB4Mjk3OTNDM0QzMTEzNTM0NDRDNEZDRjJCRjYyMjk5ODkzRjY5RkNFRjBBREY3MzQ1MzEwREI3RTczNkMyMTc1OCkoMHgzRjkwRTI0NDhDQUIyNjM5Nzg4RUVGMEVEQkQ0Rjg3NDYzMDgyRUFFMEM1MkY3MTBFMEE1N0I0MjM4NTc3QzA5KSgweDNFMTlFOUU0NUM2Q0ZDRjBGNzAzNkQzQTU5OEUyNkJDNEMyNTBBQjQ1MDQ5RTE5QTgxRUYzRjlDNjhFN0IwOUUpKDB4MzFDRjJGQzQ1QzU5RTQ1RTVCMTZBOUZBMzU3OTcyQUVGMUY3NDQzODhDODFDODg2QjI4QkRCQzU1ODE1Q0U0NSkoMHgyNEIzMTBBNDE4Q0I1ODE1NTEzRENDNUI0REJGNEIyQzY0QkQ5NEEyRDQ3NjQyOTRFRUJERjRDN0RFMUIxQjA4KSgweDNFNzQ4QjhCRjdGM0Y2MzIzNUI2NTBEQjg3M0JENjUyQkM1OERCMUM2N0M5NEFGMDNCMjE4REI1OENBMEVBODYpKSkoeigweDNGQTY3NDFEODRFMTE0MzRENzkxOEE0NTlBRDFCNjk4QjhGMzYxNkUyQTkwMUIzQjE3RTlFMEJBOEMyMjlBOTUpKShzKCgweDIxNjAyODVBNzg4MDMxQzQ1QjBFMDQxQzBDM0UxMzIyRTEzMzBDNzE4QjcwOTk5OUU2NzdFNEM4MkMxQThERUMpKDB4MkNDMUVFMTE1NEY1MjdCMzNBMDExQTVGODE2QUZDM0MyMTk4OTJEMENDM0EyNTUwMUE5MDE4M0EyMjIxQjg0NykoMHgyOTkzNjZEN0JEQjUwQ0QyNzhCREI0M0ZGQ0MxQUY2NkNGRDZDODIxMjAzRjk4MEFDMjJBOUUwMTc4NjEyRkNDKSgweDA0MjA0NzU5RTdEOEU4NEMxMTIyQkNGNjUwMDhBQkFDMDE3REU3REFFNDRCN0U0NzlEMzA3NzM5NjZFQjZCMEEpKDB4MDhENUFCREIzOENFRUE2RDUwRkMzNzhGQ0NFQTY1MTE2QzI5OEVFMDMwN0Q4MjdGRjY3NDQ3NTAyQzVDNUEyMykoMHgwQUIxQjE2MDVDMDdGQjA1NTQxNDMwOEZEOUQzODcyRDExODRBQzQzNkJGNjJCRTA2QkY2OEE0MjlFQjgwNkM4KSkpKGdlbmVyaWNfc2VsZWN0b3IoMHgyMDczRTU3RUNBMDk3Q0RCNDM0OUY1NkE5NkREODcwRUY0MjMyRjU0NzYyNEJGREQ3QUZGREY4NDA3ODI2MDAwKSkocG9zZWlkb25fc2VsZWN0b3IoMHgxNDEyNjQxRjM3OEI3QjRBQTJERjFCMjk1NzNFM0JCQTJFMDkyRTc0RDQ4Q0M4Q0EwM0JGQkQ4ODc1NUY1REQ1KSkpKSkoKHB1YmxpY19pbnB1dCAweDBFRkMwQ0M0RTg2MDRDQjRCMzM3QjIzN0JCNDY5MTYxMTBGNTYwNDA0MTY2OUUzOEVCMTcxMkM3OEE4NjUzOUQpKGV2YWxzKCh3KCgweDMwQzgxMjQ1NUQ4NDBGMDlCMUExMEQ3M0U2MDdGMUNEMjNGMDk3N0UyMDU5NDZERDcyNTIxNDlDM0M4RUIyRUIpKDB4MDMwMTA4MkZDODVBODVBNUM1RTQ4NDgzQ0IyMzFGNjRCRTRFNDJBREI3QUI3M0I5NzMwMzRGOTJDMjAwODI0MykoMHgxQUMyNjNDMjkzQjU0OEU3ODYyMjM0NDgxODY1QTZDNDI1NTE4MEYzM0Q1RkNCMUUzMDM2MERDNUFBNEE4MTY0KSgweDI2NzlCMDM5MDFBQTJBMjg2REYxRTJBOTBCQzcyQTNBRjU3QzEzREQ2NUI5QkIxMTEwNERCOTE4OUFEQkI5NzApKDB4MzlGMENGRTUxMzNENENDM0I1OThGMUY2RUExNjAwNDY2MURGN0JBNkQxMzE2QzM4RTEyNEM2NUVGNEYyMUM5NSkoMHgxNjQ1N0RGRDZCRjMyM0JFMTMxNjI3NzlFQjBGNDhDQUQzQUQ4RDQ5NzBFOUU2NDMzRjI3NUIyMjI2Q0Y5OUQ5KSgweDJBRjQzNkZFMEZBRjBDQjkwNUREODIwMkREQzQyQzA5RDE1NjVDRTQxNUZENDRGMzMxNzhEOTRCMUJGNzYxMjcpKDB4MjZBOTE0RjdENTVBQzMxMjkxOEQ0MUZEQTUxNjM0MkU5MjkwMzRDMDZEMTk3MDc5NEMxMTU2RkY4NjkwQjBFNikoMHgwQkREREIyNzZCOUNERjRCMkM5QjRDNkI0M0YyRjMwMkQ0NkUyQTAxMDQ3MjRENzc3OUI3MTRDQzFDMTNEMTBDKSgweDA1N0MwNDVGNERBNzIwMjMxN0U0QTQ3OTUyQkVGMTlEMTA5NDc1NzQ5RkM4QkYwRUQ5MjQ0RkQ2QkRCMjBDQzMpKDB4M0FEOTgwNUJFODYzNDVCM0ZFOTgzNjdEMkFEQUFBRjZBM0IyQTUxMUI3MDExRDM1NENDMDc0QkIwRjBCNjE4QykoMHgwODY0QkIyREY2MEYyOUJFQkM4RDU1REVDMkI2RjE5OURGNTNDQjY1MEJENzk3RDhDODFBQTdEMzlGN0E0OTRDKSgweDM3NUYyMTUzNkI2NkU4MTZEQ0ZDRTgyOTQ5NUE3QjQyOUNBMUVCNjU4MTIzREU4ODU4Qjc2NURCMjZEMURDNjgpKDB4MzREMUI1OUEzMzM2OTM1MDg2N0VFMEU1MzhDNjhENjkzRTE5QkQ1RjhGMDVGQkRFNTI4MjhBNkFFMzk2NjZDQSkoMHgzODFBRDI4NTMzNEE3ODg0NjkwRjNBQjg0MTIyOTFGQ0IwRDMzNTcxNjlDMEYxNzZEMkE2REI4RDJCM0ZDMDJCKSkpKHooMHgyRkI0MTUzNkU0NjU1QzExOUJFNUYwREVEOTAzOTFBODE3MUMxOTFCM0E5NzY0Rjc2NUZCQjZFQkYyQUFCQUM5KSkocygoMHgzRjU1MjJBMUQ4QTBBQkZBODg3NkI0MTg1RTlDQTFGODg1NjYzRjU1NTc5QzM5RjczNTJGOTgxQ0IzMDRDQ0VGKSgweDJFMDcwMEQ2RjhBMDJDMDRCMURGRTYzMDg5NkI1OTYxNUYyMUM0QjNCNTQxRTI2RUU2M0RCQ0ZERkU1OUQ2NTgpKDB4MTBGNzMyN0M4MzNFQjM1QjQ0OTlBRDRBMUVGMEJDQjY2ODYxODIyMzgxREVCMENDNjc5OUU3MTgyODkyQkQyNikoMHgyOUFCOEY0QzdFMjU2RDJENzcwM0UzNjhGOTEwMUJFRDAyMTVFMDhDRUM4N0FBNTQ5OUNGQTdEMUU5RTExNjU3KSgweDE2NTIzRERGNDM4QUNGMkMwNzJEQzdGMDBDNDFGMUUzQTUyMTQ3NjFDNzdEMjUzMzk3MEE5MzgyQjVCNDhEMzApKDB4MEQ2ODRBNDYwQjM0ODA4MkY1RUZCMDNGN0E2MzVCNTM1OEU1MjIzNTgyMUQzNjI1MUQ2NzY0NENFNjk0QUJDNCkpKShnZW5lcmljX3NlbGVjdG9yKDB4MkIyMDRCODU5NTI5OUQyMkNDODNERTZFMkE3OEQ0QUYzOUFBRTg1MjdGQjRCMjk3QTM1MDUxRjM3NkFFMTBDNikpKHBvc2VpZG9uX3NlbGVjdG9yKDB4MzcwQzdEQUM1OERCMURBQjExNDdEQUE4QkJGN0VFMUYxRTJDMkVBQjY0QkVFRDg4NUNBMTRGQzg2RDc4NjQ1OSkpKSkpKSkoZnRfZXZhbDEgMHgwNDU5REU5RUE3NEI4Q0IzOEI1NDQ1NEZBMEY1OUQzNzUzMDdCMTIxMEY3NDAzNTI2MTUzRDVDQzEyODhERTYzKSkpKHByb29mKChtZXNzYWdlcygod19jb21tKCgoMHgzRTJDRjhGREI3RjI1Q0MzRDUyM0U4ODczNUNDOEIwMDY4QTQzNkExMDdEOTI2OTc3QjQ0MDg5NTVBRkI1QTdEIDB4MzJDRUU5NTVFQzVCRkNGMjY5QTA1MEM1MEM5RUQ4Njg2NjRGMjZBRURCNEZDQzk2QTJFQjIyQzRFOTAzMUFDQykpKCgweDIwMjlGNTRDRTNGRTEyNTUwMDVEQzZFMEQ1NkY0NUVENDZEOTI5NEEyMDIxQUQ3QzREOUVDQjlBMkZDMzVEREMgMHgyMDA5OEU5RUI0Mzc0MTRGODYxQzhCQjVGREYzMTExRUIzQzY3MDdEQzE1NkZGRUUzRjNCNzEyRkI2N0Y0QTJFKSkoKDB4MTExMEFFM0YwNUEzREYyRkU0MTQ5RUI3MTI1QjdDRjMxNUQwMUQ2QkZCREM0RTFFQkVBMDVBREQ2MzM0NzBGRCAweDMwQkFFRjA5MUMxNjVCOEZDRkFGQUE5NkMwRkI5RUI1OUE2RkQ5ODE3Njg5NzQyMzA0MzYyM0FGQjhEQ0IwODQpKSgoMHgzMzk1RDI5OTNDQ0JCOUMwQTIyQkUzMjFENzBGNUYwMUYzOUI4M0Q3OEQ3RDM2ODRERTdFRkVGNzFDOUVFRDk0IDB4M0E5OUEwNzhEQTcwNkYzQzQzQjZDMDgxREU1QTA5QTY5RDJEMzA4QkE1MEI5NjFDQUM2QTY2NEUzRDRFOEUzRSkpKCgweDI1OEM1NkZBMzJCNTU1QkZDMzI4OEY2RUVBQTExMzQ0RTQ0MzBDNTFGM0VENkE1OUYzNUY3NDlGOUZBRjA4NEUgMHgxRDQ3QUMzNDFFRjdBQTc2RjE1RjAyMzlBNDk0QTU0MUUwMThDMTEzQUNENjJFODdGQUE3NzY0RTIzMjUxOTQ0KSkoKDB4MkMwNDMxMUI4MUVEMjkyNDBERTlEQTYyMkM4OTQzMjMyMzZERDYyMzg0NkU4M0MwODMwOUQxQzU1MkIwNjUwMyAweDI0MzgwMzZFRTdFRjJFQUVCOTIxNkE4NDM2OTJBMkZBNDVGOEI1OTUxMDdEOUVBNkMwNTUyM0M4Mjc0RENERkUpKSgoMHgxOUMxREUxMzk4MjU4M0EyMkZBRDA0NTUzMDgyNDk5Qzg4MDU1QzBENzA3QzA5REM3NzY1MEVCQzE0NzE4RjZDIDB4MjYxMUIxRkM3MjFCOEI3M0IxMDk4ODZFNUEyOTYwQUJCQzVBNDcxNDcyRjJERTI3RjBCNzA5ODlCMEU2NDBCRikpKCgweDEzNjU1MDMxNUE0NDQwRTIyREIzMjkwNkUzQzdDOTU1Qjk2QzczNUU0MDU4RjFBRkY4QkRDRjc1QkUyMzI0QzggMHgzNEFCODdBNTkwQ0I0Qjk2NzRGMjhBNzVGNkNGOTI3NTdFODRFMTY0OUYzMkNBQkNCRTBCNzZBRUQxQTYwRThEKSkoKDB4MkVFOEQ1QkVBNEQ0NjAzMjFCOUJEMUI1OEJENUY5RUY3NkRGM0QwREVCQjAxNTE5MEQzMTdDNjFDNzM1ODRBQyAweDNEMzMwNDAzRTU0QkQxODlDNTU0NDgxNzBENTlENkY5RDNFRjQ4QzgwOTUyODFGNDU1ODhCOTJCNjEwNzUzNUYpKSgoMHgzNzBFMjMzNzU3MDdCNEU3NDQ4NjQxNUExNTNDQjFGMDExMUMyQjk1MEM4NzE3OEZBODU4OTFDQ0FCMEQzRDhBIDB4MEU3NUM1OThFNjM2ODgyMTdCRUZCQjVEQ0EwMjA0MzNDRTE1OEQ0RjgwNzBDNjM5ODIyNzVGODI2MUEzQ0U5NSkpKCgweDJFRkExNjAzNTBDQzQyODJFRTA2QUY0NjNFQzhDQTY5ODBBRjA3OTgzQTQyQjYyNzVFNDJGQzRBQTZFNjg1QzggMHgwRUVDQTlFREI1MTI2NTE4MkNCRUMxMEVGM0IwQUFGODFFRkI1M0U5QjkxOTk0MDE5NEMyNzI2QjlBNzg1RDFDKSkoKDB4MjdGRTY5RkY0QTcxNkUyREYxMzg5Q0ZDRDRDNDI1QjA1MEMwMDkzMUNERDEyM0MwQzVCRUE3REZGREQzRDYwMyAweDEyMkUwNTkzMTIwNjM1NUFBQjYwREJBRTA3N0Q0OTA4ODdERDFDQUE1OTlCQUMwNTQ1OEJDM0Y0MTQyOENCQjYpKSgoMHgzNjYzRTFDMUMyN0M2RjE2M0FCNTUyRTgzQjIxRkREQzVFQkFBM0I3MzVFRkZGRTM4QkFFOTlCMDFENzFEMDM3IDB4MkM0NkM5MTMzNkNFMzgxRjM5MDBCRDJBODBDMkIzNkE2QkM5MEM1RDUzQTU3OUUwMjI0MEJCQUJCMjAxOEU2MCkpKCgweDI2NjY3RTIzQTAwODVGRERBOTcwRDRDREM3OEQ2QTREOUM5RjAwMzA2MUY0MEY1QUU4RjgxOTg2QzBENkQyNjAgMHgyQjA1QTlGMTIwREFBQTM1NUY1NEU4RDBCOTZBNzhBNjc0ODk4RkIxODMwQTRFQjcxMzU2MTM3Qzg5ODRCREE1KSkoKDB4MTA1RDI0OTFFRUFFMDNEMUFBNEFEODkwODQxMkYzRUQwQjk4OEE0M0M0RjMzQzgxNTgxQzNBNjBGRUU5NzIxRiAweDJEQkFBRDU2QkZBMURDRERFNUNGRTQwNDgwQzhFOEU1N0UwMDkzRkVCMTUzRDlENEY5ODM0MDdCM0VBOTE0MTIpKSkpKHpfY29tbSgoMHgwMjlFRTdGNjREM0ZGRjFGNjkyMEQ2RjAwOTMwNEMyQzhGOUFCRjJCNzY5QUNENjlGN0Y3ODIwMUEwOUYxMEJCIDB4MzAxNDQ5NDgzQkYzQTY4ODU1MjE5MjkzNEUxMDM5MUQ3QkU5N0U1NEJFQjI2RjdBM0YzQjFBMjQ0M0NBMDdFQykpKSh0X2NvbW0oKDB4MjdFRDA1NkUyODg2NDY5M0FCMTY1M0Y2MkFERjVDNkY0N0RDQ0QwNzBFRjE2QTJFOTExMjgzMjI0MDE1OTIxRSAweDEwNzcyODRERDE1Rjk5MTQzRUZBQ0JBODVEM0RENjM2MDhGMjIyQ0Q2RDdDRjdBNzkzREZDNjQzOTBCN0RCRDgpKDB4MDdBMTBGOTVBNEY1NTU5N0Y2NkMzQzkyQkJGOUQ2OUEyM0M2RUU4NkNFMkM4NjRGQzBBMzVGQjE5OTk4MEI4OSAweDJCQzU2NEVDMDZCOEI3MDUyRjQ2OUMzRUM3NEFERDMyQzFDNzEzRUZBMTlGMjYxMDJFN0M3MzUyMEY5MEVEMkMpKDB4M0YzMEU5NkMzRDVBMjMxNzBGOTQ4OTU1NjU0MjJDNkQ1NEI4Qzg1OTREMTU0Q0I0OTVCRDgwODk0MTg0OEMyMSAweDE3Rjg1M0QzQzU4NjkwNDJDNjAwQzcxNzIwNjEwQTIxREQwNTdENjg5QTM0Q0YwOEU2QTcwNTRCMUJEREQ3MEMpKDB4MEMyN0ZBOEQyODI5QkNCREQ5MEUyNDU2NzczOTRERjcxNTFGN0M0RTk0RDk1ODMyOTYyRDcxODdGRUIzMzQzMiAweDA0NDJDNzNCQzdDMzc3OTFEQTlDRTBCRTYzMzJGNjkxNjZFRjZFNkY2NTFFMjNEODU5MjA3QjFGQURGOUUxQTkpKDB4MDM5QjkyMDA2N0Y1OUIzNDU4RjhDRkE2NjBCQzU4NUI3MDU4MjY5MDZCODg4OTNCODhDQURFMTk5MzA2MDRDNCAweDMzQUFBNjIyMTEzQTE0QkIxNDA4NTM4QjM4Q0E1MTU3QkNDODM1NTQ2QkMwODFCQTJEMzlFNUE2MzZGNzg1NEIpKDB4MEU3NkFFRTQ3NDg1MDczQURCNjZFODgyN0I3RjExQzk5Qjc0RjVEMzYwQUYxMkMzMjZERUJGRjQ1N0FCQjI5OCAweDE1RDdGNTlCRDZCRDBFNDlCMzZCQUUxQThFMTcwNzNGQUQzNDQyQjgyNjhENTBEMzI3RTg3Q0Q0Mzc0QzlFMkUpKDB4MjRCMTdDNDI3NThDRDk3N0RBMzFBNUQ2MTlEMEIwQ0M4ODVBMDc0RjEzREYxQjBEOTAzNkE1QkU5NjJGQUE2NiAweDMzQUJGNzU5NjRENDMxOEYyMUFBN0YzQzg4OUVBODhDNDk1RTEzMjJCMjlDODE2NDZDOTAxOTA2MjZBRjkzQTApKSkpKShvcGVuaW5ncygocHJvb2YoKGxyKCgoMHgwMThFODJCODVGNDMzODBFMzJDRURBRDU3MTg4NkRDREI2NTFGRDE2QzU0QUZBQ0M4QTVGMEZDQTFBMzVENzdBIDB4MDc1NThDOERFOTM2MjgyNkY1MkVEMUZDOUYzRkFDM0U2MEJFNkJGOUE2OTNGMUE5NjBDQjJGNTRCRjlBRDMwOCkoMHgyREQzNEFERjczMjM0MENFMTY2QTM5ODlDMjg2M0UwMEFBMjBFRThERDM2ODFBNkZDNDc5NDhEREMyMjkxOTE5IDB4MzlFRkIzNTkyOTI0Q0Y0OUY0NUQ1QjQ3MUFDRDY2QkQ2QTlENzJDN0YwMzRFQzc1NzAzNzQwNzM3RTA2OEZGOSkpKCgweDA1REQ3ODQ1QjBEMTkyMTJBQ0RGNjY2REQ5MEYzMDk5OTlCRjI4NzE5QjJBMUY3MEIyMjhBRjVEM0U1OUE2MzMgMHgyMDc3OTlBQjQyMDE1NUM2RkZFQ0RCMzUzOEIwRUYyMjU5RUVGNzc2QTMzQTc4MUFDNEYzRUY2QkNFRTYwNzAwKSgweDNBQUZDNEUyNEEyNUQyQUZGNzE0RjAwMDhGMjQ2NTQ5NkM2MkVCNkMxRjc1NjJFNjA1QzM4RUM1OURCREJDNjcgMHgzNzhGNUJBQ0NFNUM0QkQ2RkVGODYzMEY2OEM0MzlGOEZFOTg2RjIxOEE1NjJCMUVDMDU0RTA3RkM1ODI0QjU5KSkoKDB4MzhFNjA4RTZDODY2QUQxQzYxQkM2RjI1MEEwQUQ3NzYxQjcxQzZFNUUwRjdBMDY1RjAxQjdCMkY0RjQ4NUQxOCAweDJGMUNGQ0VFOTY1ODRGNTkyQ0RFMDVCMEIzRjkzNkE4RDFGQjYwM0EyOTg0RUVDQjFEQjA0MkJBNkQ4MUE2RDkpKDB4MDdBRDYxODFBOEUzMkMzODk4QjA2QkYwOTJFMjhEMUM4RTkyODI5MzEyNTYwOTAzMzk3OUFFRERCOTExNkJDRSAweDM1Mjg3RjdBQTIzMDBFQ0ExQ0M1OEFFODE0MUFCOTc0MTFFMDBGNjFDNjVGNUIxQTk4QTU4RUY1OTE4QzM2M0IpKSgoMHgzNDYxRkFDRTFCRUI4NUY2MDVFNzJGQUY5QTNDODA0Q0MzQkY4MkZDMjA5NDU4MzUyOEYwQzdFQkE3NERGQjQ4IDB4MjIxMjAxNUU4Q0EyOTY1RkUwRThBNEEwNjgzOENFRERFRDFFQTUzMUExMzlGNUNGRDE1ODhEQjU3MzYzODFDMykoMHgwREUxNDM5NzdCQThCM0ZDOTNEMjU0MzRFRURBNDkyMUU4QkRFNUFENTlFMTE4MUU2QjQ1NkI0MzA5MDU3RjA4IDB4MjRCMDk0RDRBQzQ1NkVDM0Y1NUQ0NjgzMEY0RTgyQkYwNzMxMkExRkFBOTdEOTEzOEJGNDFGMTZGN0UyM0E5QSkpKCgweDIxRTU2NDUzMzBEQzczRjZGNjgxOTE3NkY4RTkwQTA4MjcxMTc2NjRBOTNCNEQ5NkUxOURFOEIyODE5Njg5RjIgMHgxQUM2MzFENjA4RkRFQjFFRUZGQjZDMThBNzIwRTQwQ0YxNDA4QjBCRTI2NkE2MkJFOEI3RDBCNDZEQUYwRkQzKSgweDAwRDczQkU5QzMxOTMxOUU0QzEyQThGOTYxMEM0NzZEMTZGMDg3OEYwMzJERTZENjY2NEU3N0RBQUE0NDYzODcgMHgxMjgxNEY4NjM4ODI2RUE2MDk5RTA2OTE3NzBGRkU1MEY4MTdDRkIzQzQ1QzFGMDY1RUIwRjg1RDZFRTdCQThCKSkoKDB4MjdEMDVENUNFOTJGODM3NUQxNUM3RTI4QTRGNkEwMkUxQzI0MEJCQTE4OTc4MzI5RENBMDcyNDM2Q0RCM0I3QiAweDFDOTk0ODQzQkUzNzk3RTlBNkYyQUM2RkNDQUIxQzlCMTc0NUU4MTkxNDNGMjkxOEEzODNEM0QzMzZDNTg0NkMpKDB4MUQ4QUJDNTk0RURFMzExQTc0QTNDRUU3REUzNkU0MDY1ODUxQzBFRDAzQTQxNDhGMUExM0FGOEE0RTFDRThCMiAweDJDMzIwN0I2N0VFMDA1QzdGQzVCMUMwNzJFOTgwQURGOTY5NUYwMTVBRTI2QkYxNkFFMzJFODNDMDZGQ0M2MTEpKSgoMHgxMzVEQzBGOTg0NjVFMzZBRUZDNEFGQUYwODJGNDU5NDQzNEI0QTQzNzQzMDlDQkQzMzQ3NTA5ODNBNzgxMUE0IDB4MTEwNTdDMERGNkJEMkNDN0E1MDVBNkIzOTk2OTA3MDY1NkNCMzlFNEVDNDc5RENGRTQyRTAxRTcwQkEzOTExNCkoMHgxRTI1NEQ5QjdFNkJFREZFMTQyMjY0RTFCOTNCMUNBOTJCOTQzMjY0RTQ4QzhFMjc2QUFCQkMwNjNFNzlDMDJCIDB4MkE2MTcyMjlGNEQxOTRGM0JFM0QxNUQzOEI3NzdFQTRBQkJBMjhGMzY0MUIyNjlGN0EyNTFGQkZDNTExQjI1QSkpKCgweDFFOUUzRkE0NkE1MEVDN0E0MkYzNzBFOUE0MjlDMjE5ODRGQ0Y3MzBGQUFDODkxM0VDNkU1MEI5REJBMDM5MEMgMHgxOUE3Q0Q3QTg0QzNFOTk4QUJGQ0FCMUQxQUI4REYxRTlGNTdENTg3OEVDQjEyNjM2QThDMEQwMDhFNDY2OTM0KSgweDNGMkMyQjczN0NENzM2NThBQ0UzQ0M5MjQyREQ5QTUyRTM5ODM2QjEzOEJDREI3MTY1OEIxMDUyQzdGRTlDODMgMHgyMThFOEVBQjFGNjU3RUZFRjFBMjgxRkU2MUE2QjFDREQ5MzAzMzEzMEZDNjY0NDAzRUIxNjEwQUUyMEVGQjNCKSkoKDB4MDYzRThCNTBBOTBFN0FGQUE0NUI0QUUyQkI0RjQ4NTM3RjE0Q0ZFODJCRUYzMUExMTAwOTM5OTlGMEFCNTMzMyAweDEwMjgxQzhDMEUwMTc0RkEyMTIxRjQzNUYzNUQ5RTgwNTA2MzdBQTNGNThFMkEzNDJERUI5QzkxNzk4QzQ3QUMpKDB4MEQ0M0FCMDg1M0M2QzIwMkEyQ0UzQzM5RTlEMUNEQTYxNDQ5QThBMTZBOTEwMTJGRkU1OEFGQ0JGNjc1RDNENiAweDNCNURBREFBQUU1N0NGNkZCOTcyQzUyMUZFRDFBQzAzQjk2MDg1MUMwRDQ0QjYxMjJFQkI3MkEyMjU4QTQ2MDQpKSgoMHgxOEFFMzg4NUFDOEFGMEU2QkQ5QzBFNzc4NUQ4MzQ3N0VENkY1RkU4QTIzOUFFMjUyNjE0MTkzMUQ4MUVBQjU2IDB4MjlGQkIwODREOEZCRTcwM0QwMDhFOUNENzBCNzAyQjMxMTNCNDlGODU5QzJBMTlCNDQwNkFEMTMwRDM3MzFBMikoMHgwNEFGOTlFNzIwMjU0QjIyRThERjM2OEFFNkZDMjczQUM3NUE0NjM5QTZGMzAwNzM2OUZENDA1NTMyOTY0Q0JFIDB4MTI0NTI1RTM3RUM2MTVCMUY1N0Q1NDAwMjgzNkUzNTM4MDU0ODI3NkM2MUQ2QjI1MzlFQTUxQzkwMTVFRUQ5QykpKCgweDMyQTRFQ0E3Mjg2NEVFRkZDRjJEODNCODQzQjlCRTRBREJDRDQ1Qjk3MjYyNDgxMUM4OTRGOTE2RTRDODFBMzAgMHgzRTZGNTdBQjlDRjUzNjE4NjY0QTdBRDk4NjJGNjVCRjE2NEVGRkI0MkI3NDk3QjY0QTg4NDQzMzkzMThDMzY1KSgweDJGN0VFQ0M2M0YzRURGNTE5QTgzRTIwRDY0RTg4MjEzMTc5MjY0RjkzQTI0MzhBMjJBMTYzMzVFQjI4NTNFNkEgMHgxRDAzQzQwODc1MTZFRTAxQzEzOTgyNTA1OTk3Q0Y1RTEzQThFNEMyMjhCNDM0NkRFRkRDQjExMDFFNjU2NDk0KSkoKDB4Mzk0QzNGNDc2RjhERkFFNjhFNUI0NjEwRTczMjM5RjdBQ0Q4QzVBRTEyRTZGMDk0QjJEMTk5RDM5MzA4RDg3RCAweDFBMzhENDFDNjhDN0JEM0M2MTc2RDI0Rjc3NDY0MTEzNkQ2QzkyOTgxMUQ4NkFFNzJFNTQ1OThCQjdEQjI3RjQpKDB4MTYwQ0I0NEIyRkFGOTNCMDM3NUQ0MEU3N0Q1NjAwOTFGMDY2Qzg2MTZCNjkyRkY4NDJGOTBCNkZFQkM5QkFCMiAweDE2QzRFNUFEQTY1MzRCNUVBMDQwNjkxOEFEMkQ2NEJDNDE0RUFGRkJDNzIzRjI3QjM1OUM1MjRGRjVGQ0UzOUMpKSgoMHgzRkIxOTExNEU5NDdGRkRDNTQwRkI0Mjg0ODM1Q0I3NDI3OURBQjFDRjMxNTRGMDg3NEIwQTBBNUU2M0EzRUVCIDB4M0Q2NUQ1QjE3MkNFRjhEMzFGMzRBNDlBQjA4ODlGN0ExMEEyMjM4ODQ2QjZCMjQ1NjlENjhBQTc5MUY5NENCNikoMHgwRjAyNjk5RDgwMERCODY4QTA2RTNFRTRBMEMxNThDOTBCQzQ4QTY5MUU4MTc0NEZGQkNGREEzMkZGMjREQ0Y0IDB4MjcxNDY3MTI0M0ZEODIzN0QzMzlFMEFDMkM5NDFFRTlBNjQyRkRGNkZDQkJFMDMxQjQyNjk2RkQ2OUU4MzFBQikpKCgweDA1MjFGNkIwNTIxMkRDOTc1QUYwMDA3Q0QyNEQzMjhCMkVDRUQxQzgyNzkxRDJFNjA2MDU5QjY1QkNCRTU1NEUgMHgzNkJFNkRBQzRCNzczNDk0MTIxRjdERDVGODUwN0QzNkFFNkFDQzFEQzk5RkE4NjBERUQxQ0E3QUU4QTNFRDAxKSgweDM4QjUxQjU5MEJGNTBDQzZBMjRBQjgwNDc0RUIxNDdBMzBDNEFGM0REMTlBNTY1NEMxQjEwNTU1OUJEMTRENEQgMHgzRTExREU4QjFCNDYzOEZCRDhDNEQ2ODM2QTc0N0MwQTgxNTc4QTREMjJCODRBQzU4RUMwNjFGRUI2OEIzMTc3KSkoKDB4MkQ1MzI4RTBCQTU4OTk1QzcwNjY3NzRBNDYzRjhBOTAyRDdDMkI5N0JENDVDMTBCOUQ4QjREODIzREYxMDZBQyAweDI2OTMzQTlDMjE3NzI3QzlDREM0QTQ0OTREM0UzMzJCMzZCQjk5NzM5NkZDQTcwNjA5OUZGRDM0MzlCQjQ4MzYpKDB4MEJCMTE2QkE4MDdEMTJENERGNzk1NTdGRkI3RjYwQjQ4ODU4NjAxOTEyNTMwRTNGNDlDODkwQTM0QUVEMzFDQiAweDI0NjJFMDM5NkVEMzAyREQxMEE2RUY0M0FFNTMyMzMzNTQzRjRBODc1NTk5RTgzRkJFNDEwNjY0NERERDNGOEUpKSkpKHpfMSAweDA2QTYxNkMzQTYyNUY5MkVENjVCNUNBOTlEOUExREFBQTQ3NjQ4MUI5QzQ1RTQ1NTNFN0E4RTQzNkIxM0Q1NzApKHpfMiAweDMxMEFFNDBDQkNFMjFGQTBEQzkyRDFERkU3REY0OUQ5MzlBNTc5RkYwMjlGODY5MTE4MDM2QkY4QjM3MDQzOEMpKGRlbHRhKDB4MzY2NDE0RjRGRTlDM0REQjI3REE1QTg1NDUyQ0VEQkM2NUFGRDEwNEQxRjVDMjQxQkUyRTU5NEY2MTVBQkJCQyAweDBCNDE5MEQ1OUVFQTZFQkY4QjkzMTYwNTQ0MzlFOTJCNUJGREM4Q0Q5QkIwQzg2NDc4M0Q1RjFENzg1REY4N0UpKShjaGFsbGVuZ2VfcG9seW5vbWlhbF9jb21taXRtZW50KDB4MTM0MEMxMEIzMEFEMDdGNDkxM0MzQ0RENTg4QzNFOEE1QTZFNkRBQzk5NDczNzhGQTk3RDExRjUyQ0NENEFFMSAweDBCMTEwQUFEMkQxOTU3QzlDNjk0NDQzOURFRDgwQzlDRTlBMEVBRDM1Qzk2OTAzQUMxRUFEQkM5NEFFQjVEMjkpKSkpKGV2YWxzKCgodygoMHgxQkYxQ0U0OTREMjQzRkVGOTI1M0NCNjZDQzNENjMwMEEzN0VENEEyMzBDMTU0NDUxNzc5RkExNkY2QUFFREQ3KSgweDJBOUFCNDE3OEY5NUVBRTZBM0Q2MDgyNzZBNEJDRDM5MEE4OERBRjhDMzUxOTYwNjFFRDc5REFEQjc0N0NBNjIpKDB4MkYyNzJGRDhERjM1MkMwMzVFODFGQzFBNUM4NjY0QUFCRUY0RjYyOTYyQjdFM0QwM0Y2QkY1M0MxMEMyQjM5OCkoMHgwOTY3QjBGN0Y3NEU2NTU4QUI4NkQ4MTNFQUI4NDkwQzQzQzU2OUJBQjlFNzI3NjFDOEQ0MDg2ODEwQTYyMUIyKSgweDNCRTU4RTdFM0M4REZGRTgzMTdFNjhFNTA3MjlGRkJENkUyMkUzRkU0M0YzRkQwQzQ2OUY0Njc2ODA2ODU1MEIpKDB4MjQxN0NCNTM4MERBRDc5NzgwRDYyNDI4Q0MwOTE3NUZCRTJEQkM0NDNFMDc2NzE1NzU4OUE3RDU4MTQ1OEQzMykoMHgyMDZGQTE3NzlDNTA1N0NEMDYzOTY2NkQyNTgxQTE3MEI4M0NFNjU0QzY1NDU0NEM3M0Y3REZEMDIyRkYxNTk3KSgweDNFQzg1NzM3ODM4RUQ4QzRDQjkwRDU0NTIzMjMxQzk1MEZDNjQxREFBODM5MEFDNjYxMjk5NUFEQkJGQzI5NDcpKDB4MUEyNEMzMzk3RDJGMzlGMURGRUVDQ0NCNjZDNzhCRTYxMjc5RDVDMjJBRDY5MkMyM0RENTI2ODEzMzc5M0YzOCkoMHgxODEzQzU5MTMzRjQyMDRGMTU1NTREODkxRjk0RDgwMkQyNkUyRjE4MzQzRDUxM0UxNjQ3MDY2MzZDRDdENkU0KSgweDA1MzRERjY3OTU0QjdBQUE5MERCREZBODE0NjhCODNGNDE4MkI5MjdENUI0MThFNTMxNzk1OTk4Qjk4MjVCRTMpKDB4MEY3RkMyQ0VBMTk5ODQ5NzJFRTU3MzI3NDNBQ0RBNEM2QzQwNkYwM0E4NTI1NTUwMTlGMjEzRTQzMzI2QjYxQSkoMHgzNjdBREE1MzcwMzNBMDU0QTY1RjBFMTQ1RTZFNzlCNTZGMDU0RUVCODAxMUYxRUVFMTYzRTEzN0Q2MzY2Qjg5KSgweDFCMzIzMkRGQTMxNjk5N0Y0NTNEN0E2RjIwMDVFNkUwOTZCNTRCMzg0N0Y2RkU4RDU4MTE2NTg4N0Y4NUZENzEpKDB4MEVEQzFCQ0Q4Qjc4MjMzRjJDNUUyMzZENkQwNTI2NUE1ODY1ODdBQjBCMUMwRjVFRTNBMjZFM0VDNDVDODU1OSkpKSh6KDB4MkQ0NjcyN0NBQkQxQUQyMEU0NzZFN0VEOEQ2NjQ2NDBEMDU2NUQzRjAxQ0JCRjdDNjI1OEUyRjQzNkUwRkI2NCkpKHMoKDB4MTZDMUQxN0Y4OEMyNjdDNDNENERGRDE5NzY4NTgzQTJFOUFCN0FFQzY5NzVCMDlGMTM5REYxQUI1QzQxQzgxNSkoMHgyNTBFQTY3QUQyMkUyNjYxMjA4QjA1RTcyQjEwNTRGNjA3OThGRDU4RERGRTMzMzNGQUE5QjVBQjU0N0M2NzQ1KSgweDI1OEE4QzkxODI4MEMyNjVGODI1RUI3MkMwQjhDNjI1NjY1QzJGQUY2MDY5N0Q1ODhFQzZBQUNBQzczRDBCODYpKDB4MDcyRUZBQUZDOTY3RUZFNDVCRkYyRUVDMUE4Q0JGOEEwQjJDQzFGNDRCMjUyOTZEQTMzRjczQjNFNDg4NjJEMikoMHgzQTIzQThBQTJBM0QwREM4NTI5OURFNDk3NUM4NDg1NDczQzlDMUQwRDBEODRBMEJFQ0ZGRDMxMzUxQTYwNzFEKSgweDBEQkM1MUM5REY5MjNBQ0I0NDI3NDc0MjA5NTc2MUU1OTlFRDFEOEY5NEVGOEY0MTRDMTUxRENDNTIyM0ExM0YpKSkoZ2VuZXJpY19zZWxlY3RvcigweDFBQjlDODhCNTNDOUNGRDBBNjU4MjMzMTE3MTFBQkYxRTEzRTVCMzUyREMyRDM1QzZEMzRBNDUwOEVGNDJDMUQpKShwb3NlaWRvbl9zZWxlY3RvcigweDBENERCOTY5NDk4NzNCOTBGMzY1QkNCQzczQjJBMUFBRTY5NTUzMzc0MkY2NDcyRTA1MEQwMjRDNDdFRjA1MUYpKSkoKHcoKDB4MDQ0RTI0ODZEMjJCNTczNzczM0M0OTMzOTQ0ODY1MDc5QzFEMjRDQjFCNjJENUE1RDk5RkI0QTg0RDFBNzgwNikoMHgyQjdENkY4RkNBN0EwMTc3MDYyNjQ4OEFEODU0MEJEQkFEMTMzN0M2MjdDRDhBOUU2MzIxMkEyQTA1ODMxNDEwKSgweDJEOTI2NzNFQkM2N0ZCODhEQzMwNTNGMDIxQUE0NEY1RUNDMTBGRTU2RTlEODE2OUVCMjhCNjNDODZBRTU3NjYpKDB4MTFCRDE3OTE3RDY4QTJFNjhGNEUxNjk5OEE4OUYxNUY1M0JDRUU4NTI0MDQyRTg3MzE2QTkxN0JFMTE4QjU3MykoMHgxOTc4RUY3MzYyNzc0NkEwNTBERkZGQjk4MUFDQ0FGREUxRUQ1MTY5MDkyMTk5NERCQ0VFNjlFNDQ4OTJDMDdBKSgweDIwQjI0Q0RERDAyRjlFM0UzODY0QjkwNUEwRTM0QzE5MTA5MTRBMzk5MDQ5NzIwOEI0NEQ5QjdEMkY5QzA0RDgpKDB4MDc0MzQ3REUzOURCQjczOTE2M0VDMTZGNEFDNjEwQkFGRTkzMjhDNzY3N0E1OUFEQjBFNDk0OUJFQTcyMTM5RikoMHgyOUYzMzQyODNBMDk3QkVGNTQ1RUQ0QkQyNUZFOTA1Mzg1NjVBRkIxRUNDRkJGMTJCQjYzNkY1MzY5NTBBQUU1KSgweDFEOTU2RjI3QTJDMkIzMkY1MTA4RjkyNjFCRjA4MzM2Q0FCRjNGNDNBMzRENzY1NDk3NDdDNTg5QUIyNjhFMjYpKDB4MEY2N0Y4MjJCNTAwNTEyOUZEREZBMTk4MDZCNjNFMkY5MjkzNjUxMzE5RTAyNEY0NzBBNEUzQzA5M0M5NTNGQSkoMHgwN0ZFMTczNzM2MDUwMjZEMDYxMUVBOEM1NkQ1QTVFMDEyNzM3QTY1MUI5REI0RjJCNkQzNjQzRTY2QUU4MDU1KSgweDA1MENBMjE3N0U3NjhEMTkwREIxQjhFRjM2QkZDOTI5NTc5NjQ0N0MwRjAwRjFDMzBENEVBRDJDNENDRjI1NzYpKDB4MDA4QjEzMkI4REQ5NzFFOEJENzEwRTIxNzZCQTFBMTQ4NkU5ODI2ODI2MDNEN0M5OTM1NEZGRERENDJFRDBERikoMHgzODZFMDRBODQ1NUFDQjg3RDBFNzM3Mjc3NDBFQ0Q3RkQyMTYwN0JCRTcwQ0U0MTNBQUEyRUQ1MjkzRkEyMDNCKSgweDI5MjI1QkQ5MkYwMENDNzEyRTlGM0ZGQ0E3NjYwNTkyQjgwOTg3QkU4QjM1RERGRjgzMTk0RjA3OTlEQzNCNDQpKSkoeigweDIzNDVBMUE3RkIwMDRGRjRCOTMzRTQ3RTkxNEJDNzYyRDMzMjFBQzc0QTFFQjgwN0YyMkY3NUY3MTZBMjk3NDUpKShzKCgweDM4NEY5RENDNTBGRkNDQ0QxN0ZFNTMwOTRGREQ2QzZFM0ExODk5MzdFRjIyMDIwNTVBOUU4NDIwN0QxRjk5MEYpKDB4M0UzQzczRjM0OEMzNkI2MUQ1MkQ1RERGRjM2RDc2NjM1N0I1OEE5MTQ4NzU1NDk0NzEzNTFCRUFCMzU5NTJDQikoMHgxOTNBNDYyQjk3MzFFNzNDODYyMkU2NThCQUQwREI1QTkzMjIxMzk3OERCMzkyNURCQjVBQ0YwN0Y4QUIyQjRDKSgweDJCNkU3MUEzNUY4QTZDMTYxQTIyRDZDQTQ1Q0E1NzY2Mzc4ODkwQzMwRUE2MUFGMEExNzlDQjZCNTQ5NkUxNzcpKDB4MDNBN0JGNDFDRjQ2MjE1ODcxREMzODVGMUM0QUIwM0E4QzNERDY3RUMzRjc4OUU0MjVCQUVDOEVEMkI0QTY1RikoMHgyM0MzNzU4QzUyRkUyNDNBNUU2M0ZENkFFQzIyMThDQzJBMDAxQTZGNjU1RjJFNDRGMUExM0UzOTFGRkE0QkI4KSkpKGdlbmVyaWNfc2VsZWN0b3IoMHgyQ0M0M0YwQTlEOThDQkU4RTVCNkZDMzU0RTlCMDkwQjkxMDc1NDE4MTE2NURCRTQ3NUU4OEEwQTAyRjVBNzg2KSkocG9zZWlkb25fc2VsZWN0b3IoMHgyMkE4MUM1MENCQkU2MDhDQjZGOEE4MDc0NzE0MjRFQjBBNTE2N0IzOTI0NDZGMzJFMTkyRTMzRUZEQkZDRTc1KSkpKSkoZnRfZXZhbDEgMHgzNEFENUZBOEFEMzhEOUZCODM1MzRGODUxRjA5MjRCQTNCOUI0M0UxQzQ1NzAzRjE1MUExOUJDQ0U3MUY0RTdEKSkpKSkp"
          |> Side_loaded.Proof.of_base64
        with
        | Error e ->
            failwith e
        | Ok pi ->
            pi
      in
      let statement =
        let transaction =
          Backend.Tick.Field.t_of_sexp
            (Atom
               "0x2340A5795E22C7C923991D225400D0052B3A995C35BCCDC612E6205287419EC1"
            )
        in
        let at_party =
          Backend.Tick.Field.t_of_sexp
            (Atom
               "0x2340A5795E22C7C923991D225400D0052B3A995C35BCCDC612E6205287419EC1"
            )
        in
        [| transaction; at_party |]
      in
      let vk =
        Side_loaded.Verification_key.of_base58_check_exn
          "VVA53aPgmCXemUiPjxo1dhgdNUSWbJarTh9Xhaki6b1AjVE31nk6wnSKcPa6JSJ8KDTDMryCozStCeisLTXLoYxBo3fjFhgPJn25EnuJMggPrVocSW3SfQBY7dgpPqQVccsqSPcFGJptarG6dRrLcx65M4SqudGDWbzpKd2oLyeTVifRTREq2BibC3rWMpUDuLwXEnp61FfFaktb4WKu3hfHyYBt5vL3Xndi9kynUWuhznijLG2yP7eX7o5M3nbjfkg7NdWaGReZH1yt4ewtrmHEMF5qTdK2UPgNzpScaK7ix8wZV5qECT483DsuY6Wpx3s2FfdmRDYwdr2YejhW4ZnJLNAxMgUkV3xkid5esqnk5TuQrdHMYvLZXju3RrZrvqhmbTFXpANKskZnuH1BUvkeoPvpQeYdoeYDJ6bgM6NFB3oWsPTU3vSMg3Wjsqx6Ekc8MuZHuaziGax9WNxbM3H6HscZFRs4npttEiwj1gSvZNaVc9FfRdCa3CMMWJNR1CkA1zKtCb8Sie1yiHc89hDA7K5mufV1yaX88xmAQrhZpTLCE8Ch62Zp3P1Vy6QVDACZCKSiz3bhikYEXFKZaJfRYVZVPeEBgjnUDrB4SD61KKnvWWESV8a3uGudeBLnJqoPJuBC8bZTUfskxqzkXmz2XTv4HMARJRTg21tFB8mZmLgVuaSWpc6inGxTZeWmE9ECSFzHuazEPNQ6yn1xo7G72ixrmLZrZqhbhPfnqSL5SWnmFWaWTihNNdHac8FDwb8JKvneC5yUur3WAZ8tTULiiNVvQhjhKVUrym2wTWFwhDAy6GqZcYeWRig9gpgdaxEuA7YnDc8XZZ5JS643PBfAWZZ3mZR4NxXPnVfn1xAUD2VFXmA8pzkqRwQ8DSpSPpKuwzwuJQUW6QSGtBheKFSxrXt6qekFX2azueedJZrhnwPW78dM7v3Qd2zTWo8iD2wfBB1Yot8BfUqAk7FYyi9hajKT1qZWQMg3kUVBywX93KBht2RFDJeVwiuE2hHaAzobxnnwsPJKPHaU8SM1EXQ4cFP2zJ2acPig52MNht3Z34fMeZ65bA3eEbcDbJw3pk2YS1pHtEr818b5TisPu6gshwkRGghbnTsQzHCjZVf61rpT4WphBsv6ob6foLwdc5ZSxq2BFzAWUv5j5nrtU9fqnQCx1DooZxAc8BnjxCXQ5TnE4Rpj82JwUR59QFNza2RwK2vZLvrNPt1LK5eCkZV8fBWuYD9J4AnxGA8icQbWBAfsSk9xXJBynEKymAsw6eTFPWCAMjQgJLhJP8MJR3NyNbqMfT1nR924EyZged7US9ogU8CLV5GcMBTSzAyCSFwFN8LGL1uT9sStzwQNbUvKvXYRwWNMYpb7Mxcjz1NjBaMbiWUryMcJc3D19yXt8VNt5g3L3Ty4GtL3WWV2aXRRXcuzYZai6wV8ESPGd3R6o4NJS5Ct5Z98fx25sNtswb77Q18pU379m4wsk8ck872oMZTPp9bDHTVpLoEBHd1gkC6j7pP8dx3cNTWc1NoewCGLi6zLDNfPZDrRXZESnaDRgVGEDinXS5SeAihMcQxvriHyskPW4SidcZsZtPvLnoQz7HQRpDnXfg4j6b8P5EX6sSJbkU9is3k6e8puQirFzLLgh2uC4oZH8EzLRZcGkonQPP5sLTmfwX4s5DJYdS4NLAVYSXndVZ4fazLfqPLukdWQkxZihUq4NtFkfzpNB8MPUBe6T72zhnvqVPegeEhgVvUokcn2DRJUc93DSYSGEJ3eZNFTruCgbM7xMXq83K6eraFRvxGqAgsQcTcQKwEfF9XvuppFDBbEHjdg84w1XiRkZ7xPKDdF6Hvi5G8V6rr6q1T7qypKiFqNrwM6frbJqgjedLpAY6RkPchip2WsZTpEX3EY1ryyGnJxZvb2fjCooQ9u1R6zNArVCV383KNJQZAaWFgzd58F7ZJ1fGU8zeFzDuhqSwqPyDE299sVYMSfbvp7xjWygxrbjApRE2FkjQtjuxaiXzsuemvrrSedVCGrktCHNqPKkJxbLcpz97rRBvwnKSd26x8LKHn2Zjzp2qeyxsY8HN7WVPATxPE4xXqi9dw41o8LBQ3GDGe1ASjphdp4bxj1guHhSZbMKTJDj7hJKyuvBMdG1YKQo3uv2qu5MiB3Afu5SZbZStNKBnxc2DRoDyF45yrQNeoBJogcSLAqWG624ZAdU4BWrqRJNjoAu6GxxE6E8TvFtvyDW1R9Nv7tXzmWE7RarrAL9YUD6uqe7gAanAv1cdAJRcPcdr2YvUL7zeB5d1daPfwJW4PYDvMwnnqDFSXgNqPreh8nFaiReDYjiHkwCojPcCgdcK5gJwpQTasjkWQBk2RmFQdfaLCpiPZGroZ6hTvRBHq2MwdUtkQHZjjCvY9fUtnniMVdUgkAZ9oLj8evpeoDEwyEHE1upmZZN84CMPP32NpHDtH3PwgGR3"
      in
      assert (
        Promise.block_on_async_exn (fun () ->
            Side_loaded.verify_promise ~value_to_field_elements:Fn.id
              ~return_typ:Impls.Step.Typ.unit
              [ (vk, (statement, ()), pi) ] ) )*)

    open Impls.Step

    let () = Snarky_backendless.Snark0.set_eval_constraints true

    module Statement = struct
      type t = Field.t

      let to_field_elements x = [| x |]

      module Constant = struct
        type t = Field.Constant.t [@@deriving bin_io]

        let to_field_elements x = [| x |]
      end
    end

    (* Currently, a circuit must have at least 1 of every type of constraint. *)
    let dummy_constraints () =
      Impl.(
        let x = exists Field.typ ~compute:(fun () -> Field.Constant.of_int 3) in
        let g =
          exists Step_main_inputs.Inner_curve.typ ~compute:(fun _ ->
              Tick.Inner_curve.(to_affine_exn one) )
        in
        ignore
          ( SC.to_field_checked'
              (module Impl)
              ~num_bits:16
              (Kimchi_backend_common.Scalar_challenge.create x)
            : Field.t * Field.t * Field.t ) ;
        ignore
          ( Step_main_inputs.Ops.scale_fast g ~num_bits:5 (Shifted_value x)
            : Step_main_inputs.Inner_curve.t ) ;
        ignore
          ( Step_main_inputs.Ops.scale_fast g ~num_bits:5 (Shifted_value x)
            : Step_main_inputs.Inner_curve.t ) ;
        ignore
          ( Step_verifier.Scalar_challenge.endo g ~num_bits:4
              (Kimchi_backend_common.Scalar_challenge.create x)
            : Field.t * Field.t ))

    module No_recursion = struct
      module Statement = Statement

      let tag, _, p, Provers.[ step ] =
        Common.time "compile" (fun () ->
            compile_promise
              (module Statement)
              (module Statement.Constant)
              ~public_input:(Input Field.typ) ~auxiliary_typ:Typ.unit
              ~branches:(module Nat.N1)
              ~max_proofs_verified:(module Nat.N0)
              ~name:"blockchain-snark"
              ~constraint_constants:
                (* Dummy values *)
                { sub_windows_per_window = 0
                ; ledger_depth = 0
                ; work_delay = 0
                ; block_window_duration_ms = 0
                ; transaction_capacity = Log_2 0
                ; pending_coinbase_depth = 0
                ; coinbase_amount = Unsigned.UInt64.of_int 0
                ; supercharged_coinbase_factor = 0
                ; account_creation_fee = Unsigned.UInt64.of_int 0
                ; fork = None
                }
              ~choices:(fun ~self ->
                [ { identifier = "main"
                  ; prevs = []
                  ; uses_lookup = false
                  ; main =
                      (fun { previous_public_inputs = []; public_input = self } ->
                        dummy_constraints () ;
                        Field.Assert.equal self Field.zero ;
                        { previous_proofs_should_verify = []
                        ; public_output = ()
                        ; auxiliary_output = ()
                        } )
                  }
                ] ) )

      module Proof = (val p)

      let example =
        let (), (), b0 =
          Common.time "b0" (fun () ->
              Promise.block_on_async_exn (fun () -> step [] Field.Constant.zero) )
        in
        assert (
          Promise.block_on_async_exn (fun () ->
              Proof.verify_promise [ (Field.Constant.zero, b0) ] ) ) ;
        (Field.Constant.zero, b0)
    end

    module No_recursion_return = struct
      module Statement = struct
        type t = unit

        let to_field_elements () = [||]

        module Constant = struct
          type t = unit [@@deriving bin_io]

          let to_field_elements () = [||]
        end
      end

      let tag, _, p, Provers.[ step ] =
        Common.time "compile" (fun () ->
            compile_promise
              (module Statement)
              (module Statement.Constant)
              ~public_input:(Output Field.typ) ~auxiliary_typ:Typ.unit
              ~branches:(module Nat.N1)
              ~max_proofs_verified:(module Nat.N0)
              ~name:"blockchain-snark"
              ~constraint_constants:
                (* Dummy values *)
                { sub_windows_per_window = 0
                ; ledger_depth = 0
                ; work_delay = 0
                ; block_window_duration_ms = 0
                ; transaction_capacity = Log_2 0
                ; pending_coinbase_depth = 0
                ; coinbase_amount = Unsigned.UInt64.of_int 0
                ; supercharged_coinbase_factor = 0
                ; account_creation_fee = Unsigned.UInt64.of_int 0
                ; fork = None
                }
              ~choices:(fun ~self ->
                [ { identifier = "main"
                  ; prevs = []
                  ; uses_lookup = false
                  ; main =
                      (fun _ ->
                        dummy_constraints () ;
                        { previous_proofs_should_verify = []
                        ; public_output = Field.zero
                        ; auxiliary_output = ()
                        } )
                  }
                ] ) )

      module Proof = (val p)

      let example =
        let res, (), b0 =
          Common.time "b0" (fun () ->
              Promise.block_on_async_exn (fun () -> step [] ()) )
        in
        assert (Field.Constant.(equal zero) res) ;
        assert (
          Promise.block_on_async_exn (fun () ->
              Proof.verify_promise [ (res, b0) ] ) ) ;
        (res, b0)
    end

    module Simple_chain = struct
      module Statement = Statement

      let tag, _, p, Provers.[ step ] =
        Common.time "compile" (fun () ->
            compile_promise
              (module Statement)
              (module Statement.Constant)
              ~public_input:(Input Field.typ) ~auxiliary_typ:Typ.unit
              ~branches:(module Nat.N1)
              ~max_proofs_verified:(module Nat.N1)
              ~name:"blockchain-snark"
              ~constraint_constants:
                (* Dummy values *)
                { sub_windows_per_window = 0
                ; ledger_depth = 0
                ; work_delay = 0
                ; block_window_duration_ms = 0
                ; transaction_capacity = Log_2 0
                ; pending_coinbase_depth = 0
                ; coinbase_amount = Unsigned.UInt64.of_int 0
                ; supercharged_coinbase_factor = 0
                ; account_creation_fee = Unsigned.UInt64.of_int 0
                ; fork = None
                }
              ~choices:(fun ~self ->
                [ { identifier = "main"
                  ; prevs = [ self ]
                  ; uses_lookup = false
                  ; main =
                      (fun { previous_public_inputs = [ prev ]
                           ; public_input = self
                           } ->
                        let is_base_case = Field.equal Field.zero self in
                        let proof_must_verify = Boolean.not is_base_case in
                        let self_correct = Field.(equal (one + prev) self) in
                        Boolean.Assert.any [ self_correct; is_base_case ] ;
                        { previous_proofs_should_verify = [ proof_must_verify ]
                        ; public_output = ()
                        ; auxiliary_output = ()
                        } )
                  }
                ] ) )

      module Proof = (val p)

      let example =
        let s_neg_one = Field.Constant.(negate one) in
        let b_neg_one : (Nat.N1.n, Nat.N1.n) Proof0.t =
          Proof0.dummy Nat.N1.n Nat.N1.n Nat.N1.n ~domain_log2:14
        in
        let (), (), b0 =
          Common.time "b0" (fun () ->
              Promise.block_on_async_exn (fun () ->
                  step [ (s_neg_one, b_neg_one) ] Field.Constant.zero ) )
        in
        assert (
          Promise.block_on_async_exn (fun () ->
              Proof.verify_promise [ (Field.Constant.zero, b0) ] ) ) ;
        let (), (), b1 =
          Common.time "b1" (fun () ->
              Promise.block_on_async_exn (fun () ->
                  step [ (Field.Constant.zero, b0) ] Field.Constant.one ) )
        in
        assert (
          Promise.block_on_async_exn (fun () ->
              Proof.verify_promise [ (Field.Constant.one, b1) ] ) ) ;
        (Field.Constant.one, b1)
    end

    module Tree_proof = struct
      let tag, _, p, Provers.[ step ] =
        Common.time "compile" (fun () ->
            compile_promise
              (module Statement)
              (module Statement.Constant)
              ~public_input:(Input Field.typ) ~auxiliary_typ:Typ.unit
              ~branches:(module Nat.N1)
              ~max_proofs_verified:(module Nat.N2)
              ~name:"blockchain-snark"
              ~constraint_constants:
                (* Dummy values *)
                { sub_windows_per_window = 0
                ; ledger_depth = 0
                ; work_delay = 0
                ; block_window_duration_ms = 0
                ; transaction_capacity = Log_2 0
                ; pending_coinbase_depth = 0
                ; coinbase_amount = Unsigned.UInt64.of_int 0
                ; supercharged_coinbase_factor = 0
                ; account_creation_fee = Unsigned.UInt64.of_int 0
                ; fork = None
                }
              ~choices:(fun ~self ->
                [ { identifier = "main"
                  ; uses_lookup = false
                  ; prevs = [ No_recursion.tag; self ]
                  ; main =
                      (fun { previous_public_inputs = [ _; prev ]
                           ; public_input = self
                           } ->
                        let is_base_case = Field.equal Field.zero self in
                        let proof_must_verify = Boolean.not is_base_case in
                        let self_correct = Field.(equal (one + prev) self) in
                        Boolean.Assert.any [ self_correct; is_base_case ] ;
                        { previous_proofs_should_verify =
                            [ Boolean.true_; proof_must_verify ]
                        ; public_output = ()
                        ; auxiliary_output = ()
                        } )
                  }
                ] ) )

      module Proof = (val p)

      let example =
        let s_neg_one = Field.Constant.(negate one) in
        let b_neg_one : (Nat.N2.n, Nat.N2.n) Proof0.t =
          Proof0.dummy Nat.N2.n Nat.N2.n Nat.N2.n ~domain_log2:15
        in
        let (), (), b0 =
          Common.time "tree b0" (fun () ->
              Promise.block_on_async_exn (fun () ->
                  step
                    [ No_recursion.example; (s_neg_one, b_neg_one) ]
                    Field.Constant.zero ) )
        in
        assert (
          Promise.block_on_async_exn (fun () ->
              Proof.verify_promise [ (Field.Constant.zero, b0) ] ) ) ;
        let (), (), b1 =
          Common.time "tree b1" (fun () ->
              Promise.block_on_async_exn (fun () ->
                  step
                    [ No_recursion.example; (Field.Constant.zero, b0) ]
                    Field.Constant.one ) )
        in
        [ (Field.Constant.zero, b0); (Field.Constant.one, b1) ]
    end

    let%test_unit "verify" =
      assert (
        Promise.block_on_async_exn (fun () ->
            Tree_proof.Proof.verify_promise Tree_proof.example ) )

    module Tree_proof_return = struct
      module Statement = No_recursion_return.Statement

      type _ Snarky_backendless.Request.t +=
        | Is_base_case : bool Snarky_backendless.Request.t

      let handler (is_base_case : bool)
          (Snarky_backendless.Request.With { request; respond }) =
        match request with
        | Is_base_case ->
            respond (Provide is_base_case)
        | _ ->
            respond Unhandled

      let tag, _, p, Provers.[ step ] =
        Common.time "compile" (fun () ->
            compile_promise
              (module Statement)
              (module Statement.Constant)
              ~public_input:(Output Field.typ) ~auxiliary_typ:Typ.unit
              ~branches:(module Nat.N1)
              ~max_proofs_verified:(module Nat.N2)
              ~name:"blockchain-snark"
              ~constraint_constants:
                (* Dummy values *)
                { sub_windows_per_window = 0
                ; ledger_depth = 0
                ; work_delay = 0
                ; block_window_duration_ms = 0
                ; transaction_capacity = Log_2 0
                ; pending_coinbase_depth = 0
                ; coinbase_amount = Unsigned.UInt64.of_int 0
                ; supercharged_coinbase_factor = 0
                ; account_creation_fee = Unsigned.UInt64.of_int 0
                ; fork = None
                }
              ~choices:(fun ~self ->
                [ { identifier = "main"
                  ; uses_lookup = false
                  ; prevs = [ No_recursion_return.tag; self ]
                  ; main =
                      (fun { previous_public_inputs = [ _; prev ]
                           ; public_input = ()
                           } ->
                        let is_base_case =
                          exists Boolean.typ ~request:(fun () -> Is_base_case)
                        in
                        let proof_must_verify = Boolean.not is_base_case in
                        let self =
                          Field.(
                            if_ is_base_case ~then_:zero ~else_:(one + prev))
                        in
                        { previous_proofs_should_verify =
                            [ Boolean.true_; proof_must_verify ]
                        ; public_output = self
                        ; auxiliary_output = ()
                        } )
                  }
                ] ) )

      module Proof = (val p)

      let example =
        let s_neg_one = Field.Constant.(negate one) in
        let b_neg_one : (Nat.N2.n, Nat.N2.n) Proof0.t =
          Proof0.dummy Nat.N2.n Nat.N2.n Nat.N2.n ~domain_log2:15
        in
        let s0, (), b0 =
          Common.time "tree b0" (fun () ->
              Promise.block_on_async_exn (fun () ->
                  step ~handler:(handler true)
                    [ No_recursion_return.example; (s_neg_one, b_neg_one) ]
                    () ) )
        in
        assert (Field.Constant.(equal zero) s0) ;
        assert (
          Promise.block_on_async_exn (fun () ->
              Proof.verify_promise [ (s0, b0) ] ) ) ;
        let s1, (), b1 =
          Common.time "tree b1" (fun () ->
              Promise.block_on_async_exn (fun () ->
                  step ~handler:(handler false)
                    [ No_recursion_return.example; (s0, b0) ]
                    () ) )
        in
        assert (Field.Constant.(equal one) s1) ;
        [ (s0, b0); (s1, b1) ]
    end

    let%test_unit "verify" =
      assert (
        Promise.block_on_async_exn (fun () ->
            Tree_proof_return.Proof.verify_promise Tree_proof_return.example ) )

    module Add_one_return = struct
      module Statement = struct
        type t = Field.t

        let to_field_elements x = [| x |]

        module Constant = struct
          type t = Field.Constant.t [@@deriving bin_io]

          let to_field_elements x = [| x |]
        end
      end

      let tag, _, p, Provers.[ step ] =
        Common.time "compile" (fun () ->
            compile_promise
              (module Statement)
              (module Statement.Constant)
              ~public_input:(Input_and_output (Field.typ, Field.typ))
              ~auxiliary_typ:Typ.unit
              ~branches:(module Nat.N1)
              ~max_proofs_verified:(module Nat.N0)
              ~name:"blockchain-snark"
              ~constraint_constants:
                (* Dummy values *)
                { sub_windows_per_window = 0
                ; ledger_depth = 0
                ; work_delay = 0
                ; block_window_duration_ms = 0
                ; transaction_capacity = Log_2 0
                ; pending_coinbase_depth = 0
                ; coinbase_amount = Unsigned.UInt64.of_int 0
                ; supercharged_coinbase_factor = 0
                ; account_creation_fee = Unsigned.UInt64.of_int 0
                ; fork = None
                }
              ~choices:(fun ~self ->
                [ { identifier = "main"
                  ; uses_lookup = false
                  ; prevs = []
                  ; main =
                      (fun { previous_public_inputs = []; public_input = x } ->
                        dummy_constraints () ;
                        { previous_proofs_should_verify = []
                        ; public_output = Field.(add one) x
                        ; auxiliary_output = ()
                        } )
                  }
                ] ) )

      module Proof = (val p)

      let example =
        let input = Field.Constant.of_int 42 in
        let res, (), b0 =
          Common.time "b0" (fun () ->
              Promise.block_on_async_exn (fun () -> step [] input) )
        in
        assert (Field.Constant.(equal (of_int 43)) res) ;
        assert (
          Promise.block_on_async_exn (fun () ->
              Proof.verify_promise [ ((input, res), b0) ] ) ) ;
        ((input, res), b0)
    end

    module Auxiliary_return = struct
      module Statement = struct
        type t = Field.t

        let to_field_elements x = [| x |]

        module Constant = struct
          type t = Field.Constant.t [@@deriving bin_io]

          let to_field_elements x = [| x |]
        end
      end

      let tag, _, p, Provers.[ step ] =
        Common.time "compile" (fun () ->
            compile_promise
              (module Statement)
              (module Statement.Constant)
              ~public_input:(Input_and_output (Field.typ, Field.typ))
              ~auxiliary_typ:Field.typ
              ~branches:(module Nat.N1)
              ~max_proofs_verified:(module Nat.N0)
              ~name:"blockchain-snark"
              ~constraint_constants:
                (* Dummy values *)
                { sub_windows_per_window = 0
                ; ledger_depth = 0
                ; work_delay = 0
                ; block_window_duration_ms = 0
                ; transaction_capacity = Log_2 0
                ; pending_coinbase_depth = 0
                ; coinbase_amount = Unsigned.UInt64.of_int 0
                ; supercharged_coinbase_factor = 0
                ; account_creation_fee = Unsigned.UInt64.of_int 0
                ; fork = None
                }
              ~choices:(fun ~self ->
                [ { identifier = "main"
                  ; uses_lookup = false
                  ; prevs = []
                  ; main =
                      (fun { previous_public_inputs = []; public_input = input } ->
                        dummy_constraints () ;
                        let sponge =
                          Step_main_inputs.Sponge.create
                            Step_main_inputs.sponge_params
                        in
                        let blinding_value =
                          exists Field.typ ~compute:Field.Constant.random
                        in
                        Step_main_inputs.Sponge.absorb sponge (`Field input) ;
                        Step_main_inputs.Sponge.absorb sponge
                          (`Field blinding_value) ;
                        let result = Step_main_inputs.Sponge.squeeze sponge in
                        { previous_proofs_should_verify = []
                        ; public_output = result
                        ; auxiliary_output = blinding_value
                        } )
                  }
                ] ) )

      module Proof = (val p)

      let example =
        let input = Field.Constant.of_int 42 in
        let result, blinding_value, b0 =
          Common.time "b0" (fun () ->
              Promise.block_on_async_exn (fun () -> step [] input) )
        in
        let sponge = Tick_field_sponge.Field.create Tick_field_sponge.params in
        Tick_field_sponge.Field.absorb sponge input ;
        Tick_field_sponge.Field.absorb sponge blinding_value ;
        let result' = Tick_field_sponge.Field.squeeze sponge in
        assert (Field.Constant.equal result result') ;
        assert (
          Promise.block_on_async_exn (fun () ->
              Proof.verify_promise [ ((input, result), b0) ] ) ) ;
        ((input, result), b0)
    end
  end )

(*
let%test_module "test" =
  ( module struct
    let () =
      Tock.Keypair.set_urs_info
        [On_disk {directory= "/tmp/"; should_write= true}]

    let () =
      Tick.Keypair.set_urs_info
        [On_disk {directory= "/tmp/"; should_write= true}]

    open Impls.Step

    module Txn_snark = struct
      module Statement = struct
        type t = Field.t

        let to_field_elements x = [|x|]

        module Constant = struct
          type t = Field.Constant.t [@@deriving bin_io]

          let to_field_elements x = [|x|]
        end
      end

      (* A snark proving one knows a preimage of a hash *)
      module Know_preimage = struct
        module Statement = Statement

        type _ Snarky_backendless.Request.t +=
          | Preimage : Field.Constant.t Snarky_backendless.Request.t

        let hash_checked x =
          let open Step_main_inputs in
          let s = Sponge.create sponge_params in
          Sponge.absorb s (`Field x) ;
          Sponge.squeeze_field s

        let hash x =
          let open Tick_field_sponge in
          let s = Field.create params in
          Field.absorb s x ; Field.squeeze s

        let tag, _, p, Provers.[prove; _] =
          compile
            (module Statement)
            (module Statement.Constant)
            ~typ:Field.typ
            ~return_typ:Typ.unit
            ~branches:(module Nat.N2) (* Should be able to set to 1 *)
            ~max_proofs_verified:
              (module Nat.N2) (* TODO: Should be able to set this to 0 *)
            ~name:"preimage"
            ~choices:(fun ~self ->
              (* TODO: Make it possible to have a system that doesn't use its "self" *)
              [ { prevs= []
                ; main=
                    (fun [] s ->
                       dummy_constraints () ;
                      let x = exists ~request:(fun () -> Preimage) Field.typ in
                      Field.Assert.equal s (hash_checked x) ;
                      [] ) }
                (* TODO: Shouldn't have to have this dummy *)
              ; { prevs= [self; self]
                ; main=
                    (fun [_; _] s ->
                       dummy_constraints () ;
                       (* Unsatisfiable. *)
                      Field.(Assert.equal s (s + one)) ;
                      [Boolean.true_; Boolean.true_] ) } ] )

        let prove ~preimage =
          let h = hash preimage in
          ( h
          , prove [] h ~handler:(fun (With {request; respond}) ->
                match request with
                | Preimage ->
                    respond (Provide preimage)
                | _ ->
                    unhandled ) )

        module Proof = (val p)

        let side_loaded_vk = Side_loaded.Verification_key.of_compiled tag
      end

      let side_loaded =
        Side_loaded.create
          ~max_proofs_verified:(module Nat.N2)
          ~name:"side-loaded"
          ~value_to_field_elements:Statement.to_field_elements
          ~var_to_field_elements:Statement.to_field_elements ~typ:Field.typ

      let tag, _, p, Provers.[base; preimage_base; merge] =
        compile
          (module Statement)
          (module Statement.Constant)
          ~typ:Field.typ
          ~return_typ:Typ.unit
          ~branches:(module Nat.N3)
          ~max_proofs_verified:(module Nat.N2)
          ~name:"txn-snark"
          ~choices:(fun ~self ->
            [ { prevs= []
              ; main=
                  (fun [] x ->
                    let t = (Field.is_square x :> Field.t) in
                    for i = 0 to 10_000 do
                      assert_r1cs t t t
                    done ;
                    [] ) }
            ; { prevs= [side_loaded]
              ; main=
                  (fun [hash] x ->
                    Side_loaded.in_circuit side_loaded
                      (exists Side_loaded_verification_key.typ
                         ~compute:(fun () -> Know_preimage.side_loaded_vk)) ;
                    Field.Assert.equal hash x ;
                    [Boolean.true_] ) }
            ; { prevs= [self; self]
              ; main=
                  (fun [l; r] res ->
                    assert_r1cs l r res ;
                    [Boolean.true_; Boolean.true_] ) } ] )

      module Proof = (val p)
    end

    let t_proof =
      let preimage = Field.Constant.of_int 10 in
(*       let base1 = preimage in *)
      let base1, preimage_proof = Txn_snark.Know_preimage.prove ~preimage in
      let base2 = Field.Constant.of_int 9 in
      let base12 = Field.Constant.(base1 * base2) in
(*       let t1 = Common.time "t1" (fun () -> Txn_snark.base [] base1) in *)
      let t1 =
        Common.time "t1" (fun () ->
            Side_loaded.in_prover Txn_snark.side_loaded
              Txn_snark.Know_preimage.side_loaded_vk ;
            Txn_snark.preimage_base [(base1, preimage_proof)] base1 )
      in
      let module M = struct
        type t = Field.Constant.t * Txn_snark.Proof.t [@@deriving bin_io]
      end in
      Common.time "verif" (fun () ->
          assert (
            Txn_snark.Proof.verify (List.init 2 ~f:(fun _ -> (base1, t1))) ) ) ;
      Common.time "verif" (fun () ->
          assert (
            Txn_snark.Proof.verify (List.init 4 ~f:(fun _ -> (base1, t1))) ) ) ;
      Common.time "verif" (fun () ->
          assert (
            Txn_snark.Proof.verify (List.init 8 ~f:(fun _ -> (base1, t1))) ) ) ;
      let t2 = Common.time "t2" (fun () -> Txn_snark.base [] base2) in
      assert (Txn_snark.Proof.verify [(base1, t1); (base2, t2)]) ;
      (* Need two separate booleans.
         Should carry around prev should verify and self should verify *)
      let t12 =
        Common.time "t12" (fun () ->
            Txn_snark.merge [(base1, t1); (base2, t2)] base12 )
      in
      assert (Txn_snark.Proof.verify [(base1, t1); (base2, t2); (base12, t12)]) ;
      Common.time "verify" (fun () ->
          assert (
            Verify.verify_heterogenous
              [ T
                  ( (module Nat.N2)
                  , (module Txn_snark.Know_preimage.Statement.Constant)
                  , Lazy.force Txn_snark.Know_preimage.Proof.verification_key
                  , base1
                  , preimage_proof )
              ; T
                  ( (module Nat.N2)
                  , (module Txn_snark.Statement.Constant)
                  , Lazy.force Txn_snark.Proof.verification_key
                  , base1
                  , t1 )
              ; T
                  ( (module Nat.N2)
                  , (module Txn_snark.Statement.Constant)
                  , Lazy.force Txn_snark.Proof.verification_key
                  , base2
                  , t2 )
              ; T
                  ( (module Nat.N2)
                  , (module Txn_snark.Statement.Constant)
                  , Lazy.force Txn_snark.Proof.verification_key
                  , base12
                  , t12 ) ] ) ) ;
      (base12, t12)

    module Blockchain_snark = struct
      module Statement = Txn_snark.Statement

      let tag, _, p, Provers.[step] =
        Common.time "compile" (fun () ->
            compile
              (module Statement)
              (module Statement.Constant)
              ~return_typ:(Input Field.typ)
              ~branches:(module Nat.N1)
              ~max_proofs_verified:(module Nat.N2)
              ~name:"blockchain-snark"
              ~choices:(fun ~self ->
                [ { prevs= [self; Txn_snark.tag]
                  ; main=
                      (fun [prev; txn_snark] self ->
                        let is_base_case = Field.equal Field.zero self in
                        let proof_must_verify = Boolean.not is_base_case in
                        Boolean.Assert.any
                          [Field.(equal (one + prev) self); is_base_case] ;
                        [proof_must_verify; proof_must_verify] ) } ] ) )

      module Proof = (val p)
    end

    let xs =
      let s_neg_one = Field.Constant.(negate one) in
      let b_neg_one : (Nat.N2.n, Nat.N2.n) Proof0.t =
        Proof0.dummy Nat.N2.n Nat.N2.n Nat.N2.n
      in
      let b0 =
        Common.time "b0" (fun () ->
            Blockchain_snark.step
              [(s_neg_one, b_neg_one); t_proof]
              Field.Constant.zero )
      in
      let b1 =
        Common.time "b1" (fun () ->
            Blockchain_snark.step
              [(Field.Constant.zero, b0); t_proof]
              Field.Constant.one )
      in
      [(Field.Constant.zero, b0); (Field.Constant.one, b1)]

    let%test_unit "verify" = assert (Blockchain_snark.Proof.verify xs)
  end ) *)
