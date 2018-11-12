type ('key, 'value) t = Root | Child of {parent: 'key; value: 'value}
[@@deriving sexp]
