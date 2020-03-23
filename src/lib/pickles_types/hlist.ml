module Hlist (F : sig
  type _ t
end) =
struct
  type _ t = [] : unit t | ( :: ) : 'a F.t * 'b t -> ('a * 'b) t
end

module Hlist2 (F : sig
  type (_, _) t
end) =
struct
  type (_, 's) t =
    | [] : (unit, _) t
    | ( :: ) : ('a, 's) F.t * ('b, 's) t -> ('a * 'b, 's) t
end

module Hlist2_1 (F : sig
  type (_, _, _) t
end) =
struct
  type (_, _, 's) t =
    | [] : (unit, unit, _) t
    | ( :: ) :
        ('a1, 'a2, 's) F.t * ('b1, 'b2, 's) t
        -> ('a1 * 'b1, 'a2 * 'b2, 's) t
end

module Id = struct
  type 'a t = 'a
end

module HlistId = Hlist (Id)
