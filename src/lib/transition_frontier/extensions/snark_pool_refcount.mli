type view =
  { removed: int
  ; refcount_table: int Transaction_snark_work.Statement.Table.t
  ; inclusion_table: int Transaction_snark_work.Statement.Table.t
  ; best_tip_table: Transaction_snark_work.Statement.Hash_set.t }
[@@deriving sexp]

include Intf.Extension_intf with type view := view
