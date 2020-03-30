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

    let to_user_command_common (t : t) ~nonce : User_command_payload.Common.t =
      { User_command_payload.Common.Poly.fee= t.fee
      ; nonce
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

  let to_user_command_payload (t : t) ~nonce : User_command_payload.t =
    { User_command_payload.Poly.common=
        Common.to_user_command_common t.common ~nonce
    ; body= t.body }
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

let inferred_nonce ~f ~(sender : Public_key.Compressed.t) nonce_opt =
  let open Result.Let_syntax in
  let%bind txn_pool_or_account_nonce =
    match Participating_state.active (f sender) |> Option.join with
    | None ->
        Error
          "Couldn't infer nonce for transaction from specified `sender` since \
           `sender` is not in the ledger or sent a transaction in transaction \
           pool."
    | Some nonce ->
        Ok nonce
  in
  match nonce_opt with
  | Some nonce ->
      if Account_nonce.equal nonce txn_pool_or_account_nonce then Ok nonce
      else
        Error
          (sprintf
             !"Input nonce %s different from inferred nonce %s"
             (Account_nonce.to_string nonce)
             (Account_nonce.to_string txn_pool_or_account_nonce))
  | None ->
      Ok txn_pool_or_account_nonce

let to_user_command ~result_cb ~infer_nonce ~logger uc_inputs :
    (User_command.t list * (_ Or_error.t -> unit)) option Deferred.t =
  let setup_user_command (client_input : t) :
      User_command.t Deferred.Or_error.t =
    (*create a user_command from input*)
    let open Deferred.Or_error.Let_syntax in
    let nonce_opt = client_input.payload.common.nonce in
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
    let%bind inferred_nonce =
      inferred_nonce ~f:infer_nonce ~sender nonce_opt
      |> to_or_error |> Deferred.return
    in
    let user_command_payload =
      Payload.to_user_command_payload client_input.payload
        ~nonce:inferred_nonce
    in
    let%map signed_user_command =
      Deferred.map
        (sign ~sender:client_input.sender ~user_command_payload
           client_input.signature)
        ~f:to_or_error
    in
    User_command.forget_check signed_user_command
  in
  let%map user_commands =
    (*When batching multiple user commands, send all the user commands if they are valid or none if there is an error in one of them*)
    let rec go acc = function
      | [] ->
          return acc
      | uc :: ucs -> (
          match%bind setup_user_command uc with
          | Ok res ->
              let acc' = Or_error.map acc ~f:(fun acc -> res :: acc) in
              go acc' ucs
          | Error e ->
              Logger.error logger
                "Failed to submit user commands. Error in $cmd: $error"
                ~module_:__MODULE__ ~location:__LOC__
                ~metadata:
                  [ ("cmd", to_yojson uc)
                  ; ("error", `String (Error.to_string_hum e)) ] ;
              return (Error e) )
    in
    go (Ok []) uc_inputs
  in
  match user_commands with
  | Ok ucs ->
      let user_commands' = List.rev ucs in
      if List.is_empty user_commands' then (
        result_cb (Error (Error.of_string "No user commands to send")) ;
        None )
      else Some (user_commands', result_cb)
      (*return the callback for the result from transaction_pool.apply_diff*)
  | Error e ->
      result_cb (Error e) ; None
