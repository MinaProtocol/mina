open Core_kernel

(** Buffer size for writing: 128 KB *)
let buffer_size = 131072

module type S = Intf.S

module Tag = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('filename_key, 'a) t =
        { filename_key : 'filename_key; offset : int64; size : int }
    end
  end]
end

module Make_custom (Inputs : sig
  type filename_key

  val filename : filename_key -> string
end) :
  S
    with type 'a tag = (Inputs.filename_key, 'a) Tag.t
     and type filename_key = Inputs.filename_key = struct
  type 'a tag = (Inputs.filename_key, 'a) Tag.t

  type filename_key = Inputs.filename_key

  type writer_t =
    { f : 'a. (module Bin_prot.Binable.S with type t = 'a) -> 'a -> 'a tag }

  let write_value { f } = f

  (* Flush buffer to file when it exceeds threshold *)
  let flush_buffer oc buffer =
    Out_channel.output_string oc (Buffer.contents buffer)

  (* Write key function provided to the callback *)
  let make_writer ~oc ~filename_key ~buffer : writer_t =
    { f =
        (fun (type a) (module B : Bin_prot.Binable.S with type t = a)
             (value : a) ->
          (* Serialize the value to a bigstring *)
          let serialized_size = B.bin_size_t value in
          let buf = Bigstring.create serialized_size in
          let written = B.bin_write_t buf ~pos:0 value in
          assert (written = serialized_size) ;

          (* Convert bigstring to string for writing *)
          let data = Bigstring.to_string buf in

          (* Create tag before writing *)
          let tag =
            { Tag.filename_key
            ; offset = Int64.of_int @@ Buffer.length buffer
            ; size = serialized_size
            }
          in

          (* Add to buffer *)
          Buffer.add_string buffer data ;

          (* Flush if buffer is large enough *)
          if Buffer.length buffer >= buffer_size then (
            flush_buffer oc buffer ; Buffer.clear buffer ) ;

          tag )
    }

  (** Write multiple keys to a database file with buffered I/O *)
  let write_values_exn ~f filename_key =
    let do_writing oc =
      (* Buffer for accumulating writes *)
      let buffer = Buffer.create buffer_size in
      let writer = make_writer ~oc ~filename_key ~buffer in

      (* Call user function with write_value *)
      let result = f writer in

      (* Flush any remaining data *)
      if Buffer.length buffer > 0 then flush_buffer oc buffer ;

      result
    in
    Out_channel.with_file
      (Inputs.filename filename_key)
      ~binary:true ~f:do_writing

  (** Read a value from the database using a tag *)
  let read :
      type a.
      (module Bin_prot.Binable.S with type t = a) -> a tag -> a Or_error.t =
   fun (module B : Bin_prot.Binable.S with type t = a) tag ->
    let do_reading ic =
      (* Seek to the specified offset *)
      In_channel.seek ic tag.offset ;

      (* Read the exact number of bytes *)
      let buffer = Bytes.create tag.size in
      In_channel.really_input_exn ic ~buf:buffer ~pos:0 ~len:tag.size ;

      (* Deserialize using bin_prot *)
      let bigstring = Bigstring.of_bytes buffer in
      let pos_ref = ref 0 in
      let%bind.Or_error value =
        Or_error.try_with ~backtrace:true
        @@ fun () -> B.bin_read_t bigstring ~pos_ref
      in
      if !pos_ref <> tag.size then
        Or_error.error_string
          (sprintf "Size mismatch: expected %d bytes, read %d bytes" tag.size
             !pos_ref )
      else Ok value
    in
    Or_error.tag ~tag:(Inputs.filename tag.filename_key)
    @@ Or_error.try_with_join ~backtrace:true
    @@ fun () ->
    In_channel.with_file
      (Inputs.filename tag.filename_key)
      ~binary:true ~f:do_reading
end

include Make_custom (struct
  type filename_key = string

  let filename = ident
end)
