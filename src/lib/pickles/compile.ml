module P = Proof

module type Statement_intf = Intf.Statement

module type Statement_var_intf = Intf.Statement_var

module type Statement_value_intf = Intf.Statement_value

module SC = Scalar_challenge
open Core_kernel
open Async_kernel
open Import
open Pickles_types
open Poly_types
open Hlist
open Backend

let verify_promise = Verify.verify

open Kimchi_backend
module Proof_ = P.Base
module Proof = P
module Inductive_rule = Inductive_rule.Kimchi
module Step_branch_data = Step_branch_data.Make (Inductive_rule)

type chunking_data = Verify.Instance.chunking_data =
  { num_chunks : int; domain_size : int; zk_rows : int }

let pad_messages_for_next_wrap_proof
    (type local_max_proofs_verifieds max_local_max_proofs_verifieds
    max_proofs_verified )
    (module M : Hlist.Maxes.S
      with type ns = max_local_max_proofs_verifieds
       and type length = max_proofs_verified )
    (messages_for_next_wrap_proofs :
      local_max_proofs_verifieds
      H1.T(Proof_.Messages_for_next_proof_over_same_field.Wrap).t ) =
  let dummy_chals = Dummy.Ipa.Wrap.challenges in
  let module Messages =
    H1.T (Proof_.Messages_for_next_proof_over_same_field.Wrap) in
  let module Maxes = H1.T (Nat) in
  let (T (messages_len, _)) = Messages.length messages_for_next_wrap_proofs in
  let (T (maxes_len, _)) = Maxes.length M.maxes in
  let (T difference) =
    let rec sub : type n m. n Nat.t -> m Nat.t -> Nat.e =
     fun x y ->
      let open Nat in
      match (x, y) with
      | _, Z ->
          T x
      | Z, S _ ->
          assert false
      | S x, S y ->
          sub x y
    in
    sub maxes_len messages_len
  in
  let rec go :
      type len ms ns. len Nat.t -> ms Maxes.t -> ns Messages.t -> ms Messages.t
      =
   fun pad maxes messages_for_next_wrap_proofs ->
    match (pad, maxes, messages_for_next_wrap_proofs) with
    | S pad, m :: maxes, _ ->
        { challenge_polynomial_commitment = Lazy.force Dummy.Ipa.Step.sg
        ; old_bulletproof_challenges = Vector.init m ~f:(fun _ -> dummy_chals)
        }
        :: go pad maxes messages_for_next_wrap_proofs
    | S _, [], _ ->
        assert false
    | Z, [], [] ->
        []
    | ( Z
      , m :: maxes
      , messages_for_next_wrap_proof :: messages_for_next_wrap_proofs ) ->
        let messages_for_next_wrap_proof =
          { messages_for_next_wrap_proof with
            old_bulletproof_challenges =
              Vector.extend_exn
                messages_for_next_wrap_proof.old_bulletproof_challenges m
                dummy_chals
          }
        in
        messages_for_next_wrap_proof :: go Z maxes messages_for_next_wrap_proofs
    | Z, [], _ :: _ | Z, _ :: _, [] ->
        assert false
  in
  go difference M.maxes messages_for_next_wrap_proofs

module type Proof_intf = sig
  type statement

  type t

  val verification_key_promise : Verification_key.t Promise.t Lazy.t

  val verification_key : Verification_key.t Deferred.t Lazy.t

  val id_promise : Cache.Wrap.Key.Verification.t Promise.t Lazy.t

  val id : Cache.Wrap.Key.Verification.t Deferred.t Lazy.t

  val verify : (statement * t) list -> unit Or_error.t Deferred.t

  val verify_promise : (statement * t) list -> unit Or_error.t Promise.t
end

module Prover = struct
  type ('prev_values, 'local_widths, 'local_heights, 'a_value, 'proof) t =
       ?handler:
         (   Snarky_backendless.Request.request
          -> Snarky_backendless.Request.response )
    -> 'a_value
    -> 'proof
end

type ('max_proofs_verified, 'branches, 'prev_varss) wrap_main_generic =
  { wrap_main :
      'max_local_max_proofs_verifieds.
         Domains.t
      -> ( 'max_proofs_verified
         , 'branches
         , 'max_local_max_proofs_verifieds )
         Full_signature.t
      -> ('prev_varss, 'branches) Hlist.Length.t
      -> ( ( Wrap_main_inputs.Inner_curve.Constant.t array
           , Wrap_main_inputs.Inner_curve.Constant.t array option )
           Wrap_verifier.index'
         , 'branches )
         Vector.t
         Promise.t
         Lazy.t
      -> (int, 'branches) Pickles_types.Vector.t
      -> (Import.Domains.t, 'branches) Pickles_types.Vector.t Promise.t
      -> (module Pickles_types.Nat.Add.Intf with type n = 'max_proofs_verified)
      -> ('max_proofs_verified, 'max_local_max_proofs_verifieds) Requests.Wrap.t
         * (   ( ( Impls.Wrap.Field.t
                 , Wrap_verifier.Challenge.t Kimchi_types.scalar_challenge
                 , Wrap_verifier.Other_field.Packed.t Shifted_value.Type1.t
                 , ( Wrap_verifier.Other_field.Packed.t Shifted_value.Type1.t
                   , Impls.Wrap.Boolean.var )
                   Opt.t
                 , ( Impls.Wrap.Impl.Field.t Composition_types.Scalar_challenge.t
                   , Impls.Wrap.Boolean.var )
                   Plonkish_prelude.Opt.t
                 , Impls.Wrap.Boolean.var )
                 Composition_types.Wrap.Proof_state.Deferred_values.Plonk
                 .In_circuit
                 .t
               , Wrap_verifier.Challenge.t Kimchi_types.scalar_challenge
               , Wrap_verifier.Other_field.Packed.t
                 Plonkish_prelude.Shifted_value.Type1.t
               , Impls.Wrap.Field.t
               , Impls.Wrap.Field.t
               , Impls.Wrap.Field.t
               , ( Impls.Wrap.Field.t Import.Scalar_challenge.t
                   Import.Types.Bulletproof_challenge.t
                 , Backend.Tick.Rounds.n )
                 Vector.T.t
               , Impls.Wrap.Field.t )
               Composition_types.Wrap.Statement.t
            -> unit )
           Promise.t
           Lazy.t
        (** An override for wrap_main, which allows for adversarial testing
              with an 'invalid' pickles statement by passing a dummy proof.
          *)
  ; tweak_statement :
      'actual_proofs_verified 'b 'e.
         ( Import.Challenge.Constant.t
         , Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
         , Backend.Tick.Field.t Pickles_types.Shifted_value.Type1.t
         , ( Backend.Tick.Field.t Pickles_types.Shifted_value.Type1.t
           , bool )
           Import.Types.Opt.t
         , ( Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
           , bool )
           Import.Types.Opt.t
         , bool
         , 'max_proofs_verified
           Proof.Base.Messages_for_next_proof_over_same_field.Wrap.t
         , Import.Types.Digest.Constant.t
         , ( 'b
           , ( Kimchi_pasta.Pallas_based_plonk.Proof.G.Affine.t
             , 'actual_proofs_verified )
             Pickles_types.Vector.t
           , ( ( Import.Challenge.Constant.t Import.Scalar_challenge.t
                 Import.Bulletproof_challenge.t
               , 'e )
               Pickles_types.Vector.t
             , 'actual_proofs_verified )
             Pickles_types.Vector.t )
           Proof.Base.Messages_for_next_proof_over_same_field.Step.t
         , Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
           Import.Types.Bulletproof_challenge.t
           Import.Types.Step_bp_vec.t
         , Import.Types.Branch_data.t )
         Import.Types.Wrap.Statement.In_circuit.t
      -> ( Import.Challenge.Constant.t
         , Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
         , Backend.Tick.Field.t Pickles_types.Shifted_value.Type1.t
         , ( Backend.Tick.Field.t Pickles_types.Shifted_value.Type1.t
           , bool )
           Import.Types.Opt.t
         , ( Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
           , bool )
           Import.Types.Opt.t
         , bool
         , 'max_proofs_verified
           Proof.Base.Messages_for_next_proof_over_same_field.Wrap.t
         , Import.Types.Digest.Constant.t
         , ( 'b
           , ( Kimchi_pasta.Pallas_based_plonk.Proof.G.Affine.t
             , 'actual_proofs_verified )
             Pickles_types.Vector.t
           , ( ( Import.Challenge.Constant.t Import.Scalar_challenge.t
                 Import.Bulletproof_challenge.t
               , 'e )
               Pickles_types.Vector.t
             , 'actual_proofs_verified )
             Pickles_types.Vector.t )
           Proof.Base.Messages_for_next_proof_over_same_field.Step.t
         , Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
           Import.Types.Bulletproof_challenge.t
           Import.Types.Step_bp_vec.t
         , Import.Types.Branch_data.t )
         Import.Types.Wrap.Statement.In_circuit.t
        (** A function to modify the statement passed into the wrap proof,
              which will be later passed to recursion pickles rules.

              This function can be used to modify the pickles statement in an
              adversarial way, along with [wrap_main] above that allows that
              statement to be accepted.
          *)
  }

module Storables = struct
  type t =
    { step_storable : Cache.Step.storable
    ; step_vk_storable : Cache.Step.vk_storable
    ; wrap_storable : Cache.Wrap.storable
    ; wrap_vk_storable : Cache.Wrap.vk_storable
    }

  let default =
    { step_storable = Cache.Step.storable
    ; step_vk_storable = Cache.Step.vk_storable
    ; wrap_storable = Cache.Wrap.storable
    ; wrap_vk_storable = Cache.Wrap.vk_storable
    }
end

let create_lock () =
  let lock = ref (Promise.return ()) in

  let open Promise.Let_syntax in
  let run_in_sequence (f : unit -> 'a Promise.t) : 'a Promise.t =
    (* acquire the lock *)
    let existing_lock = !lock in
    let unlock = ref (fun () -> ()) in
    lock := Promise.create (fun resolve -> unlock := resolve) ;
    (* await the existing lock *)
    let%bind () = existing_lock in
    (* run the function and release the lock *)
    try
      let%map res = f () in
      !unlock () ; res
    with exn -> !unlock () ; raise exn
  in
  run_in_sequence

(* turn a vector of promises into a promise of a vector *)
let promise_all (type a n) (vec : (a Promise.t, n) Vector.t) :
    (a, n) Vector.t Promise.t =
  let open Promise.Let_syntax in
  let%map () =
    (* Wait for promises to resolve. *)
    Vector.fold ~init:(Promise.return ()) vec ~f:(fun acc el ->
        let%bind _ = el in
        acc )
  in
  Vector.map ~f:(fun x -> Option.value_exn @@ Promise.peek x) vec

module Make
    (Arg_var : Statement_var_intf)
    (Arg_value : Statement_value_intf)
    (Ret_var : T0)
    (Ret_value : T0)
    (Auxiliary_var : T0)
    (Auxiliary_value : T0) =
struct
  module IR =
    Inductive_rule.Promise.T (Arg_var) (Arg_value) (Ret_var) (Ret_value)
      (Auxiliary_var)
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
            Vector.extend_front_exn
              (V.f l (M.f rule.prevs))
              Max_proofs_verified.n 0
        end)
    in
    let module V = H4.To_vector (Local_max_proofs_verifieds) in
    let padded = V.f branches (M.f choices) |> Vector.transpose in
    (padded, Maxes.m padded)

  module Lazy_keys = struct
    type t =
      (Impls.Step.Proving_key.t * Dirty.t) Promise.t Lazy.t
      * (Kimchi_bindings.Protocol.VerifierIndex.Fp.t * Dirty.t) Promise.t Lazy.t
  end

  let compile :
      type var value prev_varss prev_valuess widthss heightss max_proofs_verified branches.
         self:(var, value, max_proofs_verified, branches) Tag.t
      -> cache:Key_cache.Spec.t list
      -> storables:Storables.t
      -> proof_cache:Proof_cache.t option
      -> ?disk_keys:
           (Cache.Step.Key.Verification.t, branches) Vector.t
           * Cache.Wrap.Key.Verification.t
      -> ?override_wrap_domain:Pickles_base.Proofs_verified.t
      -> ?override_wrap_main:
           (max_proofs_verified, branches, prev_varss) wrap_main_generic
      -> ?num_chunks:int
      -> ?lazy_mode:bool
      -> branches:branches Nat.t
      -> prev_varss_length:(prev_varss, branches) Length.t
      -> max_proofs_verified:
           (module Nat.Add.Intf with type n = max_proofs_verified)
      -> name:string
      -> ?constraint_constants:Snark_keys_header.Constraint_constants.t
      -> public_input:
           ( var
           , value
           , Arg_var.t
           , Arg_value.t
           , Ret_var.t
           , Ret_value.t )
           Inductive_rule.public_input
      -> auxiliary_typ:(Auxiliary_var.t, Auxiliary_value.t) Impls.Step.Typ.t
      -> choices:(prev_varss, prev_valuess, widthss, heightss) H4.T(IR).t
      -> unit
      -> ( prev_valuess
         , widthss
         , heightss
         , Arg_value.t
         , (Ret_value.t * Auxiliary_value.t * max_proofs_verified Proof.t)
           Promise.t )
         H3_2.T(Prover).t
         * _
         * _
         * _ =
   fun ~self ~cache
       ~storables:
         { step_storable; step_vk_storable; wrap_storable; wrap_vk_storable }
       ~proof_cache ?disk_keys ?override_wrap_domain ?override_wrap_main
       ?(num_chunks = Plonk_checks.num_chunks_by_default) ?(lazy_mode = false)
       ~branches ~prev_varss_length ~max_proofs_verified ~name
       ?constraint_constants ~public_input ~auxiliary_typ ~choices () ->
    let snark_keys_header kind constraint_system_hash =
      let constraint_constants : Snark_keys_header.Constraint_constants.t =
        match constraint_constants with
        | Some constraint_constants ->
            constraint_constants
        | None ->
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
      in
      { Snark_keys_header.header_version = Snark_keys_header.header_version
      ; kind
      ; constraint_constants
      ; length = (* This is a dummy, it gets filled in on read/write. *) 0
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
    let padded, (module Maxes) =
      max_local_max_proofs_verifieds
        ( module struct
          include Max_proofs_verified
        end )
        prev_varss_length choices ~self:self.id
    in
    let full_signature = { Full_signature.padded; maxes = (module Maxes) } in
    Timer.clock __LOC__ ;
    let feature_flags =
      let rec go :
          type a b c d.
          (a, b, c, d) H4.T(IR).t -> Opt.Flag.t Plonk_types.Features.Full.t =
       fun rules ->
        match rules with
        | [] ->
            Plonk_types.Features.Full.none
        | [ r ] ->
            Plonk_types.Features.map r.feature_flags ~f:(function
              | true ->
                  Opt.Flag.Yes
              | false ->
                  Opt.Flag.No )
            |> Plonk_types.Features.to_full ~or_:Opt.Flag.( ||| )
        | r :: rules ->
            let feature_flags = go rules in
            Plonk_types.Features.Full.map2
              (Plonk_types.Features.to_full ~or_:( || ) r.feature_flags)
              feature_flags ~f:(fun enabled flag ->
                match (enabled, flag) with
                | true, Yes ->
                    Opt.Flag.Yes
                | false, No ->
                    No
                | _, Maybe | true, No | false, Yes ->
                    Maybe )
      in
      go choices
    in
    let wrap_domains =
      match override_wrap_domain with
      | None ->
          let module M =
            Wrap_domains.Make (Arg_var) (Arg_value) (Ret_var) (Ret_value)
              (Auxiliary_var)
              (Auxiliary_value)
          in
          M.f full_signature branches prev_varss_length ~max_proofs_verified
            ~feature_flags ~num_chunks
      | Some override ->
          Common.wrap_domains
            ~proofs_verified:(Pickles_base.Proofs_verified.to_int override)
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
        , branches
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
    let step_data =
      let i = ref 0 in
      Timer.clock __LOC__ ;
      let rec f :
          type a b c d.
             (a, b, c, d) H4.T(IR).t * unit Promise.t
          -> (a, b, c, d) H4.T(Branch_data).t = function
        | [], _ ->
            []
        | rule :: rules, chain_to ->
            let first =
              Timer.clock __LOC__ ;
              let res =
                Common.time "make step data" (fun () ->
                    Step_branch_data.create ~index:!i ~feature_flags ~num_chunks
                      ~actual_feature_flags:rule.feature_flags
                      ~max_proofs_verified:Max_proofs_verified.n ~branches ~self
                      ~public_input ~auxiliary_typ Arg_var.to_field_elements
                      Arg_value.to_field_elements rule ~wrap_domains ~chain_to )
              in
              Timer.clock __LOC__ ; incr i ; res
            in
            let (T b) = first in
            let chain_to = Promise.map b.domains ~f:(fun _ -> ()) in
            first :: f (rules, chain_to)
      in
      f (choices, Promise.return ())
    in
    Timer.clock __LOC__ ;
    let step_domains =
      let module Domains_promise = struct
        type t = Domains.t Promise.t
      end in
      let module M =
        H4.Map (Branch_data) (E04 (Domains_promise))
          (struct
            let f (T b : _ Branch_data.t) = b.domains
          end)
      in
      let module V = H4.To_vector (Domains_promise) in
      V.f prev_varss_length (M.f step_data)
    in

    let all_step_domains = promise_all step_domains in
    let run_in_sequence = create_lock () in

    let cache_handle = ref (Lazy.return (Promise.return `Cache_hit)) in
    let accum_dirty t = cache_handle := Cache_handle.(!cache_handle + t) in
    Timer.clock __LOC__ ;
    let step_keypairs =
      let disk_keys =
        Option.map disk_keys ~f:(fun (xs, _) -> Vector.to_array xs)
      in
      let module M =
        H4.Map (Branch_data) (E04 (Lazy_keys))
          (struct
            let etyp = Impls.Step.input ~proofs_verified:Max_proofs_verified.n

            let f (T b : _ Branch_data.t) =
              let open Impls.Step in
              let k_p =
                lazy
                  (let (T (typ, _conv, conv_inv)) = etyp in
                   let%bind.Promise main =
                     b.main ~step_domains:all_step_domains
                   in
                   run_in_sequence (fun () ->
                       let main () () =
                         let%map.Promise res = main () in
                         Impls.Step.with_label "conv_inv" (fun () ->
                             conv_inv res )
                       in
                       let constraint_builder =
                         Impl.constraint_system_manual ~input_typ:Typ.unit
                           ~return_typ:typ
                       in
                       let%map.Promise res =
                         constraint_builder.run_circuit main
                       in
                       let cs = constraint_builder.finish_computation res in
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
                       , cs ) ) )
              in
              let k_v =
                match disk_keys with
                | Some ks ->
                    Lazy.return (Promise.return ks.(b.index))
                | None ->
                    lazy
                      (let%map.Promise id, _header, index, cs =
                         Lazy.force k_p
                       in
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
                    Cache.Step.read_or_generate
                      ~prev_challenges:(Nat.to_int (fst b.proofs_verified))
                      cache ~s_p:step_storable ~s_v:step_vk_storable ~lazy_mode
                      k_p k_v )
              in
              accum_dirty (Lazy.map pk ~f:(Promise.map ~f:snd)) ;
              accum_dirty (Lazy.map vk ~f:(Promise.map ~f:snd)) ;
              res
          end)
      in
      M.f step_data
    in
    Timer.clock __LOC__ ;
    let step_vks =
      let module V = H4.To_vector (Lazy_keys) in
      lazy
        (let step_keypairs = V.f prev_varss_length step_keypairs in
         let%map.Promise () =
           (* Wait for keypair promises to resolve. *)
           Vector.fold ~init:(Promise.return ()) step_keypairs
             ~f:(fun acc (_, vk) ->
               let%bind.Promise _ = Lazy.force vk in
               acc )
         in
         Vector.map step_keypairs ~f:(fun (_, vk) ->
             Tick.Keypair.full_vk_commitments
               (fst (Option.value_exn @@ Promise.peek @@ Lazy.force vk)) ) )
    in
    Timer.clock __LOC__ ;
    let wrap_requests, wrap_main =
      match override_wrap_main with
      | None ->
          let srs = Tick.Keypair.load_urs () in
          Wrap_main.wrap_main ~num_chunks ~feature_flags ~srs full_signature
            prev_varss_length step_vks proofs_verifieds all_step_domains
            max_proofs_verified
      | Some { wrap_main; tweak_statement = _ } ->
          (* Instead of creating a proof using the pickles wrap circuit, we
             have been asked to create proof in an 'adversarial' way, where
             the wrap circuit is some other circuit.
             The [wrap_main] value passed in as part of [override_wrap_main]
             defines the alternative circuit to run; this will usually be a
             dummy circuit that verifies any public input for the purposes of
             testing.
          *)
          wrap_main wrap_domains full_signature prev_varss_length step_vks
            proofs_verifieds all_step_domains max_proofs_verified
    in
    Timer.clock __LOC__ ;
    let (wrap_pk, wrap_vk), disk_key =
      let open Impls.Wrap in
      let self_id = Type_equal.Id.uid self.id in
      let disk_key_prover =
        lazy
          (let%map.Promise wrap_main = Lazy.force wrap_main in
           let (T (typ, conv, _conv_inv)) = input ~feature_flags () in
           let main x () = wrap_main (conv x) in
           let cs =
             constraint_system ~input_typ:typ ~return_typ:Impls.Wrap.Typ.unit
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
              (let%map.Promise id, _header, cs = Lazy.force disk_key_prover in
               let digest = R1CS_constraint_system.digest cs in
               ( id
               , snark_keys_header
                   { type_ = "wrap-verification-key"; identifier = name }
                   (Md5.to_hex digest)
               , digest ) )
        | Some (_, (_id, header, digest)) ->
            Lazy.return @@ Promise.return (self_id, header, digest)
      in
      let r =
        Common.time "wrap read or generate " (fun () ->
            Cache.Wrap.read_or_generate (* Due to Wrap_hack *)
              ~prev_challenges:2 cache ~s_p:wrap_storable ~s_v:wrap_vk_storable
              ~lazy_mode disk_key_prover disk_key_verifier )
      in
      (r, disk_key_verifier)
    in
    Timer.clock __LOC__ ;
    let wrap_vk =
      Lazy.map wrap_vk
        ~f:
          (Promise.map ~f:(fun ((wrap_vk, _) as res) ->
               let computed_domain_size =
                 wrap_vk.Verification_key.index.domain.log_size_of_group
               in
               let (Pow_2_roots_of_unity proposed_domain_size) =
                 wrap_domains.h
               in
               if computed_domain_size <> proposed_domain_size then
                 failwithf
                   "This circuit was compiled for proofs using the wrap domain \
                    of size %d, but the actual wrap domain size for the \
                    circuit has size %d. You should pass the \
                    ~override_wrap_domain argument to set the correct domain \
                    size."
                   proposed_domain_size computed_domain_size () ;
               res ) )
    in
    accum_dirty (Lazy.map wrap_pk ~f:(Promise.map ~f:snd)) ;
    accum_dirty (Lazy.map wrap_vk ~f:(Promise.map ~f:snd)) ;
    let wrap_vk = Lazy.map wrap_vk ~f:(Promise.map ~f:fst) in
    let module S =
      Step.Make (Inductive_rule) (Arg_var) (Arg_value)
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
      let f :
          type prev_vars prev_values local_widths local_heights.
             (prev_vars, prev_values, local_widths, local_heights) Branch_data.t
          -> Lazy_keys.t
          -> ?handler:
               (   Snarky_backendless.Request.request
                -> Snarky_backendless.Request.response )
          -> Arg_value.t
          -> (Ret_value.t * Auxiliary_value.t * Max_proofs_verified.n Proof.t)
             Promise.t =
       fun (T b as branch_data) (step_pk, step_vk) ->
        let _, prev_vars_length = b.proofs_verified in
        let step ~proof_cache ~maxes handler next_state =
          let%bind.Promise wrap_vk = Lazy.force wrap_vk in
          let%bind.Promise step_pk = Lazy.force step_pk in
          S.f ?handler branch_data next_state ~prevs_length:prev_vars_length
            ~self ~step_domains:all_step_domains
            ~self_dlog_plonk_index:
              ((* TODO *) Plonk_verification_key_evals.map
                 ~f:(fun x -> [| x |])
                 wrap_vk.commitments )
            ~public_input ~auxiliary_typ ~feature_flags ~proof_cache ~maxes
            (fst step_pk) wrap_vk.index
        in
        let wrap ?handler next_state =
          let%bind.Promise step_vk, _ = Lazy.force step_vk in
          let%bind.Promise wrap_vk = Lazy.force wrap_vk in
          let%bind.Promise ( proof
                           , return_value
                           , auxiliary_value
                           , actual_wrap_domains ) =
            step ~proof_cache handler ~maxes:(module Maxes) next_state
          in
          let proof =
            { proof with
              statement =
                { proof.statement with
                  messages_for_next_wrap_proof =
                    pad_messages_for_next_wrap_proof
                      (module Maxes)
                      proof.statement.messages_for_next_wrap_proof
                }
            }
          in
          let%map.Promise proof =
            let tweak_statement =
              match override_wrap_main with
              | None ->
                  None
              | Some { tweak_statement; wrap_main = _ } ->
                  (* Extract the [tweak_statement] part of the
                     [override_wrap_main], so that we can run an adversarial
                     test.

                     This function modifies the statement that will be proved
                     over, and which gets passed to later recursive pickles
                     rules.
                  *)
                  Some tweak_statement
            in
            let%bind.Promise wrap_main = Lazy.force wrap_main in
            let%bind.Promise wrap_pk = Lazy.force wrap_pk in
            Wrap.wrap ~proof_cache ~max_proofs_verified:Max_proofs_verified.n
              ~feature_flags ~actual_feature_flags:b.feature_flags
              full_signature.maxes wrap_requests ?tweak_statement
              ~dlog_plonk_index:
                ((* TODO *) Plonk_verification_key_evals.map
                   ~f:(fun x -> [| x |])
                   wrap_vk.commitments )
              wrap_main ~typ ~step_vk ~step_plonk_indices:(Lazy.force step_vks)
              ~actual_wrap_domains (fst wrap_pk) proof
          in
          ( return_value
          , auxiliary_value
          , Proof.T
              { proof with
                statement =
                  { proof.statement with
                    messages_for_next_step_proof =
                      { proof.statement.messages_for_next_step_proof with
                        app_state = ()
                      }
                  }
              } )
        in
        wrap
      in
      let rec go :
          type xs1 xs2 xs3 xs4.
             (xs1, xs2, xs3, xs4) H4.T(Branch_data).t
          -> (xs1, xs2, xs3, xs4) H4.T(E04(Lazy_keys)).t
          -> ( xs2
             , xs3
             , xs4
             , Arg_value.t
             , (Ret_value.t * Auxiliary_value.t * max_proofs_verified Proof.t)
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
      { max_proofs_verified
      ; public_input = typ
      ; wrap_key =
          Lazy.map wrap_vk
            ~f:
              (Promise.map ~f:(fun x ->
                   Plonk_verification_key_evals.map
                     (Verification_key.commitments x) ~f:(fun x -> [| x |]) ) )
      ; wrap_vk = Lazy.map wrap_vk ~f:(Promise.map ~f:Verification_key.index)
      ; wrap_domains
      ; step_domains
      ; feature_flags
      ; num_chunks
      ; zk_rows =
          ( match num_chunks with
          | 1 (* cannot match with Plonk_checks.num_chunks_by_default *) ->
              Plonk_checks.zk_rows_by_default
          | num_chunks ->
              let permuts = 7 in
              ((2 * (permuts + 1) * num_chunks) - 2 + permuts) / permuts )
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

    let of_compiled_promise tag : t Promise.t =
      let d = Types_map.lookup_compiled tag.Tag.id in
      let%bind.Promise wrap_key = Lazy.force d.wrap_key in
      let%map.Promise wrap_vk = Lazy.force d.wrap_vk in
      let actual_wrap_domain_size =
        Common.actual_wrap_domain_size
          ~log_2_domain_size:wrap_vk.domain.log_size_of_group
      in
      ( { wrap_vk = Some wrap_vk
        ; wrap_index =
            Plonk_verification_key_evals.map wrap_key ~f:(fun x -> x.(0))
        ; max_proofs_verified =
            Pickles_base.Proofs_verified.of_nat_exn
              (Nat.Add.n d.max_proofs_verified)
        ; actual_wrap_domain_size
        }
        : t )

    let of_compiled tag = of_compiled_promise tag |> Promise.to_deferred

    module Max_width = Width.Max
  end

  let in_circuit tag vk = Types_map.set_ephemeral tag { index = `In_circuit vk }

  let in_prover tag vk = Types_map.set_ephemeral tag { index = `In_prover vk }

  let create ~name ~max_proofs_verified ~feature_flags ~typ =
    Types_map.add_side_loaded ~name
      { max_proofs_verified
      ; public_input = typ
      ; feature_flags =
          Plonk_types.Features.to_full ~or_:Opt.Flag.( ||| ) feature_flags
      ; num_chunks = Plonk_checks.num_chunks_by_default
      ; zk_rows = Plonk_checks.zk_rows_by_default
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
                      return
                        (Promise.return
                           (Or_error.errorf "Pickles.verify: wrap_vk not found") )
                  | Some x ->
                      x )
              ; data =
                  (* This isn't used in verify_heterogeneous, so we can leave this dummy *)
                  { constraints = 0 }
              }
            in
            Verify.Instance.T (max_proofs_verified, m, None, vk, x, p) )
        |> Verify.verify_heterogenous )

  let verify ~typ ts = verify_promise ~typ ts |> Promise.to_deferred

  let srs_precomputation () : unit =
    let srs = Tock.Keypair.load_urs () in
    List.iter [ 0; 1; 2 ] ~f:(fun i ->
        Kimchi_bindings.Protocol.SRS.Fq.add_lagrange_basis srs
          (Domain.log2_size (Common.wrap_domains ~proofs_verified:i).h) )
end

let compile_with_wrap_main_override_promise :
    type var value a_var a_value ret_var ret_value auxiliary_var auxiliary_value prev_varss prev_valuess widthss heightss max_proofs_verified branches.
       ?self:(var, value, max_proofs_verified, branches) Tag.t
    -> ?cache:Key_cache.Spec.t list
    -> ?storables:Storables.t
    -> ?proof_cache:Proof_cache.t
    -> ?disk_keys:
         (Cache.Step.Key.Verification.t, branches) Vector.t
         * Cache.Wrap.Key.Verification.t
    -> ?override_wrap_domain:Pickles_base.Proofs_verified.t
    -> ?override_wrap_main:
         (max_proofs_verified, branches, prev_varss) wrap_main_generic
    -> ?num_chunks:int
    -> ?lazy_mode:bool
    -> public_input:
         ( var
         , value
         , a_var
         , a_value
         , ret_var
         , ret_value )
         Inductive_rule.public_input
    -> auxiliary_typ:(auxiliary_var, auxiliary_value) Impls.Step.Typ.t
    -> max_proofs_verified:
         (module Nat.Add.Intf with type n = max_proofs_verified)
    -> name:string
    -> ?constraint_constants:Snark_keys_header.Constraint_constants.t
    -> choices:
         (   self:(var, value, max_proofs_verified, branches) Tag.t
          -> ( branches
             , prev_varss
             , prev_valuess
             , widthss
             , heightss
             , a_var
             , a_value
             , ret_var
             , ret_value
             , auxiliary_var
             , auxiliary_value )
             H4_6_with_length.T(Inductive_rule.Promise).t )
    -> unit
    -> (var, value, max_proofs_verified, branches) Tag.t
       * Cache_handle.t
       * (module Proof_intf
            with type t = max_proofs_verified Proof.t
             and type statement = value )
       * ( prev_valuess
         , widthss
         , heightss
         , a_value
         , (ret_value * auxiliary_value * max_proofs_verified Proof.t) Promise.t
         )
         H3_2.T(Prover).t =
 (* This function is an adapter between the user-facing Pickles.compile API
    and the underlying Make(_).compile function which builds the circuits.
 *)
 fun ?self ?(cache = []) ?(storables = Storables.default) ?proof_cache
     ?disk_keys ?override_wrap_domain ?override_wrap_main ?num_chunks ?lazy_mode
     ~public_input ~auxiliary_typ ~max_proofs_verified ~name
     ?constraint_constants ~choices () ->
  let self =
    match self with
    | None ->
        Tag.(create ~kind:Compiled name)
    | Some self ->
        self
  in
  (* Extract to_fields methods from the public input declaration. *)
  let (a_var_to_fields : a_var -> _), (a_value_to_fields : a_value -> _) =
    match public_input with
    | Input (Typ typ) ->
        ( (fun x -> fst (typ.var_to_fields x))
        , fun x -> fst (typ.value_to_fields x) )
    | Output _ ->
        ((fun () -> [||]), fun () -> [||])
    | Input_and_output (Typ typ, _) ->
        ( (fun x -> fst (typ.var_to_fields x))
        , fun x -> fst (typ.value_to_fields x) )
  in
  let module A_var = struct
    type t = a_var

    let to_field_elements = a_var_to_fields
  end in
  let module A_value = struct
    type t = a_value

    let to_field_elements = a_value_to_fields
  end in
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
      type branches v1ss v2ss wss hss.
         ( branches
         , v1ss
         , v2ss
         , wss
         , hss
         , a_var
         , a_value
         , ret_var
         , ret_value
         , auxiliary_var
         , auxiliary_value )
         H4_6_with_length.T(Inductive_rule.Promise).t
      -> (v1ss, v2ss, wss, hss) H4.T(M.IR).t = function
    | [] ->
        []
    | r :: rs ->
        r :: conv_irs rs
  in
  let choices = choices ~self in
  let branches, prev_varss_length =
    let module IR_hlist = H4_6_with_length.T (Inductive_rule.Promise) in
    IR_hlist.length choices
  in
  let provers, wrap_vk, wrap_disk_key, cache_handle =
    M.compile ~self ~proof_cache ~cache ~storables ?disk_keys
      ?override_wrap_domain ?override_wrap_main ?num_chunks ?lazy_mode ~branches
      ~prev_varss_length ~max_proofs_verified ~name ~public_input ~auxiliary_typ
      ?constraint_constants ~choices:(conv_irs choices) ()
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
  let chunking_data =
    match num_chunks with
    | None ->
        Promise.return None
    | Some num_chunks ->
        let compiled = Types_map.lookup_compiled self.id in
        let%map.Promise domains = promise_all compiled.step_domains in
        let { h = Pow_2_roots_of_unity domain_size } =
          domains
          |> Vector.reduce_exn
               ~f:(fun
                    { h = Pow_2_roots_of_unity d1 }
                    { h = Pow_2_roots_of_unity d2 }
                  -> { h = Pow_2_roots_of_unity (Int.max d1 d2) } )
        in
        Some
          { Verify.Instance.num_chunks
          ; domain_size
          ; zk_rows = compiled.zk_rows
          }
  in
  let module P = struct
    type statement = value

    module Max_local_max_proofs_verified = Max_proofs_verified

    include Proof.Make (struct
      include Max_local_max_proofs_verified
    end)

    let id_promise = wrap_disk_key

    let id = Lazy.map ~f:Promise.to_deferred wrap_disk_key

    let verification_key_promise = wrap_vk

    let verification_key = Lazy.map ~f:Promise.to_deferred wrap_vk

    let verify_promise ts =
      let%bind.Promise chunking_data = chunking_data in
      let%bind.Promise verification_key = Lazy.force verification_key_promise in
      verify_promise ?chunking_data
        ( module struct
          include Max_proofs_verified
        end )
        (module Value)
        verification_key ts

    let verify ts = verify_promise ts |> Promise.to_deferred
  end in
  (self, cache_handle, (module P), provers)

let wrap_main_dummy_override _ _ _ _ _ _ _ =
  let requests =
    (* The requests that the logic in [Wrap.wrap] use to pass
       values into and out of the wrap proof circuit.
       Since these are unnecessary for the dummy circuit below, we
       generate them without using them.
    *)
    Requests.Wrap.create ()
  in
  (* A replacement for the 'wrap' circuit, which makes no
     assertions about the statement that it receives as its first
     argument.
  *)
  let wrap_main _ =
    let module SC' = SC in
    let open Impls.Wrap in
    let open Wrap_main_inputs in
    (* Create some variables to be used in constraints below. *)
    let x = exists Field.typ ~compute:(fun () -> Field.Constant.of_int 3) in
    let y = exists Field.typ ~compute:(fun () -> Field.Constant.of_int 0) in
    let z = exists Field.typ ~compute:(fun () -> Field.Constant.of_int 0) in
    (* Every circuit must use at least 1 of each constraint; we
       use them here.
    *)
    let () =
      let g = Inner_curve.one in
      let sponge = Sponge.create sponge_params in
      Sponge.absorb sponge x ;
      ignore (Sponge.squeeze_field sponge : Field.t) ;
      ignore
        ( SC'.to_field_checked'
            (module Impl)
            ~num_bits:16
            (Kimchi_backend_common.Scalar_challenge.create x)
          : Field.t * Field.t * Field.t ) ;
      ignore (Ops.scale_fast g ~num_bits:5 (Shifted_value x) : Inner_curve.t) ;
      ignore
        ( Wrap_verifier.Scalar_challenge.endo g ~num_bits:4
            (Kimchi_backend_common.Scalar_challenge.create x)
          : Field.t * Field.t )
    in
    (* Pad the circuit so that its domain size matches the one
       that would have been used by the true wrap_main.
    *)
    for _ = 0 to 64000 do
      assert_r1cs x y z
    done
  in
  (requests, Lazy.return @@ Promise.return @@ wrap_main)

module Make_adversarial_test (M : sig
  val tweak_statement :
       ( Import.Challenge.Constant.t
       , Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
       , Backend.Tick.Field.t Pickles_types.Shifted_value.Type1.t
       , ( Backend.Tick.Field.t Pickles_types.Shifted_value.Type1.t
         , bool )
         Import.Types.Opt.t
       , ( Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
         , bool )
         Import.Types.Opt.t
       , bool
       , 'max_proofs_verified
         Proof.Base.Messages_for_next_proof_over_same_field.Wrap.t
       , Import.Types.Digest.Constant.t
       , ( 'b
         , ( Kimchi_pasta.Pallas_based_plonk.Proof.G.Affine.t
           , 'actual_proofs_verified )
           Pickles_types.Vector.t
         , ( ( Import.Challenge.Constant.t Import.Scalar_challenge.t
               Import.Bulletproof_challenge.t
             , 'e )
             Pickles_types.Vector.t
           , 'actual_proofs_verified )
           Pickles_types.Vector.t )
         Proof.Base.Messages_for_next_proof_over_same_field.Step.t
       , Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
         Import.Types.Bulletproof_challenge.t
         Import.Types.Step_bp_vec.t
       , Import.Types.Branch_data.t )
       Import.Types.Wrap.Statement.In_circuit.t
    -> ( Import.Challenge.Constant.t
       , Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
       , Backend.Tick.Field.t Pickles_types.Shifted_value.Type1.t
       , ( Backend.Tick.Field.t Pickles_types.Shifted_value.Type1.t
         , bool )
         Import.Types.Opt.t
       , ( Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
         , bool )
         Import.Types.Opt.t
       , bool
       , 'max_proofs_verified
         Proof.Base.Messages_for_next_proof_over_same_field.Wrap.t
       , Import.Types.Digest.Constant.t
       , ( 'b
         , ( Kimchi_pasta.Pallas_based_plonk.Proof.G.Affine.t
           , 'actual_proofs_verified )
           Pickles_types.Vector.t
         , ( ( Import.Challenge.Constant.t Import.Scalar_challenge.t
               Import.Bulletproof_challenge.t
             , 'e )
             Pickles_types.Vector.t
           , 'actual_proofs_verified )
           Pickles_types.Vector.t )
         Proof.Base.Messages_for_next_proof_over_same_field.Step.t
       , Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
         Import.Types.Bulletproof_challenge.t
         Import.Types.Step_bp_vec.t
       , Import.Types.Branch_data.t )
       Import.Types.Wrap.Statement.In_circuit.t

  val check_verifier_error : Error.t -> unit
end) =
struct
  open Impls.Step

  let rule self : _ Inductive_rule.Promise.t =
    { identifier = "main"
    ; prevs = [ self; self ]
    ; main =
        (fun { public_input = () } ->
          let dummy_proof =
            exists (Typ.prover_value ()) ~compute:(fun () ->
                Proof.dummy Nat.N2.n Nat.N2.n ~domain_log2:15 )
          in
          Promise.return
            { Inductive_rule.previous_proof_statements =
                [ { public_input = ()
                  ; proof = dummy_proof
                  ; proof_must_verify = Boolean.false_
                  }
                ; { public_input = ()
                  ; proof = dummy_proof
                  ; proof_must_verify = Boolean.false_
                  }
                ]
            ; public_output = ()
            ; auxiliary_output = ()
            } )
    ; feature_flags = Plonk_types.Features.none_bool
    }

  let override_wrap_main =
    { wrap_main = wrap_main_dummy_override
    ; tweak_statement = M.tweak_statement
    }

  let tag, _, p, ([ step ] : _ H3_2.T(Prover).t) =
    compile_with_wrap_main_override_promise () ~override_wrap_main
      ~public_input:(Input Typ.unit) ~auxiliary_typ:Typ.unit
      ~max_proofs_verified:(module Nat.N2)
      ~name:"blockchain-snark"
      ~choices:(fun ~self -> [ rule self ])

  module Proof = (val p)

  let proof_with_stmt =
    let (), (), p = Promise.block_on_async_exn (fun () -> step ()) in
    ((), p)

  let%test "should not be able to verify invalid proof" =
    match
      Promise.block_on_async_exn (fun () ->
          Proof.verify_promise [ proof_with_stmt ] )
    with
    | Ok () ->
        false
    | Error err ->
        M.check_verifier_error err ; true

  module Recurse_on_bad_proof = struct
    open Impls.Step

    type _ Snarky_backendless.Request.t +=
      | Proof : Proof.t Snarky_backendless.Request.t

    let handler (proof : Proof.t)
        (Snarky_backendless.Request.With { request; respond }) =
      match request with
      | Proof ->
          respond (Provide proof)
      | _ ->
          respond Unhandled

    let _tag, _, p, ([ step ] : _ H3_2.T(Prover).t) =
      Common.time "compile" (fun () ->
          compile_with_wrap_main_override_promise ()
            ~public_input:(Input Typ.unit) ~auxiliary_typ:Typ.unit
            ~max_proofs_verified:(module Nat.N2)
            ~name:"recurse-on-bad"
            ~choices:(fun ~self:_ ->
              [ { identifier = "main"
                ; feature_flags = Plonk_types.Features.none_bool
                ; prevs = [ tag; tag ]
                ; main =
                    (fun { public_input = () } ->
                      let proof =
                        exists (Typ.prover_value ()) ~request:(fun () -> Proof)
                      in
                      Promise.return
                        { Inductive_rule.previous_proof_statements =
                            [ { public_input = ()
                              ; proof
                              ; proof_must_verify = Boolean.true_
                              }
                            ; { public_input = ()
                              ; proof
                              ; proof_must_verify = Boolean.true_
                              }
                            ]
                        ; public_output = ()
                        ; auxiliary_output = ()
                        } )
                }
              ] ) )

    module Proof = (val p)
  end

  let%test "should not be able to create a recursive proof from an invalid \
            proof" =
    try
      let (), (), proof =
        Promise.block_on_async_exn (fun () ->
            Recurse_on_bad_proof.step
              ~handler:(Recurse_on_bad_proof.handler (snd proof_with_stmt))
              () )
      in
      Or_error.is_error
      @@ Promise.block_on_async_exn (fun () ->
             Recurse_on_bad_proof.Proof.verify_promise [ ((), proof) ] )
    with _ -> true
end
