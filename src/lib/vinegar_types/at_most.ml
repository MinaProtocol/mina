type ('a, _) t =
  | [] : ('a, 'n) t
  | ( :: ) : 'a * ('a, 'n) t -> ('a, 'n Nat.s) t

let rec to_list : type a n. (a, n) t -> a list = function
  | [] ->
      []
  | x :: xs ->
      x :: to_list xs

let rec _length : type a n. (a, n) t -> int = function
  | [] ->
      0
  | _ :: xs ->
      1 + _length xs

let rec to_vector : type a n. (a, n) t -> a Vector.e = function
  | [] ->
      T []
  | x :: xs ->
      let (T xs) = to_vector xs in
      T (x :: xs)

let rec of_vector : type a n m. (a, n) Vector.t -> (n, m) Nat.Lte.t -> (a, m) t
    =
 fun v p ->
  match (v, p) with [], _ -> [] | x :: xs, S p -> x :: of_vector xs p

let rec of_list_and_length_exn : type a n. a list -> n Nat.t -> (a, n) t =
 fun xs n ->
  match (xs, n) with
  | [], _ ->
      []
  | x :: xs, S n ->
      x :: of_list_and_length_exn xs n
  | _ :: _, Z ->
      failwith "At_most: Length mismatch"

module type S = sig
  type 'a t

  include Sigs.Hash_foldable.S1 with type 'a t := 'a t

  include Sigs.Comparable.S1 with type 'a t := 'a t

  include Sigs.Jsonable.S1 with type 'a t := 'a t

  include Sigs.Sexpable.S1 with type 'a t := 'a t
end

module type VERSIONED = sig
  type 'a ty

  module Stable : sig
    module V1 : sig
      type 'a t = 'a ty

      include Sigs.VERSIONED

      include Sigs.Binable.S1 with type 'a t := 'a t

      include S with type 'a t := 'a t
    end
  end

  type 'a t = 'a Stable.V1.t

  include S with type 'a t := 'a t
end

module Make = struct
  module Yojson (N : Nat.Intf) :
    Sigs.Jsonable.S1 with type 'a t := ('a, N.n) t = struct
    let to_yojson f t = Vector.L.to_yojson f (to_list t)

    let of_yojson f s =
      Core_kernel.Result.map (Vector.L.of_yojson f s)
        ~f:(Base.Fn.flip of_list_and_length_exn N.n)
  end

  module Sexpable (N : Nat.Intf) :
    Core_kernel.Sexpable.S1 with type 'a t := ('a, N.n) t =
    Core_kernel.Sexpable.Of_sexpable1
      (Base.List)
      (struct
        type nonrec 'a t = ('a, N.n) t

        let to_sexpable = to_list

        let of_sexpable xs = of_list_and_length_exn xs N.n
      end)
end

type ('a, 'n) at_most = ('a, 'n) t

module With_length (N : Nat.Intf) : S with type 'a t = ('a, N.n) at_most =
struct
  type 'a t = ('a, N.n) at_most

  let compare c t1 t2 = Base.List.compare c (to_list t1) (to_list t2)

  let hash_fold_t f s v = Base.List.hash_fold_t f s (to_list v)

  let equal f t1 t2 = List.equal f (to_list t1) (to_list t2)

  include Make.Sexpable (N)
  include Make.Yojson (N)
end

module At_most_2 = struct
  [%%versioned_binable
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type 'a t = ('a, Nat.N2.n) at_most

      include
        Core_kernel.Binable.Of_binable1_without_uuid
          (Core_kernel.List.Stable.V1)
          (struct
            type nonrec 'a t = 'a t

            let to_binable = to_list

            let of_binable xs = of_list_and_length_exn xs Nat.N2.n
          end)

      include (
        With_length
          (Nat.N2) :
            module type of With_length (Nat.N2) with type 'a t := 'a t )
      end
    end]

  type 'a t = 'a Stable.Latest.t [@@deriving sexp, equal, compare, hash, yojson]

  type 'a ty = 'a t
  end

module At_most_8 = struct
  [%%versioned_binable
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type 'a t = ('a, Nat.N8.n) at_most

      include
        Core_kernel.Binable.Of_binable1_without_uuid
          (Core_kernel.List.Stable.V1)
          (struct
            type nonrec 'a t = 'a t

            let to_binable = to_list

            let of_binable xs = of_list_and_length_exn xs Nat.N8.n
          end)

      include (
        With_length
          (Nat.N8) :
            module type of With_length (Nat.N8) with type 'a t := 'a t )
      end
    end]

  type 'a t = 'a Stable.Latest.t [@@deriving sexp, equal, compare, hash, yojson]

  type 'a ty = 'a t
  end
