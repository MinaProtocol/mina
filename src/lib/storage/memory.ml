open Core
open Async
module Location = String

type location = Location.t [@@deriving sexp]

include Checked_data

module Controller = struct
  type nonrec 'a t =
    {logger: Logger.t; tc: 'a Binable.m; mem: 'a t Location.Table.t}

  let create ~logger tc = {logger; tc; mem= Location.Table.create ()}
end

let load_with_checksum (type a) (c : a Controller.t) location =
  Deferred.return
    ( match Location.Table.find c.mem location with
    | Some t -> Ok t
    | None -> Error `No_exist )

let load c location =
  Deferred.Result.map (load_with_checksum c location) ~f:(fun t -> t.data)

let store_with_checksum (type a) (c : a Controller.t) location (data : a) =
  let checksum = md5 c.tc data in
  Deferred.return
    ( Location.Table.set c.mem ~key:location ~data:{checksum; data} ;
      checksum )

let store (c : 'a Controller.t) location data : unit Deferred.t =
  store_with_checksum c location data >>| ignore
