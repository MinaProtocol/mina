open Core_kernel
module Nat = Nat

module type Nat_intf = Nat.Intf

type z = Nat.z

type 'a s = 'a Nat.s

type 'a nat = 'a Nat.t = Z : z nat | S : 'n nat -> 'n s nat

module T = struct
  type ('a, _) t = [] : ('a, z) t | ( :: ) : 'a * ('a, 'n) t -> ('a, 'n s) t
end

include T

let rec iter : type a n. (a, n) t -> f:(a -> unit) -> unit =
 fun t ~f -> match t with [] -> () | x :: xs -> f x ; iter xs ~f

let rec iter2 : type a b n. (a, n) t -> (b, n) t -> f:(a -> b -> unit) -> unit
    =
 fun t1 t2 ~f ->
  match (t1, t2) with
  | [], [] ->
      ()
  | x :: xs, y :: ys ->
      f x y ; iter2 xs ys ~f

let rec map2 : type a b c n.
    (a, n) t -> (b, n) t -> f:(a -> b -> c) -> (c, n) t =
 fun t1 t2 ~f ->
  match (t1, t2) with
  | [], [] ->
      []
  | x :: xs, y :: ys ->
      f x y :: map2 xs ys ~f

let rec hhead_off : type xs n.
       (xs, n s) Hlist0.H1_1(T).t
    -> xs Hlist0.HlistId.t * (xs, n) Hlist0.H1_1(T).t =
 fun xss ->
  match xss with
  | [] ->
      ([], [])
  | (x :: xs) :: xss ->
      let hds, tls = hhead_off xss in
      (x :: hds, xs :: tls)

let rec mapn : type xs y n.
    (xs, n) Hlist0.H1_1(T).t -> f:(xs Hlist0.HlistId.t -> y) -> (y, n) t =
 fun xss ~f ->
  match xss with
  | [] :: _xss ->
      []
  | (_ :: _) :: _ ->
      let hds, tls = hhead_off xss in
      let y = f hds in
      let ys = mapn tls ~f in
      y :: ys
  | [] ->
      failwith "mapn: Empty args"

let zip xs ys = map2 xs ys ~f:(fun x y -> (x, y))

let rec to_list : type a n. (a, n) t -> a list =
 fun t -> match t with [] -> [] | x :: xs -> x :: to_list xs

let sexp_of_t a _ v = List.sexp_of_t a (to_list v)

let to_array t = Array.of_list (to_list t)

let rec length : type a n. (a, n) t -> n nat = function
  | [] ->
      Z
  | _ :: xs ->
      S (length xs)

let rec init : type a n. int -> n nat -> f:(int -> a) -> (a, n) t =
 fun i n ~f -> match n with Z -> [] | S n -> f i :: init (i + 1) n ~f

let init n ~f = init 0 n ~f

let rec fold_map : type acc a b n.
    (a, n) t -> f:(acc -> a -> acc * b) -> init:acc -> acc * (b, n) t =
 fun t ~f ~init ->
  match t with
  | [] ->
      (init, [])
  | x :: xs ->
      let acc, y = f init x in
      let res, ys = fold_map xs ~f ~init:acc in
      (res, y :: ys)

let rec map : type a b n. (a, n) t -> f:(a -> b) -> (b, n) t =
 fun t ~f -> match t with [] -> [] | x :: xs -> f x :: map xs ~f

let mapi (type a b m) (t : (a, m) t) ~(f : int -> a -> b) =
  let rec go : type n. int -> (a, n) t -> (b, n) t =
   fun i t -> match t with [] -> [] | x :: xs -> f i x :: go (i + 1) xs
  in
  go 0 t

let unzip ts = (map ts ~f:fst, map ts ~f:snd)

let unzip3 ts =
  (map ts ~f:Tuple3.get1, map ts ~f:Tuple3.get2, map ts ~f:Tuple3.get3)

type _ e = T : ('a, 'n) t -> 'a e

let rec of_list : type a. a list -> a e = function
  | [] ->
      T []
  | x :: xs ->
      let (T xs) = of_list xs in
      T (x :: xs)

let to_sequence : type a n. (a, n) t -> a Sequence.t =
 fun t ->
  Sequence.unfold ~init:(T t) ~f:(fun (T t) ->
      match t with [] -> None | x :: xs -> Some (x, T xs) )

let rec of_list_and_length_exn : type a n. a list -> n nat -> (a, n) t =
 fun xs n ->
  match (xs, n) with
  | [], Z ->
      []
  | x :: xs, S n ->
      x :: of_list_and_length_exn xs n
  | _ ->
      failwith "Vector: Length mismatch"

let of_list_and_length xs n =
  Option.try_with (fun () -> of_list_and_length_exn xs n)

let of_array_and_length_exn : type a n. a array -> n nat -> (a, n) t =
 fun xs n ->
  if Array.length xs <> Nat.to_int n then
    failwithf "of_array_and_length_exn: got %d (expected %d)" (Array.length xs)
      (Nat.to_int n) () ;
  init n ~f:(Array.get xs)

let rec take_from_list : type a n. a list -> n nat -> (a, n) t =
 fun xs n ->
  match (xs, n) with
  | _, Z ->
      []
  | x :: xs, S n ->
      x :: take_from_list xs n
  | _ ->
      failwith "take_from_list: Not enough to take"

let rec fold : type acc a n. (a, n) t -> f:(acc -> a -> acc) -> init:acc -> acc
    =
 fun t ~f ~init ->
  match t with
  | [] ->
      init
  | x :: xs ->
      let acc = f init x in
      fold xs ~f ~init:acc

let for_all : type a n. (a, n) t -> f:(a -> bool) -> bool =
 fun v ~f ->
  with_return (fun {return} ->
      iter v ~f:(fun x -> if not (f x) then return false) ;
      true )

let foldi t ~f ~init =
  snd (fold t ~f:(fun (i, acc) x -> (i + 1, f i acc x)) ~init:(0, init))

let reduce (init :: xs) ~f = fold xs ~f ~init

let reduce_exn (type n) (t : (_, n) t) ~f =
  match t with
  | [] ->
      failwith "reduce_exn: empty list"
  | init :: xs ->
      fold xs ~f ~init

module L = struct
  type 'a t = 'a list [@@deriving yojson]
end

module type Yojson_intf1 = sig
  type 'a t

  val to_yojson : ('a -> Yojson.Safe.t) -> 'a t -> Yojson.Safe.t

  val of_yojson :
       (Yojson.Safe.t -> 'a Ppx_deriving_yojson_runtime.error_or)
    -> Yojson.Safe.t
    -> 'a t Ppx_deriving_yojson_runtime.error_or
end

module Make = struct
  module Cata (F : sig
    type _ t

    val pair : 'a t -> 'b t -> ('a * 'b) t

    val cnv : ('a -> 'b) -> ('b -> 'a) -> 'b t -> 'a t

    val unit : unit t
  end) =
  struct
    let rec f : type n a. n nat -> a F.t -> (a, n) t F.t =
     fun n tc ->
      match n with
      | Z ->
          F.cnv (function [] -> ()) (fun () -> []) F.unit
      | S n ->
          let tl = f n tc in
          F.cnv
            (function x :: xs -> (x, xs))
            (fun (x, xs) -> x :: xs)
            (F.pair tc tl)
  end

  module Sexpable (N : Nat_intf) : Sexpable.S1 with type 'a t := ('a, N.n) t =
  struct
    let sexp_of_t f t = List.sexp_of_t f (to_list t)

    let t_of_sexp f s = of_list_and_length_exn (List.t_of_sexp f s) N.n
  end

  module Yojson (N : Nat_intf) : Yojson_intf1 with type 'a t := ('a, N.n) t =
  struct
    let to_yojson f t = L.to_yojson f (to_list t)

    let of_yojson f s =
      Result.map (L.of_yojson f s) ~f:(Fn.flip of_list_and_length_exn N.n)
  end

  module Binable (N : Nat_intf) : Binable.S1 with type 'a t := ('a, N.n) t =
  struct
    open Bin_prot

    module Tc = Cata (struct
      type 'a t = 'a Type_class.t

      let pair = Type_class.bin_pair

      let cnv t = Type_class.cnv Fn.id t

      let unit = Type_class.bin_unit
    end)

    module Shape = Cata (struct
      type _ t = Shape.t

      let pair = Shape.bin_shape_pair

      let cnv _ _ = Fn.id

      let unit = Shape.bin_shape_unit
    end)

    module Size = Cata (struct
      type 'a t = 'a Size.sizer

      let pair = Size.bin_size_pair

      let cnv a_to_b _b_to_a b_sizer a = b_sizer (a_to_b a)

      let unit = Size.bin_size_unit
    end)

    module Write = Cata (struct
      type 'a t = 'a Write.writer

      let pair = Write.bin_write_pair

      let cnv a_to_b _b_to_a b_writer buf ~pos a = b_writer buf ~pos (a_to_b a)

      let unit = Write.bin_write_unit
    end)

    module Writer = Cata (struct
      type 'a t = 'a Type_class.writer

      let pair = Type_class.bin_writer_pair

      let cnv a_to_b _b_to_a b_writer = Type_class.cnv_writer a_to_b b_writer

      let unit = Type_class.bin_writer_unit
    end)

    module Reader = Cata (struct
      type 'a t = 'a Type_class.reader

      let pair = Type_class.bin_reader_pair

      let cnv _a_to_b b_to_a b_reader = Type_class.cnv_reader b_to_a b_reader

      let unit = Type_class.bin_reader_unit
    end)

    module Read = Cata (struct
      type 'a t = 'a Read.reader

      let pair = Read.bin_read_pair

      let cnv _a_to_b b_to_a b_reader buf ~pos_ref =
        b_to_a (b_reader buf ~pos_ref)

      let unit = Read.bin_read_unit
    end)

    let bin_shape_t sh = Shape.f N.n sh

    let bin_size_t sz = Size.f N.n sz

    let bin_write_t wr = Write.f N.n wr

    let bin_writer_t wr = Writer.f N.n wr

    let bin_t tc = Tc.f N.n tc

    let bin_reader_t re = Reader.f N.n re

    let bin_read_t re = Read.f N.n re

    let __bin_read_t__ _f _buf ~pos_ref _vint =
      Common.raise_variant_wrong_type "vector" !pos_ref
  end
end

type ('a, 'n) vec = ('a, 'n) t

module With_length (N : Nat.Intf) = struct
  type 'a t = ('a, N.n) vec

  let compare c t1 t2 = Base.List.compare c (to_list t1) (to_list t2)

  let hash_fold_t f s v = List.hash_fold_t f s (to_list v)

  let equal f t1 t2 = List.equal f (to_list t1) (to_list t2)

  include Make.Yojson (N)
  include Make.Sexpable (N)

  let map (t : 'a t) = map t

  let of_list_exn : 'a list -> 'a t = fun ls -> of_list_and_length_exn ls N.n

  let to_list : 'a t -> 'a list = to_list
end

let rec typ' : type f var value n.
       ((var, value, f) Snarky_backendless.Typ.t, n) t
    -> ((var, n) t, (value, n) t, f) Snarky_backendless.Typ.t =
  let open Snarky_backendless.Typ in
  fun elts ->
    match elts with
    | elt :: elts ->
        let tl = typ' elts in
        let there = function x :: xs -> (x, xs) in
        let back (x, xs) = x :: xs in
        transport (elt * tl) ~there ~back |> transport_var ~there ~back
    | [] ->
        let there [] = () in
        let back () = [] in
        transport (unit ()) ~there ~back |> transport_var ~there ~back

let typ elt n = typ' (init n ~f:(fun _ -> elt))

let rec append : type n m n_m a.
    (a, n) t -> (a, m) t -> (n, m, n_m) Nat.Adds.t -> (a, n_m) t =
 fun t1 t2 adds ->
  match (t1, adds) with
  | [], Z ->
      t2
  | x :: t1, S adds ->
      x :: append t1 t2 adds

let rec transpose : type a n m. ((a, n) t, m) t -> ((a, m) t, n) t =
 fun xss ->
  match xss with
  | [] ->
      failwith "transpose: empty list"
  | [] :: _ ->
      []
  | (_ :: _) :: _ ->
      let heads, tails = unzip (map xss ~f:(fun (x :: xs) -> (x, xs))) in
      heads :: transpose tails

let rec trim : type a n m. (a, m) t -> (n, m) Nat.Lte.t -> (a, n) t =
 fun v p -> match (v, p) with _, Z -> [] | x :: xs, S p -> x :: trim xs p

let rec extend_exn : type n m a. (a, n) t -> m Nat.t -> a -> (a, m) t =
 fun v m default ->
  match (v, m) with
  | [], Z ->
      []
  | [], S n ->
      default :: extend_exn [] n default
  | _x :: _xs, Z ->
      failwith "extend_exn: list too long"
  | x :: xs, S m ->
      let extended = extend_exn xs m default in
      x :: extended

let rec extend : type a n m.
    (a, n) t -> (n, m) Nat.Lte.t -> m Nat.t -> a -> (a, m) t =
 fun v p m default ->
  match (v, p, m) with
  | _, Z, Z ->
      []
  | _, Z, S m ->
      default :: extend [] Z m default
  | x :: xs, S p, S m ->
      x :: extend xs p m default

module With_version (N : Nat.Intf) = struct
  module type S = sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        type 'a t = ('a, N.n) vec
        [@@deriving compare, yojson, sexp, hash, equal]
      end
    end]

    val map : 'a t -> f:('a -> 'b) -> 'b t

    val of_list_exn : 'a list -> 'a t

    val to_list : 'a t -> 'a list
  end
end

module Vector_2 = struct
  module T = With_length (Nat.N2)

  [%%versioned_binable
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type 'a t = ('a, Nat.N2.n) vec

      include Make.Binable (Nat.N2)

      include (T : module type of T with type 'a t := 'a t)

      module Tests = struct
        (* TODO *)
      end
    end
  end]

  include T

  let _ =
    let _f : type a. unit -> (a t, a Stable.Latest.t) Type_equal.t =
     fun () -> Type_equal.T
    in
    ()
end

module Vector_4 = struct
  module T = With_length (Nat.N4)

  [%%versioned_binable
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type 'a t = ('a, Nat.N4.n) vec

      include Make.Binable (Nat.N4)

      include (T : module type of T with type 'a t := 'a t)

      module Tests = struct
        (* TODO *)
      end
    end
  end]

  include T

  let _ =
    let _f : type a. unit -> (a t, a Stable.Latest.t) Type_equal.t =
     fun () -> Type_equal.T
    in
    ()
end

module Vector_8 = struct
  module T = With_length (Nat.N8)

  [%%versioned_binable
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type 'a t = ('a, Nat.N8.n) vec

      include Make.Binable (Nat.N8)

      include (T : module type of T with type 'a t := 'a t)

      module Tests = struct
        (* TODO *)
      end
    end
  end]

  include T

  let _ =
    let _f : type a. unit -> (a t, a Stable.Latest.t) Type_equal.t =
     fun () -> Type_equal.T
    in
    ()
end

module Vector_17 = struct
  module T = With_length (Nat.N17)

  [%%versioned_binable
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type 'a t = ('a, Nat.N17.n) vec

      include Make.Binable (Nat.N17)

      include (T : module type of T with type 'a t := 'a t)

      module Tests = struct
        (* TODO *)
      end
    end
  end]

  include T

  let _ =
    let _f : type a. unit -> (a t, a Stable.Latest.t) Type_equal.t =
     fun () -> Type_equal.T
    in
    ()
end

module Vector_18 = struct
  module T = With_length (Nat.N18)

  [%%versioned_binable
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type 'a t = ('a, Nat.N18.n) vec

      include Make.Binable (Nat.N18)

      include (T : module type of T with type 'a t := 'a t)

      module Tests = struct
        (* TODO *)
      end
    end
  end]

  include T

  let _ =
    let _f : type a. unit -> (a t, a Stable.Latest.t) Type_equal.t =
     fun () -> Type_equal.T
    in
    ()
end
