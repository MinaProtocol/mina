(** IO operations *)

val close_in  : in_channel  -> unit
val close_out : out_channel -> unit

val input_lines : in_channel -> string list

val copy_channels : in_channel -> out_channel -> unit

val read_all : in_channel -> string

module type S = sig
  type path

  val open_in  : ?binary:bool (* default true *) -> path -> in_channel
  val open_out : ?binary:bool (* default true *) -> path -> out_channel

  val with_file_in  : ?binary:bool (* default true *) -> path -> f:(in_channel -> 'a) -> 'a
  val with_file_out : ?binary:bool (* default true *) -> path -> f:(out_channel -> 'a) -> 'a

  val with_lexbuf_from_file : path -> f:(Lexing.lexbuf -> 'a) -> 'a
  val lines_of_file : path -> string list

  val read_file : ?binary:bool -> path -> string
  val write_file : ?binary:bool -> path -> string -> unit

  val compare_files : path -> path -> Ordering.t
  val compare_text_files : path -> path -> Ordering.t

  val write_lines : path -> string list -> unit
  val copy_file : ?chmod:(int -> int) -> src:path -> dst:path -> unit -> unit
end

include S with type path = Path.t

module String_path : S with type path = string
