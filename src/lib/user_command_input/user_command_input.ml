open Coda_base
open Signature_lib
open Coda_numbers
open Core_kernel
open Async_kernel

module Payload = struct
  module Common = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          ( Currency.Fee.Stable.V1.t
          , Public_key.Compressed.Stable.V1.t
          , Token_id.Stable.V1.t
          , Account_nonce.Stable.V1.t option
          , Global_slot.Stable.V1.t
          , User_command_memo.Stable.V1.t )
          User_command_payload.Common.Poly.Stable.V1.t
        [@@deriving sexp, to_yojson]

        let to_latest = Fn.id
      end
    end]

    let create ~fee ~fee_token ~fee_payer_pk ?nonce ~valid_until ~memo : t =
      {fee; fee_token; fee_payer_pk; nonce; valid_until; memo}

    let to_user_command_common (t : t) ~inferred_nonce :
        (User_command_payload.Common.t, string) Result.t =
      let open Result.Let_syntax in
      let%map () =
        match t.nonce with
        | None ->
            (*User did not provide a nonce, use inferred*)
            Ok ()
        | Some nonce ->
            if Account_nonce.equal inferred_nonce nonce then Ok ()
            else
              Error
                (sprintf
                   !"Input nonce %s different from inferred nonce %s"
                   (Account_nonce.to_string nonce)
                   (Account_nonce.to_string inferred_nonce))
      in
      { User_command_payload.Common.Poly.fee= t.fee
      ; fee_token= t.fee_token
      ; fee_payer_pk= t.fee_payer_pk
      ; nonce= inferred_nonce
      ; valid_until= t.valid_until
      ; memo= t.memo }

    let fee_payer ({fee_token; fee_payer_pk; _} : t) =
      Account_id.create fee_payer_pk fee_token
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        ( Common.Stable.V1.t
        , User_command_payload.Body.Stable.V1.t )
        User_command_payload.Poly.Stable.V1.t
      [@@deriving sexp, to_yojson]

      let to_latest = Fn.id
    end
  end]

  let create ~fee ~fee_token ~fee_payer_pk ?nonce ~valid_until ~memo ~body : t
      =
    { common=
        Common.create ~fee ~fee_token ~fee_payer_pk ?nonce ~valid_until ~memo
    ; body }

  let to_user_command_payload (t : t) ~inferred_nonce :
      (User_command_payload.t, string) Result.t =
    let open Result.Let_syntax in
    let%map common = Common.to_user_command_common t.common ~inferred_nonce in
    {User_command_payload.Poly.common; body= t.body}

  let fee_payer ({common; _} : t) = Common.fee_payer common
end

module Sign_choice = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        | Signature of Signature.Stable.V1.t
        | Hd_index of Unsigned_extended.UInt32.Stable.V1.t
        | Keypair of Keypair.Stable.V1.t
      [@@deriving sexp, to_yojson]

      let to_latest = Fn.id
    end
  end]
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      ( Payload.Stable.V1.t
      , Public_key.Compressed.Stable.V1.t
      , Sign_choice.Stable.V1.t )
      User_command.Poly.Stable.V1.t
    [@@deriving sexp, to_yojson]

    let to_latest = Fn.id
  end
end]

[%%define_locally
Stable.Latest.(to_yojson)]

let fee_payer ({payload; _} : t) = Payload.fee_payer payload

let create ?nonce ~fee ~fee_token ~fee_payer_pk ~valid_until ~memo ~body
    ~signer ~sign_choice () : t =
  let valid_until = Option.value valid_until ~default:Global_slot.max_value in
  let payload =
    Payload.create ~fee ~fee_token ~fee_payer_pk ?nonce ~valid_until ~memo
      ~body
  in
  {payload; signer; signature= sign_choice}

let sign ~signer ~(user_command_payload : User_command_payload.t) = function
  | Sign_choice.Signature signature ->
      Option.value_map
        ~default:(Deferred.return (Error "Invalid_signature"))
        (User_command.create_with_signature_checked signature signer
           user_command_payload)
        ~f:Deferred.Result.return
  | Keypair signer_kp ->
      Deferred.Result.return (User_command.sign signer_kp user_command_payload)
  | Hd_index hd_index ->
      Secrets.Hardware_wallets.sign ~hd_index
        ~public_key:(Public_key.decompress_exn signer)
        ~user_command_payload

let inferred_nonce ~get_current_nonce ~(fee_payer : Account_id.t) ~nonce_map =
  let open Result.Let_syntax in
  let update_map = Map.set nonce_map ~key:fee_payer in
  match Map.find nonce_map fee_payer with
  | Some nonce ->
      (* Multiple user commands from the same fee-payer. *)
      let next_nonce = Account_nonce.succ nonce in
      let updated_map = update_map ~data:next_nonce in
      Ok (next_nonce, updated_map)
  | None ->
      let%map txn_pool_or_account_nonce = get_current_nonce fee_payer in
      let updated_map = update_map ~data:txn_pool_or_account_nonce in
      (txn_pool_or_account_nonce, updated_map)

let to_user_command ?(nonce_map = Account_id.Map.empty) ~get_current_nonce
    (client_input : t) =
  Deferred.map
    ~f:
      (Result.map_error ~f:(fun str ->
           Error.createf "Error creating user command: %s Error: %s"
             (Yojson.Safe.to_string (to_yojson client_input))
             str ))
  @@
  let open Deferred.Result.Let_syntax in
  let fee_payer = fee_payer client_input in
  let%bind inferred_nonce, updated_nonce_map =
    inferred_nonce ~get_current_nonce ~fee_payer ~nonce_map |> Deferred.return
  in
  let%bind user_command_payload =
    Payload.to_user_command_payload client_input.payload ~inferred_nonce
    |> Deferred.return
  in
  let%map signed_user_command =
    sign ~signer:client_input.signer ~user_command_payload
      client_input.signature
  in
  (User_command.forget_check signed_user_command, updated_nonce_map)

let to_user_commands ?(nonce_map = Account_id.Map.empty) ~get_current_nonce
    uc_inputs : User_command.t list Deferred.Or_error.t =
  (* When batching multiple user commands, keep track of the nonces and send
      all the user commands if they are valid or none if there is an error in
      one of them.
  *)
  let open Deferred.Or_error.Let_syntax in
  let%map user_commands, _ =
    Deferred.Or_error.List.fold ~init:([], nonce_map) uc_inputs
      ~f:(fun (valid_user_commands, nonce_map) uc_input ->
        let%map res, updated_nonce_map =
          to_user_command ~nonce_map ~get_current_nonce uc_input
        in
        (res :: valid_user_commands, updated_nonce_map) )
  in
  List.rev user_commands
