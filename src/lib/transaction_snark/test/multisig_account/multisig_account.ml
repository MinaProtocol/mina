open Core
open Mina_ledger
open Signature_lib
open Mina_base
open Snark_params
open Tick
open Pickles_types
module U = Transaction_snark_tests.Util
module Spec = Transaction_snark.For_tests.Spec
module Impl = Pickles.Impls.Step

let%test_module "multisig_account" =
  ( module struct
    let constraint_constants = U.constraint_constants

    module M_of_n_predicate = struct
      type _witness = (Schnorr.Chunked.Signature.t * Public_key.t) list

      (* check that two public keys are equal *)
      let eq_pk ((x0, y0) : Public_key.var) ((x1, y1) : Public_key.var) :
          Boolean.var Checked.t =
        let open Checked in
        [ Field.Checked.equal x0 x1; Field.Checked.equal y0 y1 ]
        |> Checked.List.all >>= Boolean.all

      (* check that two public keys are not equal *)
      let neq_pk (pk0 : Public_key.var) (pk1 : Public_key.var) :
          Boolean.var Checked.t =
        Checked.(eq_pk pk0 pk1 >>| Boolean.not)

      (* check that the witness has distinct public keys for each signature *)
      let rec distinct_public_keys = function
        | (_, pk) :: xs ->
            let open Checked in
            Checked.List.map ~f:(fun (_, pk') -> neq_pk pk pk') xs
            >>= fun bs ->
            [%with_label __LOC__]
              (Boolean.Assert.all bs >>= fun () -> distinct_public_keys xs)
        | [] ->
            Checked.return ()

      let%snarkydef distinct_public_keys x = distinct_public_keys x

      (* check a signature on msg against a public key *)
      let check_sig pk msg sigma : Boolean.var Checked.t =
        let%bind (module S) = Inner_curve.Checked.Shifted.create () in
        Schnorr.Chunked.Checked.verifies (module S) sigma pk msg

      (* verify witness signatures against public keys *)
      let%snarkydef verify_sigs pubkeys commitment witness =
        let%bind pubkeys =
          exists
            (Typ.list ~length:(List.length pubkeys) Inner_curve.typ)
            ~compute:(As_prover.return pubkeys)
        in
        let open Checked in
        let verify_sig (sigma, pk) : Boolean.var Checked.t =
          Checked.List.exists pubkeys ~f:(fun pk' ->
              [ eq_pk pk pk'; check_sig pk' commitment sigma ]
              |> Checked.List.all >>= Boolean.all )
        in
        Checked.List.map witness ~f:verify_sig
        >>= fun bs -> [%with_label __LOC__] (Boolean.Assert.all bs)

      let check_witness m pubkeys commitment witness =
        if List.length witness <> m then
          failwith @@ "witness length must be exactly " ^ Int.to_string m
        else
          let open Checked in
          Transaction_snark.dummy_constraints ()
          >>= fun () ->
          distinct_public_keys witness
          >>= fun () -> verify_sigs pubkeys commitment witness

      let%test_unit "1-of-1" =
        let gen =
          let open Quickcheck.Generator.Let_syntax in
          let%map sk = Private_key.gen and msg = Field.gen_uniform in
          (sk, Random_oracle.Input.Chunked.field_elements [| msg |])
        in
        Quickcheck.test ~trials:1 gen ~f:(fun (sk, msg) ->
            let pk = Inner_curve.(scale one sk) in
            (let%bind pk_var =
               exists Inner_curve.typ ~compute:(As_prover.return pk)
             in
             let sigma = Schnorr.Chunked.sign sk msg in
             let%bind sigma_var =
               exists Schnorr.Chunked.Signature.typ
                 ~compute:(As_prover.return sigma)
             in
             let%bind msg_var =
               exists
                 (Schnorr.chunked_message_typ ())
                 ~compute:(As_prover.return msg)
             in
             let witness = [ (sigma_var, pk_var) ] in
             check_witness 1 [ pk ] msg_var witness )
            |> Checked.map ~f:As_prover.return
            |> run_and_check |> Or_error.ok_exn )

      let%test_unit "2-of-2" =
        let gen =
          let open Quickcheck.Generator.Let_syntax in
          let%map sk0 = Private_key.gen
          and sk1 = Private_key.gen
          and msg = Field.gen_uniform in
          (sk0, sk1, Random_oracle.Input.Chunked.field_elements [| msg |])
        in
        Quickcheck.test ~trials:1 gen ~f:(fun (sk0, sk1, msg) ->
            let pk0 = Inner_curve.(scale one sk0) in
            let pk1 = Inner_curve.(scale one sk1) in
            (let%bind pk0_var =
               exists Inner_curve.typ ~compute:(As_prover.return pk0)
             in
             let%bind pk1_var =
               exists Inner_curve.typ ~compute:(As_prover.return pk1)
             in
             let sigma0 = Schnorr.Chunked.sign sk0 msg in
             let sigma1 = Schnorr.Chunked.sign sk1 msg in
             let%bind sigma0_var =
               exists Schnorr.Chunked.Signature.typ
                 ~compute:(As_prover.return sigma0)
             in
             let%bind sigma1_var =
               exists Schnorr.Chunked.Signature.typ
                 ~compute:(As_prover.return sigma1)
             in
             let%bind msg_var =
               exists
                 (Schnorr.chunked_message_typ ())
                 ~compute:(As_prover.return msg)
             in
             let witness = [ (sigma0_var, pk0_var); (sigma1_var, pk1_var) ] in
             check_witness 2 [ pk0; pk1 ] msg_var witness )
            |> Checked.map ~f:As_prover.return
            |> run_and_check |> Or_error.ok_exn )
    end

    type _ Snarky_backendless.Request.t +=
      | Pubkey : int -> Inner_curve.t Snarky_backendless.Request.t
      | Sigma : int -> Schnorr.Chunked.Signature.t Snarky_backendless.Request.t

    (* test with a 2-of-3 multisig *)
    let%test_unit "zkapps-based proved transaction" =
      let open Mina_transaction_logic.For_tests in
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let%map sk0 = Private_key.gen
        and sk1 = Private_key.gen
        and sk2 = Private_key.gen
        (* index of the key that is not signing the msg *)
        and not_signing = Base_quickcheck.Generator.int_inclusive 0 2
        and test_spec = Test_spec.gen in
        let secrets = (sk0, sk1, sk2) in
        (secrets, not_signing, test_spec)
      in
      Quickcheck.test ~trials:1 gen
        ~f:(fun (secrets, not_signing, { init_ledger; specs }) ->
          let sk0, sk1, sk2 = secrets in
          let pk0 = Inner_curve.(scale one sk0) in
          let pk1 = Inner_curve.(scale one sk1) in
          let pk2 = Inner_curve.(scale one sk2) in
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Init_ledger.init (module Ledger.Ledger_inner) init_ledger ledger ;
              let spec = List.hd_exn specs in
              let tag, _, (module P), Pickles.Provers.[ multisig_prover; _ ] =
                let multisig_rule : _ Pickles.Inductive_rule.t =
                  let multisig_main (tx_commitment : Zkapp_statement.Checked.t)
                      : unit Checked.t =
                    let%bind pk0_var =
                      exists Inner_curve.typ
                        ~request:(As_prover.return @@ Pubkey 0)
                    and pk1_var =
                      exists Inner_curve.typ
                        ~request:(As_prover.return @@ Pubkey 1)
                    and pk2_var =
                      exists Inner_curve.typ
                        ~request:(As_prover.return @@ Pubkey 2)
                    in
                    let msg_var =
                      tx_commitment |> Zkapp_statement.Checked.to_field_elements
                      |> Random_oracle_input.Chunked.field_elements
                    in
                    let%bind sigma0_var =
                      exists Schnorr.Chunked.Signature.typ
                        ~request:(As_prover.return @@ Sigma 0)
                    and sigma1_var =
                      exists Schnorr.Chunked.Signature.typ
                        ~request:(As_prover.return @@ Sigma 1)
                    and sigma2_var =
                      exists Schnorr.Chunked.Signature.typ
                        ~request:(As_prover.return @@ Sigma 2)
                    in
                    let witness =
                      [ (sigma0_var, pk0_var)
                      ; (sigma1_var, pk1_var)
                      ; (sigma2_var, pk2_var)
                      ]
                      |> Fn.flip List.drop not_signing
                    in
                    M_of_n_predicate.check_witness 2 [ pk0; pk1; pk2 ] msg_var
                      witness
                  in
                  { identifier = "multisig-rule"
                  ; prevs = []
                  ; main =
                      (fun [] x ->
                        multisig_main x |> Run.run_checked
                        |> fun _ :
                               unit
                               Pickles_types.Hlist0.H1
                                 (Pickles_types.Hlist.E01
                                    (Pickles.Inductive_rule.B))
                               .t ->
                        [] )
                  ; main_value = (fun [] _ -> [])
                  }
                in
                Pickles.compile ~cache:Cache_dir.cache
                  (module Zkapp_statement.Checked)
                  (module Zkapp_statement)
                  ~typ:Zkapp_statement.typ
                  ~branches:(module Nat.N2)
                  ~max_proofs_verified:(module Nat.N2)
                    (* You have to put 2 here... *)
                  ~name:"multisig"
                  ~constraint_constants:
                    (Genesis_constants.Constraint_constants.to_snark_keys_header
                       constraint_constants )
                  ~choices:(fun ~self ->
                    [ multisig_rule
                    ; { identifier = "dummy"
                      ; prevs = [ self; self ]
                      ; main_value = (fun [ _; _ ] _ -> [ true; true ])
                      ; main =
                          (fun [ _; _ ] _ ->
                            Impl.run_checked
                              (Transaction_snark.dummy_constraints ())
                            |> fun () ->
                            (* Unsatisfiable. *)
                            Run.exists Field.typ ~compute:(fun () ->
                                Run.Field.Constant.zero )
                            |> fun s ->
                            Run.Field.(Assert.equal s (s + one))
                            |> fun () :
                                   ( Zkapp_statement.Checked.t
                                   * (Zkapp_statement.Checked.t * unit) )
                                   Pickles_types.Hlist0.H1
                                     (Pickles_types.Hlist.E01
                                        (Pickles.Inductive_rule.B))
                                   .t ->
                            [ Boolean.true_; Boolean.true_ ] )
                      }
                    ] )
              in
              let vk = Pickles.Side_loaded.Verification_key.of_compiled tag in
              let { Mina_transaction_logic.For_tests.Transaction_spec.fee
                  ; sender = sender, sender_nonce
                  ; receiver = multisig_account_pk
                  ; amount
                  ; receiver_is_new = _
                  } =
                spec
              in
              let vk =
                With_hash.of_data ~hash_data:Zkapp_account.digest_vk vk
              in
              let total =
                Option.value_exn Currency.Amount.(add (of_fee fee) amount)
              in
              (let _is_new, _loc =
                 let pk = Public_key.compress sender.public_key in
                 let id = Account_id.create pk Token_id.default in
                 Ledger.get_or_create_account ledger id
                   (Account.create id
                      Currency.Balance.(
                        Option.value_exn (add_amount zero total)) )
                 |> Or_error.ok_exn
               in
               let _is_new, loc =
                 let id =
                   Account_id.create multisig_account_pk Token_id.default
                 in
                 Ledger.get_or_create_account ledger id
                   (Account.create id Currency.Balance.(of_int 0))
                 |> Or_error.ok_exn
               in
               let a = Ledger.get ledger loc |> Option.value_exn in
               Ledger.set ledger loc
                 { a with
                   permissions =
                     { Permissions.user_default with set_permissions = Proof }
                 ; zkapp =
                     Some
                       { (Option.value ~default:Zkapp_account.default a.zkapp) with
                         verification_key = Some vk
                       }
                 } ) ;
              let update_empty_permissions =
                let permissions =
                  Zkapp_basic.Set_or_keep.Set Permissions.empty
                in
                { Party.Update.noop with permissions }
              in
              let sender_pk = sender.public_key |> Public_key.compress in
              let fee_payer : Party.Fee_payer.t =
                { body =
                    { public_key = sender_pk
                    ; update = Party.Update.noop
                    ; fee
                    ; events = []
                    ; sequence_events = []
                    ; protocol_state_precondition =
                        Zkapp_precondition.Protocol_state.accept
                    ; nonce = sender_nonce
                    }
                    (* Real signature added in below *)
                ; authorization = Signature.dummy
                }
              in
              let sender_party_data : Party.Simple.t =
                { body =
                    { public_key = sender_pk
                    ; update = Party.Update.noop
                    ; token_id = Token_id.default
                    ; balance_change =
                        Currency.Amount.(Signed.(negate (of_unsigned amount)))
                    ; increment_nonce = true
                    ; events = []
                    ; sequence_events = []
                    ; call_data = Field.zero
                    ; call_depth = 0
                    ; protocol_state_precondition =
                        Zkapp_precondition.Protocol_state.accept
                    ; account_precondition =
                        Nonce (Account.Nonce.succ sender_nonce)
                    ; use_full_commitment = false
                    ; caller = Call
                    }
                ; authorization = Signature Signature.dummy
                }
              in
              let snapp_party_data : Party.Simple.t =
                { body =
                    { public_key = multisig_account_pk
                    ; update = update_empty_permissions
                    ; token_id = Token_id.default
                    ; balance_change =
                        Currency.Amount.Signed.(of_unsigned amount)
                    ; increment_nonce = false
                    ; events = []
                    ; sequence_events = []
                    ; call_data = Field.zero
                    ; call_depth = 0
                    ; protocol_state_precondition =
                        Zkapp_precondition.Protocol_state.accept
                    ; account_precondition =
                        Full Zkapp_precondition.Account.accept
                    ; use_full_commitment = false
                    ; caller = Call
                    }
                ; authorization = Proof Mina_base.Proof.transaction_dummy
                }
              in
              let memo = Signed_command_memo.empty in
              let ps =
                Parties.Call_forest.of_parties_list
                  ~party_depth:(fun (p : Party.Simple.t) -> p.body.call_depth)
                  [ sender_party_data; snapp_party_data ]
                |> Parties.Call_forest.add_callers_simple
                |> Parties.Call_forest.accumulate_hashes_predicated
              in
              let other_parties_hash = Parties.Call_forest.hash ps in
              let transaction : Parties.Transaction_commitment.t =
                (*FIXME: is this correct? *)
                Parties.Transaction_commitment.create ~other_parties_hash
              in
              let at_party = Parties.Call_forest.hash ps in
              let tx_statement : Zkapp_statement.t =
                { transaction; at_party = (at_party :> Field.t) }
              in
              let msg =
                tx_statement |> Zkapp_statement.to_field_elements
                |> Random_oracle_input.Chunked.field_elements
              in
              let sigma0 = Schnorr.Chunked.sign sk0 msg in
              let sigma1 = Schnorr.Chunked.sign sk1 msg in
              let sigma2 = Schnorr.Chunked.sign sk2 msg in
              let handler (Snarky_backendless.Request.With { request; respond })
                  =
                match request with
                | Pubkey 0 ->
                    respond @@ Provide pk0
                | Pubkey 1 ->
                    respond @@ Provide pk1
                | Pubkey 2 ->
                    respond @@ Provide pk2
                | Sigma 0 ->
                    respond @@ Provide sigma0
                | Sigma 1 ->
                    respond @@ Provide sigma1
                | Sigma 2 ->
                    respond @@ Provide sigma2
                | _ ->
                    respond Unhandled
              in
              let pi : Pickles.Side_loaded.Proof.t =
                (fun () -> multisig_prover ~handler [] tx_statement)
                |> Async.Thread_safe.block_on_async_exn
              in
              let fee_payer =
                let txn_comm =
                  Parties.Transaction_commitment.create_complete transaction
                    ~memo_hash:(Signed_command_memo.hash memo)
                    ~fee_payer_hash:
                      (Parties.Digest.Party.create
                         (Party.of_fee_payer fee_payer) )
                in
                { fee_payer with
                  authorization =
                    Signature_lib.Schnorr.Chunked.sign sender.private_key
                      (Random_oracle.Input.Chunked.field txn_comm)
                }
              in
              let sender : Party.Simple.t =
                { body = sender_party_data.body
                ; authorization =
                    Signature
                      (Signature_lib.Schnorr.Chunked.sign sender.private_key
                         (Random_oracle.Input.Chunked.field transaction) )
                }
              in
              let parties : Parties.t =
                Parties.of_simple
                  { fee_payer
                  ; other_parties =
                      [ sender
                      ; { body = snapp_party_data.body
                        ; authorization = Proof pi
                        }
                      ]
                  ; memo
                  }
              in
              Init_ledger.init (module Ledger.Ledger_inner) init_ledger ledger ;
              ignore (U.apply_parties ledger [ parties ] : Sparse_ledger.t) ) )
  end )
