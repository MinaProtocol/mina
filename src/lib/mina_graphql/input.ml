open Core
open Async
open Graphql_async
open Mina_base
open Signature_lib
module Schema = Graphql_wrapper.Make (Schema)
open Schema
open Utils


open Schema.Arg

module NetworkPeer = struct
  type input = Network_peer.Peer.t

  let arg_typ : ((Network_peer.Peer.t, string) result option, _) arg_typ =
    obj "NetworkPeer"
      ~doc:"Network identifiers for another protocol participant"
      ~coerce:(fun peer_id host libp2p_port ->
        try
          Ok
            Network_peer.Peer.
          { peer_id; host = Unix.Inet_addr.of_string host; libp2p_port }
        with _ -> Error "Invalid format for NetworkPeer.host" )
      ~fields:
      [ arg "peer_id" ~doc:"base58-encoded peer ID" ~typ:(non_null string)
      ; arg "host" ~doc:"IP address of the remote host"
          ~typ:(non_null string)
      ; arg "libp2p_port" ~typ:(non_null int)
      ]
      ~split:(fun f (p : input) ->
        f p.peer_id (Unix.Inet_addr.to_string p.host) p.libp2p_port )
end

module PublicKey = struct
  type input = Account.key

  let arg_typ =
    scalar "PublicKey" ~doc:"Base58Check-encoded public key string"
      ~coerce:(fun key ->
        match key with
        | `String s ->
           Result.try_with (fun () ->
               Public_key.of_base58_check_decompress_exn s )
           |> Result.map_error ~f:(fun e -> Exn.to_string e)
        | _ ->
           Error "Invalid format for public key." )
      ~to_json:(function
        | (k : input) -> `String (Public_key.Compressed.to_base58_check k)
      )
end

module PrivateKey = struct
  type input = Signature_lib.Private_key.t

  let arg_typ =
    scalar "PrivateKey" ~doc:"Base58Check-encoded private key"
      ~coerce:Signature_lib.Private_key.of_yojson
      ~to_json:Signature_lib.Private_key.to_yojson
end

module TokenId = struct
  type input = Token_id.t

  let arg_typ =
    scalar "TokenId"
      ~doc:"String representation of a token's UInt64 identifier"
      ~coerce:(fun token ->
        try
          match token with
          | `String token ->
             Ok (Token_id.of_string token)
          | _ ->
             Error "Invalid format for token."
        with _ -> Error "Invalid format for token." )
      ~to_json:(function (i : input) -> `String (Token_id.to_string i))
end

module PrecomputedBlock = struct
  type input = Mina_block.Precomputed.t

  let arg_typ =
    scalar "PrecomputedBlock"
      ~doc:"Block encoded in precomputed block format"
      ~coerce:(fun json ->
        let json = to_yojson json in
        Mina_block.Precomputed.of_yojson json )
      ~to_json:(fun (x : input) ->
        Yojson.Safe.to_basic (Mina_block.Precomputed.to_yojson x) )
end

module ExtensionalBlock = struct
  type input = Archive_lib.Extensional.Block.t

  let arg_typ =
    scalar "ExtensionalBlock"
      ~doc:"Block encoded in extensional block format"
      ~coerce:(fun json ->
        let json = to_yojson json in
        Archive_lib.Extensional.Block.of_yojson json )
      ~to_json:(fun (x : input) ->
        Yojson.Safe.to_basic @@ Archive_lib.Extensional.Block.to_yojson x )
end

module type Numeric_type = sig
  type t

  val to_string : t -> string

  val of_string : string -> t

  val of_int : int -> t

  val to_int : t -> int
end

(** Converts a type into a graphql argument type. Expect name to start with uppercase    *)
let make_numeric_arg (type t) ~name
      (module Numeric : Numeric_type with type t = t) =
  let lower_name = String.lowercase name in
  scalar name
    ~doc:
    (sprintf
       "String or Integer representation of a %s number. If the input is \
        a string, it must represent the number in base 10"
       lower_name )
    ~to_json:(function n -> `String (Numeric.to_string n))
    ~coerce:(fun key ->
      match key with
      | `String s -> (
        try
          let n = Numeric.of_string s in
          let s' = Numeric.to_string n in
          (* Here, we check that the string that was passed converts to
             the numeric type, and that it is in range, by converting
             back to a string and checking that it is equal to the one
             passed. This prevents the following weirdnesses in the
             [Unsigned.UInt*] parsers:
             * if the absolute value is greater than [max_int], the value
             returned is [max_int]
             - ["99999999999999999999999999999999999"] is [max_int]
             - ["-99999999999999999999999999999999999"] is [max_int]
             * if otherwise the value is negative, the value returned is
             [max_int - (x - 1)]
             - ["-1"] is [max_int]
             * if there is a non-numeric character part-way through the
             string, the numeric prefix is treated as a number
             - ["1_000_000"] is [1]
             - ["-1_000_000"] is [max_int]
             - ["1.1"] is [1]
             - ["0x15"] is [0]
             * leading spaces are ignored
             - [" 1"] is [1]
             This is annoying to document, none of these behaviors are
             useful to users, and unexpectedly triggering one of them
             could have nasty consequences. Thus, we raise an error
             rather than silently misinterpreting their input.
           *)
          assert (String.equal s s') ;
          Ok n
        with _ -> Error (sprintf "Could not decode %s." lower_name) )
      | `Int n ->
         if n < 0 then
           Error
             (sprintf "Could not convert negative number to %s." lower_name)
         else Ok (Numeric.of_int n)
      | _ ->
         Error (sprintf "Invalid format for %s type." lower_name) )

module UInt64 = struct
  type input = Unsigned.UInt64.t

  let arg_typ = make_numeric_arg ~name:"UInt64" (module Unsigned.UInt64)
end

module UInt32 = struct
  type input = Unsigned.UInt32.t

  let arg_typ = make_numeric_arg ~name:"UInt32" (module Unsigned.UInt32)
end

module SignatureInput = struct
  open Snark_params.Tick

  type input =
    | Raw of Signature.t
    | Field_and_scalar of Field.t * Inner_curve.Scalar.t

  let arg_typ =
    obj "SignatureInput"
      ~coerce:(fun field scalar rawSignature ->
        match rawSignature with
        | Some signature ->
           Result.of_option
             (Signature.Raw.decode signature)
             ~error:"rawSignature decoding error"
        | None -> (
          match (field, scalar) with
          | Some field, Some scalar ->
             Ok
               ( Field.of_string field
               , Inner_curve.Scalar.of_string scalar )
          | _ ->
             Error "Either field+scalar or rawSignature must by non-null"
      ) )
      ~doc:
      "A cryptographic signature -- you must provide either field+scalar \
       or rawSignature"
      ~fields:
      [ arg "field" ~typ:string ~doc:"Field component of signature"
      ; arg "scalar" ~typ:string ~doc:"Scalar component of signature"
      ; arg "rawSignature" ~typ:string ~doc:"Raw encoded signature"
      ]
      ~split:(fun f (input : input) ->
        match input with
        | Raw (s : Signature.t) ->
           f None None (Some (Signature.Raw.encode s))
        | Field_and_scalar (field, scalar) ->
           f
             (Some (Field.to_string field))
             (Some (Inner_curve.Scalar.to_string scalar))
             None )
end

module VrfMessageInput = struct
  type input = Consensus_vrf.Layout.Message.t

  let arg_typ =
    obj "VrfMessageInput" ~doc:"The inputs to a vrf evaluation"
      ~coerce:(fun global_slot epoch_seed delegator_index ->
        { Consensus_vrf.Layout.Message.global_slot
        ; epoch_seed = Mina_base.Epoch_seed.of_base58_check_exn epoch_seed
        ; delegator_index
      } )
      ~fields:
      [ arg "globalSlot" ~typ:(non_null UInt32.arg_typ)
      ; arg "epochSeed" ~doc:"Formatted with base58check"
          ~typ:(non_null string)
      ; arg "delegatorIndex"
          ~doc:"Position in the ledger of the delegator's account"
          ~typ:(non_null int)
      ]
      ~split:(fun f (t : input) ->
        f t.global_slot
          (Mina_base.Epoch_seed.to_base58_check t.epoch_seed)
          t.delegator_index )
end

module VrfThresholdInput = struct
  type input = Consensus_vrf.Layout.Threshold.t

  let arg_typ =
    obj "VrfThresholdInput"
      ~doc:
      "The amount of stake delegated, used to determine the threshold \
       for a vrf evaluation producing a block"
      ~coerce:(fun delegated_stake total_stake ->
        { Consensus_vrf.Layout.Threshold.delegated_stake =
            Currency.Balance.of_uint64 delegated_stake
        ; total_stake = Currency.Amount.of_uint64 total_stake
      } )
      ~fields:
      [ arg "delegatedStake"
          ~doc:
          "The amount of stake delegated to the vrf evaluator by the \
           delegating account. This should match the amount in the \
           epoch's staking ledger, which may be different to the \
           amount in the current ledger."
          ~typ:(non_null UInt64.arg_typ)
      ; arg "totalStake"
          ~doc:
          "The total amount of stake across all accounts in the \
           epoch's staking ledger."
          ~typ:(non_null UInt64.arg_typ)
      ]
      ~split:(fun f (t : input) ->
        f
          (Currency.Balance.to_uint64 t.delegated_stake)
          (Currency.Amount.to_uint64 t.total_stake) )
end

module VrfEvaluationInput = struct
  type input = Consensus_vrf.Layout.Evaluation.t

  let arg_typ =
    obj "VrfEvaluationInput" ~doc:"The witness to a vrf evaluation"
      ~coerce:(fun message public_key c s scaled_message_hash vrf_threshold ->
        { Consensus_vrf.Layout.Evaluation.message
        ; public_key = Public_key.decompress_exn public_key
        ; c = Snark_params.Tick.Inner_curve.Scalar.of_string c
        ; s = Snark_params.Tick.Inner_curve.Scalar.of_string s
        ; scaled_message_hash =
            Consensus_vrf.Group.of_string_list_exn scaled_message_hash
        ; vrf_threshold
        ; vrf_output = None
        ; vrf_output_fractional = None
        ; threshold_met = None
      } )
      ~split:(fun f (x : input) ->
        f x.message
          (Public_key.compress x.public_key)
          (Snark_params.Tick.Inner_curve.Scalar.to_string x.c)
          (Snark_params.Tick.Inner_curve.Scalar.to_string x.s)
          (Consensus_vrf.Group.to_string_list_exn x.scaled_message_hash)
          x.vrf_threshold )
      ~fields:
      [ arg "message" ~typ:(non_null VrfMessageInput.arg_typ)
      ; arg "publicKey" ~typ:(non_null PublicKey.arg_typ)
      ; arg "c" ~typ:(non_null string)
      ; arg "s" ~typ:(non_null string)
      ; arg "scaledMessageHash" ~typ:(non_null (list (non_null string)))
      ; arg "vrfThreshold" ~typ:VrfThresholdInput.arg_typ
      ]
end

module Fields = struct
  let from ~doc = arg "from" ~typ:(non_null PublicKey.arg_typ) ~doc

  let to_ ~doc = arg "to" ~typ:(non_null PublicKey.arg_typ) ~doc

  let token ~doc = arg "token" ~typ:(non_null TokenId.arg_typ) ~doc

  let token_opt ~doc = arg "token" ~typ:TokenId.arg_typ ~doc

  let token_owner ~doc =
    arg "tokenOwner" ~typ:(non_null PublicKey.arg_typ) ~doc

  let receiver ~doc = arg "receiver" ~typ:(non_null PublicKey.arg_typ) ~doc

  let receiver_opt ~doc = arg "receiver" ~typ:PublicKey.arg_typ ~doc

  let fee_payer_opt ~doc = arg "feePayer" ~typ:PublicKey.arg_typ ~doc

  let fee ~doc = arg "fee" ~typ:(non_null UInt64.arg_typ) ~doc

  let amount ~doc = arg "amount" ~typ:(non_null UInt64.arg_typ) ~doc

  let memo =
    arg "memo" ~typ:string
      ~doc:"Short arbitrary message provided by the sender"

  let valid_until =
    arg "validUntil" ~typ:UInt32.arg_typ
      ~doc:
      "The global slot number after which this transaction cannot be \
       applied"

  let nonce =
    arg "nonce" ~typ:UInt32.arg_typ
      ~doc:
      "Should only be set when cancelling transactions, otherwise a \
       nonce is determined automatically"

  let signature =
    arg "signature" ~typ:SignatureInput.arg_typ
      ~doc:
      "If a signature is provided, this transaction is considered signed \
       and will be broadcasted to the network without requiring a \
       private key"

  let senders =
    arg "senders"
      ~typ:(non_null (list (non_null PrivateKey.arg_typ)))
      ~doc:"The private keys from which to sign the payments"

  let repeat_count =
    arg "repeat_count" ~typ:(non_null UInt32.arg_typ)
      ~doc:"How many times shall transaction be repeated"

  let repeat_delay_ms =
    arg "repeat_delay_ms" ~typ:(non_null UInt32.arg_typ)
      ~doc:"Delay with which a transaction shall be repeated"
end

module SendPaymentInput = struct
  type input =
    { from : (Epoch_seed.t, bool) Public_key.Compressed.Poly.t
    ; to_ : Account.key
    ; amount : Currency.Amount.t
    ; token : Token_id.t option
    ; fee : Currency.Fee.t
    ; valid_until : Unsigned.uint32 option
    ; memo : string option
    ; nonce : Unsigned.uint32 option
    }
      [@@deriving make]

  let arg_typ =
    let open Fields in
    obj "SendPaymentInput"
      ~coerce:(fun from to_ token amount fee valid_until memo nonce ->
        (from, to_, token, amount, fee, valid_until, memo, nonce) )
      ~split:(fun f (x : input) ->
        f x.from x.to_ x.token
          (Currency.Amount.to_uint64 x.amount)
          (Currency.Fee.to_uint64 x.fee)
          x.valid_until x.memo x.nonce )
      ~fields:
      [ from ~doc:"Public key of sender of payment"
      ; to_ ~doc:"Public key of recipient of payment"
      ; token_opt ~doc:"Token to send"
      ; amount ~doc:"Amount of mina to send to receiver"
      ; fee ~doc:"Fee amount in order to send payment"
      ; valid_until
      ; memo
      ; nonce
      ]
end

module SendDelegationInput = struct
  type input =
    { from : PublicKey.input
    ; to_ : PublicKey.input
    ; fee : Currency.Fee.t
    ; valid_until : UInt32.input option
    ; memo : string option
    ; nonce : UInt32.input option
    }
      [@@deriving make]

  let arg_typ =
    let open Fields in
    obj "SendDelegationInput"
      ~coerce:(fun from to_ fee valid_until memo nonce ->
        (from, to_, fee, valid_until, memo, nonce) )
      ~split:(fun f (x : input) ->
        f x.from x.to_
          (Currency.Fee.to_uint64 x.fee)
          x.valid_until x.memo x.nonce )
      ~fields:
      [ from ~doc:"Public key of sender of a stake delegation"
      ; to_ ~doc:"Public key of the account being delegated to"
      ; fee ~doc:"Fee amount in order to send a stake delegation"
      ; valid_until
      ; memo
      ; nonce
      ]
end

module SendCreateTokenInput = struct
  type input =
    { fee_payer : PublicKey.input option
    ; token_owner : PublicKey.input
    ; fee : UInt64.input
    ; valid_until : UInt32.input option
    ; memo : string option
    ; nonce : UInt32.input option
    }
      [@@deriving make]

  let arg_typ =
    let open Fields in
    obj "SendCreateTokenInput"
      ~coerce:(fun fee_payer token_owner fee valid_until memo nonce ->
        (fee_payer, token_owner, fee, valid_until, memo, nonce) )
      ~split:(fun f (x : input) ->
        f x.fee_payer x.token_owner x.fee x.valid_until x.memo x.nonce )
      ~fields:
      [ fee_payer_opt
          ~doc:
          "Public key to pay the fee from (defaults to the tokenOwner)"
      ; token_owner ~doc:"Public key to create the token for"
      ; fee ~doc:"Fee amount in order to create a token"
      ; valid_until
      ; memo
      ; nonce
      ]
end

module SendCreateTokenAccountInput = struct
  type input =
    { token_owner : PublicKey.input
    ; token : TokenId.input
    ; receiver : PublicKey.input
    ; fee : UInt64.input
    ; fee_payer : PublicKey.input option
    ; valid_until : UInt32.input option
    ; memo : string option
    ; nonce : UInt32.input option
    }
      [@@deriving make]

  let arg_typ =
    let open Fields in
    obj "SendCreateTokenAccountInput"
      ~coerce:(fun token_owner token receiver fee fee_payer valid_until memo
                   nonce ->
        ( token_owner
        , token
        , receiver
        , fee
        , fee_payer
        , valid_until
        , memo
        , nonce ) )
      ~split:(fun f (x : input) ->
        f x.token_owner x.token x.receiver x.fee x.fee_payer x.valid_until
          x.memo x.nonce )
      ~fields:
      [ token_owner ~doc:"Public key of the token's owner"
      ; token ~doc:"Token to create an account for"
      ; receiver ~doc:"Public key to create the account for"
      ; fee ~doc:"Fee amount in order to create a token account"
      ; fee_payer_opt
          ~doc:
          "Public key to pay the fees from and sign the transaction \
           with (defaults to the receiver)"
      ; valid_until
      ; memo
      ; nonce
      ]
end

module SendMintTokensInput = struct
  type input =
    { token_owner : PublicKey.input
    ; token : TokenId.input
    ; receiver : PublicKey.input option
    ; amount : UInt64.input
    ; fee : UInt64.input
    ; valid_until : UInt32.input option
    ; memo : string option
    ; nonce : UInt32.input option
    }
      [@@deriving make]

  let arg_typ =
    let open Fields in
    obj "SendMintTokensInput"
      ~coerce:(fun token_owner token receiver amount fee valid_until memo
                   nonce ->
        (token_owner, token, receiver, amount, fee, valid_until, memo, nonce)
      )
      ~split:(fun f (x : input) ->
        f x.token_owner x.token x.receiver x.amount x.fee x.valid_until
          x.memo x.nonce )
      ~fields:
      [ token_owner ~doc:"Public key of the token's owner"
      ; token ~doc:"Token to mint more of"
      ; receiver_opt
          ~doc:
          "Public key to mint the new tokens for (defaults to token \
           owner's account)"
      ; arg "amount"
          ~doc:"Amount of token to create in the receiver's account"
          ~typ:(non_null UInt64.arg_typ)
      ; fee ~doc:"Fee amount in order to mint tokens"
      ; valid_until
      ; memo
      ; nonce
      ]
end

module RosettaTransaction = struct
  type input = Yojson.Basic.t

  let arg_typ =
    Schema.Arg.scalar "RosettaTransaction"
      ~doc:"A transaction encoded in the rosetta format"
      ~coerce:(fun graphql_json ->
        Rosetta_lib.Transaction.to_mina_signed (to_yojson graphql_json)
        |> Result.map_error ~f:Error.to_string_hum )
      ~to_json:Fn.id
end

module AddAccountInput = struct
  type input = string

  let arg_typ =
    obj "AddAccountInput" ~coerce:Fn.id
      ~fields:
      [ arg "password" ~doc:"Password used to encrypt the new account"
          ~typ:(non_null string)
      ]
      ~split:Fn.id
end

module UnlockInput = struct
  type input = Bytes.t * PublicKey.input

  let arg_typ =
    obj "UnlockInput"
      ~coerce:(fun password pk -> (password, pk))
      ~fields:
      [ arg "password" ~doc:"Password for the account to be unlocked"
          ~typ:(non_null string)
      ; arg "publicKey"
          ~doc:"Public key specifying which account to unlock"
          ~typ:(non_null PublicKey.arg_typ)
      ]
      ~split:(fun f ((password, pk) : input) ->
        f (Bytes.to_string password) pk )
end

module CreateHDAccountInput = struct
  type input = UInt32.input

  let arg_typ =
    obj "CreateHDAccountInput" ~coerce:Fn.id
      ~fields:
      [ arg "index" ~doc:"Index of the account in hardware wallet"
          ~typ:(non_null UInt32.arg_typ)
      ]
      ~split:Fn.id
end

module LockInput = struct
  type input = PublicKey.input

  let arg_typ =
    obj "LockInput" ~coerce:Fn.id
      ~fields:
      [ arg "publicKey" ~doc:"Public key specifying which account to lock"
          ~typ:(non_null PublicKey.arg_typ)
      ]
      ~split:Fn.id
end

module DeleteAccountInput = struct
  type input = PublicKey.input

  let arg_typ =
    obj "DeleteAccountInput" ~coerce:Fn.id
      ~fields:
      [ arg "publicKey" ~doc:"Public key of account to be deleted"
          ~typ:(non_null PublicKey.arg_typ)
      ]
      ~split:Fn.id
end

module ResetTrustStatusInput = struct
  type input = string

  let arg_typ =
    obj "ResetTrustStatusInput" ~coerce:Fn.id
      ~fields:[ arg "ipAddress" ~typ:(non_null string) ]
      ~split:Fn.id
end

module BlockFilterInput = struct
  type input = PublicKey.input

  (* TODO: Treat cases where filter_input has a null argument *)
  let arg_typ =
    obj "BlockFilterInput" ~coerce:Fn.id ~split:Fn.id
      ~fields:
      [ arg "relatedTo"
          ~doc:
          "A public key of a user who has their\n\
           \        transaction in the block, or produced the block"
          ~typ:(non_null PublicKey.arg_typ)
      ]
end

module UserCommandFilterType = struct
  type input = PublicKey.input

  let arg_typ =
    obj "UserCommandFilterType" ~coerce:Fn.id ~split:Fn.id
      ~fields:
      [ arg "toOrFrom"
          ~doc:
          "Public key of sender or receiver of transactions you are \
           looking for"
          ~typ:(non_null PublicKey.arg_typ)
      ]
end

module SetCoinbaseReceiverInput = struct
  type input = PublicKey.input option

  let arg_typ =
    obj "SetCoinbaseReceiverInput" ~coerce:Fn.id ~split:Fn.id
      ~fields:
      [ arg "publicKey" ~typ:PublicKey.arg_typ
          ~doc:
          "Public key of the account to receive coinbases. Block \
           production keys will receive the coinbases if none is given"
      ]
end

module SetSnarkWorkFee = struct
  type input = UInt64.input

  let arg_typ =
    obj "SetSnarkWorkFee"
      ~fields:
      [ Fields.fee ~doc:"Fee to get rewarded for producing snark work" ]
      ~coerce:Fn.id ~split:Fn.id
end

module SetSnarkWorkerInput = struct
  type input = PublicKey.input option

  let arg_typ =
    obj "SetSnarkWorkerInput" ~coerce:Fn.id ~split:Fn.id
      ~fields:
      [ arg "publicKey" ~typ:PublicKey.arg_typ
          ~doc:
          "Public key you wish to start snark-working on; null to stop \
           doing any snark work"
      ]
end

module AddPaymentReceiptInput = struct
  type input = { payment : string; added_time : string }

  let arg_typ =
    obj "AddPaymentReceiptInput"
      ~coerce:(fun payment added_time -> { payment; added_time })
      ~split:(fun f (t : input) -> f t.payment t.added_time)
      ~fields:
      [ arg "payment"
          ~doc:(Doc.bin_prot "Serialized payment")
          ~typ:(non_null string)
      ; (* TODO: create a formal method for verifying that the provided added_time is correct  *)
        arg "added_time" ~typ:(non_null string)
          ~doc:
          (Doc.date
             "Time that a payment gets added to another clients \
              transaction database" )
      ]
end

module SetConnectionGatingConfigInput = struct
  type input = Mina_net2.connection_gating

  let arg_typ =
    obj "SetConnectionGatingConfigInput"
      ~coerce:(fun trusted_peers banned_peers isolate ->
        let open Result.Let_syntax in
        let%bind trusted_peers = Result.all trusted_peers in
        let%map banned_peers = Result.all banned_peers in
        Mina_net2.{ isolate; trusted_peers; banned_peers } )
      ~split:(fun f (t : input) ->
        f t.trusted_peers t.banned_peers t.isolate )
      ~fields:
      Arg.
    [ arg "trustedPeers"
        ~typ:(non_null (list (non_null NetworkPeer.arg_typ)))
        ~doc:"Peers we will always allow connections from"
    ; arg "bannedPeers"
        ~typ:(non_null (list (non_null NetworkPeer.arg_typ)))
        ~doc:
        "Peers we will never allow connections from (unless they \
         are also trusted!)"
    ; arg "isolate" ~typ:(non_null bool)
        ~doc:
        "If true, no connections will be allowed unless they are \
         from a trusted peer"
    ]
end
