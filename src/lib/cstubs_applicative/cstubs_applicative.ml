open Base
include Cstubs

module type Applicative_with_let = sig
  include Applicative.S

  include Applicative.Let_syntax with type 'a t := 'a t
end

module Make_applicative_with_let (X : Applicative.Basic) :
  Applicative_with_let with type 'a t := 'a X.t = struct
  module A = struct
    type 'a t = unit

    include Applicative.Make (X)
  end

  include A

  include Applicative.Make_let_syntax
            (A)
            (struct
              module type S = sig end
            end)
            ()
end

module Applicative_unit = Make_applicative_with_let (struct
  type 'a t = unit

  let apply () () = ()

  let map = `Custom (fun () ~f:_ -> ())

  let return _ = ()
end)

module Applicative_id = Make_applicative_with_let (struct
  type 'a t = 'a result

  let apply = Fn.id

  let map = `Custom (fun x ~f -> f x)

  let return = Fn.id
end)

module type Foreign_applicative = sig
  include FOREIGN

  include Applicative_with_let with type 'a t := 'a result
end

module type Bindings_with_applicative = functor
  (F : Foreign_applicative with type 'a result = unit)
  -> sig end

module Make_applicative_unit (F : FOREIGN with type 'a result = unit) :
  Foreign_applicative with type 'a result = unit = struct
  include F
  include Applicative_unit
end

module Make_applicative_id (F : FOREIGN with type 'a result = 'a) :
  Foreign_applicative with type 'a result = 'a = struct
  include F
  include Applicative_id
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
|ocaml}
