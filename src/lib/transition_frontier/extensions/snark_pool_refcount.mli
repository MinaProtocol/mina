type view =
  { removed: int
  ; refcount_table: int Transaction_snark_work.Statement.Table.t
  ; inclusion_table: int Transaction_snark_work.Statement.Table.t }
[@@deriving sexp]

include Intf.Extension_intf with type view := view
