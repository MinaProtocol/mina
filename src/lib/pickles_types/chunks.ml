open Core_kernel

let hash_fold_array f s x = hash_fold_list f s (Array.to_list x)

[%%versioned
module Stable = struct
  module V1 = struct
    type 'a t = { data : 'a array }
    [@@unboxed] [@@deriving sexp, compare, hash, equal, yojson, hlist]
  end
end]

(* For local use only, when we know we don't need to copy *)
let of_array_unsafe data = { data }

let init ~origin ~len ~f =
  ( if len <= 0 then
    let msg =
      Printf.sprintf "Chunks.%s requires a positive integer (given %d)" origin
        len
    in
    invalid_arg msg ) ;
  { data = Array.init len ~f }

let of_array a =
  init ~origin:__FUNCTION__ ~len:(Array.length a) ~f:(Array.get a)

let create ~len v = init ~origin:__FUNCTION__ ~len ~f:(fun _ -> v)

let length { data } = Array.length data

let get { data } idx =
  if idx < 0 || idx >= Array.length data then None
  else Some (Array.unsafe_get data idx)

let get_exn chunk idx =
  match get chunk idx with
  | Some v ->
      v
  | None ->
      let msg =
        Printf.sprintf
          "Chunks.get: index is out_of_bounds. Given %d, while index must be \
           in interval [0,%d["
          idx (length chunk)
      in
      invalid_arg msg

let hd { data } = Array.unsafe_get data 0

let map { data } ~f = Array.map ~f data |> of_array_unsafe

let iter { data } ~f = Array.iter ~f data

let map2_exn { data } { data = data' } ~f =
  Array.map2_exn ~f data data' |> of_array_unsafe

let fold { data } ~init ~f = Array.fold data ~init ~f

let to_list { data } = Array.to_list data

let typ ~len base =
  let data = Snarky_backendless.Typ.array ~length:len base in
  Snarky_backendless.Typ.of_hlistable [ data ] ~var_to_hlist:to_hlist
    ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
