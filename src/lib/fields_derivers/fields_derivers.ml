module type Deriver_basic_intf = sig
  module Input : sig
    type 'input_type t
  end

  module Creator : sig
    type 'input_type t
  end

  module Output : sig
    module Finish : sig
      type t
    end

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
    -> ('input_type Creator.t -> 'f) * 'input_type Accumulator.t

  val finish :
       Output.Finish.t
    -> ('input_type Creator.t -> 'input_type) * 'input_type Accumulator.t
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
      -> ('input_type Creator.t -> 'f) * 'input_type Accumulator.t
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
      -> ('input_type Creator.t -> 'f) * 'input_type Accumulator.t
  end

  module Prim = struct
    let int fd acc = add_field D.int_ fd acc

    let string fd acc = add_field D.string_ fd acc

    let bool fd acc = add_field D.bool_ fd acc

    let list l fd acc = add_field (D.list_ l) fd acc
  end
end

module Make2 (D1 : Deriver_intf) (D2 : Deriver_intf) :
  Deriver_intf
    with type 'input_type Accumulator.t =
          'input_type D1.Accumulator.t * 'input_type D2.Accumulator.t
     and type 'input_type Input.t =
          'input_type D1.Input.t * 'input_type D2.Input.t
     and type 'input_type Creator.t =
          ('input_type D1.Creator.t, 'input_type D2.Creator.t) Base.Either.t
     and type 'input_type Output.t =
          'input_type D1.Output.t * 'input_type D2.Output.t
     and type Output.Finish.t = D1.Output.Finish.t * D2.Output.Finish.t = struct
  module Input = struct
    type 'input_type t = 'input_type D1.Input.t * 'input_type D2.Input.t
  end

  module Creator = struct
    type 'input_type t =
      ('input_type D1.Creator.t, 'input_type D2.Creator.t) Base.Either.t
  end

  module Output = struct
    module Finish = struct
      type t = D1.Output.Finish.t * D2.Output.Finish.t
    end

    type 'input_type t = 'input_type D1.Output.t * 'input_type D2.Output.t
  end

  module Accumulator = struct
    type 'input_type t =
      'input_type D1.Accumulator.t * 'input_type D2.Accumulator.t
  end

  let init () = (D1.init (), D2.init ())

  let add_field (d1_field, d2_field) field (d1_acc, d2_acc) =
    let open Base.Either in
    let d1_create, d1 = D1.add_field d1_field field d1_acc in
    let d2_create, d2 = D2.add_field d2_field field d2_acc in
    let create = function First x -> d1_create x | Second x -> d2_create x in
    (create, (d1, d2))

  let finish (m1, m2) (creator, (d1_acc, d2_acc)) =
    let open Base.Either in
    ( D1.finish m1 ((fun x -> creator (First x)), d1_acc)
    , D2.finish m2 ((fun x -> creator (Second x)), d2_acc) )

  module Step = struct
    type ('a, 'input_type, 'f) t =
         ( ([< `Read | `Set_and_create ] as 'a)
         , 'input_type
         , 'f )
         Fieldslib.Field.t_with_perm
      -> 'input_type Accumulator.t
      -> ('input_type Creator.t -> 'f) * 'input_type Accumulator.t
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
