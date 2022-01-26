module type Deriver = sig
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
    -> ('input_type Creator.t -> 'f) * 'input_type Accumulator.t

  val finish :
       ('input_type Creator.t -> 'input_type) * 'input_type Accumulator.t
    -> 'input_type Output.t
end

module Make2 (D1 : Deriver) (D2 : Deriver) : Deriver = struct
  module Input = struct
    type 'input_type t = 'input_type D1.Input.t * 'input_type D2.Input.t
  end

  module Creator = struct
    type 'input_type t =
      | A of 'input_type D1.Creator.t
      | B of 'input_type D2.Creator.t
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
    let open Creator in
    let d1_create, d1 = D1.add_field d1_field field d1_acc in
    let d2_create, d2 = D2.add_field d2_field field d2_acc in
    let create = function A x -> d1_create x | B x -> d2_create x in
    (create, (d1, d2))

  let finish (creator, (d1_acc, d2_acc)) =
    let open Creator in
    ( D1.finish ((fun x -> creator (A x)), d1_acc)
    , D2.finish ((fun x -> creator (B x)), d2_acc) )
end
