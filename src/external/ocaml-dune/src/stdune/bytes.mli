include module type of StdLabels.Bytes with type t = StdLabels.Bytes.t

val blit_string
  :  src:string
  -> src_pos:int
  -> dst:t
  -> dst_pos:int
  -> len:int
  -> unit

val sub_string
  :  t
  -> pos:int
  -> len:int
  -> string
