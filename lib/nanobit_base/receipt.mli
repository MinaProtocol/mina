open Core
open Snark_params.Tick

module Chain_hash : sig
  include Data_hash.Full_size

  val empty : t

  val cons : Transaction.Payload.t -> t -> t

  module Checked : sig
    val constant : t -> var

    type t = var

    val cons
      : payload:Pedersen_hash.Section.t
      -> t
      -> (t, _) Checked.t
  end
end
