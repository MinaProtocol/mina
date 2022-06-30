open Async_kernel
open Snark_params.Tick
open Snark_params.Tick.Run
open Currency
open Signature_lib
open Mina_base

module Party_under_construction = struct
  module Account_condition = struct
    type t = { state_proved : bool option }

    let create () = { state_proved = None }

    let to_predicate ({ state_proved } : t) : Zkapp_precondition.Account.t =
      (* TODO: Don't do this. *)
      let default : Zkapp_precondition.Account.t =
        { balance = Ignore
        ; nonce = Ignore
        ; receipt_chain_hash = Ignore
        ; delegate = Ignore
        ; state =
            [ Ignore; Ignore; Ignore; Ignore; Ignore; Ignore; Ignore; Ignore ]
        ; sequence_state = Ignore
        ; proved_state = Ignore
        }
      in
      let proved_state =
        match state_proved with
        | None ->
            default.proved_state
        | Some state_proved ->
            Zkapp_basic.Or_ignore.Check state_proved
      in
      { default with proved_state }

    let assert_state_proved (t : t) =
      match t.state_proved with
      | None ->
          { state_proved = Some true }
      | Some b ->
          if not b then failwith "State is already unproved" ;
          t

    let assert_state_unproved (t : t) =
      match t.state_proved with
      | None ->
          { state_proved = Some false }
      | Some b ->
          if b then failwith "State is already proved" ;
          t
  end

  module Update = struct
    type t = { app_state : Field.Constant.t option Zkapp_state.V.t }

    let create () =
      { app_state = [ None; None; None; None; None; None; None; None ] }

    let to_parties_update ({ app_state } : t) : Party.Update.t =
      let default : Party.Update.t =
        { app_state = [ Keep; Keep; Keep; Keep; Keep; Keep; Keep; Keep ]
        ; delegate = Keep
        ; verification_key = Keep
        ; permissions = Keep
        ; zkapp_uri = Keep
        ; token_symbol = Keep
        ; timing = Keep
        ; voting_for = Keep
        }
      in
      let app_state =
        Pickles_types.Vector.map ~f:Zkapp_basic.Set_or_keep.of_option app_state
      in
      { default with app_state }

    let set_full_state app_state (_t : t) =
      match app_state with
      | [ a0; a1; a2; a3; a4; a5; a6; a7 ] ->
          { app_state =
              [ Some a0
              ; Some a1
              ; Some a2
              ; Some a3
              ; Some a4
              ; Some a5
              ; Some a6
              ; Some a7
              ]
          }
      | _ ->
          failwith "Incorrect length of app_state"
  end

  type t =
    { public_key : Public_key.Compressed.t
    ; token_id : Token_id.t
    ; account_condition : Account_condition.t
    ; update : Update.t
    }

  let create ~public_key ?(token_id = Token_id.default) () =
    { public_key
    ; token_id
    ; account_condition = Account_condition.create ()
    ; update = Update.create ()
    }

  let to_party (t : t) : Party.Body.t =
    { public_key = t.public_key
    ; token_id = t.token_id
    ; update = Update.to_parties_update t.update
    ; balance_change = { magnitude = Amount.zero; sgn = Pos }
    ; increment_nonce = false
    ; events = []
    ; sequence_events = []
    ; call_data = Field.Constant.zero
    ; preconditions =
        { Party.Preconditions.network =
            { snarked_ledger_hash = Ignore
            ; timestamp = Ignore
            ; blockchain_length = Ignore
            ; min_window_density = Ignore
            ; last_vrf_output = ()
            ; total_currency = Ignore
            ; global_slot_since_hard_fork = Ignore
            ; global_slot_since_genesis = Ignore
            ; staking_epoch_data =
                { ledger =
                    { Epoch_ledger.Poly.hash = Ignore; total_currency = Ignore }
                ; seed = Ignore
                ; start_checkpoint = Ignore
                ; lock_checkpoint = Ignore
                ; epoch_length = Ignore
                }
            ; next_epoch_data =
                { ledger =
                    { Epoch_ledger.Poly.hash = Ignore; total_currency = Ignore }
                ; seed = Ignore
                ; start_checkpoint = Ignore
                ; lock_checkpoint = Ignore
                ; epoch_length = Ignore
                }
            }
        ; account = Full (Account_condition.to_predicate t.account_condition)
        }
    ; use_full_commitment = false
    ; caller = t.token_id
    }

  let assert_state_unproved (t : t) =
    { t with
      account_condition =
        Account_condition.assert_state_unproved t.account_condition
    }

  let assert_state_proved (t : t) =
    { t with
      account_condition =
        Account_condition.assert_state_proved t.account_condition
    }

  let set_full_state app_state (t : t) =
    { t with update = Update.set_full_state app_state t.update }

  module In_circuit = struct
    module Account_condition = struct
      type t = { state_proved : Boolean.var option }

      let create () = { state_proved = None }

      let to_predicate ({ state_proved } : t) :
          Zkapp_precondition.Account.Checked.t =
        (* TODO: Don't do this. *)
        let var_of_t (type var value) (typ : (var, value) Typ.t) (x : value) :
            var =
          let open Snark_params.Tick in
          let (Typ typ) = typ in
          let fields, aux = typ.value_to_fields x in
          let fields = Array.map Field.Var.constant fields in
          typ.var_of_fields (fields, aux)
        in
        let default =
          var_of_t
            (Party.Account_precondition.typ ())
            (Full
               { balance = Ignore
               ; nonce = Ignore
               ; receipt_chain_hash = Ignore
               ; delegate = Ignore
               ; state =
                   [ Ignore
                   ; Ignore
                   ; Ignore
                   ; Ignore
                   ; Ignore
                   ; Ignore
                   ; Ignore
                   ; Ignore
                   ]
               ; sequence_state = Ignore
               ; proved_state = Ignore
               } )
        in
        let proved_state =
          (* TODO: This is not great. *)
          match state_proved with
          | None ->
              default.proved_state
          | Some state_proved ->
              Zkapp_basic.Or_ignore.Checked.make_unsafe_explicit Boolean.true_
                state_proved
        in
        { default with proved_state }

      let assert_state_proved (t : t) =
        match t.state_proved with
        | None ->
            { state_proved = Some Boolean.true_ }
        | Some b ->
            Boolean.Assert.( = ) b Boolean.true_ ;
            t

      let assert_state_unproved (t : t) =
        match t.state_proved with
        | None ->
            { state_proved = Some Boolean.false_ }
        | Some b ->
            Boolean.Assert.( = ) b Boolean.false_ ;
            t
    end

    module Update = struct
      type t = { app_state : Field.t option Zkapp_state.V.t }

      let create () =
        { app_state = [ None; None; None; None; None; None; None; None ] }

      let to_parties_update ({ app_state } : t) : Party.Update.Checked.t =
        (* TODO: Don't do this. *)
        let var_of_t (type var value) (typ : (var, value) Typ.t) (x : value) :
            var =
          let open Snark_params.Tick in
          let (Typ typ) = typ in
          let fields, aux = typ.value_to_fields x in
          let fields = Array.map Field.Var.constant fields in
          typ.var_of_fields (fields, aux)
        in
        let default =
          var_of_t (Party.Update.typ ())
            { app_state = [ Keep; Keep; Keep; Keep; Keep; Keep; Keep; Keep ]
            ; delegate = Keep
            ; verification_key = Keep
            ; permissions = Keep
            ; zkapp_uri = Keep
            ; token_symbol = Keep
            ; timing = Keep
            ; voting_for = Keep
            }
        in
        let app_state =
          Pickles_types.Vector.map app_state ~f:(function
            | None ->
                (* TODO: Shouldn't need to know that the dummy is Field.zero
                   here. Functor, perhaps?
                *)
                Zkapp_basic.Set_or_keep.Checked.keep ~dummy:Field.zero
            | Some x ->
                Zkapp_basic.Set_or_keep.Checked.set x )
        in
        { default with app_state }

      let set_full_state app_state (_t : t) =
        match app_state with
        | [ a0; a1; a2; a3; a4; a5; a6; a7 ] ->
            { app_state =
                [ Some a0
                ; Some a1
                ; Some a2
                ; Some a3
                ; Some a4
                ; Some a5
                ; Some a6
                ; Some a7
                ]
            }
        | _ ->
            failwith "Incorrect length of app_state"
    end

    type t =
      { public_key : Public_key.Compressed.var
      ; token_id : Token_id.Checked.t
      ; account_condition : Account_condition.t
      ; update : Update.t
      }

    let create ~public_key ?(token_id = Token_id.(Checked.constant default)) ()
        =
      { public_key
      ; token_id
      ; account_condition = Account_condition.create ()
      ; update = Update.create ()
      }

    let to_party_and_calls (t : t) :
        Party.Body.Checked.t * Zkapp_call_forest.Checked.t =
      (* TODO: Don't do this. *)
      let var_of_t (type var value) (typ : (var, value) Typ.t) (x : value) : var
          =
        let open Snark_params.Tick in
        let (Typ typ) = typ in
        let fields, aux = typ.value_to_fields x in
        let fields = Array.map Field.Var.constant fields in
        typ.var_of_fields (fields, aux)
      in
      let party : Party.Body.Checked.t =
        { public_key = t.public_key
        ; token_id = t.token_id
        ; update = Update.to_parties_update t.update
        ; balance_change =
            var_of_t Amount.Signed.typ { magnitude = Amount.zero; sgn = Pos }
        ; increment_nonce = Boolean.false_
        ; events = var_of_t Zkapp_account.Events.typ []
        ; sequence_events = var_of_t Zkapp_account.Events.typ []
        ; call_data = Field.zero
        ; preconditions =
            { Party.Preconditions.Checked.network =
                var_of_t Zkapp_precondition.Protocol_state.typ
                  { snarked_ledger_hash = Ignore
                  ; timestamp = Ignore
                  ; blockchain_length = Ignore
                  ; min_window_density = Ignore
                  ; last_vrf_output = ()
                  ; total_currency = Ignore
                  ; global_slot_since_hard_fork = Ignore
                  ; global_slot_since_genesis = Ignore
                  ; staking_epoch_data =
                      { ledger =
                          { Epoch_ledger.Poly.hash = Ignore
                          ; total_currency = Ignore
                          }
                      ; seed = Ignore
                      ; start_checkpoint = Ignore
                      ; lock_checkpoint = Ignore
                      ; epoch_length = Ignore
                      }
                  ; next_epoch_data =
                      { ledger =
                          { Epoch_ledger.Poly.hash = Ignore
                          ; total_currency = Ignore
                          }
                      ; seed = Ignore
                      ; start_checkpoint = Ignore
                      ; lock_checkpoint = Ignore
                      ; epoch_length = Ignore
                      }
                  }
            ; account = Account_condition.to_predicate t.account_condition
            }
        ; use_full_commitment = Boolean.false_
        ; caller = t.token_id
        }
      in
      let calls = exists Zkapp_call_forest.typ ~compute:(fun () -> []) in
      (party, calls)

    let assert_state_unproved (t : t) =
      { t with
        account_condition =
          Account_condition.assert_state_unproved t.account_condition
      }

    let assert_state_proved (t : t) =
      { t with
        account_condition =
          Account_condition.assert_state_proved t.account_condition
      }

    let set_full_state app_state (t : t) =
      { t with update = Update.set_full_state app_state t.update }
  end
end

(* TODO: Move this somewhere convenient. *)
let dummy_constraints () =
  let x = exists Field.typ ~compute:(fun () -> Field.Constant.of_int 3) in
  let g = exists Inner_curve.typ ~compute:(fun _ -> Inner_curve.one) in
  ignore
    ( Pickles.Scalar_challenge.to_field_checked'
        (module Impl)
        ~num_bits:16
        (Kimchi_backend_common.Scalar_challenge.create x)
      : Field.t * Field.t * Field.t ) ;
  ignore
    ( Pickles.Step_main_inputs.Ops.scale_fast g ~num_bits:5 (Shifted_value x)
      : Pickles.Step_main_inputs.Inner_curve.t ) ;
  ignore
    ( Pickles.Step_main_inputs.Ops.scale_fast g ~num_bits:5 (Shifted_value x)
      : Pickles.Step_main_inputs.Inner_curve.t ) ;
  ignore
    ( Pickles.Step_verifier.Scalar_challenge.endo g ~num_bits:4
        (Kimchi_backend_common.Scalar_challenge.create x)
      : Field.t * Field.t )

type return_type =
  { party : Party.Body.t
  ; party_digest : Parties.Digest.Party.t
  ; calls :
      ( ( Party.t
        , Parties.Digest.Party.t
        , Parties.Digest.Forest.t )
        Parties.Call_forest.Tree.t
      , Parties.Digest.Forest.t )
      With_stack_hash.t
      list
  }

let to_party party : Zkapp_statement.Checked.t * return_type Prover_value.t =
  dummy_constraints () ;
  let party, calls =
    Party_under_construction.In_circuit.to_party_and_calls party
  in
  let party_digest = Parties.Call_forest.Digest.Party.Checked.create party in
  let public_output : Zkapp_statement.Checked.t =
    { party = (party_digest :> Field.t)
    ; calls = (Zkapp_call_forest.Checked.hash calls :> Field.t)
    }
  in
  let auxiliary_output =
    Prover_value.create (fun () ->
        let party = As_prover.read (Party.Body.typ ()) party in
        let party_digest =
          As_prover.read Parties.Call_forest.Digest.Party.typ party_digest
        in
        let calls = Prover_value.get calls.data in
        { party; calls; party_digest } )
  in
  (public_output, auxiliary_output)

open Pickles_types
open Hlist

let wrap_main f { Pickles.Inductive_rule.public_input = () } =
  { Pickles.Inductive_rule.previous_proof_statements = []
  ; public_output = f ()
  ; auxiliary_output = ()
  }

let compile :
    type auxiliary_var auxiliary_value prev_varss prev_valuess widthss heightss max_proofs_verified branches.
       ?self:
         ( Zkapp_statement.Checked.t
         , Zkapp_statement.t
         , max_proofs_verified
         , branches )
         Pickles.Tag.t
    -> ?cache:_
    -> ?disk_keys:(_, branches) Vector.t * _
    -> auxiliary_typ:(auxiliary_var, auxiliary_value) Typ.t
    -> branches:(module Nat.Intf with type n = branches)
    -> max_proofs_verified:
         (module Nat.Add.Intf with type n = max_proofs_verified)
    -> name:string
    -> constraint_constants:_
    -> choices:
         (   self:
               ( Zkapp_statement.Checked.t
               , Zkapp_statement.t
               , max_proofs_verified
               , branches )
               Pickles.Tag.t
          -> ( prev_varss
             , prev_valuess
             , widthss
             , heightss
             , unit
             , unit
             , Party_under_construction.In_circuit.t
             , unit (* TODO: Remove? *)
             , auxiliary_var
             , auxiliary_value )
             H4_6.T(Pickles.Inductive_rule).t )
    -> unit
    -> ( Zkapp_statement.Checked.t
       , Zkapp_statement.t
       , max_proofs_verified
       , branches )
       Pickles.Tag.t
       * _
       * (module Pickles.Proof_intf
            with type t = ( max_proofs_verified
                          , max_proofs_verified )
                          Pickles.Proof.t
             and type statement = Zkapp_statement.t )
       * ( prev_valuess
         , widthss
         , heightss
         , unit
         , ( ( Party.t
             , Parties.Digest.Party.t
             , Parties.Digest.Forest.t )
             Parties.Call_forest.Tree.t
           * auxiliary_value )
           Deferred.t )
         H3_2.T(Pickles.Prover).t =
 fun ?self ?cache ?disk_keys ~auxiliary_typ ~branches ~max_proofs_verified ~name
     ~constraint_constants ~choices () ->
  let choices ~self =
    let rec go :
        type prev_varss prev_valuess widthss heightss.
           ( prev_varss
           , prev_valuess
           , widthss
           , heightss
           , unit
           , unit
           , Party_under_construction.In_circuit.t
           , unit
           , auxiliary_var
           , auxiliary_value )
           H4_6.T(Pickles.Inductive_rule).t
        -> ( prev_varss
           , prev_valuess
           , widthss
           , heightss
           , unit
           , unit
           , Zkapp_statement.Checked.t
           , Zkapp_statement.t
           , return_type Prover_value.t * auxiliary_var
           , return_type * auxiliary_value )
           H4_6.T(Pickles.Inductive_rule).t = function
      | [] ->
          []
      | { identifier; prevs; main } :: choices ->
          { identifier
          ; prevs
          ; main =
              (fun main_input ->
                let { Pickles.Inductive_rule.previous_proof_statements
                    ; public_output = party_under_construction
                    ; auxiliary_output
                    } =
                  main main_input
                in
                let public_output, party_tree =
                  to_party party_under_construction
                in
                { previous_proof_statements
                ; public_output
                ; auxiliary_output = (party_tree, auxiliary_output)
                } )
          }
          :: go choices
    in
    go (choices ~self)
  in
  let module Statement = struct
    type t = unit

    let to_field_elements () = [||]
  end in
  let tag, cache_handle, proof, provers =
    Pickles.compile ?self ?cache ?disk_keys
      (module Statement)
      (module Statement)
      ~public_input:(Output Zkapp_statement.typ)
      ~auxiliary_typ:Typ.(Prover_value.typ () * auxiliary_typ)
      ~branches ~max_proofs_verified ~name ~constraint_constants ~choices
  in
  let provers =
    let rec go :
        type prev_valuess widthss heightss.
           ( prev_valuess
           , widthss
           , heightss
           , unit
           , ( Zkapp_statement.t
             * (return_type * auxiliary_value)
             * (max_proofs_verified, max_proofs_verified) Pickles.Proof.t )
             Deferred.t )
           H3_2.T(Pickles.Prover).t
        -> ( prev_valuess
           , widthss
           , heightss
           , unit
           , ( ( Party.t
               , Parties.Digest.Party.t
               , Parties.Digest.Forest.t )
               Parties.Call_forest.Tree.t
             * auxiliary_value )
             Deferred.t )
           H3_2.T(Pickles.Prover).t = function
      | [] ->
          []
      | prover :: provers ->
          let prover ?handler () =
            let open Async_kernel in
            let%map ( _stmt
                    , ({ party; party_digest; calls }, auxiliary_value)
                    , proof ) =
              prover ?handler ()
            in
            let party : Party.t =
              { body = party
              ; authorization = Proof (Pickles.Side_loaded.Proof.of_proof proof)
              }
            in
            ( { Parties.Call_forest.Tree.party; party_digest; calls }
            , auxiliary_value )
          in
          prover :: go provers
    in
    go provers
  in
  (tag, cache_handle, proof, provers)
