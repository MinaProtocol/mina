module type Unchecked = sig
  module Scalar : Scalar_intf.Unchecked

  module Group : Group_intf.Unchecked with type scalar := Scalar.t

  module Hash :
    Hash_intf.Unchecked with type scalar := Scalar.t and type group := Group.t
end

module type Checked = sig
  module Impl : Snarky_backendless.Snark_intf.S

  module Scalar : Scalar_intf.Checked

  module Group :
    Group_intf.Checked with module Impl := Impl and type scalar := Scalar.t

  module Hash :
    Hash_intf.Checked
    with module Impl := Impl
     and type group := Group.t
     and type scalar := Scalar.t
end

module type S = sig
  module Impl : Snarky_backendless.Snark_intf.S

  module Scalar : Scalar_intf.S with module Impl := Impl

  module Group :
    Group_intf.S with module Impl := Impl and module Scalar := Scalar

  module Hash :
    Hash_intf.S
    with module Impl := Impl
     and module Scalar := Scalar
     and module Group := Group
end
