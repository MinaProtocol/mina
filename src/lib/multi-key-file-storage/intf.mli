module type S = sig
  (** Tag representing the location and metadata of a stored value *)
  type 'a tag

  (** Writer object used to write values to the single-file database *)
  type writer_t

  (** Type that represents the key used to identify the file *)
  type filename_key

  (** Write a value to the database.
    
    [write_value writer bin_prot_module value] serializes [value] using the
    provided bin_prot serializer and returns a [tag] that can be used to read the value later.
*)
  val write_value :
    'a. writer_t -> (module Bin_prot.Binable.S with type t = 'a) -> 'a -> 'a tag

  (** Write multiple keys to a database file.
    
    The [f] parameter is a callback that receives a [write_value] function which can be
    called multiple times to write different key-value pairs to the database.
    
    Example (assuming the default implementation with [type filename_key = string]):
    {[
      write_values_exn "my.db" ~f:(fun writer ->
        let tag1 = write_value writer (module Int) 42 in
        let tag2 = write_value writer (module String) "hello" in
        (* ... store tags for later use ... *)
      )
    ]}
    See the tests for a full usage example.
*)
  val write_values_exn : 'tags. f:(writer_t -> 'tags) -> filename_key -> 'tags

  (** Read a value from the database using a tag.
    
    [read m tag] takes a [tag] (obtained from a previous [write] operation)
    and a bin_prot module [m] to deserialize the stored bytes back into a typed value.
    
    Returns [Ok value] on success, or [Error msg] if reading or deserialization fails.
    
    Example:
    {[
      match read (module Int) tag1 with
      | Ok value -> Printf.printf "Read value: %d\n" value
      | Error msg -> Printf.eprintf "Error: %s\n" msg
    ]}
*)
  val read :
       (module Bin_prot.Binable.S with type t = 'a)
    -> 'a tag
    -> 'a Core_kernel.Or_error.t

  val read_many :
       (module Bin_prot.Binable.S with type t = 'a)
    -> 'a tag list
    -> 'a list Core_kernel.Or_error.t
end
