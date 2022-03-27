type mode = Hidden | Inline | After

type config =
  { mode : mode; max_interpolation_length : int; pretty_print : bool }

val result_fold_left :
     'a list
  -> init:'b
  -> f:('b -> 'a -> ('b, 'c) Core_kernel._result)
  -> ('b, 'c) Core_kernel._result

val parser : [> `Interpolate of string | `Raw of string ] list Angstrom.t

val parse :
  string -> ([> `Interpolate of string | `Raw of string ] list, string) result

val render :
     max_interpolation_length:Core_kernel__Int.t
  -> format_json:('a -> string)
  -> 'a Core_kernel.String.Map.t
  -> [< `Interpolate of Core_kernel.String.Map.Key.t | `Raw of string ] list
  -> ( string * (Core_kernel.String.Map.Key.t * string) list
     , string )
     Core_kernel__Result.t

val interpolate :
     config
  -> string
  -> Yojson.Safe.t Core_kernel.String.Map.t
  -> ( string * (Core_kernel.String.Map.Key.t * string) list
     , string )
     Core_kernel._result
