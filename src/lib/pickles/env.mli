module Bool : Plonk_checks.Bool_intf with type t = bool

module Tick_field :
  Plonk_checks.Field_with_if_int
    with type t = Backend.Tick.Field.t
     and type bool = bool

module Tock_field :
  Plonk_checks.Field_with_if_int
    with type t = Backend.Tock.Field.t
     and type bool = bool
