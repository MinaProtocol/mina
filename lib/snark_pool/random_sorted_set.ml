open Core

module type S = sig
  (* include Random_set.S *)
  type t [@@deriving sexp, bin_io]

  type key

  val create : unit -> t

  val add : t -> key -> unit

  val remove : t -> key -> unit

  val mem : t -> key -> bool

  val get_random : t -> key -> key option

end

module Make (Key : sig
  type t [@@deriving sexp, bin_io, compare]

  val gen : t Quickcheck.Generator.t

  include Hashable.S_binable with type t := t
end) : S with type key := Key.t = struct

  module Sorted_array = struct
    include Dyn_array

    let rec get_index t key ~start_index ~end_index =
      if start_index >= end_index then start_index else
        let mid = (start_index + end_index) / 2 in
        let mid_value = Dyn_array.get t mid in
        if (key = mid_value) then mid else 
        (if (key >= mid_value) then get_index t key (mid + 1) end_index else
        get_index t key start_index mid)
  end

  type t = Key.t Dyn_array.t [@@deriving sexp, bin_io]

  let create () = Dyn_array.create ()

  let is_match (t: t) (key: Key.t) index = index < (Sorted_array.length t) && ((Sorted_array.get t index) = key)

  let add (t: t) (key: Key.t) = if Dyn_array.empty t then Dyn_array.add t key else
        let insert_index = Sorted_array.get_index t key 0 (Dyn_array.length t) in
        if not @@ is_match t key insert_index then Sorted_array.insert t insert_index key

  let mem (t: t) (key: Key.t) = 
    Sorted_array.get_index t key 0 (Sorted_array.length t) |>
      is_match t key

  let remove (t: t) (key : Key.t) =
      let delete_index = Sorted_array.get_index t key 0 (Dyn_array.length t) in
        if is_match t key delete_index then Sorted_array.delete t delete_index

  (* let get_random (t: t) (key: Key.t) = *)


  let gen =
    let open Quickcheck in
    let open Quickcheck.Generator.Let_syntax in
    let%map sample_list = Quickcheck.Generator.list Key.gen in
    let t = create () in
    List.iter sample_list ~f:(add t) ;
    t
  let%test_unit "for all s : is_sorted s" =
  Quickcheck.test ~sexp_of:[%sexp_of : t]
    gen ~f: ([%test_pred: t] (fun s ->
      Sorted_array.to_array s |> Array.is_sorted ~compare:Key.compare
      ))

  let%test_unit "for all s, x: add s x -> mem s x" = 
    Quickcheck.test ~sexp_of:[%sexp_of : t * Key.t]
    (Quickcheck.Generator.tuple2 gen Key.gen) ~f: ([%test_pred: t * Key.t ] (fun (s, key) ->
      add s key;
      mem s key
      ))

  let%test_unit "for all s, x: add s x; remove s x-> not mem s x" = 
    Quickcheck.test ~sexp_of:[%sexp_of : t * Key.t]
    (Quickcheck.Generator.tuple2 gen Key.gen) ~f: ([%test_pred: t * Key.t ] (fun (s, key) ->
      add s key;
      remove s key;
      not @@ mem s key
      ))
end

let%test_module "random sorted set test" =
  ( module struct
  module Int_random_sorted_set = Make (Int)
  end )
