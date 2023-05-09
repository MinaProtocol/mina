type ondisk_database
type ondisk_batch

type ondisk_key = Core.Bigstring.t
type ondisk_value = Core.Bigstring.t

type 'a ondisk_result = ('a, string) result

module Rust = struct
  external ondisk_database_create : string -> ondisk_database ondisk_result = "rust_ondisk_database_create"
  external ondisk_database_create_checkpoint : ondisk_database -> string -> ondisk_database ondisk_result = "rust_ondisk_database_create_checkpoint"
  external ondisk_database_make_checkpoint : ondisk_database -> string -> unit ondisk_result = "rust_ondisk_database_make_checkpoint"
  external ondisk_database_get_uuid : ondisk_database -> string ondisk_result = "rust_ondisk_database_get_uuid"
  external ondisk_database_close : ondisk_database -> unit ondisk_result = "rust_ondisk_database_close"
  external ondisk_database_get : ondisk_database -> ondisk_key -> (ondisk_value option) ondisk_result = "rust_ondisk_database_get"
  external ondisk_database_get_batch : ondisk_database -> ondisk_key list -> (ondisk_value option list) ondisk_result = "rust_ondisk_database_get_batch"
  external ondisk_database_set : ondisk_database -> ondisk_key -> ondisk_value -> unit ondisk_result = "rust_ondisk_database_set"
  external ondisk_database_set_batch : ondisk_database -> Core.Bigstring.t list -> (ondisk_key * ondisk_value) list -> unit ondisk_result = "rust_ondisk_database_set_batch"
  external ondisk_database_remove : ondisk_database -> ondisk_key -> unit ondisk_result = "rust_ondisk_database_remove"
  external ondisk_database_to_alist : ondisk_database -> ((ondisk_key * ondisk_value) list) ondisk_result = "rust_ondisk_database_to_alist"
  external ondisk_database_gc : ondisk_database -> unit ondisk_result = "rust_ondisk_database_gc"

  external ondisk_database_batch_create : unit -> ondisk_batch = "rust_ondisk_database_batch_create"
  external ondisk_database_batch_set : ondisk_batch -> ondisk_key -> ondisk_value -> unit = "rust_ondisk_database_batch_set"
  external ondisk_database_batch_remove : ondisk_batch -> ondisk_key -> unit = "rust_ondisk_database_batch_remove"
  external ondisk_database_batch_run : ondisk_database -> ondisk_batch -> unit ondisk_result = "rust_ondisk_database_batch_run"
end
