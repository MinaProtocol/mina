open Core
open Graphql_async
open Mina_base
module Schema = Graphql_wrapper.Make (Schema)
open Schema

include struct
  open Graphql_lib.Scalars

  let public_key = PublicKey.typ ()

  let uint64 = UInt64.typ ()

  let uint32 = UInt32.typ ()

  let token_id = TokenId.typ ()

  let json : (Mina_lib.t, Yojson.Basic.t option) typ = JSON.typ ()

                                                                (* let epoch_seed = EpochSeed.typ () *)
end
let kind :
      ( 'context
      , [< `Payment
        | `Stake_delegation
        | `Create_new_token
        | `Create_token_account
        | `Mint_tokens ]
          option )
        typ =
  scalar "UserCommandKind" ~doc:"The kind of user command" ~coerce:(function
      | `Payment ->
         `String "PAYMENT"
      | `Stake_delegation ->
         `String "STAKE_DELEGATION"
      | `Create_new_token ->
         `String "CREATE_NEW_TOKEN"
      | `Create_token_account ->
         `String "CREATE_TOKEN_ACCOUNT"
      | `Mint_tokens ->
         `String "MINT_TOKENS" )

let to_kind (t : Signed_command.t) =
  match Signed_command.payload t |> Signed_command_payload.body with
  | Payment _ ->
     `Payment
  | Stake_delegation _ ->
     `Stake_delegation
  | Create_new_token _ ->
     `Create_new_token
  | Create_token_account _ ->
     `Create_token_account
  | Mint_tokens _ ->
     `Mint_tokens

let user_command_interface :
      ( 'context
      , ( 'context
        , (Signed_command.t, Transaction_hash.t) With_hash.t )
          abstract_value
          option )
        typ =
  interface "UserCommand" ~doc:"Common interface for user commands"
    ~fields:(fun _ ->
      [ abstract_field "id" ~typ:(non_null guid) ~args:[]
      ; abstract_field "hash" ~typ:(non_null string) ~args:[]
      ; abstract_field "kind" ~typ:(non_null kind) ~args:[]
          ~doc:"String describing the kind of user command"
      ; abstract_field "nonce" ~typ:(non_null int) ~args:[]
          ~doc:"Sequence number of command for the fee-payer's account"
      ; abstract_field "source"
          ~typ:(non_null AccountObj.account)
          ~args:[] ~doc:"Account that the command is sent from"
      ; abstract_field "receiver"
          ~typ:(non_null AccountObj.account)
          ~args:[] ~doc:"Account that the command applies to"
      ; abstract_field "feePayer"
          ~typ:(non_null AccountObj.account)
          ~args:[] ~doc:"Account that pays the fees for the command"
      ; abstract_field "validUntil" ~typ:(non_null uint32) ~args:[]
          ~doc:
          "The global slot number after which this transaction cannot be \
           applied"
      ; abstract_field "token" ~typ:(non_null token_id) ~args:[]
          ~doc:"Token used by the command"
      ; abstract_field "amount" ~typ:(non_null uint64) ~args:[]
          ~doc:
          "Amount that the source is sending to receiver - 0 for \
           commands that are not associated with an amount"
      ; abstract_field "feeToken" ~typ:(non_null token_id) ~args:[]
          ~doc:"Token used to pay the fee"
      ; abstract_field "fee" ~typ:(non_null uint64) ~args:[]
          ~doc:
          "Fee that the fee-payer is willing to pay for making the \
           transaction"
      ; abstract_field "memo" ~typ:(non_null string) ~args:[]
          ~doc:"Short arbitrary message provided by the sender"
      ; abstract_field "isDelegation" ~typ:(non_null bool) ~args:[]
          ~doc:
          "If true, this represents a delegation of stake, otherwise it \
           is a payment"
          ~deprecated:(Deprecated (Some "use kind field instead"))
      ; abstract_field "from" ~typ:(non_null public_key) ~args:[]
          ~doc:"Public key of the sender"
          ~deprecated:(Deprecated (Some "use feePayer field instead"))
      ; abstract_field "fromAccount"
          ~typ:(non_null AccountObj.account)
          ~args:[] ~doc:"Account of the sender"
          ~deprecated:(Deprecated (Some "use feePayer field instead"))
      ; abstract_field "to" ~typ:(non_null public_key) ~args:[]
          ~doc:"Public key of the receiver"
          ~deprecated:(Deprecated (Some "use receiver field instead"))
      ; abstract_field "toAccount"
          ~typ:(non_null AccountObj.account)
          ~args:[] ~doc:"Account of the receiver"
          ~deprecated:(Deprecated (Some "use receiver field instead"))
      ; abstract_field "failureReason" ~typ:string ~args:[]
          ~doc:"null is no failure, reason for failure otherwise."
    ] )

module Status = struct
  type t =
    | Applied
    | Included_but_failed of Transaction_status.Failure.t
    | Unknown
end

module With_status = struct
  type 'a t = { data : 'a; status : Status.t }

  let map t ~f = { t with data = f t.data }
end

let field_no_status ?doc ?deprecated lab ~typ ~args ~resolve =
  field ?doc ?deprecated lab ~typ ~args ~resolve:(fun c uc ->
      resolve c uc.With_status.data )

let user_command_shared_fields :
      ( Mina_lib.t
      , (Signed_command.t, Transaction_hash.t) With_hash.t With_status.t )
        field
        list =
  [ field_no_status "id" ~typ:(non_null guid) ~args:[]
      ~resolve:(fun _ user_command ->
        Signed_command.to_base58_check user_command.With_hash.data )
  ; field_no_status "hash" ~typ:(non_null string) ~args:[]
      ~resolve:(fun _ user_command ->
        Transaction_hash.to_base58_check user_command.With_hash.hash )
  ; field_no_status "kind" ~typ:(non_null kind) ~args:[]
      ~doc:"String describing the kind of user command"
      ~resolve:(fun _ cmd -> to_kind cmd.With_hash.data)
  ; field_no_status "nonce" ~typ:(non_null int) ~args:[]
      ~doc:"Sequence number of command for the fee-payer's account"
      ~resolve:(fun _ payment ->
        Signed_command_payload.nonce
        @@ Signed_command.payload payment.With_hash.data
        |> Account.Nonce.to_int )
  ; field_no_status "source" ~typ:(non_null AccountObj.account)
      ~args:[] ~doc:"Account that the command is sent from"
      ~resolve:(fun { ctx = coda; _ } cmd ->
        AccountObj.get_best_ledger_account coda
          (Signed_command.source ~next_available_token:Token_id.invalid
             cmd.With_hash.data ) )
  ; field_no_status "receiver" ~typ:(non_null AccountObj.account)
      ~args:[] ~doc:"Account that the command applies to"
      ~resolve:(fun { ctx = coda; _ } cmd ->
        AccountObj.get_best_ledger_account coda
          (Signed_command.receiver ~next_available_token:Token_id.invalid
             cmd.With_hash.data ) )
  ; field_no_status "feePayer" ~typ:(non_null AccountObj.account)
      ~args:[] ~doc:"Account that pays the fees for the command"
      ~resolve:(fun { ctx = coda; _ } cmd ->
        AccountObj.get_best_ledger_account coda
          (Signed_command.fee_payer cmd.With_hash.data) )
  ; field_no_status "validUntil" ~typ:(non_null uint32) ~args:[]
      ~doc:
      "The global slot number after which this transaction cannot be \
       applied" ~resolve:(fun _ cmd ->
        Signed_command.valid_until cmd.With_hash.data )
  ; field_no_status "token" ~typ:(non_null token_id) ~args:[]
      ~doc:"Token used for the transaction" ~resolve:(fun _ cmd ->
        Signed_command.token cmd.With_hash.data )
  ; field_no_status "amount" ~typ:(non_null uint64) ~args:[]
      ~doc:
      "Amount that the source is sending to receiver; 0 for commands \
       without an associated amount" ~resolve:(fun _ cmd ->
        match Signed_command.amount cmd.With_hash.data with
        | Some amount ->
           Currency.Amount.to_uint64 amount
        | None ->
           Unsigned.UInt64.zero )
  ; field_no_status "feeToken" ~typ:(non_null token_id) ~args:[]
      ~doc:"Token used to pay the fee" ~resolve:(fun _ cmd ->
        Signed_command.fee_token cmd.With_hash.data )
  ; field_no_status "fee" ~typ:(non_null uint64) ~args:[]
      ~doc:
      "Fee that the fee-payer is willing to pay for making the \
       transaction" ~resolve:(fun _ cmd ->
        Signed_command.fee cmd.With_hash.data |> Currency.Fee.to_uint64 )
  ; field_no_status "memo" ~typ:(non_null string) ~args:[]
      ~doc:
      (sprintf
         "A short message from the sender, encoded with Base58Check, \
          version byte=0x%02X; byte 2 of the decoding is the message \
          length"
         (Char.to_int Base58_check.Version_bytes.user_command_memo) )
      ~resolve:(fun _ payment ->
        Signed_command_payload.memo
        @@ Signed_command.payload payment.With_hash.data
        |> Signed_command_memo.to_base58_check )
  ; field_no_status "isDelegation" ~typ:(non_null bool) ~args:[]
      ~doc:"If true, this command represents a delegation of stake"
      ~deprecated:(Deprecated (Some "use kind field instead"))
      ~resolve:(fun _ user_command ->
        match
          Signed_command.Payload.body
          @@ Signed_command.payload user_command.With_hash.data
        with
        | Stake_delegation _ ->
           true
        | _ ->
           false )
  ; field_no_status "from" ~typ:(non_null public_key) ~args:[]
      ~doc:"Public key of the sender"
      ~deprecated:(Deprecated (Some "use feePayer field instead"))
      ~resolve:(fun _ cmd -> Signed_command.fee_payer_pk cmd.With_hash.data)
  ; field_no_status "fromAccount" ~typ:(non_null AccountObj.account)
      ~args:[] ~doc:"Account of the sender"
      ~deprecated:(Deprecated (Some "use feePayer field instead"))
      ~resolve:(fun { ctx = coda; _ } payment ->
        AccountObj.get_best_ledger_account coda
        @@ Signed_command.fee_payer payment.With_hash.data )
  ; field_no_status "to" ~typ:(non_null public_key) ~args:[]
      ~doc:"Public key of the receiver"
      ~deprecated:(Deprecated (Some "use receiver field instead"))
      ~resolve:(fun _ cmd -> Signed_command.receiver_pk cmd.With_hash.data)
  ; field_no_status "toAccount"
      ~typ:(non_null AccountObj.account)
      ~doc:"Account of the receiver"
      ~deprecated:(Deprecated (Some "use receiver field instead"))
      ~args:Arg.[]
      ~resolve:(fun { ctx = coda; _ } cmd ->
        AccountObj.get_best_ledger_account coda
        @@ Signed_command.receiver ~next_available_token:Token_id.invalid
             cmd.With_hash.data )
  ; field "failureReason" ~typ:string ~args:[]
      ~doc:
      "null is no failure or status unknown, reason for failure \
       otherwise." ~resolve:(fun _ uc ->
        match uc.With_status.status with
        | Applied | Unknown ->
           None
        | Included_but_failed failure ->
           Some (Transaction_status.Failure.to_string failure) )
  ]

let payment =
  obj "UserCommandPayment" ~fields:(fun _ -> user_command_shared_fields)

let mk_payment = add_type user_command_interface payment

let stake_delegation =
  obj "UserCommandDelegation" ~fields:(fun _ ->
      field_no_status "delegator" ~typ:(non_null AccountObj.account)
        ~args:[] ~resolve:(fun { ctx = coda; _ } cmd ->
          AccountObj.get_best_ledger_account coda
            (Signed_command.source ~next_available_token:Token_id.invalid
               cmd.With_hash.data ) )
      :: field_no_status "delegatee" ~typ:(non_null AccountObj.account)
           ~args:[] ~resolve:(fun { ctx = coda; _ } cmd ->
             AccountObj.get_best_ledger_account coda
               (Signed_command.receiver
                  ~next_available_token:Token_id.invalid cmd.With_hash.data ) )
      :: user_command_shared_fields )

let mk_stake_delegation = add_type user_command_interface stake_delegation

let create_new_token =
  obj "UserCommandNewToken" ~fields:(fun _ ->
      field_no_status "tokenOwner" ~typ:(non_null public_key) ~args:[]
        ~doc:"Public key to set as the owner of the new token"
        ~resolve:(fun _ cmd -> Signed_command.source_pk cmd.With_hash.data)
      :: field_no_status "newAccountsDisabled" ~typ:(non_null bool) ~args:[]
           ~doc:"Whether new accounts created in this token are disabled"
           ~resolve:(fun _ cmd ->
             match
               Signed_command_payload.body
               @@ Signed_command.payload cmd.With_hash.data
             with
             | Create_new_token { disable_new_accounts; _ } ->
                disable_new_accounts
             | _ ->
                (* We cannot exclude this at the type level. *)
                failwith
                  "Type error: Expected a Create_new_token user command" )
      :: user_command_shared_fields )

let mk_create_new_token = add_type user_command_interface create_new_token

let create_token_account =
  obj "UserCommandNewAccount" ~fields:(fun _ ->
      field_no_status "tokenOwner" ~typ:(non_null AccountObj.account)
        ~args:[] ~doc:"The account that owns the token for the new account"
        ~resolve:(fun { ctx = coda; _ } cmd ->
          AccountObj.get_best_ledger_account coda
            (Signed_command.source ~next_available_token:Token_id.invalid
               cmd.With_hash.data ) )
      :: field_no_status "disabled" ~typ:(non_null bool) ~args:[]
           ~doc:
           "Whether this account should be disabled upon creation. If \
            this command was not issued by the token owner, it should \
            match the 'newAccountsDisabled' property set in the token \
            owner's account." ~resolve:(fun _ cmd ->
             match
               Signed_command_payload.body
               @@ Signed_command.payload cmd.With_hash.data
             with
             | Create_token_account { account_disabled; _ } ->
                account_disabled
             | _ ->
                (* We cannot exclude this at the type level. *)
                failwith
                  "Type error: Expected a Create_new_token user command" )
      :: user_command_shared_fields )

let mk_create_token_account =
  add_type user_command_interface create_token_account

let mint_tokens =
  obj "UserCommandMintTokens" ~fields:(fun _ ->
      field_no_status "tokenOwner" ~typ:(non_null AccountObj.account)
        ~args:[] ~doc:"The account that owns the token to mint"
        ~resolve:(fun { ctx = coda; _ } cmd ->
          AccountObj.get_best_ledger_account coda
            (Signed_command.source ~next_available_token:Token_id.invalid
               cmd.With_hash.data ) )
      :: user_command_shared_fields )

let mk_mint_tokens = add_type user_command_interface mint_tokens

let mk_user_command
      (cmd : (Signed_command.t, Transaction_hash.t) With_hash.t With_status.t)
  =
  match
    Signed_command_payload.body @@ Signed_command.payload cmd.data.data
  with
  | Payment _ ->
     mk_payment cmd
  | Stake_delegation _ ->
     mk_stake_delegation cmd
  | Create_new_token _ ->
     mk_create_new_token cmd
  | Create_token_account _ ->
     mk_create_token_account cmd
  | Mint_tokens _ ->
     mk_mint_tokens cmd
