module type Deriver_basic_intf = sig
  module Input : sig
    type 'input_type t
  end

  module Creator : sig
    type 'input_type t
  end

  module Output : sig
    type 'output_type t
  end

  module Accumulator : sig
    type 'input_type t
  end

  val init : unit -> 'input_type Accumulator.t

  val add_field :
       'f Input.t
    -> ( [< `Read | `Set_and_create ]
       , 'input_type
       , 'f )
       Fieldslib.Field.t_with_perm
    -> 'input_type Accumulator.t
    -> ('input_type Creator.t -> ('f, string) Result.t)
       * 'input_type Accumulator.t

  val finish :
       ('input_type Creator.t -> 'input_type) * 'input_type Accumulator.t
    -> 'input_type Output.t

  val int_ : int Input.t

  val string_ : string Input.t

  val bool_ : bool Input.t

  val list_ : 'a Input.t -> 'a list Input.t
end

module type Deriver_intf = sig
  include Deriver_basic_intf

  module Step : sig
    type ('a, 'input_type, 'f) t =
         ( ([< `Read | `Set_and_create ] as 'a)
         , 'input_type
         , 'f )
         Fieldslib.Field.t_with_perm
      -> 'input_type Accumulator.t
      -> ('input_type Creator.t -> ('f, string) Result.t)
         * 'input_type Accumulator.t
  end

  module Prim : sig
    val int : ('a, 'input_type, int) Step.t

    val string : ('a, 'input_type, string) Step.t

    val bool : ('a, 'input_type, bool) Step.t

    val list : 'l Input.t -> ('a, 'input_type, 'l list) Step.t
  end
end

module Make (D : Deriver_basic_intf) :
  Deriver_intf
    with module Accumulator = D.Accumulator
     and module Input = D.Input
     and module Creator = D.Creator
     and module Output = D.Output = struct
  include D

  module Step = struct
    type ('a, 'input_type, 'f) t =
         ( ([< `Read | `Set_and_create ] as 'a)
         , 'input_type
         , 'f )
         Fieldslib.Field.t_with_perm
      -> 'input_type Accumulator.t
      -> ('input_type Creator.t -> ('f, string) Result.t)
         * 'input_type Accumulator.t
  end

  module Prim = struct
    let int fd acc = add_field D.int_ fd acc

    let string fd acc = add_field D.string_ fd acc

    let bool fd acc = add_field D.bool_ fd acc

    let list l fd acc = add_field (D.list_ l) fd acc
  end
end

let under_to_camel s =
  let open Core_kernel in
  let ws = String.split s ~on:'_' in
  match ws with
  | [] ->
      ""
  | w :: ws ->
      w :: (ws |> List.map ~f:String.capitalize) |> String.concat ?sep:None

let%test_unit "under_to_camel works as expected" =
  let open Core_kernel in
  [%test_eq: string] "fooHello" (under_to_camel "foo_hello") ;
  [%test_eq: string] "fooHello" (under_to_camel "foo_hello___")

(** Like Field.name but rewrites underscore_case to camelCase. *)
let name_under_to_camel f = Fieldslib.Field.name f |> under_to_camel

module Either = struct
  type ('a, 'b) t = A of 'a | B of 'b
end

module Make2 (D1 : Deriver_intf) (D2 : Deriver_intf) :
  Deriver_intf
    with type 'input_type Accumulator.t =
          'input_type D1.Accumulator.t * 'input_type D2.Accumulator.t
     and type 'input_type Input.t =
          'input_type D1.Input.t * 'input_type D2.Input.t
     and type 'input_type Creator.t =
          ('input_type D1.Creator.t, 'input_type D2.Creator.t) Either.t
     and type 'input_type Output.t =
          'input_type D1.Output.t * 'input_type D2.Output.t = struct
  module Input = struct
    type 'input_type t = 'input_type D1.Input.t * 'input_type D2.Input.t
  end

  module Creator = struct
    type 'input_type t =
      ('input_type D1.Creator.t, 'input_type D2.Creator.t) Either.t
  end

  module Output = struct
    type 'input_type t = 'input_type D1.Output.t * 'input_type D2.Output.t
  end

  module Accumulator = struct
    type 'input_type t =
      'input_type D1.Accumulator.t * 'input_type D2.Accumulator.t
  end

  let init () = (D1.init (), D2.init ())

  let add_field (d1_field, d2_field) field (d1_acc, d2_acc) =
    let open Either in
    let d1_create, d1 = D1.add_field d1_field field d1_acc in
    let d2_create, d2 = D2.add_field d2_field field d2_acc in
    let create = function A x -> d1_create x | B x -> d2_create x in
    (create, (d1, d2))

  let finish (creator, (d1_acc, d2_acc)) =
    let open Either in
    ( D1.finish ((fun x -> creator (A x)), d1_acc)
    , D2.finish ((fun x -> creator (B x)), d2_acc) )

  module Step = struct
    type ('a, 'input_type, 'f) t =
         ( ([< `Read | `Set_and_create ] as 'a)
         , 'input_type
         , 'f )
         Fieldslib.Field.t_with_perm
      -> 'input_type Accumulator.t
      -> ('input_type Creator.t -> ('f, string) Result.t)
         * 'input_type Accumulator.t
  end

  let int_ = (D1.int_, D2.int_)

  let string_ = (D1.string_, D2.string_)

  let bool_ = (D1.bool_, D2.bool_)

  let list_ (l1, l2) = (D1.list_ l1, D2.list_ l2)

  module Prim = struct
    let int : (_, 'input_type, int) Step.t =
     fun fd acc -> add_field (D1.int_, D2.int_) fd acc

    let string : (_, 'input_type, string) Step.t =
     fun fd acc -> add_field (D1.string_, D2.string_) fd acc

    let bool : (_, 'input_type, bool) Step.t =
     fun fd acc -> add_field (D1.bool_, D2.bool_) fd acc

    let list (l1, l2) fd acc = add_field (D1.list_ l1, D2.list_ l2) fd acc
  end
end
