open Core

module type S = sig
  type t [@@deriving sexp, bin_io]

  type key

  val create : unit -> t

  val add : t -> key -> unit

  val remove : t -> key -> unit

  val mem : t -> key -> bool

  val get_random : t -> key option

  val length : t -> int

  val gen : t Quickcheck.Generator.t
end

module Make (Key : sig
  type t [@@deriving sexp, bin_io]

  val gen : t Quickcheck.Generator.t

  include Hashable.S_binable with type t := t
end) : S with type key := Key.t = struct
  type t = {keys: Key.t Dyn_array.t; key_to_loc: Int.t Key.Table.t}
  [@@deriving sexp, bin_io]

  let create () = {keys= Dyn_array.create (); key_to_loc= Key.Table.create ()}

  let add t key =
    if not (Key.Table.mem t.key_to_loc key) then (
      Key.Table.set t.key_to_loc key (Dyn_array.length t.keys) ;
      Dyn_array.add t.keys key )
    else ()

  let mem t = Key.Table.mem t.key_to_loc

  let get_random t =
    if Dyn_array.empty t.keys then None
    else
      let random_index = Random.int (Dyn_array.length t.keys) in
      Some (Dyn_array.get t.keys random_index)

  let remove t key =
    Option.iter (Key.Table.find_and_remove t.key_to_loc key)
      ~f:(fun delete_index ->
        let last_elem = Dyn_array.last t.keys in
        Dyn_array.set t.keys delete_index last_elem ;
        Dyn_array.delete_last t.keys )

  let length t = DynArray.length t.keys

  let gen =
    let open Quickcheck.Generator.Let_syntax in
    let%map sample_list = Quickcheck.Generator.list Key.gen in
    let t = create () in
    List.iter sample_list ~f:(add t) ;
    t

  let%test_unit "for all s, x : add s x -> mem s x" =
    Quickcheck.test ~sexp_of:[%sexp_of: t * Key.t]
      (Quickcheck.Generator.tuple2 gen Key.gen) ~f:(fun (s, x) ->
        add s x ;
        assert (mem s x) )

  let%test_unit "for all s, x: add s x & remove s x -> !mem s x" =
    Quickcheck.test ~sexp_of:[%sexp_of: t * Key.t]
      (Quickcheck.Generator.tuple2 gen Key.gen) ~f:(fun (s, x) ->
        add s x ;
        remove s x ;
        assert (not (mem s x)) )
end

let%test_module "random set test" =
  ( module struct
    module Int_random_set = Make (Int)

    let%test "simulate random numbers from 0 to 10" =
      Test_util.with_randomness 123456789 (fun () ->
          let s = Int_random_set.create () in
          let upper_bound = 10 in
          let sample_size = 100000 in
          List.iter
            (List.range 1 (upper_bound + 1))
            ~f:(fun i -> Int_random_set.add s i) ;
          let sampled_values =
            let open List in
            range 0 sample_size
            >>| fun _ -> Option.value_exn (Int_random_set.get_random s)
          in
          let summed_values = List.fold sampled_values ~init:0 ~f:( + ) in
          let sampled_expectation =
            Int.to_float summed_values /. Int.to_float sample_size
          in
          let expected_expectation =
            Int.to_float (upper_bound * (upper_bound + 1) / 2)
            /. Int.to_float upper_bound
          in
          let episilon =
            Float.abs (sampled_expectation -. expected_expectation)
          in
          episilon <. 0.1 )
  end )
