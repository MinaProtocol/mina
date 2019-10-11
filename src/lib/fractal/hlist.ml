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

module Id = struct
  type 'a t = 'a
end

module HlistId = Hlist (Id)
