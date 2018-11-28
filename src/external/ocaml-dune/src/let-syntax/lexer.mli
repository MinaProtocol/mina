type t

val create
  :  output_fname:string
  -> oc:out_channel
  -> t

val apply : t -> fname:string -> unit

val print_endline : t -> string -> unit
