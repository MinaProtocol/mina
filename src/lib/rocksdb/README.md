# RocksDB for Mina

This library provides OCaml bindings for the RocksDB key-value store, tailored
for use within the Mina protocol.

## Overview

RocksDB is a high-performance embedded database for key-value data, optimized for
fast storage. This library provides an OCaml interface to use RocksDB within the
Mina protocol.

## Features

- Simple API for basic operations (get, set, delete)
- Batch operations support
- Checkpoint functionality
- Iteration capabilities
- Thread-safe access

## Usage Examples

You can experiment with the library in a REPL session using `dune utop`:

```
$ cd /path/to/mina
$ dune utop src/lib/rocksdb
```

### Basic Operations

```ocaml
# open Core;;
# open Rocksdb.Database;;

(* Create a temporary database *)
# let temp_dir = Filename.temp_dir "rocksdb_example" "";;
# let db = create temp_dir;;

(* Create some key-value pairs *)
# let key1 = Bigstring.of_string "key1";;
# let val1 = Bigstring.of_string "value1";;
# let key2 = Bigstring.of_string "key2";;
# let val2 = Bigstring.of_string "value2";;

(* Set key-value pairs *)
# set db ~key:key1 ~data:val1;;
# set db ~key:key2 ~data:val2;;

(* Retrieve values *)
# let retrieved1 = get db ~key:key1;;
# Bigstring.to_string (Option.value_exn retrieved1);;
- : string = "value1"

(* Get multiple values at once *)
# let keys = [key1; key2; Bigstring.of_string "nonexistent"];;
# let results = get_batch db ~keys;;
# List.map results ~f:(Option.map ~f:Bigstring.to_string);;
- : string option list = [Some "value1"; Some "value2"; None]

(* Convert database to association list *)
# let all_pairs = to_alist db;;
# List.map all_pairs ~f:(fun (k, v) ->
    (Bigstring.to_string k, Bigstring.to_string v));;
- : (string * string) list = [("key1", "value1"); ("key2", "value2")]

(* Clean up *)
# close db;;
```

### Batch Operations

```ocaml
# let db = create temp_dir;;

(* Create batch updates *)
# let key_data_pairs = [
    (Bigstring.of_string "batch1", Bigstring.of_string "value1");
    (Bigstring.of_string "batch2", Bigstring.of_string "value2");
  ];;

# set_batch db ~key_data_pairs;;

(* Verify the batch update *)
# let all_pairs = to_alist db;;
# List.map all_pairs ~f:(fun (k, v) ->
    (Bigstring.to_string k, Bigstring.to_string v));;

(* Delete keys in a batch *)
# let remove_keys = [Bigstring.of_string "batch1"];;
# set_batch db ~remove_keys ~key_data_pairs:[];;

(* Verify deletion *)
# let all_pairs = to_alist db;;
# List.map all_pairs ~f:(fun (k, v) ->
    (Bigstring.to_string k, Bigstring.to_string v));;

# close db;;
```

### Creating Checkpoints

```ocaml
# let db = create temp_dir;;
# set db ~key:(Bigstring.of_string "key1") ~data:(Bigstring.of_string "value1");;

(* Create a checkpoint *)
# let checkpoint_dir = Filename.temp_dir "rocksdb_checkpoint" "";;
# let checkpoint_db = create_checkpoint db checkpoint_dir;;

(* Add different data to each database *)
# set db ~key:(Bigstring.of_string "key2") ~data:(Bigstring.of_string "main_db");;
# set checkpoint_db ~key:(Bigstring.of_string "key2")
    ~data:(Bigstring.of_string "checkpoint_db");;

(* The databases now have different content *)
# let main_pairs = to_alist db;;
# let checkpoint_pairs = to_alist checkpoint_db;;

# List.map main_pairs ~f:(fun (k, v) ->
    (Bigstring.to_string k, Bigstring.to_string v));;
# List.map checkpoint_pairs ~f:(fun (k, v) ->
    (Bigstring.to_string k, Bigstring.to_string v));;

# close db;;
# close checkpoint_db;;
```

### Iteration

```ocaml
# let db = create temp_dir;;
# List.iter [("a", "1"); ("b", "2"); ("c", "3")]
    ~f:(fun (k, v) ->
      set db ~key:(Bigstring.of_string k) ~data:(Bigstring.of_string v));;

(* Use foldi to iterate with indices *)
# let result = foldi db ~init:[] ~f:(fun i acc ~key ~data ->
    (i, Bigstring.to_string key, Bigstring.to_string data) :: acc);;
# List.rev result;;
- : (int * string * string) list = [(0, "a", "1"); (1, "b", "2"); (2, "c", "3")]

(* Use fold_until to stop iteration early *)
# let result = fold_until db ~init:[]
    ~f:(fun acc ~key ~data ->
      let k = Bigstring.to_string key in
      let v = Bigstring.to_string data in
      if k = "b" then
        Stop (Some (k, v))
      else
        Continue ((k, v) :: acc))
    ~finish:(fun acc -> acc);;
# result;;

# close db;;
```

## Thread Safety

RocksDB operations are thread-safe. Multiple threads can access the same database
concurrently.

## Testing

Run the test suite with:

```
dune runtest src/lib/rocksdb
```
