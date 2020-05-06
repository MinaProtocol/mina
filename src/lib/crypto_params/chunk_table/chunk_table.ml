(* chunk_table.ml -- wrapper around table of memoized curve points in Pedersen hash *)

open Core_kernel
module Group = Snarky_bn382_backend.G

type t = {table_data: Group.t Array.t Array.t} [@@deriving bin_io]

(** creates chunk table *)
let create table_data = {table_data}
