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

  let to_user_command_payload ~fee ~nonce ~valid_until ~memo ~body :
      User_command_payload.t =
    User_command.Payload.create ~fee ~nonce ~valid_until ~memo ~body
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

let to_user_command ~result_cb ~inferred_nonce ~logger uc_inputs :
    (User_command.t list * (_ Or_error.t -> unit)) option Deferred.t =
  let setup_user_command (client_input : t) :
      User_command.t Deferred.Or_error.t =
    let open Deferred.Or_error.Let_syntax in
    let nonce_opt = client_input.payload.common.nonce in
    let payload_common = client_input.payload.common in
    let err str =
      sprintf "Error creating user command: %s Error: %s"
        (Yojson.Safe.to_string (to_yojson client_input))
        str
    in
    let opt_error ~error_string = function
      | None ->
          Deferred.Or_error.error_string (err error_string)
      | Some v ->
          Deferred.Or_error.return v
    in
    let create_user_command nonce : User_command.t Deferred.Or_error.t =
      let user_command_payload =
        Payload.to_user_command_payload ~fee:payload_common.fee ~nonce
          ~valid_until:payload_common.valid_until ~memo:payload_common.memo
          ~body:client_input.payload.body
      in
      let%map signed_user_command =
        Deferred.map
          (sign ~sender:client_input.sender ~user_command_payload
             client_input.signature)
          ~f:(Result.map_error ~f:(fun str -> Error.of_string (err str)))
      in
      User_command.forget_check signed_user_command
    in
    let%bind nonce_inferred =
      Participating_state.active (inferred_nonce client_input.sender)
      |> Option.bind ~f:Fn.id
      |> opt_error
           ~error_string:
             "Couldn't infer nonce for transaction from specified `sender` \
              since `sender` is not in the ledger or sent a transaction in \
              transaction pool."
    in
    let%bind nonce =
      match nonce_opt with
      | Some nonce ->
          if Account_nonce.equal nonce nonce_inferred then
            Deferred.Or_error.return nonce
          else
            opt_error
              ~error_string:
                (sprintf
                   !"Input nonce %s different from inferred nonce %s"
                   (Account_nonce.to_string nonce)
                   (Account_nonce.to_string nonce_inferred))
              None
      | None ->
          Deferred.Or_error.return nonce_inferred
    in
    create_user_command nonce
  in
  let%map user_commands =
    let rec go acc ucs =
      match ucs with
      | [] ->
          return acc
      | uc :: ucs -> (
          match%bind setup_user_command uc with
          | Ok res ->
              let acc' = Or_error.map acc ~f:(fun acc -> res :: acc) in
              go acc' ucs
          | Error e ->
              Logger.warn logger "Cannot submit $cmd to the pool: $error"
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
  | Error e ->
      result_cb (Error e) ; None
