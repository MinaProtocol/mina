open Core
open Snark_params.Tick

module Hash : Data_hash.Full_size

module Entry : sig
  type t = Blockchain_state.t * Transaction.Payload.t

  include Snarkable.S with type value := t
end

module Tail : sig
  include module type of Hash with type t = Hash.t

  val cons : Entry.t -> t -> t

  val empty : t

  module Checked : sig
    val empty : var

    (* TODO: Fix this interface once the hash_section PR lands *)

    val cons :
         prefix_and_state:Hash_curve.var
      -> payload_bits:Boolean.var list
      -> var
      -> (var, _) Checked.t
  end
end

type t = {entries: Entry.t list; base: Hash.t}
