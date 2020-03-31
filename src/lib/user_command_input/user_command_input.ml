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
          , Account_nonce.Stable.V1.t option
          , Global_slot.Stable.V1.t
          , User_command_memo.Stable.V1.t )
          User_command_payload.Common.Poly.Stable.V1.t
        [@@deriving sexp, to_yojson]

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t [@@deriving sexp, to_yojson]

    let create ~fee ~nonce_opt ~valid_until ~memo : t =
      {fee; nonce= nonce_opt; valid_until; memo}

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
      ; nonce= inferred_nonce
      ; valid_until= t.valid_until
      ; memo= t.memo }
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

  type t = Stable.Latest.t [@@deriving sexp, to_yojson]

  let create ~fee ~nonce_opt ~valid_until ~memo ~body : t =
    {common= Common.create ~fee ~nonce_opt ~valid_until ~memo; body}

  let to_user_command_payload (t : t) ~inferred_nonce :
      (User_command_payload.t, string) Result.t =
    let open Result.Let_syntax in
    let%map common = Common.to_user_command_common t.common ~inferred_nonce in
    {User_command_payload.Poly.common; body= t.body}
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

  type t = Stable.Latest.t =
    | Signature of Signature.t
    | Hd_index of Unsigned_extended.UInt32.t
    | Keypair of Keypair.t
  [@@deriving sexp, to_yojson]
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

type t = Stable.Latest.t [@@deriving sexp, to_yojson]

let create ?(nonce_opt = None) ~fee ~valid_until ~memo ~body ~sender
    ~sign_choice () : t =
  let payload = Payload.create ~fee ~nonce_opt ~valid_until ~memo ~body in
  {payload; sender; signature= sign_choice}

let sign ~sender ~(user_command_payload : User_command_payload.t) = function
  | Sign_choice.Signature signature ->
      Option.value_map
        ~default:(Deferred.return (Error "Invalid_signature"))
        (User_command.create_with_signature_checked signature sender
           user_command_payload)
        ~f:Deferred.Result.return
  | Keypair sender_kp ->
      Deferred.Result.return (User_command.sign sender_kp user_command_payload)
  | Hd_index hd_index ->
      Secrets.Hardware_wallets.sign ~hd_index
        ~public_key:(Public_key.decompress_exn sender)
        ~user_command_payload

let inferred_nonce ~get_current_nonce ~(sender : Public_key.Compressed.t)
    ~nonce_map =
  let open Result.Let_syntax in
  let update_map = Public_key.Compressed.Map.set nonce_map ~key:sender in
  match Public_key.Compressed.Map.find nonce_map sender with
  | Some nonce ->
      (*multiple user commands from a sender*)
      let next_nonce = Account_nonce.succ nonce in
      let updated_map = update_map ~data:next_nonce in
      Ok (next_nonce, updated_map)
  | None ->
      let%map txn_pool_or_account_nonce = get_current_nonce sender in
      let updated_map = update_map ~data:txn_pool_or_account_nonce in
      (txn_pool_or_account_nonce, updated_map)

let to_user_commands ~get_current_nonce uc_inputs :
    User_command.t list Deferred.Or_error.t =
  let open Deferred.Or_error.Let_syntax in
  let setup_user_command (client_input : t) nonce_map =
    (*create a user_command from input*)
    let sender = client_input.sender in
    let to_or_error : type a. (a, string) Result.t -> a Or_error.t =
     fun e ->
      let err_with_input str =
        sprintf "Error creating user command: %s Error: %s"
          (Yojson.Safe.to_string (to_yojson client_input))
          str
      in
      Result.map_error e ~f:(Fn.compose Error.of_string err_with_input)
    in
    let%bind inferred_nonce, updated_nonce_map =
      inferred_nonce ~get_current_nonce ~sender ~nonce_map
      |> to_or_error |> Deferred.return
    in
    let%bind user_command_payload =
      Payload.to_user_command_payload client_input.payload ~inferred_nonce
      |> to_or_error |> Deferred.return
    in
    let%map signed_user_command =
      Deferred.map
        (sign ~sender:client_input.sender ~user_command_payload
           client_input.signature)
        ~f:to_or_error
    in
    (User_command.forget_check signed_user_command, updated_nonce_map)
  in
  (*When batching multiple user commands, keep track of the nonces and send all the user commands if they are valid or none if there is an error in one of them*)
  let%map user_commands, _ =
    Deferred.Or_error.List.fold ~init:([], Public_key.Compressed.Map.empty)
      uc_inputs ~f:(fun (valid_user_commands, nonce_map) uc_input ->
        let open Deferred.Or_error.Let_syntax in
        let%map res, updated_nonce_map =
          setup_user_command uc_input nonce_map
        in
        (res :: valid_user_commands, updated_nonce_map) )
  in
  List.rev user_commands
