open Core_kernel
open Currency
open Mina_base
open Mina_numbers
open Signature_lib

type ('ledger, 'location) ledger =
  { t : 'ledger
  ; ops : (module Ledger_intf.S with type t = 'ledger and type location = 'location)
  }

type ('ledger, 'location) common =
  { ledger : ('ledger, 'location) ledger
  ; fee : Fee.t
  ; nonce : Account.Nonce.t
  ; global_slot : Global_slot.t
  }

type ('ledger, 'location) initial =
  { common : ('ledger, 'location) common
  ; fee_payer_id : Account_id.t
  }

type ('ledger, 'location) with_account =
  { common : ('ledger, 'location) common
  ; fee_payer : Account.t
  ; location : 'location
  }

type ('ledger, 'location) account_updated =
  { ledger : ('ledger, 'location) ledger
  ; location : 'location
  ; fee_payer : Account.t 
  }

let fail_unless ~error condition =
  if condition then Ok () else Or_error.error_string error

let init_with_signed_command (type ledger loc)
    ~(ledger_ops : (module Ledger_intf.S with type t = ledger and type location = loc))
    ~(ledger : ledger) ~(global_slot : Global_slot.t) (cmd : Signed_command.t) :
    [> `FP_initial of (ledger, loc) initial ] Or_error.t =
  let open Or_error.Let_syntax in
  let signer_pk = Public_key.compress cmd.signer in
  let fee_payer_id = Signed_command.fee_payer cmd in
  let%bind () =
    fail_unless ~error:"Fee-payer must sign the command"
      (Public_key.Compressed.equal
         (Account_id.public_key fee_payer_id)
         signer_pk )
  in
  let%map () =
    fail_unless ~error:"Fee-payer must be the fee-payer"
      (Token_id.equal (Signed_command.fee_token cmd) Token_id.default)
  in
  `FP_initial
    { common =
        { ledger = { t = ledger; ops = ledger_ops }
        ; fee = Signed_command.fee cmd
        ; nonce = Signed_command.nonce cmd
        ; global_slot
        }
    ; fee_payer_id
    }

let find_account (type ledger loc) (`FP_initial (state : (ledger, loc) initial)) :
    [> `FP_account_found of (ledger, loc) with_account ] Or_error.t =
  let module L = (val state.common.ledger.ops : Ledger_intf.S with type t = ledger and type location = loc) in
  let a =
    let open Option.Let_syntax in
    let%bind location =
      L.location_of_account state.common.ledger.t state.fee_payer_id
    in
    let%map account = L.get state.common.ledger.t location in
    (location, account)
  in
  match a with
  | None ->
      Or_error.error_string "Fee-payer account not found"
  | Some ((location : L.location), fee_payer) ->
     Ok (`FP_account_found
           { common = state.common; fee_payer; location }
       )

let validate_payment (type ledger loc)
    (`FP_account_found (state : (ledger, loc) with_account)) :
    [> `FP_account_updated of (ledger, loc) account_updated ] Or_error.t =
  let open Or_error.Let_syntax in
  let%bind () =
    fail_unless
      ~error:
      "Nonce in account %{sexp: Account.Nonce.t} different from nonce in \
       transaction %{sexp: Account.Nonce.t}"
      (Account.Nonce.equal state.fee_payer.nonce state.common.nonce)
  in
  let%bind balance =
    Balance.sub_amount state.fee_payer.balance (Amount.of_fee state.common.fee)
    |> Option.value_map
         ~default:(Or_error.error_string "Insufficient funds")
         ~f:Or_error.return
  in
  let fee_payer = { state.fee_payer with balance } in
  let%bind () =
    match fee_payer.timing with
    | Untimed ->
       Ok ()
    | Timed
       { initial_minimum_balance
       ; cliff_time
       ; cliff_amount
       ; vesting_period
       ; vesting_increment
       } ->
       let min_balance =
         Account.min_balance_at_slot ~global_slot:state.common.global_slot
           ~cliff_time ~cliff_amount ~vesting_period ~vesting_increment
           ~initial_minimum_balance
       in
       let error =
         sprintf
           !"For timed account, the requested transaction for amount %{sexp: \
             Fee.t} at global slot %{sexp: Global_slot.t}, applying the \
             transaction would put the balance below the calculated minimum \
             balance of %{sexp: Balance.t}"
           state.common.fee state.common.global_slot min_balance
       in
       fail_unless ~error (Balance.( >= ) fee_payer.balance min_balance)
  in
  let%bind () =
    fail_unless ~error:"update not permitted – nonce"
      (Account.has_permission_to_increment_nonce fee_payer)
  in
  let%map () =
    fail_unless ~error:"update not permitted – balance"
      (Account.has_permission_to_send fee_payer)
  in
  `FP_account_updated { ledger = state.common.ledger
                    ; location = state.location
                    ; fee_payer = fee_payer
                    }

let apply (type ledger loc)
      (`FP_account_updated (state : (ledger, loc) account_updated))
    : [> `FP_halted of loc * Account.t ] =
  let module L = (val state.ledger.ops) in
  L.set state.ledger.t state.location state.fee_payer;
  `FP_halted (state.location, state.fee_payer)

