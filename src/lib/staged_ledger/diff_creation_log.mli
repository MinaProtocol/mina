module Summary : sig
  type t
end

module Detail : sig
  type line

  type t = line list
end

type t = Summary.t * Detail.t

val discard_completed_work :
     [ `End | `Extra_work | `Init | `Insufficient_fees | `No_space | `No_work ]
  -> Transaction_snark_work.t
  -> t
  -> t

val discard_command :
     [ `End | `Extra_work | `Init | `Insufficient_fees | `No_space | `No_work ]
  -> Mina_base.User_command.t
  -> t
  -> t

val init :
     completed_work:Transaction_snark_work.Checked.t Core_kernel.Sequence.t
  -> commands:Mina_base.User_command.Valid.t Core_kernel.Sequence.t
  -> coinbase:Mina_base.Coinbase.Fee_transfer.t Staged_ledger_diff.At_most_two.t
  -> partition:[ `First | `Second ]
  -> available_slots:int
  -> required_work_count:int
  -> t

val end_log :
     completed_work:Transaction_snark_work.Checked.t Core_kernel.Sequence.t
  -> commands:Mina_base.User_command.Valid.t Core_kernel.Sequence.t
  -> coinbase:Mina_base.Coinbase.Fee_transfer.t Staged_ledger_diff.At_most_two.t
  -> t
  -> t

val summary_list_to_yojson : Summary.t list -> Yojson.Safe.t

val detail_list_to_yojson : Detail.t list -> Yojson.Safe.t
