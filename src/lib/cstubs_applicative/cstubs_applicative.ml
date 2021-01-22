open Base
include Cstubs

module type Applicative_with_let = sig
  include Applicative.S

  include Applicative.Let_syntax with type 'a t := 'a t
end

module Make_applicative_with_let (X : Applicative.Basic) :
  Applicative_with_let with type 'a t := 'a X.t = struct
  module A = struct
    type 'a t = 'a X.t

    include Applicative.Make (X)
  end

  include A

  module Open_on_rhs_intf = struct
    module type S = sig end
  end

  include Applicative.Make_let_syntax (A) (Open_on_rhs_intf) ()
end

module Applicative_unit = Make_applicative_with_let (struct
  type 'a t = unit

  let apply () () = ()

  let map = `Custom (fun () ~f:_ -> ())

  let return _ = ()
end)

module Applicative_id = Make_applicative_with_let (struct
  type 'a t = 'a

  let apply = Fn.id

  let map = `Custom (fun x ~f -> f x)

  let return = Fn.id
end)

module type Foreign_applicative = sig
  include FOREIGN

  include Applicative_with_let with type 'a t := 'a result

  (* NB: These types aren't ideal, since they're not satisfiable for the cstubs
     foreign interface, but making a full monad adds complexity for no actual
     benefit.
  *)

  val map_return : 'a return -> f:('a -> 'b) -> 'b return

  val bind_return : 'a return -> f:('a -> 'b return) -> 'b
end

module type Bindings_with_applicative = functor
  (F : Foreign_applicative with type 'a result = unit)
  -> sig end

module Make_applicative_unit (F : FOREIGN with type 'a result = unit) :
  Foreign_applicative with type 'a result = unit = struct
  include F
  include Applicative_unit

  (* We assume here that it is impossible to create a value of type [return],
     in accordance with the cstubs foreign interface. *)

  let map_return _x ~f:_ =
    failwith "Cstubs_applicative: This should be impossible"

  let bind_return _x ~f:_ =
    failwith "Cstubs_applicative: This should be impossible"
end

module Make_applicative_id
    (F : FOREIGN with type 'a result = 'a and type 'a return = 'a) :
  Foreign_applicative with type 'a result = 'a and type 'a return = 'a = struct
  include F
  include Applicative_id

  let map_return x ~f = f x

  let bind_return x ~f = f x
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
include Cstubs_applicative.Applicative_id

let map_return x ~f = f x

let bind_return x ~f = f x
|ocaml}
