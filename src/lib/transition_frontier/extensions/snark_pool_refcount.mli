type view = { removed_work : Transaction_snark_work.Statement.t list }
[@@deriving sexp]

include Intf.Extension_intf with type view := view

val work_is_referenced : t -> Transaction_snark_work.Statement.t -> bool

val best_tip_table : t -> Transaction_snark_work.Statement.Hash_set.t
