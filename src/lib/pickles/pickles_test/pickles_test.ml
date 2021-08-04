open Pickles
open Pickles_types
open Backend

let%test_module "test no side-loaded" =
  ( module struct
    let () =
      Tock.Keypair.set_urs_info
        [ On_disk { directory = "/tmp/"; should_write = true } ]

    let () =
      Tick.Keypair.set_urs_info
        [ On_disk { directory = "/tmp/"; should_write = true } ]

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

    module Blockchain_snark = struct
      module Statement = Statement

      let tag, _, p, Provers.[ step ] =
        Common.time "compile" (fun () ->
            compile
              (module Statement)
              (module Statement.Constant)
              ~typ:Field.typ
              ~branches:(module Nat.N1)
              ~max_branching:(module Nat.N2)
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
                  ; prevs = [ self; self ]
                  ; main =
                      (fun [ prev; _ ] self ->
                        let is_base_case = Field.equal Field.zero self in
                        let proof_must_verify = Boolean.not is_base_case in
                        let self_correct = Field.(equal (one + prev) self) in
                        Boolean.Assert.any [ self_correct; is_base_case ] ;
                        [ proof_must_verify; Boolean.false_ ])
                  ; main_value =
                      (fun _ self ->
                        let is_base_case = Field.Constant.(equal zero self) in
                        let proof_must_verify = not is_base_case in
                        [ proof_must_verify; false ])
                  }
                ]))

      module Proof = (val p)
    end

    let xs =
      let s_neg_one = Field.Constant.(negate one) in
      let b_neg_one : (Nat.N2.n, Nat.N2.n) Proof.t =
        Proof.dummy Nat.N2.n Nat.N2.n Nat.N2.n
      in
      let b0 =
        Common.time "b0" (fun () ->
            Async.Thread_safe.block_on_async_exn (fun () ->
                Blockchain_snark.step
                  [ (s_neg_one, b_neg_one); (s_neg_one, b_neg_one) ]
                  Field.Constant.zero))
      in
      let b1 =
        Common.time "b1" (fun () ->
            Async.Thread_safe.block_on_async_exn (fun () ->
                Blockchain_snark.step
                  [ (Field.Constant.zero, b0); (Field.Constant.zero, b0) ]
                  Field.Constant.one))
      in
      [ (Field.Constant.zero, b0); (Field.Constant.one, b1) ]

    let%test_unit "verify" =
      assert (
        Async.Thread_safe.block_on_async_exn (fun () ->
            Blockchain_snark.Proof.verify xs) )
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

      let dummy_constraints () =
        let b = exists Boolean.typ_unchecked ~compute:(fun _ -> true) in
        let g = exists
            Step_main_inputs.Inner_curve.typ ~compute:(fun _ ->
                Tick.Inner_curve.(to_affine_exn one))
        in
        let _ =
          Step_main_inputs.Ops.scale_fast g
            (`Plus_two_to_len [|b; b|])
        in
        let _ =
          Pairing_main.Scalar_challenge.endo g (Scalar_challenge [b])
        in
        ()

        let tag, _, p, Provers.[prove; _] =
          compile
            (module Statement)
            (module Statement.Constant)
            ~typ:Field.typ
            ~branches:(module Nat.N2) (* Should be able to set to 1 *)
            ~max_branching:
              (module Nat.N2) (* TODO: Should be able to set this to 0 *)
            ~name:"preimage"
            ~choices:(fun ~self ->
              (* TODO: Make it possible to have a system that doesn't use its "self" *)
              [ { prevs= []
                ; main_value= (fun [] _ -> [])
                ; main=
                    (fun [] s ->
                       dummy_constraints () ;
                      let x = exists ~request:(fun () -> Preimage) Field.typ in
                      Field.Assert.equal s (hash_checked x) ;
                      [] ) }
                (* TODO: Shouldn't have to have this dummy *)
              ; { prevs= [self; self]
                ; main_value= (fun [_; _] _ -> [true; true])
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
          ~max_branching:(module Nat.N2)
          ~name:"side-loaded"
          ~value_to_field_elements:Statement.to_field_elements
          ~var_to_field_elements:Statement.to_field_elements ~typ:Field.typ

      let tag, _, p, Provers.[base; preimage_base; merge] =
        compile
          (module Statement)
          (module Statement.Constant)
          ~typ:Field.typ
          ~branches:(module Nat.N3)
          ~max_branching:(module Nat.N2)
          ~name:"txn-snark"
          ~choices:(fun ~self ->
            [ { prevs= []
              ; main=
                  (fun [] x ->
                    let t = (Field.is_square x :> Field.t) in
                    for i = 0 to 10_000 do
                      assert_r1cs t t t
                    done ;
                    [] )
              ; main_value= (fun [] _ -> []) }
            ; { prevs= [side_loaded]
              ; main=
                  (fun [hash] x ->
                    Side_loaded.in_circuit side_loaded
                      (exists Side_loaded_verification_key.typ
                         ~compute:(fun () -> Know_preimage.side_loaded_vk)) ;
                    Field.Assert.equal hash x ;
                    [Boolean.true_] )
              ; main_value= (fun [_] _ -> [true]) }
            ; { prevs= [self; self]
              ; main=
                  (fun [l; r] res ->
                    assert_r1cs l r res ;
                    [Boolean.true_; Boolean.true_] )
              ; main_value= (fun _ _ -> [true; true]) } ] )

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
              ~typ:Field.typ
              ~branches:(module Nat.N1)
              ~max_branching:(module Nat.N2)
              ~name:"blockchain-snark"
              ~choices:(fun ~self ->
                [ { prevs= [self; Txn_snark.tag]
                  ; main=
                      (fun [prev; txn_snark] self ->
                        let is_base_case = Field.equal Field.zero self in
                        let proof_must_verify = Boolean.not is_base_case in
                        Boolean.Assert.any
                          [Field.(equal (one + prev) self); is_base_case] ;
                        [proof_must_verify; proof_must_verify] )
                  ; main_value=
                      (fun _ self ->
                        let is_base_case = Field.Constant.(equal zero self) in
                        let proof_must_verify = not is_base_case in
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
