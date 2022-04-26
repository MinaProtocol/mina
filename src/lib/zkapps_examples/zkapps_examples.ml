open Pickles_types.Hlist
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
        ; public_key = Ignore
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
    ; call_depth = 0
    ; protocol_state_precondition =
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
    ; use_full_commitment = false
    ; account_precondition =
        Full (Account_condition.to_predicate t.account_condition)
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
          Snarky_backendless.Typ_monads.Store.run (typ.store x) Field.constant
        in
        let default =
          var_of_t
            (Party.Account_precondition.typ ())
            (Full
               { balance = Ignore
               ; nonce = Ignore
               ; receipt_chain_hash = Ignore
               ; public_key = Ignore
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
               })
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
          Snarky_backendless.Typ_monads.Store.run (typ.store x) Field.constant
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
                Zkapp_basic.Set_or_keep.Checked.set x)
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

    let to_party (t : t) : Party.Body.Checked.t =
      (* TODO: Don't do this. *)
      let var_of_t (type var value) (typ : (var, value) Typ.t) (x : value) : var
          =
        Snarky_backendless.Typ_monads.Store.run (typ.store x) Field.constant
      in
      { public_key = t.public_key
      ; token_id = t.token_id
      ; update = Update.to_parties_update t.update
      ; balance_change =
          var_of_t Amount.Signed.typ { magnitude = Amount.zero; sgn = Pos }
      ; increment_nonce = Boolean.false_
      ; events = var_of_t Zkapp_account.Events.typ []
      ; sequence_events = var_of_t Zkapp_account.Events.typ []
      ; call_data = Field.zero
      ; call_depth = As_prover.Ref.create (fun () -> 0)
      ; protocol_state_precondition =
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
      ; use_full_commitment = Boolean.false_
      ; account_precondition =
          Account_condition.to_predicate t.account_condition
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

(* TODO: Should be able to *return* stmt instead of consuming it.
         Modify snarky to do this.
*)
let party_circuit f ([] : _ H1.T(Id).t)
    ({ transaction; at_party } : Zkapp_statement.Checked.t) :
    _ H1.T(E01(Pickles.Inductive_rule.B)).t =
  dummy_constraints () ;
  let party = f () in
  let party = Party_under_construction.In_circuit.to_party party in
  let returned_transaction = Party.Checked.digest party in
  let returned_at_party =
    (* TODO: This should be returned from
             [Party_under_construction.In_circuit.to_party].
    *)
    Field.constant Parties.Call_forest.empty
  in
  Run.Field.Assert.equal returned_transaction transaction ;
  Run.Field.Assert.equal returned_at_party at_party ;
  []
