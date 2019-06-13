open Core_kernel
include Proof

module Variable_base = struct
  module Instance = Variable_base_instance
  module Intf = Intf.Variable_base

  module Make_unchecked (Inputs : Inputs_intf.Unchecked) :
    Intf.Unchecked with module Inputs := Inputs = struct
    open Inputs

    type t = (Group.t, Scalar.t) Proof.t [@@deriving bin_io]

    module Instance = struct
      type t = (Group.t, Group.t) Instance.t
    end

    let create ~base ~log =
      let r = Scalar.random () in
      let h = Group.(r * base) in
      let c = Hash.(to_scalar (create h)) in
      {h; s= Scalar.(r + (c * log))}

    let verify ({h; s} : t) ({base; element} : Instance.t) =
      let c = Hash.(to_scalar (create h)) in
      let open Group in
      equal (s * base) (h + (c * element))
  end

  module Make_checked (Inputs : Inputs_intf.Checked) :
    Intf.Checked with module Inputs := Inputs = struct
    open Inputs

    type t = (Group.t, Scalar.t) Proof.t

    module Instance = struct
      type t = (Group.t, Group.t) Instance.t
    end

    let verify' k ({h; s} : t) ({base; element} : Instance.t) =
      let open Impl.Checked in
      let%bind c = Hash.(create h >>| to_scalar) in
      let open Group in
      let%bind rhs = s * base and lhs = c * element >>= ( + ) h in
      k rhs lhs

    let verify t s = verify' Group.equal t s

    module Assert = struct
      let verifies t s = verify' Group.Assert.equal t s
    end
  end
end

module Make (Inputs : Inputs_intf.S) = struct
  open Inputs

  module Variable_base = struct
    module Unchecked = Variable_base.Make_unchecked (struct
      module Scalar = Scalar.Unchecked
      module Group = Group.Unchecked
      module Hash = Hash.Unchecked
    end)

    module Checked = Variable_base.Make_checked (struct
      module Impl = Impl
      module Scalar = Scalar.Checked
      module Group = Group.Checked
      module Hash = Hash.Checked
    end)
  end

  module Fixed_base = struct
    module Instance = struct
      type t = Group.Unchecked.t [@@deriving bin_io]
    end
  end
end
