open Core_kernel

include Digest_intf.S

val cons : Stack_frame.Digest.t -> t -> t

val empty : t

val gen : t Quickcheck.Generator.t

module Checked : sig
  include Digest_intf.S_checked

  val cons : Stack_frame.Digest.Checked.t -> t -> t
end

include Digest_intf.S_aux with type t := t and type checked := Checked.t
