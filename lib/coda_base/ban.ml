open Core
open Async
open Banlist
open Unsigned

module type Elem_intf = sig
  type t

  val serialize : t -> Bigstring.t

  val deserialize : Bigstring.t -> t
end

module Make_rocks (Key : Elem_intf) (Value : Elem_intf) = struct
  type t = Rocksdb_database.t

  let create ~directory = Rocksdb_database.create ~directory

  let close = Rocksdb_database.destroy

  let get t ~key =
    let open Option.Let_syntax in
    let%map serialized_value = Rocksdb_database.get t (Key.serialize key) in
    Value.deserialize serialized_value

  let set t ~key ~data =
    Rocksdb_database.set t (Key.serialize key) (Value.serialize data)

  let remove t ~key = Rocksdb_database.delete t (Key.serialize key)
end

module Make_serializable (Elem : Binable.S) = struct
  type t = Elem.t

  let serialize t =
    let size = Elem.bin_size_t t in
    let buf = Bigstring.create size in
    ignore (Elem.bin_write_t buf ~pos:0 t) ;
    buf

  let deserialize buf = Elem.bin_read_t buf ~pos_ref:(ref 0)
end

module Punishment_record = struct
  type time = Time.t

  include Banlist.Punishment.Record.Make (struct
    let duration = Time.Span.of_day 1.0
  end)
end

module Serializable_host_and_port = Make_serializable (Host_and_port)
module Serializable_punishment_record = Make_serializable (Punishment_record)
module Punished_db =
  Punished_db.Make (Host_and_port) (Time) (Punishment_record)
    (Make_rocks (Serializable_host_and_port) (Serializable_punishment_record))

let ban_threshold = 100

module Score_mechanism = struct
  open Offense

  let score offense =
    Score.of_int
      ( match offense with
      | Failed_to_connect -> ban_threshold + 1
      | Send_bad_hash -> ban_threshold / 2
      | Send_bad_aux -> ban_threshold / 4 )
end

module Suspicious_db = Make_rocks (Serializable_host_and_port) (Score)

module Banlist = struct
  include Make (Host_and_port) (Punishment_record) (Suspicious_db)
            (Punished_db)
            (Score_mechanism)

  let create = create ~ban_threshold
end

include Banlist
