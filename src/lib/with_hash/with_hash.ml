open Core_kernel

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V1 = struct
    type ('a, 'h) t = ('a, 'h) Mina_wire_types.With_hash.V1.t =
      { data : 'a; hash : 'h }
    [@@deriving annot, sexp, equal, compare, hash, yojson, fields]

    let to_latest data_latest hash_latest { data; hash } =
      { data = data_latest data; hash = hash_latest hash }
  end
end]

type ('a, 'h) t = ('a, 'h) Stable.Latest.t = { data : 'a; hash : 'h }
[@@deriving annot, compare, equal, fields, hash, sexp, yojson]

let map t ~f = { t with data = f t.data }

let map_hash t ~f = { t with hash = f t.hash }

let of_data data ~hash_data = { data; hash = hash_data data }

(** Set for [('a, 'h) t] that assumes the hash ['h] is cryptographically sound, and data is ignored
*)
module Set (Hash : Comparable.S) :
  Mina_stdlib.Generic_set.S1 with type 'a el := ('a, Hash.t) t = struct
  type 'a t = 'a Hash.Map.t

  let empty = Hash.Map.empty

  let add t { data; hash } =
    match Hash.Map.add t ~key:hash ~data with `Ok t' -> t' | `Duplicate -> t

  let union =
    Hash.Map.merge ~f:(fun ~key:_ -> function
      | `Both (_, b) -> Some b | `Left a -> Some a | `Right b -> Some b )

  let iter t ~f = Hash.Map.iteri t ~f:(fun ~key ~data -> f { data; hash = key })

  (* Ignoring values, comparing just on keys *)
  let equal a b = Hash.Map.equal (fun _ _ -> true) a b

  let of_list = List.fold ~init:empty ~f:add

  let length = Hash.Map.length

  let singleton { data; hash } = Hash.Map.singleton hash data
end
