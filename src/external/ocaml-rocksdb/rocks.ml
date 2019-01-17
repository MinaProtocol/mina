open Ctypes
open Foreign
open Rocks_common

type bigarray = Rocks_intf.bigarray

module Views = Views

exception OperationOnInvalidObject = Rocks_common.OperationOnInvalidObject

module WriteBatch = struct
  module C = CreateConstructors_(struct let name = "writebatch" end)
  include C

  let clear =
    foreign
      "rocksdb_writebatch_clear"
      (t @-> returning void)

  let count =
    foreign
      "rocksdb_writebatch_count"
      (t @-> returning int)

  let put_raw =
    foreign
      "rocksdb_writebatch_put"
      (t @->
       ptr char @-> Views.int_to_size_t @->
       ptr char @-> Views.int_to_size_t @-> returning void)

  let put_raw_string =
    foreign
      "rocksdb_writebatch_put"
      (t @->
       ocaml_string @-> Views.int_to_size_t @->
       ocaml_string @-> Views.int_to_size_t @-> returning void)

  let put ?(key_pos=0) ?key_len ?(value_pos=0) ?value_len batch key value =
    let open Bigarray.Array1 in
    let key_len = match key_len with None -> dim key - key_pos | Some len -> len in
    let value_len = match value_len with None -> dim value - value_pos | Some len -> len in
    put_raw
      batch
      (bigarray_start array1 key +@ key_pos) key_len
      (bigarray_start array1 value +@ value_pos) value_len

  let put_string ?(key_pos=0) ?key_len ?(value_pos=0) ?value_len batch key value =
    let key_len = match key_len with None -> String.length key - key_pos | Some len -> len in
    let value_len = match value_len with None -> String.length value - value_pos | Some len -> len in
    put_raw_string batch
      (ocaml_string_start key +@ key_pos) key_len
      (ocaml_string_start value +@ value_pos) value_len

  let delete_raw =
    foreign
      "rocksdb_writebatch_delete"
      (t @-> ptr char @-> Views.int_to_size_t @-> returning void)

  let delete_raw_string =
    foreign
      "rocksdb_writebatch_delete"
      (t @-> ocaml_string @-> Views.int_to_size_t @-> returning void)

  let delete ?(pos=0) ?len batch key =
    let open Bigarray.Array1 in
    let len = match len with None -> dim key - pos | Some len -> len in
    delete_raw batch (bigarray_start array1 key +@ pos) len

  let delete_string ?(pos=0) ?len batch key =
    let len = match len with None -> String.length key - pos | Some len -> len in
    delete_raw_string batch (ocaml_string_start key +@ pos) len
end

module Version = struct
  let major = 5
  let minor = 17
  let patch = 2
  let git_revision = "tags/v5.17.2-0-gf438b98e5"
  let summary = (major, minor, patch, git_revision)
end

let returning_error typ = ptr string_opt @-> returning typ

let with_err_pointer f =
  let err_pointer = allocate string_opt None in
  let res = f err_pointer in
  match !@ err_pointer with
  | None -> res
  | Some err -> failwith err

module rec Iterator : Rocks_intf.ITERATOR with type db := RocksDb.t = struct
  module ReadOptions = Rocks_options.ReadOptions
  type nonrec t = t
  let t = t

  type db
  let db = t

  let get_pointer = get_pointer

  exception InvalidIterator

  let create_no_gc =
    foreign
      "rocksdb_create_iterator"
      (db @-> ReadOptions.t @-> returning t)

  let destroy =
    let inner =
      foreign
        "rocksdb_iter_destroy"
        (t @-> returning void)
    in
    fun t ->
      inner t;
      t.valid <- false

  let create ?opts db =
    let inner opts =
      let t = create_no_gc db opts in
      Gc.finalise destroy t;
      t
    in
    match opts with
    | None -> ReadOptions.with_t inner
    | Some opts -> inner opts

  let with_t ?opts db ~f =
    let inner opts =
      let t = create_no_gc db opts in
      finalize (fun () -> f t) (fun () -> destroy t)
    in
    match opts with
    | None -> ReadOptions.with_t inner
    | Some opts -> inner opts

  let is_valid =
    foreign
      "rocksdb_iter_valid"
      (t @-> returning Views.bool_to_uchar)

  let seek_to_first =
    foreign
      "rocksdb_iter_seek_to_first"
      (t @-> returning void)

  let seek_to_last =
    foreign
      "rocksdb_iter_seek_to_last"
      (t @-> returning void)

  let seek_raw =
    foreign
      "rocksdb_iter_seek"
      (t @-> ptr char @-> Views.int_to_size_t @-> returning void)

  let seek_raw_string =
    foreign
      "rocksdb_iter_seek"
      (t @-> ocaml_string @-> Views.int_to_size_t @-> returning void)

  let seek ?(pos=0) ?len t key =
    let open Bigarray.Array1 in
    let len = match len with None -> dim key - pos | Some len -> len in
    seek_raw t (bigarray_start array1 key +@ pos) len

  let seek_string ?(pos=0) ?len t key =
    let len = match len with None -> String.length key - pos | Some len -> len in
    seek_raw_string t (ocaml_string_start key +@ pos) len

  let next =
    foreign
      "rocksdb_iter_next"
      (t @-> returning void)

  let prev =
    foreign
      "rocksdb_iter_prev"
      (t @-> returning void)

  let get_key_raw =
    let inner =
      foreign "rocksdb_iter_key" (t @-> ptr Views.int_to_size_t @-> returning (ptr char))
    in
    fun t size -> if is_valid t then inner t size else raise InvalidIterator

  let get_key t =
    let res_size = allocate Views.int_to_size_t 0 in
    let res = get_key_raw t res_size in
    if (to_voidp res) = null
    then failwith (Printf.sprintf "could not get key, is_valid=%b" (is_valid t))
    else bigarray_of_ptr array1 (!@res_size) Bigarray.char res

  let get_key_string t =
    let res_size = allocate Views.int_to_size_t 0 in
    let res = get_key_raw t res_size in
    if (to_voidp res) = null
    then failwith (Printf.sprintf "could not get key, is_valid=%b" (is_valid t))
    else string_from_ptr res (!@ res_size)

  let get_value_raw =
    let inner =
      foreign "rocksdb_iter_value" (t @-> ptr Views.int_to_size_t @-> returning (ptr char))
    in
    fun t size -> if is_valid t then inner t size else raise InvalidIterator

  let get_value t =
    let res_size = allocate Views.int_to_size_t 0 in
    let res = get_value_raw t res_size in
    if (to_voidp res) = null
    then failwith (Printf.sprintf "could not get value, is_valid=%b" (is_valid t))
    else bigarray_of_ptr array1 (!@res_size) Bigarray.char res

  let get_value_string t =
    let res_size = allocate Views.int_to_size_t 0 in
    let res = get_value_raw t res_size in
    if (to_voidp res) = null
    then failwith (Printf.sprintf "could not get value, is_valid=%b" (is_valid t))
    else string_from_ptr res (!@ res_size)

  let get_error_raw =
    foreign
      "rocksdb_iter_get_error"
      (t @-> ptr string_opt @-> returning void)

  let get_error t =
    let err_pointer = allocate string_opt None in
    get_error_raw t err_pointer;
    !@err_pointer
end

and Transaction : Rocks_intf.TRANSACTION with type db := RocksDb.t and type iter := Iterator.t = struct
  module ReadOptions = Rocks_options.ReadOptions
  module WriteOptions = Rocks_options.WriteOptions
  module TransactionOptions = Rocks_options.TransactionOptions
  module Snapshot = Rocks_options.Snapshot

  let name = "transaction"
  let destructor  = "rocksdb_" ^ name ^ "_destroy"

  type db = t
  let db = t

  type nonrec t = t
  let t = t

  let txnbegin_raw =
    foreign
      "rocksdb_transaction_begin"
      (db @-> WriteOptions.t @-> TransactionOptions.t @-> ptr void @->
         returning t)

  let destroy = make_destroy t destructor

  let txnbegin_no_gc ?wopts ?txnopts db =
    let inner wopts txnopts =
      txnbegin_raw db wopts txnopts null in
    match wopts, txnopts with
      None, None -> TransactionOptions.with_t (fun txnopts ->
                        (WriteOptions.with_t (fun wopts ->
                             inner wopts txnopts)))
    | Some wopts, None -> TransactionOptions.with_t (inner wopts)
    | None, Some txnopts -> (WriteOptions.with_t (fun wopts ->
                                 inner wopts txnopts))
    | Some wopts, Some txnopts -> inner wopts txnopts

  let txnbegin ?wopts ?txnopts db =
    let t = txnbegin_no_gc ?wopts ?txnopts db in
    Gc.finalise destroy t;
    t

  let commit_raw =
    foreign "rocksdb_transaction_commit"
      (t @-> returning_error void)

  let commit t =
    with_err_pointer (commit_raw t)

  let rollback_raw =
    foreign "rocksdb_transaction_rollback"
      (t @-> returning_error void)

  let rollback t =
    with_err_pointer (rollback_raw t)

  let with_t db f =
    let t = txnbegin_no_gc db in
    finalize
      (fun () -> f t)
      (fun () -> destroy t)

  let put_raw =
    foreign
      "rocksdb_transaction_put"
      (t @->
       ptr char @-> Views.int_to_size_t @->
       ptr char @-> Views.int_to_size_t @->
       returning_error void)

  let put_raw_string =
    foreign
      "rocksdb_transaction_put"
      (t @->
       ocaml_string @-> Views.int_to_size_t @->
       ocaml_string @-> Views.int_to_size_t @->
       returning_error void)

  let put ?(key_pos=0) ?key_len ?(value_pos=0) ?value_len ?opts t key value =
    let open Bigarray.Array1 in
    let key_len = match key_len with None -> dim key - key_pos | Some len -> len in
    let value_len = match value_len with None -> dim value - value_pos | Some len -> len in
    with_err_pointer begin
        put_raw t
          (bigarray_start array1 key +@ key_pos) key_len
          (bigarray_start array1 value +@ value_pos) value_len
      end

  let put_string ?(key_pos=0) ?key_len ?(value_pos=0) ?value_len ?opts t key value =
    let key_len = match key_len with None -> String.length key - key_pos | Some len -> len in
    let value_len = match value_len with None -> String.length value - value_pos | Some len -> len in
    with_err_pointer begin
        put_raw_string t
          (ocaml_string_start key +@ key_pos) key_len
          (ocaml_string_start value +@ value_pos) value_len
      end

  let delete_raw =
    foreign
      "rocksdb_transaction_delete"
      (t @->
       ptr char @-> Views.int_to_size_t @->
       returning_error void)

  let delete_raw_string =
    foreign
      "rocksdb_transaction_delete"
      (t @->
       ocaml_string @-> Views.int_to_size_t @->
       returning_error void)

  let delete ?(pos=0) ?len ?opts t key =
    let open Bigarray.Array1 in
    let len = match len with None -> dim key - pos | Some len -> len in
    with_err_pointer (delete_raw t (bigarray_start array1 key +@ pos) len)

  let delete_string ?(pos=0) ?len ?opts t key =
    let len = match len with None -> String.length key - pos | Some len -> len in
    with_err_pointer (delete_raw_string t (ocaml_string_start key +@ pos) len)

  let get_raw =
    foreign
      "rocksdb_transaction_get"
      (t @-> ReadOptions.t @->
       ptr char @-> Views.int_to_size_t @-> ptr Views.int_to_size_t @->
       returning_error (ptr char))

  let get_raw_string =
    foreign
      "rocksdb_transaction_get"
      (t @-> ReadOptions.t @->
       ocaml_string @-> Views.int_to_size_t @-> ptr Views.int_to_size_t @->
       returning_error (ptr char))

  let get ?(pos=0) ?len ?opts t key =
    let open Bigarray.Array1 in
    let len = match len with None -> dim key - pos | Some len -> len in
    let inner opts =
      let res_size = allocate Views.int_to_size_t 0 in
      let res = with_err_pointer
          (get_raw t opts (bigarray_start array1 key +@ pos) len res_size)
      in
      if (to_voidp res) = null
      then None
      else begin
        let res' = bigarray_of_ptr array1 (!@res_size) Bigarray.char res in
        Gc.finalise (fun res -> free (to_voidp res)) res;
        Some res'
      end
    in
    match opts with
    | Some opts -> inner opts
    | None -> ReadOptions.with_t inner

  let get_string ?(pos=0) ?len ?opts t key =
    let len = match len with None -> String.length key - pos | Some len -> len in
    let inner opts =
      let res_size = allocate Views.int_to_size_t 0 in
      let res = with_err_pointer
          (get_raw_string t opts (ocaml_string_start key +@ pos) len res_size)
      in
      if (to_voidp res) = null
      then None
      else begin
        let res' = string_from_ptr res (!@ res_size) in
        Gc.finalise (fun res -> free (to_voidp res)) res;
        Some res'
      end
    in
    match opts with
    | Some opts -> inner opts
    | None -> ReadOptions.with_t inner

  let get_snapshot =
    foreign "rocksdb_transaction_get_snapshot"
      (t @-> returning Snapshot.t)

  let free_snapshot =
    foreign "rocksdb_free"
      (Snapshot.t @-> returning void)

  let create_iterator_no_gc =
    foreign
      "rocksdb_transaction_create_iterator"
      (t @-> ReadOptions.t @-> returning t)

  let destroy_iterator =
    let inner =
      foreign
        "rocksdb_iter_destroy"
        (t @-> returning void)
    in
    fun t -> inner t;
             t.valid <- false

  let create_iterator ?opts txn =
    let inner opts =
      let t = create_iterator_no_gc txn opts in
      Gc.finalise destroy_iterator t;
      t
    in
    match opts with
    | None -> ReadOptions.with_t inner
    | Some opts -> inner opts

  let with_iterator ?opts txn ~f =
    let inner opts =
      let t = create_iterator_no_gc txn opts in
      finalize
        (fun () -> f t)
        (fun () -> destroy_iterator t)
    in
    match opts with
    | None -> ReadOptions.with_t inner
    | Some opts -> inner opts
end

and RocksDb : Rocks_intf.ROCKS with type batch := WriteBatch.t = struct
  module ReadOptions = Rocks_options.ReadOptions
  module WriteOptions = Rocks_options.WriteOptions
  module FlushOptions = Rocks_options.FlushOptions
  module Options = Rocks_options.Options
  module Cache = Rocks_options.Cache
  module Snapshot = Rocks_options.Snapshot
  module BlockBasedTableOptions = Rocks_options.BlockBasedTableOptions
  module TransactionDbOptions = Rocks_options.TransactionDbOptions

  type nonrec t = t
  type batch

  let t = t

  let get_pointer = get_pointer

  let open_db_raw =
    foreign
      "rocksdb_open"
      (Options.t @-> string @-> ptr string_opt @-> returning t)

  let open_db_for_read_only_raw =
    foreign
      "rocksdb_open_for_read_only"
      (Options.t @-> string @-> Views.bool_to_uchar @-> ptr string_opt @-> returning t)

  let open_transactiondb_raw =
    foreign
      "rocksdb_transactiondb_open"
      (Options.t @-> TransactionDbOptions.t @-> string @-> ptr string_opt @-> returning t)

  let open_transactiondb ?opts ?txnopts name =
    let inner opts txndbopts = with_err_pointer (open_transactiondb_raw opts txndbopts name) in
    match opts, txnopts with
      None, None -> TransactionDbOptions.with_t (fun txndbopts ->
                        (Options.with_t (fun opts ->
                             inner opts txndbopts)))
    | Some opts, None -> TransactionDbOptions.with_t (inner opts)
    | None, Some txndbopts -> Options.with_t (fun opts ->
                                  inner opts txndbopts)
    | Some opts, Some txndbopts -> inner opts txndbopts

    let open_db ?opts name =
    match opts with
    | None -> Options.with_t (fun options -> with_err_pointer (open_db_raw options name))
    | Some opts -> with_err_pointer (open_db_raw opts name)

  let open_db_for_read_only ?opts name error_if_log_file_exists =
    match opts with
    | None -> Options.with_t (fun options -> with_err_pointer (open_db_for_read_only_raw options name error_if_log_file_exists))
    | Some opts -> with_err_pointer (open_db_for_read_only_raw opts name error_if_log_file_exists)

  let close =
    let inner =
      foreign
        "rocksdb_close"
        (t @-> returning void)
    in
    fun t ->
      inner t;
      t.valid <- false

  let with_db ?opts name ~f =
    let db = open_db ?opts name in
    finalize (fun () -> f db) (fun () -> close db)

  let put_raw =
    foreign
      "rocksdb_put"
      (t @-> WriteOptions.t @->
       ptr char @-> Views.int_to_size_t @->
       ptr char @-> Views.int_to_size_t @->
       returning_error void)

  let put_raw_string =
    foreign
      "rocksdb_put"
      (t @-> WriteOptions.t @->
       ocaml_string @-> Views.int_to_size_t @->
       ocaml_string @-> Views.int_to_size_t @->
       returning_error void)

  let put ?(key_pos=0) ?key_len ?(value_pos=0) ?value_len ?opts t key value =
    let open Bigarray.Array1 in
    let key_len = match key_len with None -> dim key - key_pos | Some len -> len in
    let value_len = match value_len with None -> dim value - value_pos | Some len -> len in
    let inner opts = with_err_pointer begin
        put_raw t opts
          (bigarray_start array1 key +@ key_pos) key_len
          (bigarray_start array1 value +@ value_pos) value_len
      end
    in
    match opts with
    | None -> WriteOptions.with_t inner
    | Some opts -> inner opts

  let put_string ?(key_pos=0) ?key_len ?(value_pos=0) ?value_len ?opts t key value =
    let key_len = match key_len with None -> String.length key - key_pos | Some len -> len in
    let value_len = match value_len with None -> String.length value - value_pos | Some len -> len in
    let inner opts = with_err_pointer begin
        put_raw_string t opts
          (ocaml_string_start key +@ key_pos) key_len
          (ocaml_string_start value +@ value_pos) value_len
      end
    in
    match opts with
    | None -> WriteOptions.with_t inner
    | Some opts -> inner opts

  let delete_raw =
    foreign
      "rocksdb_delete"
      (t @-> WriteOptions.t @->
       ptr char @-> Views.int_to_size_t @->
       returning_error void)

  let delete_raw_string =
    foreign
      "rocksdb_delete"
      (t @-> WriteOptions.t @->
       ocaml_string @-> Views.int_to_size_t @->
       returning_error void)

  let delete ?(pos=0) ?len ?opts t key =
    let open Bigarray.Array1 in
    let len = match len with None -> dim key - pos | Some len -> len in
    let inner opts =
      with_err_pointer (delete_raw t opts (bigarray_start array1 key +@ pos) len) in
    match opts with
    | None -> WriteOptions.with_t inner
    | Some opts -> inner opts

  let delete_string ?(pos=0) ?len ?opts t key =
    let len = match len with None -> String.length key - pos | Some len -> len in
    let inner opts =
      with_err_pointer (delete_raw_string t opts (ocaml_string_start key +@ pos) len) in
    match opts with
    | None -> WriteOptions.with_t inner
    | Some opts -> inner opts

  let write_raw =
    foreign
      "rocksdb_write"
      (t @-> WriteOptions.t @-> WriteBatch.t @->
       returning_error void)

  let write ?opts t wb =
    let inner opts = with_err_pointer (write_raw t opts wb) in
    match opts with
    | None -> WriteOptions.with_t inner
    | Some opts -> with_err_pointer (write_raw t opts wb)

  let get_raw =
    foreign
      "rocksdb_get"
      (t @-> ReadOptions.t @->
       ptr char @-> Views.int_to_size_t @-> ptr Views.int_to_size_t @->
       returning_error (ptr char))

  let get_raw_string =
    foreign
      "rocksdb_get"
      (t @-> ReadOptions.t @->
       ocaml_string @-> Views.int_to_size_t @-> ptr Views.int_to_size_t @->
       returning_error (ptr char))

  let get ?(pos=0) ?len ?opts t key =
    let open Bigarray.Array1 in
    let len = match len with None -> dim key - pos | Some len -> len in
    let inner opts =
      let res_size = allocate Views.int_to_size_t 0 in
      let res = with_err_pointer
          (get_raw t opts (bigarray_start array1 key +@ pos) len res_size)
      in
      if (to_voidp res) = null
      then None
      else begin
        let res' = bigarray_of_ptr array1 (!@res_size) Bigarray.char res in
        Gc.finalise (fun res -> free (to_voidp res)) res;
        Some res'
      end
    in
    match opts with
    | Some opts -> inner opts
    | None -> ReadOptions.with_t inner

  let get_string ?(pos=0) ?len ?opts t key =
    let len = match len with None -> String.length key - pos | Some len -> len in
    let inner opts =
      let res_size = allocate Views.int_to_size_t 0 in
      let res = with_err_pointer
          (get_raw_string t opts (ocaml_string_start key +@ pos) len res_size)
      in
      if (to_voidp res) = null
      then None
      else begin
        let res' = string_from_ptr res (!@ res_size) in
        Gc.finalise (fun res -> free (to_voidp res)) res;
        Some res'
      end
    in
    match opts with
    | Some opts -> inner opts
    | None -> ReadOptions.with_t inner

  let flush_raw =
      foreign
        "rocksdb_flush"
        (t @-> FlushOptions.t @-> returning_error void)

  let flush ?opts t =
    let inner opts = with_err_pointer (flush_raw t opts) in
    match opts with
    | None -> FlushOptions.with_t inner
    | Some opts -> inner opts

  let create_snapshot =
    foreign "rocksdb_create_snapshot"
      (t @-> returning Snapshot.t)

  let release_snapshot =
    foreign "rocksdb_release_snapshot"
      (t @-> Snapshot.t @-> returning void)

  module CheckpointObject = struct
    let name = "checkpoint_object"
    let constructor = "rocksdb_" ^ name ^ "_create"
    let destructor  = "rocksdb_" ^ name ^ "_destroy"

    type db = t
    let db = t

    type nonrec t = t
    let t = t

    let create_no_gc =
      foreign
        constructor
        (db @-> returning t)

    let destroy = make_destroy t destructor

    let create db =
      let t = create_no_gc db in
      Gc.finalise destroy t;
      t

    let with_t db f =
      let t = create_no_gc db in
      finalize
        (fun () -> f t)
        (fun () -> destroy t)
  end

  let checkpoint_create db dir log_size_for_flush =
    let checkpoint_create_raw =
      foreign "rocksdb_checkpoint_create"
        (CheckpointObject.t @-> string @->
           Views.int_to_uint64_t @-> ptr string_opt @-> returning void) in
    CheckpointObject.with_t db (fun checkpoint_object ->
        with_err_pointer (checkpoint_create_raw checkpoint_object dir
                                                log_size_for_flush))

  let property_value db name =
    (* Ugly hack. Is there a better way to retrieve string from C? *)
    let get = foreign "rocksdb_property_value"
                (t @-> string @-> returning (ptr_opt char)) in
    let free = foreign "free" ((ptr char) @-> returning void) in
    let strlen = foreign "strlen" ((ptr char) @-> returning int) in
    match get db name with
      Some p -> let value = string_from_ptr p ~length:(strlen p) in
                free p;
                Some value
    | None -> None
end

include RocksDb
