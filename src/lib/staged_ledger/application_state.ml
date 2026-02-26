open Core_kernel
open Mina_base
open Mina_transaction

module Make (Txn : sig
  type t [@@deriving to_yojson]

  val key : t -> Account_id.t

  val is_zkapp_command : t -> bool

  val to_user_command : t -> User_command.t
end) =
struct
  type t =
    { valid_seq : Txn.t Sequence.t
    ; invalid : (Txn.t * Error.t) list
    ; skipped_by_fee_payer : Txn.t list Account_id.Map.t
    ; zkapp_space_remaining : int option
    ; total_space_remaining : int
    }

  let init ?zkapp_limit ~total_limit =
    { valid_seq = Sequence.empty
    ; invalid = []
    ; skipped_by_fee_payer = Account_id.Map.empty
    ; zkapp_space_remaining = zkapp_limit
    ; total_space_remaining = total_limit
    }

  let add_skipped_txn t (txn : Txn.t) =
    Account_id.Map.update t.skipped_by_fee_payer (Txn.key txn)
      ~f:(Option.value_map ~default:[ txn ] ~f:(List.cons txn))

  let dependency_skipped txn t =
    Account_id.Map.mem t.skipped_by_fee_payer (Txn.key txn)

  let try_applying_txn ?logger ~apply (state : t) (txn : Txn.t) =
    let open Continue_or_stop in
    match state.zkapp_space_remaining with
    | _ when state.total_space_remaining < 1 ->
        Stop (state.valid_seq, state.invalid)
    | Some zkapp_limit when Txn.is_zkapp_command txn && zkapp_limit < 1 ->
        Continue { state with skipped_by_fee_payer = add_skipped_txn state txn }
    | Some _ when dependency_skipped txn state ->
        Continue { state with skipped_by_fee_payer = add_skipped_txn state txn }
    | _ -> (
        match
          O1trace.sync_thread "validate_transaction_against_staged_ledger"
            (fun () -> apply (Transaction.Command (Txn.to_user_command txn)))
        with
        | Error e ->
            Option.iter logger ~f:(fun logger ->
                [%log error]
                  ~metadata:
                    [ ("user_command", Txn.to_yojson txn)
                    ; ("error", Error_json.error_to_yojson e)
                    ]
                  "Staged_ledger_diff creation: Skipping user command: \
                   $user_command due to error: $error" ) ;
            Continue { state with invalid = (txn, e) :: state.invalid }
        | Ok _txn_partially_applied ->
            let valid_seq =
              Sequence.append (Sequence.singleton txn) state.valid_seq
            in
            let zkapp_space_remaining =
              Option.map state.zkapp_space_remaining ~f:(fun limit ->
                  if Txn.is_zkapp_command txn then limit - 1 else limit )
            in
            Continue
              { state with
                valid_seq
              ; zkapp_space_remaining
              ; total_space_remaining = state.total_space_remaining - 1
              } )
end

module Valid_user_command = Make (struct
  type t = User_command.Valid.t [@@deriving to_yojson]

  let key = function
    | User_command.Zkapp_command cmd ->
        Zkapp_command.(Valid.forget cmd |> fee_payer)
    | Signed_command cmd ->
        Signed_command.(forget_check cmd |> fee_payer)

  let is_zkapp_command = function
    | User_command.Zkapp_command _ ->
        true
    | Signed_command _ ->
        false

  let to_user_command = User_command.forget_check
end)
