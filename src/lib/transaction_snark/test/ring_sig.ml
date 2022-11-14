open Util
open Core
open Currency
open Mina_base
open Signature_lib
module Impl = Pickles.Impls.Step
module Inner_curve = Snark_params.Tick.Inner_curve
module Nat = Pickles_types.Nat
module Local_state = Mina_state.Local_state
module Zkapp_command_segment = Transaction_snark.Zkapp_command_segment
module Statement = Transaction_snark.Statement
open Snark_params.Tick
open Snark_params.Tick.Let_syntax

(* check a signature on msg against a public key *)
let check_sig pk msg sigma : Boolean.var Checked.t =
  let%bind (module S) = Inner_curve.Checked.Shifted.create () in
  Schnorr.Chunked.Checked.verifies (module S) sigma pk msg

(* verify witness signature against public keys *)
let%snarkydef_ verify_sig pubkeys msg sigma =
  let%bind pubkeys =
    exists
      (Typ.list ~length:(List.length pubkeys) Inner_curve.typ)
      ~compute:(As_prover.return pubkeys)
  in
  Checked.List.exists pubkeys ~f:(fun pk -> check_sig pk msg sigma)
  >>= Boolean.Assert.is_true

let check_witness pubkeys msg witness =
  Transaction_snark.dummy_constraints ()
  >>= fun () -> verify_sig pubkeys msg witness

type _ Snarky_backendless.Request.t +=
  | Sigma : Schnorr.Chunked.Signature.t Snarky_backendless.Request.t

let ring_sig_rule (ring_member_pks : Schnorr.Chunked.Public_key.t list) :
    _ Pickles.Inductive_rule.t =
  let ring_sig_main (tx_commitment : Zkapp_statement.Checked.t) : unit Checked.t
      =
    let msg_var =
      Zkapp_statement.Checked.to_field_elements tx_commitment
      |> Random_oracle_input.Chunked.field_elements
    in
    let%bind sigma_var =
      exists Schnorr.Chunked.Signature.typ ~request:(As_prover.return Sigma)
    in
    check_witness ring_member_pks msg_var sigma_var
  in
  { identifier = "ring-sig-rule"
  ; prevs = []
  ; main =
      (fun { public_input = x } ->
        Run.run_checked @@ ring_sig_main x ;
        { previous_proof_statements = []
        ; public_output = ()
        ; auxiliary_output = ()
        } )
  ; uses_lookup = false
  }

let%test_unit "1-of-1" =
  let gen =
    let open Quickcheck.Generator.Let_syntax in
    let%map sk = Private_key.gen and msg = Field.gen_uniform in
    (sk, Random_oracle.Input.Chunked.field_elements [| msg |])
  in
  Quickcheck.test ~trials:1 gen ~f:(fun (sk, msg) ->
      let pk = Inner_curve.(scale one sk) in
      (let sigma = Schnorr.Chunked.sign sk msg in
       let%bind sigma_var, msg_var =
         exists
           Typ.(Schnorr.Chunked.Signature.typ * Schnorr.chunked_message_typ ())
           ~compute:As_prover.(return (sigma, msg))
       in
       check_witness [ pk ] msg_var sigma_var )
      |> Checked.map ~f:As_prover.return
      |> run_and_check |> Or_error.ok_exn )

let%test_unit "1-of-2" =
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
      (let sigma1 = Schnorr.Chunked.sign sk1 msg in
       let%bind sigma1_var =
         exists Schnorr.Chunked.Signature.typ ~compute:(As_prover.return sigma1)
       and msg_var =
         exists (Schnorr.chunked_message_typ ()) ~compute:(As_prover.return msg)
       in
       check_witness [ pk0; pk1 ] msg_var sigma1_var )
      |> Checked.map ~f:As_prover.return
      |> run_and_check |> Or_error.ok_exn )

(* test a snapp tx with a 3-account_update ring *)
let%test_unit "ring-signature snapp tx with 3 zkapp_command" =
  let open Mina_transaction_logic.For_tests in
  let gen =
    let open Quickcheck.Generator.Let_syntax in
    (* secret keys of ring participants*)
    let%map ring_member_sks =
      Quickcheck.Generator.list_with_length 3 Private_key.gen
    (* index of the key that will sign the msg *)
    and sign_index = Base_quickcheck.Generator.int_inclusive 0 2
    and test_spec = Test_spec.gen in
    (ring_member_sks, sign_index, test_spec)
  in
  (* set to true to print vk, zkapp_command *)
  let debug_mode : bool = false in
  Quickcheck.test ~trials:1 gen
    ~f:(fun (ring_member_sks, sign_index, { init_ledger; specs }) ->
      let ring_member_pks =
        List.map ring_member_sks ~f:Inner_curve.(scale one)
      in
      Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
          Init_ledger.init (module Ledger.Ledger_inner) init_ledger ledger ;
          let spec = List.hd_exn specs in
          let tag, _, (module P), Pickles.Provers.[ ringsig_prover; _ ] =
            Pickles.compile () ~cache:Cache_dir.cache
              ~public_input:(Input Zkapp_statement.typ) ~auxiliary_typ:Typ.unit
              ~branches:(module Nat.N2)
              ~max_proofs_verified:(module Nat.N2)
                (* You have to put 2 here... *)
              ~name:"ringsig"
              ~constraint_constants:
                (Genesis_constants.Constraint_constants.to_snark_keys_header
                   constraint_constants )
              ~choices:(fun ~self ->
                [ ring_sig_rule ring_member_pks; dummy_rule self ] )
          in
          let vk = Pickles.Side_loaded.Verification_key.of_compiled tag in
          ( if debug_mode then
            Binable.to_string (module Side_loaded_verification_key.Stable.V2) vk
            |> Base64.encode_exn ~alphabet:Base64.uri_safe_alphabet
            |> printf "vk:\n%s\n\n" )
          |> fun () ->
          let Mina_transaction_logic.For_tests.Transaction_spec.
                { sender = sender, sender_nonce
                ; receiver = ringsig_account_pk
                ; amount
                ; _
                } =
            spec
          in
          let fee = Amount.of_string "1000000" in
          let vk = With_hash.of_data ~hash_data:Zkapp_account.digest_vk vk in
          let total = Option.value_exn (Amount.add fee amount) in
          (let _is_new, _loc =
             let pk = Public_key.compress sender.public_key in
             let id = Account_id.create pk Token_id.default in
             Ledger.get_or_create_account ledger id
               (Account.create id
                  Balance.(Option.value_exn (add_amount zero total)) )
             |> Or_error.ok_exn
           in
           let _is_new, loc =
             let id = Account_id.create ringsig_account_pk Token_id.default in
             Ledger.get_or_create_account ledger id
               (Account.create id Balance.zero)
             |> Or_error.ok_exn
           in
           let a = Ledger.get ledger loc |> Option.value_exn in
           Ledger.set ledger loc
             { a with
               zkapp =
                 Some
                   { (Option.value ~default:Zkapp_account.default a.zkapp) with
                     verification_key = Some vk
                   }
             } ) ;
          let sender_pk = sender.public_key |> Public_key.compress in
          let fee_payer : Account_update.Fee_payer.t =
            { Account_update.Fee_payer.body =
                { public_key = sender_pk
                ; fee = Amount.to_fee fee
                ; valid_until = None
                ; nonce = sender_nonce
                }
                (* Real signature added in below *)
            ; authorization = Signature.dummy
            }
          in
          let sender_account_update_data : Account_update.Simple.t =
            { body =
                { public_key = sender_pk
                ; update = Account_update.Update.noop
                ; token_id = Token_id.default
                ; balance_change = Amount.(Signed.(negate (of_unsigned amount)))
                ; increment_nonce = true
                ; events = []
                ; sequence_events = []
                ; call_data = Field.zero
                ; call_depth = 0
                ; preconditions =
                    { Account_update.Preconditions.network =
                        Zkapp_precondition.Protocol_state.accept
                    ; account = Nonce (Account.Nonce.succ sender_nonce)
                    }
                ; caller = Call
                ; use_full_commitment = false
                ; authorization_kind = Signature
                }
            ; authorization = Signature Signature.dummy
            }
          in
          let snapp_account_update_data : Account_update.Simple.t =
            { body =
                { public_key = ringsig_account_pk
                ; update = Account_update.Update.noop
                ; token_id = Token_id.default
                ; balance_change = Amount.Signed.(of_unsigned amount)
                ; events = []
                ; sequence_events = []
                ; call_data = Field.zero
                ; call_depth = 0
                ; increment_nonce = false
                ; preconditions =
                    { Account_update.Preconditions.network =
                        Zkapp_precondition.Protocol_state.accept
                    ; account = Full Zkapp_precondition.Account.accept
                    }
                ; use_full_commitment = false
                ; caller = Call
                ; authorization_kind = Proof
                }
            ; authorization = Proof Mina_base.Proof.transaction_dummy
            }
          in
          let protocol_state = Zkapp_precondition.Protocol_state.accept in
          let ps =
            Zkapp_command.Call_forest.With_hashes.of_zkapp_command_simple_list
              [ sender_account_update_data; snapp_account_update_data ]
          in
          let account_updates_hash = Zkapp_command.Call_forest.hash ps in
          let memo = Signed_command_memo.empty in
          let memo_hash = Signed_command_memo.hash memo in
          let transaction : Zkapp_command.Transaction_commitment.t =
            Zkapp_command.Transaction_commitment.create ~account_updates_hash
          in
          let tx_statement : Zkapp_statement.t =
            { account_update =
                Account_update.Body.digest
                  (Zkapp_command.add_caller_simple snapp_account_update_data
                     Token_id.default )
                    .body
            ; calls = (Zkapp_command.Digest.Forest.empty :> field)
            }
          in
          let msg =
            tx_statement |> Zkapp_statement.to_field_elements
            |> Random_oracle_input.Chunked.field_elements
          in
          let signing_sk = List.nth_exn ring_member_sks sign_index in
          let sigma = Schnorr.Chunked.sign signing_sk msg in
          let handler (Snarky_backendless.Request.With { request; respond }) =
            match request with
            | Sigma ->
                respond @@ Provide sigma
            | _ ->
                respond Unhandled
          in
          let (), (), (pi : Pickles.Side_loaded.Proof.t) =
            (fun () -> ringsig_prover ~handler tx_statement)
            |> Async.Thread_safe.block_on_async_exn
          in
          let fee_payer =
            let txn_comm =
              Zkapp_command.Transaction_commitment.create_complete transaction
                ~memo_hash
                ~fee_payer_hash:
                  (Zkapp_command.Digest.Account_update.create
                     (Account_update.of_fee_payer fee_payer) )
            in
            { fee_payer with
              authorization =
                Signature_lib.Schnorr.Chunked.sign sender.private_key
                  (Random_oracle.Input.Chunked.field txn_comm)
            }
          in
          let sender : Account_update.Simple.t =
            let sender_signature =
              Signature_lib.Schnorr.Chunked.sign sender.private_key
                (Random_oracle.Input.Chunked.field transaction)
            in
            { body = sender_account_update_data.body
            ; authorization = Signature sender_signature
            }
          in
          let zkapp_command : Zkapp_command.t =
            Zkapp_command.of_simple
              { fee_payer
              ; account_updates =
                  [ sender
                  ; { body = snapp_account_update_data.body
                    ; authorization = Proof pi
                    }
                  ]
              ; memo
              }
          in
          ( if debug_mode then
            (* print fee payer *)
            Account_update.Fee_payer.to_yojson fee_payer
            |> Yojson.Safe.pretty_to_string
            |> printf "fee_payer:\n%s\n\n"
            |> fun () ->
            (* print other_account_update data *)
            Zkapp_command.Call_forest.iteri zkapp_command.account_updates
              ~f:(fun idx (p : Account_update.t) ->
                Account_update.Body.to_yojson p.body
                |> Yojson.Safe.pretty_to_string
                |> printf "other_account_update #%d body:\n%s\n\n" idx )
            |> fun () ->
            (* print other_account_update proof *)
            Pickles.Side_loaded.Proof.Stable.V2.sexp_of_t pi
            |> Sexp.to_string |> Base64.encode_exn
            |> printf "other_account_update_proof:\n%s\n\n"
            |> fun () ->
            (* print protocol_state *)
            Zkapp_precondition.Protocol_state.to_yojson protocol_state
            |> Yojson.Safe.pretty_to_string
            |> printf "protocol_state:\n%s\n\n" )
          |> fun () ->
          ignore (apply_zkapp_command ledger [ zkapp_command ] : Sparse_ledger.t) ) )
