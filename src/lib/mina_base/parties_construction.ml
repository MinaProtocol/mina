open Core_kernel
open Snapp_basic
open Currency
open Signature_lib

module Partial_party = struct
  module Update = struct
    type t =
      { app_state : F.t Set_or_keep.t option Snapp_state.V.t
      ; delegate : Public_key.Compressed.t Set_or_keep.t option
      ; verification_key :
          (Pickles.Side_loaded.Verification_key.t, F.t) With_hash.t
          Set_or_keep.t
          option
      ; permissions : Permissions.t Set_or_keep.t option
      ; snapp_uri : string Set_or_keep.t option
      ; token_symbol : Account.Token_symbol.t Set_or_keep.t option
      }
  end

  module Predicate = struct
    open Snapp_predicate

    type t =
      { balance : Balance.t Numeric.t option
      ; nonce : Mina_numbers.Account_nonce.t Numeric.t option
      ; receipt_chain_hash : Receipt.Chain_hash.t Hash.t option
      ; public_key : Public_key.Compressed.t Eq_data.t option
      ; delegate : Public_key.Compressed.t Eq_data.t option
      ; state : F.t Eq_data.t option Snapp_state.V.t
      ; rollup_state : F.t Eq_data.t option
      ; proved_state : bool Eq_data.t option
      }
  end

  module Call_data = struct
    type t =
      | Opaque of F.t
      | Structured of { input : F.t array option; output : F.t array option }

    let to_field = function
      | Opaque f ->
          f
      | Structured { input; output } ->
          let data =
            match (input, output) with
            | Some input, Some output ->
                Array.append input output
            | Some data, None | None, Some data ->
                data
            | None, None ->
                [||]
          in
          let len = Array.length data in
          if len = 0 then F.zero
          else if len = 1 then data.(0)
          else Random_oracle.hash ~init:Hash_prefix.snapp_call_data data

    let opt_to_field = function None -> F.zero | Some data -> to_field data
  end

  type t =
    { pk : Public_key.Compressed.t option
    ; update : Update.t
    ; token_id : Token_id.t option
    ; delta : Amount.Signed.t option
    ; events : F.t array list
    ; rollup_events : F.t array list
    ; call_data : Call_data.t option
    ; rev_sub_parties : (Party.t, Party.Digest.t) Parties.Party_or_stack.t list
    ; predicate : Predicate.t
    ; control : Control.t option
    }

  let set_pk pk t =
    if Option.is_some t.pk then failwith "Public key is already set"
    else { t with pk = Some pk }

  let set_token_id token_id t =
    if Option.is_some t.token_id then failwith "Token id is already set"
    else { t with token_id = Some token_id }

  let set_delta delta t =
    if Option.is_some t.delta then failwith "Delta is already set"
    else { t with delta = Some delta }

  let emit_event event t = { t with events = event :: t.events }

  let emit_rollup_event event t =
    { t with rollup_events = event :: t.rollup_events }

  let set_opaque_call_data data t =
    match t.call_data with
    | None ->
        { t with call_data = Some (Opaque data) }
    | Some _ ->
        failwith "Call data is already set"

  let set_input_call_data input t =
    match t.call_data with
    | None ->
        { t with
          call_data = Some (Structured { input = Some input; output = None })
        }
    | Some (Structured { input = None; output }) ->
        { t with call_data = Some (Structured { input = Some input; output }) }
    | Some (Opaque _) ->
        failwith "Call data is already set"
    | Some (Structured { input = Some _; _ }) ->
        failwith "Call input is already set"

  let set_output_call_data output t =
    match t.call_data with
    | None ->
        { t with
          call_data = Some (Structured { input = None; output = Some output })
        }
    | Some (Structured { input; output = None }) ->
        { t with call_data = Some (Structured { input; output = Some output }) }
    | Some (Opaque _) ->
        failwith "Call data is already set"
    | Some (Structured { output = Some _; _ }) ->
        failwith "Call output is already set"

  let update_app_state app_state t =
    let app_state =
      Pickles_types.Vector.map2 t.update.app_state app_state
        ~f:(fun f_old f_new ->
          match f_old with
          | None ->
              Some (Set_or_keep.Set f_new)
          | Some _ ->
              failwith "App state has already been updated")
    in
    { t with update = { t.update with app_state } }

  let update_app_state_partial app_state t =
    let app_state =
      Pickles_types.Vector.map2 t.update.app_state app_state
        ~f:(fun f_old f_new ->
          match (f_old, f_new) with
          | None, None ->
              None
          | Some f, None ->
              Some f
          | None, Some f ->
              Some (Set_or_keep.Set f)
          | Some _, Some _ ->
              failwith "App state has already been updated")
    in
    { t with update = { t.update with app_state } }

  let update_app_state_i i state t =
    let app_state =
      Pickles_types.Vector.mapi t.update.app_state ~f:(fun j f_old ->
          if i = j then
            match f_old with
            | None ->
                Some (Set_or_keep.Set state)
            | Some _ ->
                failwith "App state has already been updated"
          else f_old)
    in
    { t with update = { t.update with app_state } }

  let update_delegate delegate t =
    match t.update.delegate with
    | None ->
        { t with update = { t.update with delegate = Some (Set delegate) } }
    | Some _ ->
        failwith "Delegate has already been updated"

  let update_verification_key verification_key t =
    match t.update.verification_key with
    | None ->
        { t with
          update =
            { t.update with verification_key = Some (Set verification_key) }
        }
    | Some _ ->
        failwith "Verification key has already been updated"

  let update_permissions permissions t =
    match t.update.permissions with
    | None ->
        { t with
          update = { t.update with permissions = Some (Set permissions) }
        }
    | Some _ ->
        failwith "Permissions have already been updated"

  let update_snapp_uri snapp_uri t =
    match t.update.snapp_uri with
    | None ->
        { t with update = { t.update with snapp_uri = Some (Set snapp_uri) } }
    | Some _ ->
        failwith "Snapp URI has already been updated"

  let update_token_symbol token_symbol t =
    match t.update.token_symbol with
    | None ->
        { t with
          update = { t.update with token_symbol = Some (Set token_symbol) }
        }
    | Some _ ->
        failwith "Token symbol has already been updated"

  let expect_balance balance t =
    match t.predicate.balance with
    | None ->
        { t with
          predicate =
            { t.predicate with
              balance = Some (Check { lower = balance; upper = balance })
            }
        }
    | Some _ ->
        failwith "Balance has already been constrained"

  let expect_balance_between ~min ~max t =
    match t.predicate.balance with
    | None ->
        { t with
          predicate =
            { t.predicate with
              balance = Some (Check { lower = min; upper = max })
            }
        }
    | Some _ ->
        failwith "Balance has already been constrained"

  let expect_nonce nonce t =
    match t.predicate.nonce with
    | None ->
        { t with
          predicate =
            { t.predicate with
              nonce = Some (Check { lower = nonce; upper = nonce })
            }
        }
    | Some _ ->
        failwith "Nonce has already been constrained"

  let expect_nonce_between ~min ~max t =
    match t.predicate.nonce with
    | None ->
        { t with
          predicate =
            { t.predicate with
              nonce = Some (Check { lower = min; upper = max })
            }
        }
    | Some _ ->
        failwith "Nonce has already been constrained"

  let expect_receipt_chain_hash receipt_chain_hash t =
    match t.predicate.receipt_chain_hash with
    | None ->
        { t with
          predicate =
            { t.predicate with
              receipt_chain_hash = Some (Check receipt_chain_hash)
            }
        }
    | Some _ ->
        failwith "Receipt chain hash has already been constrained"

  let expect_public_key public_key t =
    match t.predicate.public_key with
    | None ->
        { t with
          predicate = { t.predicate with public_key = Some (Check public_key) }
        }
    | Some _ ->
        failwith "Public key has already been constrained"

  let expect_delegate delegate t =
    match t.predicate.delegate with
    | None ->
        { t with
          predicate = { t.predicate with delegate = Some (Check delegate) }
        }
    | Some _ ->
        failwith "Delegate has already been constrained"

  let expect_app_state app_state t =
    let state =
      Pickles_types.Vector.map2 t.predicate.state app_state
        ~f:(fun f_old f_new ->
          match f_old with
          | None ->
              Some (Or_ignore.Check f_new)
          | Some _ ->
              failwith "App state has already been constrained")
    in
    { t with predicate = { t.predicate with state } }

  let expect_app_state_partial app_state t =
    let state =
      Pickles_types.Vector.map2 t.predicate.state app_state
        ~f:(fun f_old f_new ->
          match (f_old, f_new) with
          | None, None ->
              None
          | Some f, None ->
              Some f
          | None, Some f ->
              Some (Or_ignore.Check f)
          | Some _, Some _ ->
              failwith "App state has already been constrained")
    in
    { t with predicate = { t.predicate with state } }

  let expect_app_state_i i state t =
    let state =
      Pickles_types.Vector.mapi t.predicate.state ~f:(fun j f_old ->
          if i = j then
            match f_old with
            | None ->
                Some (Or_ignore.Check state)
            | Some _ ->
                failwith "App state has already been constrained"
          else f_old)
    in
    { t with predicate = { t.predicate with state } }

  let expect_rollup_state rollup_state t =
    match t.predicate.rollup_state with
    | None ->
        { t with
          predicate =
            { t.predicate with rollup_state = Some (Check rollup_state) }
        }
    | Some _ ->
        failwith "Rollup state has already been constrained"

  let expect_proved_state proved_state t =
    match t.predicate.proved_state with
    | None ->
        { t with
          predicate =
            { t.predicate with proved_state = Some (Check proved_state) }
        }
    | Some _ ->
        failwith "State proved has already been constrained"

  let init ?pk ?token_id () =
    { pk
    ; update =
        { app_state =
            Pickles_types.Vector.init Snapp_state.Max_state_size.n ~f:(fun _ ->
                None)
        ; delegate = None
        ; verification_key = None
        ; permissions = None
        ; snapp_uri = None
        ; token_symbol = None
        }
    ; token_id
    ; delta = None
    ; events = []
    ; rollup_events = []
    ; call_data = None
    ; rev_sub_parties = []
    ; predicate =
        { balance = None
        ; nonce = None
        ; receipt_chain_hash = None
        ; public_key = None
        ; delegate = None
        ; state =
            Pickles_types.Vector.init Snapp_state.Max_state_size.n ~f:(fun _ ->
                None)
        ; rollup_state = None
        ; proved_state = None
        }
    ; control = None
    }

  let to_party
      { pk
      ; update
      ; token_id
      ; delta
      ; events
      ; rollup_events
      ; call_data
      ; rev_sub_parties
      ; predicate
      ; control
      } : (Party.t, Party.Digest.t) Parties.Party_or_stack.t =
    let data : Party.Predicated.t =
      { body =
          { pk =
              ( match pk with
              | Some pk ->
                  pk
              | None ->
                  failwith "No public key was set" )
          ; token_id =
              ( match token_id with
              | Some token_id ->
                  token_id
              | None ->
                  failwith "No token id was set" )
          ; delta = Option.value ~default:Amount.Signed.zero delta
          ; update =
              (let { Update.app_state
                   ; delegate
                   ; verification_key
                   ; permissions
                   ; snapp_uri
                   ; token_symbol
                   } =
                 update
               in
               { app_state =
                   Pickles_types.Vector.map app_state
                     ~f:(Option.value ~default:Set_or_keep.Keep)
               ; delegate = Option.value ~default:Set_or_keep.Keep delegate
               ; verification_key =
                   Option.value ~default:Set_or_keep.Keep verification_key
               ; permissions =
                   Option.value ~default:Set_or_keep.Keep permissions
               ; snapp_uri = Option.value ~default:Set_or_keep.Keep snapp_uri
               ; token_symbol =
                   Option.value ~default:Set_or_keep.Keep token_symbol
               ; timing = Set_or_keep.Keep
               })
          ; events
          ; rollup_events
          ; call_data =
              ( match call_data with
              | None ->
                  F.zero
              | Some call_data ->
                  Call_data.to_field call_data )
          ; depth = 0
          }
      ; predicate =
          (let { Predicate.balance
               ; nonce
               ; receipt_chain_hash
               ; public_key
               ; delegate
               ; state
               ; rollup_state
               ; proved_state
               } =
             predicate
           in
           Full
             { balance = Option.value ~default:Or_ignore.Ignore balance
             ; nonce = Option.value ~default:Or_ignore.Ignore nonce
             ; receipt_chain_hash =
                 Option.value ~default:Or_ignore.Ignore receipt_chain_hash
             ; public_key = Option.value ~default:Or_ignore.Ignore public_key
             ; delegate = Option.value ~default:Or_ignore.Ignore delegate
             ; state =
                 Pickles_types.Vector.map
                   ~f:(Option.value ~default:Or_ignore.Ignore)
                   state
             ; rollup_state =
                 Option.value ~default:Or_ignore.Ignore rollup_state
             ; proved_state =
                 Option.value ~default:Or_ignore.Ignore proved_state
             })
      }
    in
    let digest = Party.Predicated.digest data in
    let party : (Party.t, Party.Digest.t) Parties.Party_or_stack.t =
      Party
        ( { data
          ; authorization =
              (match control with Some control -> control | None -> None_given)
          }
        , digest )
    in
    let stack_digest, sub_parties =
      List.fold_left rev_sub_parties ~init:(Parties.Party_or_stack.empty, [])
        ~f:(fun (acc_hash, tl) hd ->
          (* TODO: Not sure this is right.. *)
          (Parties.Party_or_stack.hash_cons digest acc_hash, hd :: tl))
    in
    match sub_parties with
    | [] ->
        party
    | _ :: _ ->
        Parties.Party_or_stack.Stack
          ( party :: sub_parties
          , Parties.Party_or_stack.hash_cons digest stack_digest )
end

include Partial_party

let init ?partial_party () =
  match partial_party with
  | Some partial_party ->
      partial_party
  | None ->
      init ()

let finish ?control t =
  let t =
    match control with
    | None ->
        t
    | Some control -> (
        match t.control with
        | None ->
            { t with control = Some control }
        | Some _ ->
            failwith "Control is already set" )
  in
  (to_party t, t.call_data)
