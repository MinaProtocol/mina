open Core_kernel
open Async_kernel
open Snark_params.Tick
open Snark_params.Tick.Run
open Currency
open Signature_lib
open Mina_base

module Account_update_under_construction = struct
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
          let fields = Array.map ~f:Field.Var.constant fields in
          typ.var_of_fields (fields, aux)
        in
        let default =
          var_of_t
            (Account_update.Account_precondition.typ ())
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
            ; action_state = Ignore
            ; proved_state = Ignore
            ; is_new = Ignore
            }
        in
        let proved_state =
          (* TODO: This is not great. *)
          match state_proved with
          | None ->
              default.proved_state
          | Some state_proved ->
              Zkapp_basic.Or_ignore.Checked.make_unsafe Boolean.true_
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

      let to_zkapp_command_update ({ app_state } : t) :
          Account_update.Update.Checked.t =
        (* TODO: Don't do this. *)
        let var_of_t (type var value) (typ : (var, value) Typ.t) (x : value) :
            var =
          let open Snark_params.Tick in
          let (Typ typ) = typ in
          let fields, aux = typ.value_to_fields x in
          let fields = Array.map ~f:Field.Var.constant fields in
          typ.var_of_fields (fields, aux)
        in
        let default =
          var_of_t
            (Account_update.Update.typ ())
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

      let set_state i value (t : t) =
        if i < 0 || i >= 8 then failwith "Incorrect index" ;
        { app_state =
            Pickles_types.Vector.mapi t.app_state ~f:(fun j old_value ->
                if i = j then Some value else old_value )
        }
    end

    module Events = struct
      type t = { events : Field.t array list }

      let create () = { events = [] }

      let add_events t events : t = { events = t.events @ events }

      let to_zkapp_command_events ({ events } : t) : Zkapp_account.Events.var =
        let open Core_kernel in
        let empty_var : Zkapp_account.Events.var =
          exists ~compute:(fun () -> []) Zkapp_account.Events.typ
        in
        (* matches fold_right in Zkapp_account.Events.hash *)
        List.fold_right events ~init:empty_var
          ~f:(Fn.flip Zkapp_account.Events.push_to_data_as_hash)
    end

    module Actions = struct
      type t = { actions : Field.t array list }

      let create () = { actions = [] }

      let add_actions t actions : t = { actions = t.actions @ actions }

      let to_zkapp_command_actions ({ actions } : t) : Zkapp_account.Actions.var
          =
        let open Core_kernel in
        let empty_var : Zkapp_account.Events.var =
          exists ~compute:(fun () -> []) Zkapp_account.Actions.typ
        in
        (* matches fold_right in Zkapp_account.Actions.hash *)
        List.fold_right actions ~init:empty_var
          ~f:(Fn.flip Zkapp_account.Actions.push_to_data_as_hash)
    end

    module Calls_kind = struct
      type t =
        | No_calls
        | Rev_calls of
            ( Zkapp_call_forest.Checked.account_update
            * Zkapp_call_forest.Checked.t )
            list
        | Calls of Zkapp_call_forest.Checked.t
    end

    module Authorization_kind = struct
      type t = { is_signed : Boolean.var; is_proved : Boolean.var }
    end

    type t =
      { public_key : Public_key.Compressed.var
      ; token_id : Token_id.Checked.t
      ; balance_change : Currency.Amount.Signed.Checked.t
      ; may_use_token : Account_update.May_use_token.Checked.t
      ; account_condition : Account_condition.t
      ; update : Update.t
      ; calls : Calls_kind.t
      ; call_data : Field.t option
      ; events : Events.t
      ; actions : Actions.t
      ; authorization_kind : Authorization_kind.t
      ; vk_hash : Field.t Option.t
      }

    let create ~public_key ?vk_hash
        ?(token_id = Token_id.(Checked.constant default))
        ?(may_use_token = Account_update.May_use_token.Checked.constant No) () =
      { public_key
      ; token_id
      ; balance_change =
          Amount.Signed.Checked.constant { magnitude = Amount.zero; sgn = Pos }
      ; may_use_token
      ; account_condition = Account_condition.create ()
      ; update = Update.create ()
      ; calls = No_calls
      ; call_data = None
      ; events = Events.create ()
      ; actions = Actions.create ()
      ; authorization_kind =
          { is_signed = Boolean.false_; is_proved = Boolean.true_ }
      ; vk_hash
      }

    let to_account_update_and_calls (t : t) :
        Account_update.Body.Checked.t * Zkapp_call_forest.Checked.t =
      (* TODO: Don't do this. *)
      let var_of_t (type var value) (typ : (var, value) Typ.t) (x : value) : var
          =
        let open Snark_params.Tick in
        let (Typ typ) = typ in
        let fields, aux = typ.value_to_fields x in
        let fields = Array.map ~f:Field.Var.constant fields in
        typ.var_of_fields (fields, aux)
      in
      let account_update : Account_update.Body.Checked.t =
        { public_key = t.public_key
        ; token_id = t.token_id
        ; update = Update.to_zkapp_command_update t.update
        ; balance_change = t.balance_change
        ; increment_nonce = Boolean.false_
        ; call_data = Option.value ~default:Field.zero t.call_data
        ; events = Events.to_zkapp_command_events t.events
        ; actions = Actions.to_zkapp_command_actions t.actions
        ; preconditions =
            { Account_update.Preconditions.Checked.network =
                var_of_t Zkapp_precondition.Protocol_state.typ
                  { snarked_ledger_hash = Ignore
                  ; blockchain_length = Ignore
                  ; min_window_density = Ignore
                  ; total_currency = Ignore
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
            ; valid_while = var_of_t Zkapp_precondition.Valid_while.typ Ignore
            }
        ; use_full_commitment = Boolean.false_
        ; implicit_account_creation_fee =
            (* Probably shouldn't hard-code this logic, but :shrug:, it's a
               reasonable test.
            *)
            Token_id.(Checked.equal t.token_id (Checked.constant default))
        ; may_use_token = t.may_use_token
        ; authorization_kind =
            (let dummy_vk_hash =
               Field.constant (Zkapp_account.dummy_vk_hash ())
             in
             { is_signed = t.authorization_kind.is_signed
             ; is_proved = t.authorization_kind.is_proved
             ; verification_key_hash =
                 Option.value ~default:dummy_vk_hash t.vk_hash
             } )
        }
      in
      let calls =
        match t.calls with
        | No_calls ->
            Zkapp_call_forest.Checked.empty ()
        | Rev_calls rev_calls ->
            List.fold_left ~init:(Zkapp_call_forest.Checked.empty ()) rev_calls
              ~f:(fun acc (account_update, calls) ->
                Zkapp_call_forest.Checked.push ~account_update ~calls acc )
        | Calls calls ->
            calls
      in
      (account_update, calls)

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

    let set_state idx data (t : t) =
      { t with update = Update.set_state idx data t.update }

    let register_call account_update calls (t : t) =
      let rev_calls =
        match t.calls with
        | No_calls ->
            []
        | Rev_calls rev_calls ->
            rev_calls
        | Calls _ ->
            failwith "Cannot append calls to an already-completed tree"
      in
      { t with calls = Rev_calls ((account_update, calls) :: rev_calls) }

    let set_calls calls (t : t) =
      ( match t.calls with
      | No_calls ->
          ()
      | Rev_calls _ ->
          failwith
            "Cannot append an already-completed tree to the current calls"
      | Calls _ ->
          failwith "Cannot join two already-completed trees" ) ;
      { t with calls = Calls calls }

    let set_call_data call_data (t : t) = { t with call_data = Some call_data }

    let add_events events (t : t) =
      { t with events = Events.add_events t.events events }

    let add_actions actions (t : t) =
      { t with actions = Actions.add_actions t.actions actions }

    let set_balance_change balance_change (t : t) = { t with balance_change }

    let set_authorization_kind authorization_kind (t : t) =
      { t with authorization_kind }
  end
end

class account_update ~public_key ?vk_hash ?token_id ?may_use_token () =
  object
    val mutable account_update =
      Account_update_under_construction.In_circuit.create ~public_key ?vk_hash
        ?token_id ?may_use_token ()

    method assert_state_proved =
      account_update <-
        Account_update_under_construction.In_circuit.assert_state_proved
          account_update

    method assert_state_unproved =
      account_update <-
        Account_update_under_construction.In_circuit.assert_state_unproved
          account_update

    method set_state idx data =
      account_update <-
        Account_update_under_construction.In_circuit.set_state idx data
          account_update

    method set_full_state app_state =
      account_update <-
        Account_update_under_construction.In_circuit.set_full_state app_state
          account_update

    method set_call_data call_data =
      account_update <-
        Account_update_under_construction.In_circuit.set_call_data call_data
          account_update

    method register_call called_account_update sub_calls =
      account_update <-
        Account_update_under_construction.In_circuit.register_call
          called_account_update sub_calls account_update

    method set_calls calls =
      account_update <-
        Account_update_under_construction.In_circuit.set_calls calls
          account_update

    method add_events events =
      account_update <-
        Account_update_under_construction.In_circuit.add_events events
          account_update

    method add_actions actions =
      account_update <-
        Account_update_under_construction.In_circuit.add_actions actions
          account_update

    method set_balance_change balance_change =
      account_update <-
        Account_update_under_construction.In_circuit.set_balance_change
          balance_change account_update

    method set_authorization_kind authorization_kind =
      account_update <-
        Account_update_under_construction.In_circuit.set_authorization_kind
          authorization_kind account_update

    method account_update_under_construction = account_update
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
  { account_update : Account_update.Body.t
  ; account_update_digest : Zkapp_command.Digest.Account_update.t
  ; calls :
      ( ( Account_update.t
        , Zkapp_command.Digest.Account_update.t
        , Zkapp_command.Digest.Forest.t )
        Zkapp_command.Call_forest.Tree.t
      , Zkapp_command.Digest.Forest.t )
      With_stack_hash.t
      list
  }

let to_account_update (account_update : account_update) :
    Zkapp_statement.Checked.t * return_type Prover_value.t =
  dummy_constraints () ;
  let account_update, calls =
    Account_update_under_construction.In_circuit.to_account_update_and_calls
      account_update#account_update_under_construction
  in
  let account_update_digest =
    Zkapp_command.Call_forest.Digest.Account_update.Checked.create
      account_update
  in
  let public_output : Zkapp_statement.Checked.t =
    { account_update = (account_update_digest :> Field.t)
    ; calls = (Zkapp_call_forest.Checked.hash calls :> Field.t)
    }
  in
  let auxiliary_output =
    Prover_value.create (fun () ->
        let account_update =
          As_prover.read (Account_update.Body.typ ()) account_update
        in
        let account_update_digest =
          As_prover.read Zkapp_command.Call_forest.Digest.Account_update.typ
            account_update_digest
        in
        let calls = Prover_value.get calls.data in
        { account_update; calls; account_update_digest } )
  in
  (public_output, auxiliary_output)

open Pickles_types
open Hlist

let wrap_main ~public_key ?token_id ?may_use_token f
    { Pickles.Inductive_rule.public_input = vk_hash } =
  let account_update =
    new account_update ~public_key ~vk_hash ?token_id ?may_use_token ()
  in
  let auxiliary_output = f account_update in
  { Pickles.Inductive_rule.previous_proof_statements = []
  ; public_output = account_update
  ; auxiliary_output
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
    -> ?override_wrap_domain:_
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
             , Field.t
             , Field.Constant.t
             , account_update
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
         , ( ( Account_update.t
             , Zkapp_command.Digest.Account_update.t
             , Zkapp_command.Digest.Forest.t )
             Zkapp_command.Call_forest.Tree.t
           * auxiliary_value )
           Deferred.t )
         H3_2.T(Pickles.Prover).t =
 fun ?self ?cache ?disk_keys ?override_wrap_domain ~auxiliary_typ ~branches
     ~max_proofs_verified ~name ~constraint_constants ~choices () ->
  let vk_hash = ref None in
  let choices ~self =
    let rec go :
        type prev_varss prev_valuess widthss heightss.
           ( prev_varss
           , prev_valuess
           , widthss
           , heightss
           , Field.t
           , Field.Constant.t
           , account_update
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
      | { identifier; prevs; main; feature_flags } :: choices ->
          { identifier
          ; prevs
          ; feature_flags
          ; main =
              (fun { Pickles.Inductive_rule.public_input = () } ->
                let vk_hash =
                  exists Field.typ ~compute:(fun () ->
                      Lazy.force @@ Option.value_exn !vk_hash )
                in
                let { Pickles.Inductive_rule.previous_proof_statements
                    ; public_output = account_update_under_construction
                    ; auxiliary_output
                    } =
                  main { Pickles.Inductive_rule.public_input = vk_hash }
                in
                let public_output, account_update_tree =
                  to_account_update account_update_under_construction
                in
                { previous_proof_statements
                ; public_output
                ; auxiliary_output = (account_update_tree, auxiliary_output)
                } )
          }
          :: go choices
    in
    go (choices ~self)
  in
  let tag, cache_handle, proof, provers =
    Pickles.compile () ?self ?cache ?disk_keys ?override_wrap_domain
      ~public_input:(Output Zkapp_statement.typ)
      ~auxiliary_typ:Typ.(Prover_value.typ () * auxiliary_typ)
      ~branches ~max_proofs_verified ~name ~constraint_constants ~choices
  in
  let () =
    vk_hash :=
      Some
        ( lazy
          ( Zkapp_account.digest_vk
          @@ Pickles.Side_loaded.Verification_key.of_compiled tag ) )
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
           , ( ( Account_update.t
               , Zkapp_command.Digest.Account_update.t
               , Zkapp_command.Digest.Forest.t )
               Zkapp_command.Call_forest.Tree.t
             * auxiliary_value )
             Deferred.t )
           H3_2.T(Pickles.Prover).t = function
      | [] ->
          []
      | prover :: provers ->
          let prover ?handler () =
            let open Async_kernel in
            let%map ( _stmt
                    , ( { account_update; account_update_digest; calls }
                      , auxiliary_value )
                    , proof ) =
              prover ?handler ()
            in
            let account_update : Account_update.t =
              { body = account_update
              ; authorization = Proof (Pickles.Side_loaded.Proof.of_proof proof)
              }
            in
            ( { Zkapp_command.Call_forest.Tree.account_update
              ; account_update_digest
              ; calls
              }
            , auxiliary_value )
          in
          prover :: go provers
    in
    go provers
  in
  (tag, cache_handle, proof, provers)

let mk_update_body ?(token_id = Token_id.default)
    ?(update = Account_update.Update.dummy)
    ?(balance_change = Amount.Signed.zero) ?(increment_nonce = false)
    ?(events = []) ?(actions = []) ?(call_data = Field.Constant.zero)
    ?(preconditions = Account_update.Preconditions.accept)
    ?(use_full_commitment = false)
    ?(may_use_token = Account_update.May_use_token.No)
    ?(authorization_kind = Account_update.Authorization_kind.Signature)
    ?(implicit_account_creation_fee = false) public_key =
  { Account_update.Body.public_key
  ; update
  ; token_id
  ; balance_change
  ; increment_nonce
  ; events
  ; actions
  ; call_data
  ; preconditions
  ; use_full_commitment
  ; may_use_token
  ; authorization_kind
  ; implicit_account_creation_fee
  }

module Deploy_account_update = struct
  let body ?(balance_change = Account_update.Body.dummy.balance_change)
      ?(access = Permissions.Auth_required.None) public_key token_id vk :
      Account_update.Body.t =
    { Account_update.Body.dummy with
      public_key
    ; balance_change
    ; token_id
    ; update =
        { Account_update.Update.dummy with
          verification_key =
            Set
              { data = vk
              ; hash =
                  (* TODO: This function should live in
                     [Side_loaded_verification_key].
                  *)
                  Zkapp_account.digest_vk vk
              }
        ; permissions =
            Set
              { edit_state = Proof
              ; send = Either
              ; receive = None
              ; set_delegate = Proof
              ; set_permissions = Proof
              ; set_verification_key = (Proof, Mina_numbers.Txn_version.current)
              ; set_zkapp_uri = Proof
              ; edit_action_state = Proof
              ; set_token_symbol = Proof
              ; increment_nonce = Proof
              ; set_voting_for = Proof
              ; set_timing = Proof
              ; access
              }
        }
    ; use_full_commitment = true
    ; preconditions =
        { Account_update.Preconditions.network =
            Zkapp_precondition.Protocol_state.accept
        ; account = Zkapp_precondition.Account.accept
        ; valid_while = Ignore
        }
    ; authorization_kind = Signature
    }

  let full ?balance_change ?access public_key token_id vk : Account_update.t =
    (* TODO: This is a pain. *)
    { body = body ?balance_change ?access public_key token_id vk
    ; authorization = Signature Signature.dummy
    }
end

let insert_signatures pk_compressed sk
    ({ fee_payer; account_updates; memo } : Zkapp_command.t) : Zkapp_command.t =
  let transaction_commitment : Zkapp_command.Transaction_commitment.t =
    (* TODO: This is a pain. *)
    let account_updates_hash = Zkapp_command.Call_forest.hash account_updates in
    Zkapp_command.Transaction_commitment.create ~account_updates_hash
  in
  let memo_hash = Signed_command_memo.hash memo in
  let full_commitment =
    Zkapp_command.Transaction_commitment.create_complete transaction_commitment
      ~memo_hash
      ~fee_payer_hash:
        (Zkapp_command.Call_forest.Digest.Account_update.create
           (Account_update.of_fee_payer fee_payer) )
  in
  let fee_payer =
    match fee_payer with
    | { body = { public_key; _ }; _ }
      when Public_key.Compressed.equal public_key pk_compressed ->
        { fee_payer with
          authorization =
            Schnorr.Chunked.sign sk
              (Random_oracle.Input.Chunked.field full_commitment)
        }
    | fee_payer ->
        fee_payer
  in
  let account_updates =
    Zkapp_command.Call_forest.map account_updates ~f:(function
      | ({ body = { public_key; use_full_commitment; _ }
         ; authorization = Signature _
         } as account_update :
          Account_update.t )
        when Public_key.Compressed.equal public_key pk_compressed ->
          let commitment =
            if use_full_commitment then full_commitment
            else transaction_commitment
          in
          { account_update with
            authorization =
              Signature
                (Schnorr.Chunked.sign sk
                   (Random_oracle.Input.Chunked.field commitment) )
          }
      | account_update ->
          account_update )
  in
  { fee_payer; account_updates; memo }
