module type Unchecked = sig
  type t [@@deriving bin_io]

  val random : unit -> t

  val ( + ) : t -> t -> t

  val ( * ) : t -> t -> t
end

module type Checked = sig
  type t
end

module type S = sig
  module Impl : Snarky_backendless.Snark_intf.S

  module Unchecked : Unchecked

  module Checked : Checked

  val typ : (Checked.t, Unchecked.t) Impl.Typ.t
end
