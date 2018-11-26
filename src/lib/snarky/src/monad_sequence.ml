open Core_kernel

module type S = sig
  type ('a, 's) monad

  type 'a t

  type boolean

  val foldi :
    'a t -> init:'b -> f:(int -> 'b -> 'a -> ('b, 's) monad) -> ('b, 's) monad

  val fold :
    'a t -> init:'b -> f:('b -> 'a -> ('b, 's) monad) -> ('b, 's) monad

  val exists : 'a t -> f:('a -> (boolean, 's) monad) -> (boolean, 's) monad

  val existsi :
    'a t -> f:(int -> 'a -> (boolean, 's) monad) -> (boolean, 's) monad

  val for_all : 'a t -> f:('a -> (boolean, 's) monad) -> (boolean, 's) monad

  val for_alli :
    'a t -> f:(int -> 'a -> (boolean, 's) monad) -> (boolean, 's) monad

  val all : ('a, 's) monad t -> ('a t, 's) monad

  val all_unit : (unit, 's) monad t -> (unit, 's) monad

  val init : int -> f:(int -> ('a, 's) monad) -> ('a t, 's) monad

  val iter : 'a t -> f:('a -> (unit, 's) monad) -> (unit, 's) monad

  val iteri : 'a t -> f:(int -> 'a -> (unit, 's) monad) -> (unit, 's) monad

  val map : 'a t -> f:('a -> ('b, 's) monad) -> ('b t, 's) monad

  val mapi : 'a t -> f:(int -> 'a -> ('b, 's) monad) -> ('b t, 's) monad
end

module List
    (M : Monad.S2) (Bool : sig
        type t

        val any : t list -> (t, _) M.t

        val all : t list -> (t, _) M.t
    end) :
  S
  with type 'a t = 'a list
   and type ('a, 's) monad := ('a, 's) M.t
   and type boolean := Bool.t = struct
  type 'a t = 'a list

  open M.Let_syntax

  let foldi t ~init ~f =
    let rec go i acc = function
      | [] -> return acc
      | x :: xs ->
          let%bind acc = f i acc x in
          go (i + 1) acc xs
    in
    go 0 init t

  let fold t ~init ~f = foldi t ~init ~f:(fun _ acc x -> f acc x)

  let all = M.all

  let all_unit = M.all_unit

  let init n ~f =
    let rec go acc i =
      if i < 0 then return acc
      else
        let%bind x = f i in
        go (x :: acc) (i - 1)
    in
    go [] (n - 1)

  let iteri t ~f =
    let rec go i = function
      | [] -> return ()
      | x :: xs ->
          let%bind () = f i x in
          go (i + 1) xs
    in
    go 0 t

  let iter t ~f = iteri t ~f:(fun _i x -> f x)

  let mapi t ~f =
    let rec go i acc = function
      | [] -> return (List.rev acc)
      | x :: xs ->
          let%bind y = f i x in
          go (i + 1) (y :: acc) xs
    in
    go 0 [] t

  let map t ~f = mapi t ~f:(fun _i x -> f x)

  let existsi t ~f = mapi t ~f >>= Bool.any

  let exists t ~f = map t ~f >>= Bool.any

  let for_alli t ~f = mapi t ~f >>= Bool.all

  let for_all t ~f = map t ~f >>= Bool.all
end
