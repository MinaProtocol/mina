open Coda_base
open Signature_lib
open Coda_numbers
open Core_kernel
open Async_kernel

module Client_input = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { sender: Public_key.Compressed.Stable.V1.t
        ; fee: Currency.Fee.Stable.V1.t
        ; nonce_opt: Account_nonce.Stable.V1.t option
        ; valid_until: Account_nonce.Stable.V1.t
        ; memo: User_command_memo.Stable.V1.t
        ; body: User_command_payload.Body.Stable.V1.t
        ; sign_choice:
            [ `Signature of Signature.Stable.V1.t
            | `Hd_index of Unsigned_extended.UInt32.Stable.V1.t
            | `Keypair of Keypair.Stable.V1.t ] }
      [@@deriving to_yojson]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t =
    { sender: Public_key.Compressed.t
    ; fee: Currency.Fee.t
    ; nonce_opt: Account_nonce.t option
    ; valid_until: Account_nonce.t
    ; memo: User_command_memo.t
    ; body: User_command_payload.Body.t
    ; sign_choice:
        [ `Signature of Signature.t
        | `Hd_index of Unsigned_extended.UInt32.t
        | `Keypair of Keypair.t ] }
  [@@deriving make, to_yojson]
end

type user_command_input =
  { client_input: Client_input.t list
  ; inferred_nonce: Public_key.Compressed.t -> Account_nonce.t Option.t
  ; result: User_command.t list Or_error.t Ivar.t }

let process_user_command_input (uc_input : user_command_input) logger =
  let setup_user_command (client_input : Client_input.t) :
      User_command.t Deferred.Or_error.t =
    let open Deferred.Or_error.Let_syntax in
    let opt_error ~error_string opt =
      Option.value_map
        ~default:
          (Or_error.error_string
             (sprintf "Error creating user command: %s Error: %s"
                (Yojson.Safe.to_string (Client_input.to_yojson client_input))
                error_string))
        ~f:(fun value -> Ok value)
        opt
      |> Deferred.return
    in
    let create_user_command nonce =
      let payload =
        User_command.Payload.create ~fee:client_input.fee ~nonce
          ~valid_until:client_input.valid_until ~memo:client_input.memo
          ~body:client_input.body
      in
      (*Capture the errors*)
      let%map signed_user_command =
        match client_input.sign_choice with
        | `Signature signature ->
            User_command.create_with_signature_checked signature
              client_input.sender payload
            |> opt_error ~error_string:"Invalid signature"
        | `Keypair sender_kp ->
            Deferred.Or_error.return (User_command.sign sender_kp payload)
        | `Hd_index hd_index ->
            Deferred.map
              (Secrets.Hardware_wallets.sign ~hd_index
                 ~public_key:(Public_key.decompress_exn client_input.sender)
                 ~user_command_payload:payload)
              ~f:(Result.map_error ~f:Error.of_string)
      in
      User_command.forget_check signed_user_command
    in
    let%bind nonce =
      match client_input.nonce_opt with
      | Some nonce ->
          Deferred.Or_error.return nonce
      | None ->
          (*get inferred nonce*)
          uc_input.inferred_nonce client_input.sender
          |> opt_error
               ~error_string:
                 "Couldn't infer nonce for transaction from specified \
                  `sender` since `sender` is not in the ledger or sent a \
                  transaction in transaction pool."
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
              let acc' =
                let open Or_error.Let_syntax in
                let%map acc = acc in
                res :: acc
              in
              go acc' ucs
          | Error e ->
              Logger.warn logger "Cannot submit $cmd to the pool: $error"
                ~module_:__MODULE__ ~location:__LOC__
                ~metadata:
                  [ ("cmd", Client_input.to_yojson uc)
                  ; ("error", `String (Error.to_string_hum e)) ] ;
              return (Error e) )
    in
    go (Ok []) uc_input.client_input
  in
  match user_commands with
  | Ok ucs ->
      let user_commands' = List.rev ucs in
      Ivar.fill uc_input.result (Ok user_commands') ;
      user_commands'
  | Error e ->
      Ivar.fill uc_input.result (Error e) ;
      []
