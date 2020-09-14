open Core_kernel
open Coda_base

type count_and_fee = int * Currency.Fee.t [@@deriving sexp, to_yojson]

module Fee_Summable = struct
  open Currency

  type t = Fee.t

  let zero = Fee.zero

  let ( + ) (x : Fee.t) (x' : Fee.t) = Fee.add x x' |> Option.value_exn
end

module Summary = struct
  type resources =
    { completed_work: count_and_fee
    ; commands: count_and_fee
    ; coinbase_work_fees: Currency.Fee.t Staged_ledger_diff.At_most_two.t }
  [@@deriving sexp, to_yojson, lens]

  type command_constraints = {insufficient_work: int; insufficient_space: int}
  [@@deriving sexp, to_yojson, lens]

  type completed_work_constraints = {insufficient_fees: int; extra_work: int}
  [@@deriving sexp, to_yojson, lens]

  type t =
    { partition: [`First | `Second]
    ; start_resources: resources
    ; available_slots: int
    ; required_work_count: int
    ; discarded_commands: command_constraints
    ; discarded_completed_work: completed_work_constraints
    ; end_resources: resources }
  [@@deriving sexp, to_yojson, lens]

  let coinbase_fees
      (coinbase : Coinbase.Fee_transfer.t Staged_ledger_diff.At_most_two.t) =
    match coinbase with
    | One (Some x) ->
        Staged_ledger_diff.At_most_two.One (Some x.fee)
    | Two (Some (x, None)) ->
        Two (Some (x.fee, None))
    | Two (Some (x, Some x')) ->
        Two (Some (x.fee, Some x'.fee))
    | Zero ->
        Zero
    | One None ->
        One None
    | Two None ->
        Two None

  let init_resources
      ~(completed_work : Transaction_snark_work.Checked.t Sequence.t)
      ~(commands : User_command.Valid.t With_status.t Sequence.t)
      ~(coinbase : Coinbase.Fee_transfer.t Staged_ledger_diff.At_most_two.t) =
    let completed_work =
      ( Sequence.length completed_work
      , Sequence.sum
          (module Fee_Summable)
          completed_work ~f:Transaction_snark_work.fee )
    in
    let commands =
      ( Sequence.length commands
      , Sequence.sum
          (module Fee_Summable)
          commands
          ~f:(fun cmd ->
            User_command.fee_exn (cmd.data :> User_command.t) )
      )
    in
    let coinbase_work_fees = coinbase_fees coinbase in
    {completed_work; commands; coinbase_work_fees}

  let init ~(completed_work : Transaction_snark_work.Checked.t Sequence.t)
      ~(commands : User_command.Valid.t With_status.t Sequence.t)
      ~(coinbase : Coinbase.Fee_transfer.t Staged_ledger_diff.At_most_two.t)
      ~partition ~available_slots ~required_work_count =
    let start_resources = init_resources ~completed_work ~commands ~coinbase in
    let discarded_commands = {insufficient_work= 0; insufficient_space= 0} in
    let discarded_completed_work = {insufficient_fees= 0; extra_work= 0} in
    let end_resources =
      { completed_work= (0, Currency.Fee.zero)
      ; commands= (0, Currency.Fee.zero)
      ; coinbase_work_fees= Staged_ledger_diff.At_most_two.Zero }
    in
    { partition
    ; available_slots
    ; required_work_count
    ; start_resources
    ; discarded_completed_work
    ; discarded_commands
    ; end_resources }

  let end_log t ~(completed_work : Transaction_snark_work.Checked.t Sequence.t)
      ~(commands : User_command.Valid.t With_status.t Sequence.t)
      ~(coinbase : Coinbase.Fee_transfer.t Staged_ledger_diff.At_most_two.t) =
    end_resources.set (init_resources ~completed_work ~commands ~coinbase) t

  let incr (top : ('a, 'b) Lens.t) (nested : ('b, int) Lens.t) (t : 'a) =
    let nested_field = top.get t in
    top.set (nested.set (nested.get nested_field + 1) nested_field) t

  let discard_command (why : [> `No_work | `No_space]) t =
    match why with
    | `No_work ->
        incr discarded_commands command_constraints_insufficient_work t
    | `No_space ->
        incr discarded_commands command_constraints_insufficient_space t
    | _ ->
        t

  let discard_completed_work (why : [> `Insufficient_fees | `Extra_work]) t =
    match why with
    | `Insufficient_fees ->
        incr discarded_completed_work
          completed_work_constraints_insufficient_fees t
    | `Extra_work ->
        incr discarded_completed_work completed_work_constraints_extra_work t
    | _ ->
        t
end

module Detail = struct
  type line =
    { reason:
        [`No_space | `No_work | `Insufficient_fees | `Extra_work | `Init | `End]
    ; commands: count_and_fee
    ; completed_work: count_and_fee
    ; coinbase: Currency.Fee.t Staged_ledger_diff.At_most_two.t }
  [@@deriving sexp, to_yojson, lens]

  type t = line list [@@deriving sexp, to_yojson]

  let init ~(completed_work : Transaction_snark_work.Checked.t Sequence.t)
      ~(commands : User_command.Valid.t With_status.t Sequence.t)
      ~(coinbase : Coinbase.Fee_transfer.t Staged_ledger_diff.At_most_two.t) =
    let init = Summary.init_resources ~completed_work ~commands ~coinbase in
    [ { reason= `Init
      ; commands= init.commands
      ; completed_work= init.completed_work
      ; coinbase= init.coinbase_work_fees } ]

  let discard_command (why : [> `No_work | `No_space]) command = function
    | [] ->
        failwith "Log not initialized"
    | x :: xs ->
        let new_line =
          { x with
            reason= why
          ; commands=
              ( fst x.commands - 1
              , Currency.Fee.sub (snd x.commands)
                  (User_command.fee_exn command)
                |> Option.value_exn ) }
        in
        new_line :: x :: xs

  let discard_completed_work (why : [> `Insufficient_fees | `Extra_work])
      completed_work = function
    | [] ->
        failwith "Log not initialized"
    | x :: xs ->
        let new_line =
          { x with
            reason= why
          ; completed_work=
              ( fst x.completed_work - 1
              , Currency.Fee.sub (snd x.completed_work)
                  (Transaction_snark_work.fee completed_work)
                |> Option.value_exn ) }
        in
        new_line :: x :: xs

  let end_log coinbase = function
    | [] ->
        failwith "Log not initialized"
    | x :: xs ->
        (*Because coinbase could be updated ooutside of the check_constraints_and_update function*)
        {x with reason= `End; coinbase= Summary.coinbase_fees coinbase}
        :: x :: xs
end

type t = Summary.t * Detail.t [@@deriving sexp, to_yojson]

type log_list = t list [@@deriving sexp, to_yojson]

type summary_list = Summary.t list [@@deriving sexp, to_yojson]

type detail_list = Detail.t list [@@deriving sexp, to_yojson]

let init ~(completed_work : Transaction_snark_work.Checked.t Sequence.t)
    ~(commands : User_command.Valid.t With_status.t Sequence.t)
    ~(coinbase : Coinbase.Fee_transfer.t Staged_ledger_diff.At_most_two.t)
    ~partition ~available_slots ~required_work_count =
  let summary =
    Summary.init ~completed_work ~commands ~coinbase ~partition
      ~available_slots ~required_work_count
  in
  let detailed = Detail.init ~completed_work ~commands ~coinbase in
  (summary, detailed)

let discard_command why command t =
  let detailed = Detail.discard_command why command (snd t) in
  let summary = Summary.discard_command why (fst t) in
  (summary, detailed)

let discard_completed_work why completed_work t =
  let detailed = Detail.discard_completed_work why completed_work (snd t) in
  let summary = Summary.discard_completed_work why (fst t) in
  (summary, detailed)

let end_log ~(completed_work : Transaction_snark_work.Checked.t Sequence.t)
    ~(commands : User_command.Valid.t With_status.t Sequence.t)
    ~(coinbase : Coinbase.Fee_transfer.t Staged_ledger_diff.At_most_two.t) t =
  let summary = Summary.end_log (fst t) ~completed_work ~commands ~coinbase in
  let detailed = Detail.end_log coinbase (snd t) in
  (summary, detailed)
