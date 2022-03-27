val sexp_to_yojson : Base.Sexp.t -> Yojson.Safe.t

val sexp_of_yojson : Yojson.Safe.t -> (Base.Sexp.t, Base.string) Base.Result.t

type info_data =
  | Sexp of Base.Sexp.t
  | String of Base.string
  | Exn of Base.exn
  | Of_list of Base.int Base.option * Base.int * Yojson.Safe.t

type info_tag =
  { tag : Base.string
  ; data : Base.Sexp.t Base.option
  ; loc : Base.Source_code_position.t Base.option
  }

type 'a info_repr =
  { base : 'a
  ; rev_tags : info_tag Base.list
  ; backtrace : Base.string Base.option
  }

val info_repr_to_yojson : info_data info_repr -> Yojson.Safe.t

val info_internal_repr_to_yojson_aux :
  Base.Info.Internal_repr.t -> Base.unit info_repr -> info_data info_repr

val info_internal_repr_to_yojson : Base.Info.Internal_repr.t -> Yojson.Safe.t

val info_to_yojson : Base.Info.t -> Yojson.Safe.t

val error_to_yojson : Base.Error.t -> Yojson.Safe.t
