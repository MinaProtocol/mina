module Variable_base = struct
  module type Unchecked = sig
    module Inputs : Inputs_intf.Unchecked

    open Inputs

    type t = (Group.t, Scalar.t) Proof.t [@@deriving bin_io]

    module Instance : sig
      type t = (Group.t, Group.t) Variable_base_instance.t
    end

    val create : base:Group.t -> log:Scalar.t -> t

    val verify : t -> Instance.t -> bool
  end

  module type Checked = sig
    module Inputs : Inputs_intf.Checked

    open Inputs

    type t = (Group.t, Scalar.t) Proof.t

    open Impl

    module Instance : sig
      type t = (Group.t, Group.t) Variable_base_instance.t
    end

    val verify : t -> Instance.t -> (Boolean.var, _) Checked.t

    module Assert : sig
      val verifies : t -> Instance.t -> (unit, _) Checked.t
    end
  end
end
