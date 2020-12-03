module type Unchecked = sig
  type group

  type scalar

  type t

  val create : group -> t

  val to_scalar : t -> scalar
end

module type Checked = sig
  module Impl : Snarky_backendless.Snark_intf.S

  type group

  type scalar

  type t

  val create : group -> (t, _) Impl.Checked.t

  val to_scalar : t -> scalar
end

module type S = sig
  module Impl : Snarky_backendless.Snark_intf.S

  module Scalar : Scalar_intf.S with module Impl := Impl

  module Group :
    Group_intf.S with module Impl := Impl and module Scalar := Scalar

  module Unchecked :
    Unchecked
    with type scalar := Scalar.Unchecked.t
     and type group := Group.Unchecked.t

  module Checked :
    Checked
    with module Impl := Impl
     and type scalar := Scalar.Checked.t
     and type group := Group.Checked.t
end
