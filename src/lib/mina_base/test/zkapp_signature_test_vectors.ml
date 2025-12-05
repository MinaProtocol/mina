(** Testing
    -------
    Component:  Mina base - zkApp signature verification using Verifier.Common
    Invocation: dune exec src/lib/mina_base/test/main.exe -- test '^zkApp signature'
    Subject:    Tests for zkApp signature verification using the production Verifier.Common module.

    These tests verify that the Verifier.Common module correctly validates signatures
    on zkApp transactions. The module is used by the verifier subprocess and other
    components to check signature validity before transaction processing.

    Key functions tested:
    - {!Verifier.Common.check_signatures_of_zkapp_command}: Verifies all signatures
      in a zkApp command against the transaction commitment.

    Verification flow (tested here):
    1. Compute transaction commitment from account updates
    2. Compute full commitment (includes memo and fee payer)
    3. Verify fee payer signature against full commitment
    4. For each account update with signature authorization:
       - Use full or partial commitment based on [use_full_commitment]
       - Verify signature against [body.public_key]

    This mirrors the logic enforced by the transaction SNARK
    (see [Transaction_snark.check_authorization]).
*)

open Core
open Mina_base
open Signature_lib

(* Test: Verifier.Common accepts fee payer signatures on testnet and mainnet.
   This verifies that sign_zkapp_command produces signatures accepted by the verifier. *)
let test_fee_payer_signature_verification () =
  let networks =
    [ (Mina_signature_kind.Testnet, "testnet")
    ; (Mina_signature_kind.Mainnet, "mainnet")
    ]
  in
  let private_key = "EKE2M5q5afTtdzZTzyKu89Pzc7274BD6fm2fsDLgLt5zy34TAN5N" in
  List.iter
    ~f:(fun (signature_kind, network_name) ->
      let fee_payer_sk = Private_key.of_base58_check_exn private_key in
      let fee_payer_kp = Keypair.of_private_key_exn fee_payer_sk in
      let fee_payer_pk = Public_key.compress fee_payer_kp.public_key in
      (* Create a minimal zkApp command with no account updates *)
      let fee_payer : Account_update.Fee_payer.t =
        Account_update.Fee_payer.make
          ~body:
            { public_key = fee_payer_pk
            ; fee = Currency.Fee.of_nanomina_int_exn 1_000_000_000 (* 1 MINA *)
            ; valid_until = None
            ; nonce = Mina_numbers.Account_nonce.of_int 0
            }
          ~authorization:Signature.dummy
      in
      let memo = Signed_command_memo.create_from_string_exn "test memo" in
      let unsigned_zkapp_command : Zkapp_command.t =
        Zkapp_command.write_all_proofs_to_disk ~signature_kind
          ~proof_cache_db:(Proof_cache_tag.For_tests.create_db ())
          { Zkapp_command.Poly.fee_payer; memo; account_updates = [] }
      in
      (* Sign using our helper *)
      let signed_zkapp_command =
        Zkapp_command_builder.sign_zkapp_command ~signature_kind ~fee_payer_sk
          ~account_update_keys:Public_key.Compressed.Map.empty
          unsigned_zkapp_command
      in
      (* Verify using Verifier.Common *)
      let result =
        Verifier.Common.check_signatures_of_zkapp_command ~signature_kind
          signed_zkapp_command
      in
      Alcotest.(check bool)
        (Printf.sprintf "Verifier.Common accepts fee payer signature (%s)"
           network_name )
        true (Result.is_ok result) )
    networks

(** Test vectors for zkApp transaction signing.

    These vectors help external implementers verify their implementations of:
    1. Transaction commitment computation
    2. Schnorr signature generation over the Pallas curve

    {2 Commitment computation}

    Uses [Zkapp_command.Transaction_commitment] which internally computes:
    - [txn_commitment] = hash of account_updates forest (0 for empty forest)
    - [full_txn_commitment] = Poseidon hash of (memo_hash, fee_payer_hash, txn_commitment)

    The [fee_payer_hash] includes [signature_kind], which is why testnet and mainnet
    produce different [full_txn_commitment] values for the same inputs.

    {2 Signature algorithm}

    Signatures use [Schnorr.Chunked.sign] over the Pallas curve with the commitment
    as the message. The fee payer always signs the [full_txn_commitment].

    {2 Test vector format}

    Each test vector contains:
    - Inputs: (signature_kind, test_name, fee_nanomina, nonce, memo, account_updates)
    - Expected outputs: (txn_commitment, full_txn_commitment, fee_payer_signature_rx, fee_payer_signature_s)

    {2 Keys used in test vectors}

    - Fee payer: B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg
      (private key: EKE2M5q5afTtdzZTzyKu89Pzc7274BD6fm2fsDLgLt5zy34TAN5N)
    - Account update: B62qjsV6WQwTeEWrNrRRBP6VaaLvQhwWTnFi4WP4LQjGvpfZEumXzxb
      (private key: EKFXH5yESt7nsD1TJy5WNb4agVczkvzPRVexKQ8qYdNqauQRA8Ef)
*)

(* Helper to create account update for test vectors *)
let make_test_account_update ~public_key ~balance_change_nanomina =
  let account_update_body : Account_update.Body.Simple.t =
    { public_key
    ; token_id = Token_id.default
    ; update = Account_update.Update.noop
    ; balance_change =
        Currency.Amount.Signed.create
          ~magnitude:
            (Currency.Amount.of_nanomina_int_exn (abs balance_change_nanomina))
          ~sgn:(if balance_change_nanomina >= 0 then Sgn.Pos else Sgn.Neg)
    ; increment_nonce = true
    ; events = []
    ; actions = []
    ; call_data = Snark_params.Tick.Field.zero
    ; call_depth = 0
    ; preconditions =
        { network = Zkapp_precondition.Protocol_state.accept
        ; account = Zkapp_precondition.Account.accept
        ; valid_while = Ignore
        }
    ; use_full_commitment = false
    ; implicit_account_creation_fee = false
    ; may_use_token = No
    ; authorization_kind = Signature
    }
  in
  Account_update.with_no_aux
    ~body:(Account_update.Body.of_simple account_update_body)
    ~authorization:(Control.Poly.Signature Signature.dummy)

let test_vectors_sign_commitments () =
  (* Keys used in test vectors *)
  let fee_payer_sk =
    Private_key.of_base58_check_exn
      "EKE2M5q5afTtdzZTzyKu89Pzc7274BD6fm2fsDLgLt5zy34TAN5N"
  in
  let fee_payer_kp = Keypair.of_private_key_exn fee_payer_sk in
  let fee_payer_pk = Public_key.compress fee_payer_kp.public_key in
  let account_update_sk =
    Private_key.of_base58_check_exn
      "EKFXH5yESt7nsD1TJy5WNb4agVczkvzPRVexKQ8qYdNqauQRA8Ef"
  in
  let account_update_kp = Keypair.of_private_key_exn account_update_sk in
  let account_update_pk = Public_key.compress account_update_kp.public_key in
  (* Test vectors: inputs and expected outputs
     Format: ((signature_kind, name, fee_nanomina, nonce, memo, account_updates),
              (txn_commitment, full_txn_commitment, signature_rx, signature_s)) *)
  let test_vectors =
    [ ( (* Testnet, empty account_updates *)
        ( Mina_signature_kind.Testnet
        , "testnet empty"
        , 1_000_000_000
        , 0
        , "test memo"
        , [] )
      , ( "0"
        , "3041571627639553107763978219346471367756783628926005589985808519032108787934"
        , "4266834823372287532760817254072645307841005061680726992776543327772151281014"
        , "3079039545427233451923903809119260002681107642943888692560829632352724237439"
        ) )
    ; ( (* Mainnet, empty account_updates - full_commitment differs due to signature_kind *)
        ( Mina_signature_kind.Mainnet
        , "mainnet empty"
        , 1_000_000_000
        , 0
        , "test memo"
        , [] )
      , ( "0"
        , "422045518501495772048071382727552080008668713741305956694382931481646868481"
        , "9972830741886821681852046198401315423305107264528442664937846405409569504084"
        , "10792148642093276869967529079359806250285579064621632797368741656451502596282"
        ) )
    ; ( (* Testnet with one account update *)
        ( Mina_signature_kind.Testnet
        , "testnet one update"
        , 1_000_000_000
        , 0
        , "test memo"
        , [ (account_update_pk, -500_000_000) ] )
      , ( "19324771557230145641697323727857286724822072462197451437034244510338886478089"
        , "25580356045179279578155188481917405448408304515405338744264514431865149176112"
        , "14772096075817281633269594552099080759274752910242452549387176321441997084999"
        , "21709039648790699017799364758013470307385027987343874203883469397155058185918"
        ) )
    ; ( (* Mainnet with one account update - txn_commitment differs due to signature_kind in auth_kind *)
        ( Mina_signature_kind.Mainnet
        , "mainnet one update"
        , 1_000_000_000
        , 0
        , "test memo"
        , [ (account_update_pk, -500_000_000) ] )
      , ( "19426714728898087079204887306277167349986114269582561183976721908205528941271"
        , "20034904653737506075700802490731438456693113135533829651036381199169976184191"
        , "11833242830917911151902603672890698564063224655310405777202321274134884924663"
        , "6742816739920892991702698458813003132250425010631181666201218222924459721575"
        ) )
    ; ( (* Testnet, nonce=5 *)
        ( Mina_signature_kind.Testnet
        , "testnet nonce=5"
        , 1_000_000_000
        , 5
        , "test memo"
        , [] )
      , ( "0"
        , "26127762587523861735243260112605389832342739434617412111159268165981958646027"
        , "26949501756690800364239925901796065588445770253302602090281690929364134467840"
        , "10153496495999946635816252723528874012202475686776461109247834544676967649615"
        ) )
    ; ( (* Testnet, different memo *)
        ( Mina_signature_kind.Testnet
        , "testnet different memo"
        , 1_000_000_000
        , 0
        , "another memo"
        , [] )
      , ( "0"
        , "20627285609730421395516762088565900330838073944049490328561910873549940650131"
        , "28215319037168169816913336804641280610762002692202825679430743899773983349169"
        , "9039062852248997974064612293199064551493415682038704836168110222175015854691"
        ) )
    ; ( (* Testnet, different fee *)
        ( Mina_signature_kind.Testnet
        , "testnet fee=2MINA"
        , 2_000_000_000
        , 0
        , "test memo"
        , [] )
      , ( "0"
        , "8427650486167544141753967885437684374233936787671711882044970156776856185804"
        , "4115135114161412295107192458780274725375698193390835539627947792163323302197"
        , "1008415608950947413191644655211731784275288437743189571976126276307432433319"
        ) )
    ]
  in
  List.iter
    ~f:(fun ( ( signature_kind
              , test_name
              , fee_nanomina
              , nonce
              , memo_str
              , account_update_specs )
            , ( expected_txn_commitment
              , expected_full_txn_commitment
              , expected_sig_rx
              , expected_sig_s ) ) ->
      let fee_payer : Account_update.Fee_payer.t =
        Account_update.Fee_payer.make
          ~body:
            { public_key = fee_payer_pk
            ; fee = Currency.Fee.of_nanomina_int_exn fee_nanomina
            ; valid_until = None
            ; nonce = Mina_numbers.Account_nonce.of_int nonce
            }
          ~authorization:Signature.dummy
      in
      let memo = Signed_command_memo.create_from_string_exn memo_str in
      let account_updates =
        List.map account_update_specs ~f:(fun (pk, balance_change) ->
            let account_update =
              make_test_account_update ~public_key:pk
                ~balance_change_nanomina:balance_change
            in
            { With_stack_hash.stack_hash = ()
            ; elt =
                { Zkapp_command.Call_forest.Tree.account_update
                ; account_update_digest = ()
                ; calls = []
                }
            } )
      in
      let zkapp_command : Zkapp_command.t =
        Zkapp_command.write_all_proofs_to_disk ~signature_kind
          ~proof_cache_db:(Proof_cache_tag.For_tests.create_db ())
          { Zkapp_command.Poly.fee_payer; memo; account_updates }
      in
      let txn_commitment, full_txn_commitment =
        Zkapp_command.get_transaction_commitments ~signature_kind zkapp_command
      in
      (* Verify commitment values match test vectors *)
      Alcotest.(check string)
        (Printf.sprintf "txn_commitment (%s)" test_name)
        expected_txn_commitment
        (Snark_params.Tick.Field.to_string txn_commitment) ;
      Alcotest.(check string)
        (Printf.sprintf "full_txn_commitment (%s)" test_name)
        expected_full_txn_commitment
        (Snark_params.Tick.Field.to_string full_txn_commitment) ;
      (* Sign and verify signature values *)
      let account_update_keys =
        List.fold account_update_specs ~init:Public_key.Compressed.Map.empty
          ~f:(fun acc (pk, _) ->
            Public_key.Compressed.Map.set acc ~key:pk ~data:account_update_sk )
      in
      let signed_zkapp_command =
        Zkapp_command_builder.sign_zkapp_command ~signature_kind ~fee_payer_sk
          ~account_update_keys zkapp_command
      in
      let fee_payer_sig = signed_zkapp_command.fee_payer.authorization in
      let sig_rx, sig_s = fee_payer_sig in
      (* Verify signature components match test vectors *)
      Alcotest.(check string)
        (Printf.sprintf "fee_payer_signature.rx (%s)" test_name)
        expected_sig_rx
        (Snark_params.Tick.Field.to_string sig_rx) ;
      Alcotest.(check string)
        (Printf.sprintf "fee_payer_signature.s (%s)" test_name)
        expected_sig_s
        (Snark_params.Tick.Inner_curve.Scalar.to_string sig_s) ;
      (* Verify Verifier.Common accepts the signed command *)
      let result =
        Verifier.Common.check_signatures_of_zkapp_command ~signature_kind
          signed_zkapp_command
      in
      Alcotest.(check bool)
        (Printf.sprintf "Verifier.Common accepts (%s)" test_name)
        true (Result.is_ok result) )
    test_vectors

(* Test: zkApp with account update using signature authorization verified by Verifier.Common *)
let test_account_update_signature_verification () =
  let signature_kind = Mina_signature_kind.Testnet in
  (* Fee payer key *)
  let fee_payer_sk =
    Private_key.of_base58_check_exn
      "EKE2M5q5afTtdzZTzyKu89Pzc7274BD6fm2fsDLgLt5zy34TAN5N"
  in
  let fee_payer_kp = Keypair.of_private_key_exn fee_payer_sk in
  let fee_payer_pk = Public_key.compress fee_payer_kp.public_key in
  (* Account update key (different from fee payer) *)
  let account_update_sk =
    Private_key.of_base58_check_exn
      "EKFXH5yESt7nsD1TJy5WNb4agVczkvzPRVexKQ8qYdNqauQRA8Ef"
  in
  let account_update_kp = Keypair.of_private_key_exn account_update_sk in
  let account_update_pk = Public_key.compress account_update_kp.public_key in
  (* Create fee payer *)
  let fee_payer : Account_update.Fee_payer.t =
    Account_update.Fee_payer.make
      ~body:
        { public_key = fee_payer_pk
        ; fee = Currency.Fee.of_nanomina_int_exn 1_000_000_000
        ; valid_until = None
        ; nonce = Mina_numbers.Account_nonce.of_int 5
        }
      ~authorization:Signature.dummy
  in
  (* Create account update body with use_full_commitment = false *)
  let account_update_body : Account_update.Body.Simple.t =
    { public_key = account_update_pk
    ; token_id = Token_id.default
    ; update = Account_update.Update.noop
    ; balance_change =
        Currency.Amount.Signed.create
          ~magnitude:(Currency.Amount.of_nanomina_int_exn 500_000_000)
          ~sgn:Sgn.Neg
    ; increment_nonce = true
    ; events = []
    ; actions = []
    ; call_data = Snark_params.Tick.Field.zero
    ; call_depth = 0
    ; preconditions =
        { network = Zkapp_precondition.Protocol_state.accept
        ; account = Zkapp_precondition.Account.accept
        ; valid_while = Ignore
        }
    ; use_full_commitment = false
    ; implicit_account_creation_fee = false
    ; may_use_token = No
    ; authorization_kind = Signature
    }
  in
  let account_update =
    Account_update.with_no_aux
      ~body:(Account_update.Body.of_simple account_update_body)
      ~authorization:(Control.Poly.Signature Signature.dummy)
  in
  let memo = Signed_command_memo.create_from_string_exn "with account update" in
  let account_updates =
    [ { With_stack_hash.stack_hash = ()
      ; elt =
          { Zkapp_command.Call_forest.Tree.account_update
          ; account_update_digest = ()
          ; calls = []
          }
      }
    ]
  in
  let unsigned_zkapp_command : Zkapp_command.t =
    Zkapp_command.write_all_proofs_to_disk ~signature_kind
      ~proof_cache_db:(Proof_cache_tag.For_tests.create_db ())
      { Zkapp_command.Poly.fee_payer; memo; account_updates }
  in
  (* Sign using our helper *)
  let account_update_keys =
    Public_key.Compressed.Map.of_alist_exn
      [ (account_update_pk, account_update_sk) ]
  in
  let signed_zkapp_command =
    Zkapp_command_builder.sign_zkapp_command ~signature_kind ~fee_payer_sk
      ~account_update_keys unsigned_zkapp_command
  in
  (* Verify using Verifier.Common *)
  let result =
    Verifier.Common.check_signatures_of_zkapp_command ~signature_kind
      signed_zkapp_command
  in
  Alcotest.(check bool)
    "Verifier.Common accepts account update with partial commitment signature"
    true (Result.is_ok result)

(* Test using production verification code (Verifier.Common.check_signatures_of_zkapp_command).
   This ensures our signing logic matches what the production verifier expects. *)
let test_production_signature_verification () =
  let signature_kind = Mina_signature_kind.Testnet in
  (* Fee payer key *)
  let fee_payer_sk =
    Private_key.of_base58_check_exn
      "EKE2M5q5afTtdzZTzyKu89Pzc7274BD6fm2fsDLgLt5zy34TAN5N"
  in
  let fee_payer_kp = Keypair.of_private_key_exn fee_payer_sk in
  let fee_payer_pk = Public_key.compress fee_payer_kp.public_key in
  (* Account update key *)
  let account_update_sk =
    Private_key.of_base58_check_exn
      "EKFXH5yESt7nsD1TJy5WNb4agVczkvzPRVexKQ8qYdNqauQRA8Ef"
  in
  let account_update_kp = Keypair.of_private_key_exn account_update_sk in
  let account_update_pk = Public_key.compress account_update_kp.public_key in
  (* Create fee payer *)
  let fee_payer : Account_update.Fee_payer.t =
    Account_update.Fee_payer.make
      ~body:
        { public_key = fee_payer_pk
        ; fee = Currency.Fee.of_nanomina_int_exn 1_000_000_000
        ; valid_until = None
        ; nonce = Mina_numbers.Account_nonce.of_int 0
        }
      ~authorization:Signature.dummy
  in
  (* Create account update with signature authorization *)
  let account_update_body : Account_update.Body.Simple.t =
    { public_key = account_update_pk
    ; token_id = Token_id.default
    ; update = Account_update.Update.noop
    ; balance_change =
        Currency.Amount.Signed.create
          ~magnitude:(Currency.Amount.of_nanomina_int_exn 100_000_000)
          ~sgn:Sgn.Neg
    ; increment_nonce = true
    ; events = []
    ; actions = []
    ; call_data = Snark_params.Tick.Field.zero
    ; call_depth = 0
    ; preconditions =
        { network = Zkapp_precondition.Protocol_state.accept
        ; account = Zkapp_precondition.Account.accept
        ; valid_while = Ignore
        }
    ; use_full_commitment = false
    ; implicit_account_creation_fee = false
    ; may_use_token = No
    ; authorization_kind = Signature
    }
  in
  let account_update =
    Account_update.with_no_aux
      ~body:(Account_update.Body.of_simple account_update_body)
      ~authorization:(Control.Poly.Signature Signature.dummy)
  in
  let memo =
    Signed_command_memo.create_from_string_exn "production verify test"
  in
  let account_updates =
    [ { With_stack_hash.stack_hash = ()
      ; elt =
          { Zkapp_command.Call_forest.Tree.account_update
          ; account_update_digest = ()
          ; calls = []
          }
      }
    ]
  in
  let unsigned_zkapp_command : Zkapp_command.t =
    Zkapp_command.write_all_proofs_to_disk ~signature_kind
      ~proof_cache_db:(Proof_cache_tag.For_tests.create_db ())
      { Zkapp_command.Poly.fee_payer; memo; account_updates }
  in
  (* Sign using our helper (same logic as zkapp_command_builder.replace_authorizations) *)
  let account_update_keys =
    Public_key.Compressed.Map.of_alist_exn
      [ (account_update_pk, account_update_sk) ]
  in
  let signed_zkapp_command =
    Zkapp_command_builder.sign_zkapp_command ~signature_kind ~fee_payer_sk
      ~account_update_keys unsigned_zkapp_command
  in
  (* Verify using production code *)
  let result =
    Verifier.Common.check_signatures_of_zkapp_command ~signature_kind
      signed_zkapp_command
  in
  Alcotest.(check bool)
    "production verifier accepts correctly signed zkapp_command" true
    (Result.is_ok result)
