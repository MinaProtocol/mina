open Core_kernel

(** Buffer size for writing: 128 KB *)
let default_buffer_size = 131072

module type S = Intf.S

module Tag = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('filename_key, 'a) t =
        { filename_key : 'filename_key; offset : int64; size : int }

      let compare filename_key_compare t1 t2 =
        let c = filename_key_compare t1.filename_key t2.filename_key in
        if c <> 0 then c
        else
          let c' = Int64.compare t1.offset t2.offset in
          if c' <> 0 then c' else Int.compare t1.size t2.size

      let equal filename_key_equal t1 t2 =
        let c = filename_key_equal t1.filename_key t2.filename_key in
        if c then
          if Int64.equal t1.offset t2.offset then Int.equal t1.size t2.size
          else false
        else false

      let sexp_of_t sexp_of_filename_key t =
        [%sexp_of: Sexp.t * int64 * int]
          (sexp_of_filename_key t.filename_key, t.offset, t.size)

      let t_of_sexp filename_key_of_sexp sexp =
        [%of_sexp: Sexp.t * int64 * int] sexp
        |> fun (filename_key, offset, size) ->
        { filename_key = filename_key_of_sexp filename_key; offset; size }
    end
  end]

  [%%define_locally Stable.Latest.(compare, equal, t_of_sexp, sexp_of_t)]
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
  let make_writer ~buffer_size ~init_offset ~oc ~filename_key ~buffer : writer_t
      =
    let offset = ref init_offset in
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
            { Tag.filename_key; offset = !offset; size = serialized_size }
          in

          (offset := Int64.(!offset + of_int serialized_size)) ;

          (* Add to buffer *)
          Buffer.add_string buffer data ;

          (* Flush if buffer is large enough *)
          if Buffer.length buffer >= buffer_size then (
            flush_buffer oc buffer ; Buffer.clear buffer ) ;

          tag )
    }

  (** Write multiple keys to a database file with buffered I/O *)
  let write_values_exn ?(buffer_size = default_buffer_size) ~f filename_key =
    let do_writing oc =
      (* Buffer for accumulating writes *)
      let buffer = Buffer.create buffer_size in
      let writer =
        make_writer ~buffer_size ~init_offset:0L ~oc ~filename_key ~buffer
      in

      (* Call user function with write_value *)
      let result = f writer in

      (* Flush any remaining data *)
      if Buffer.length buffer > 0 then flush_buffer oc buffer ;

      result
    in
    Out_channel.with_file
      (Inputs.filename filename_key)
      ~binary:true ~f:do_writing

  (** Append multiple keys to an existing database file with buffered I/O *)
  let append_values_exn ?(buffer_size = default_buffer_size) ~f filename_key =
    let filename = Inputs.filename filename_key in
    let do_appending oc =
      (* Get current file size to calculate offset for new writes *)
      let init_offset = Out_channel.length oc in

      (* Buffer for accumulating writes *)
      let buffer = Buffer.create buffer_size in

      (* Create a modified writer that accounts for the initial file offset *)
      let writer =
        make_writer ~buffer_size ~init_offset ~oc ~filename_key ~buffer
      in

      (* Call user function with write_value *)
      let result = f writer in

      (* Flush any remaining data *)
      if Buffer.length buffer > 0 then flush_buffer oc buffer ;

      result
    in
    Out_channel.with_file filename ~binary:true ~append:true ~f:do_appending

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

  let read_many (type a) (module B : Bin_prot.Binable.S with type t = a) tags =
    let%map.Or_error reversed =
      List.fold_result tags ~init:[] ~f:(fun acc tag ->
          let%map.Or_error value = read (module B) tag in
          value :: acc )
    in
    List.rev reversed
end

include Make_custom (struct
  type filename_key = string

  let filename = ident
end)
