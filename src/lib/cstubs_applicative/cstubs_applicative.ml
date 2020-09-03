open Base
include Cstubs

module type Foreign_applicative = sig
  include FOREIGN

  include Applicative.S with type 'a t := 'a result
end

module type Bindings_with_applicative = functor
  (F : Foreign_applicative with type 'a result = unit)
  -> sig end

module Make_applicative_unit (F : FOREIGN with type 'a result = unit) :
  Foreign_applicative with type 'a result = unit = struct
  include F

  include Applicative.Make (struct
    type 'a t = 'a result

    let apply () () = ()

    let map = `Define_using_apply

    let return _ = ()
  end)
end

module Make_applicative_transparent (F : FOREIGN with type 'a result = 'a) :
  Foreign_applicative with type 'a result = 'a = struct
  include F

  include Applicative.Make (struct
    type 'a t = 'a result

    let apply = Fn.id

    let map = `Define_using_apply

    let return x = x
  end)
end

module Make_cstubs_bindings
    (B : Bindings_with_applicative)
    (F : FOREIGN with type 'a result = unit) =
  B (Make_applicative_unit (F))

let make_bindings (module B : Bindings_with_applicative) =
  (module Make_cstubs_bindings (B) : BINDINGS)

let write_c ?concurrency ?errno fmt ~prefix b =
  write_c ?concurrency ?errno fmt ~prefix (make_bindings b)

let write_ml ?concurrency ?errno fmt ~prefix b =
  write_ml ?concurrency ?errno fmt ~prefix (make_bindings b) ;
  (* Append the applicative interface instance to the end of the file. *)
  Stdlib.Format.fprintf fmt "%s@."
    {ocaml|
include (struct
  let return x = x
  let map x ~f = f x
  let both x y = (x, y)
  let apply f x = f x
  let map2 x y ~f = f x y
  let map3 x y z ~f = f x y z
  let all l = l
  let all_unit _ = ()
  let all_ignore _ = ()
  module Applicative_infix = struct
    let ( <*> ) f x = f x
    let ( <* ) x () = x
    let ( *> ) () x = x
    let ( >>| ) x f = f x
  end
  include Applicative_infix
end : sig
  val return : 'a -> 'a return
  val map : 'a return -> f:('a -> 'b) -> 'b return
  val both : 'a return -> 'b return -> ('a * 'b) return
  val ( <*> ) : ('a -> 'b) return -> 'a return -> 'b return
  val ( <* ) : 'a return -> unit return -> 'a return
  val ( *> ) : unit return -> 'a return -> 'a return
  val ( >>| ) : 'a return -> ('a -> 'b) -> 'b return
  val apply : ('a -> 'b) return -> 'a return -> 'b return
  val map2 : 'a return -> 'b return -> f:('a -> 'b -> 'c) -> 'c return
  val map3 : 'a return -> 'b return -> 'c return -> f:('a -> 'b -> 'c -> 'd) -> 'd return
  val all : 'a return list -> 'a list return
  val all_unit : unit return list -> unit return
  val all_ignore : unit return list -> unit return
  module Applicative_infix :
    sig
      val ( <*> ) : ('a -> 'b) return -> 'a return -> 'b return
      val ( <* ) : 'a return -> unit return -> 'a return
      val ( *> ) : unit return -> 'a return -> 'a return
      val ( >>| ) : 'a return -> ('a -> 'b) -> 'b return
    end
end)
|ocaml}
