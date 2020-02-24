open Core_kernel
open Coda_base
open Signature_lib

module Summary = struct
  type budget =
    { snark_fees: Currency.Fee.t
    ; user_command_fees: Currency.Fee.t
    ; coinbase_work_fees: Currency.Fee.t Staged_ledger_diff.At_most_two.t }

  type user_command_constraints = {not_enough_work: int; not_enough_space: int}

  type completed_work_constraints = {not_enough_fees: int; extra_work: int}

  type t =
    { start_budget: budget
    ; discarded_user_commands: user_command_constraints
    ; discarded_completed_work: completed_work_constraints
    ; end_budget: budget }

  module Fee_Summable = struct
    open Currency

    type t = Fee.t

    let zero = Fee.zero

    let ( + ) (x : Fee.t) (x' : Fee.t) = Fee.add x x' |> Option.value_exn
  end

  let init_budget
      ~(completed_works : Transaction_snark_work.Checked.t Sequence.t)
      ~(user_commands : User_command.With_valid_signature.t Sequence.t)
      ~(coinbase :
         (Public_key.Compressed.t * Currency.Fee.t)
         Staged_ledger_diff.At_most_two.t) =
    let snark_fees =
      Sequence.sum
        (module Fee_Summable)
        completed_works ~f:Transaction_snark_work.fee
    in
    let user_command_fees =
      Sequence.sum
        (module Fee_Summable)
        user_commands
        ~f:(Fn.compose User_command.fee User_command.forget_check)
    in
    let coinbase_work_fees =
      match coinbase with
      | One (Some x) ->
          Staged_ledger_diff.At_most_two.One (Some (snd x))
      | Two (Some (x, None)) ->
          Two (Some (snd x, None))
      | Two (Some (x, Some x')) ->
          Two (Some (snd x, Some (snd x)))
      | Zero ->
          Zero
      | One None ->
          One None
      | Two None ->
          Two None
    in
    {snark_fees; user_command_fees; coinbase_work_fees}

  let start ~(completed_works : Transaction_snark_work.Checked.t Sequence.t)
      ~(user_commands : User_command.With_valid_signature.t Sequence.t)
      ~(coinbase :
         (Public_key.Compressed.t * Currency.Fee.t)
         Staged_ledger_diff.At_most_two.t) =
    let start_budget = init_budget ~completed_works ~user_commands ~coinbase in
    let discarded_user_commands = {not_enough_work= 0; not_enough_space= 0} in
    let discarded_completed_work = {not_enough_fees= 0; extra_work= 0} in
    let end_budget =
      { snark_fees= Currency.Fee.zero
      ; user_command_fees= Currency.Fee.zero
      ; coinbase_work_fees= Staged_ledger_diff.At_most_two.Zero }
    in
    { start_budget
    ; discarded_completed_work
    ; discarded_user_commands
    ; end_budget }

  let end_budget t
      ~(completed_works : Transaction_snark_work.Checked.t Sequence.t)
      ~(user_commands : User_command.With_valid_signature.t Sequence.t)
      ~(coinbase :
         (Public_key.Compressed.t * Currency.Fee.t)
         Staged_ledger_diff.At_most_two.t) =
    {t with end_budget= init_budget ~completed_works ~user_commands ~coinbase}

  let discard_user_command (why : [`No_work | `No_space]) t =
    match why with
    | `No_work ->
        { t with
          discarded_user_commands=
            { t.discarded_user_commands with
              not_enough_work= t.discarded_user_commands.not_enough_work + 1 }
        }
    | `No_space ->
        { t with
          discarded_user_commands=
            { t.discarded_user_commands with
              not_enough_space= t.discarded_user_commands.not_enough_space + 1
            } }

  let discard_completed_work (why : [`Insufficient_fees | `Extra_work]) t =
    match why with
    | `Insufficient_fees ->
        { t with
          discarded_completed_work=
            { t.discarded_completed_work with
              not_enough_fees= t.discarded_completed_work.not_enough_fees + 1
            } }
    | `Extra_work ->
        { t with
          discarded_completed_work=
            { t.discarded_completed_work with
              extra_work= t.discarded_completed_work.extra_work + 1 } }
end

module Detail = struct end
