[%%import "/src/config.mlh"]

open Core_kernel
open Coda_base
open Unsigned

(*include
  Coda_numbers.Nat.Intf.S_unchecked
  with type t = Coda_numbers.Global_slot.Stable.Latest.t

[%%versioned:
module Stable : sig
  module V1 : sig
    type nonrec t = t [@@deriving sexp, eq, compare, hash, yojson]
  end
end]*)
module Poly : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type 'a t [@@deriving sexp, eq, compare, hash, yojson]
    end
  end]

  type 'a t = 'a Stable.Latest.t [@@deriving sexp, eq, compare, hash, yojson]
end

[%%versioned:
module Stable : sig
  module V1 : sig
    type t = Coda_numbers.Global_slot.Stable.V1.t Poly.Stable.V1.t
    [@@deriving compare, eq, sexp, hash, yojson]
  end
end]

type t = Stable.Latest.t [@@deriving sexp, eq, compare, hash, yojson]

val to_input : t -> (_, bool) Random_oracle.Input.t

val of_slot_number : 'a -> slots_per_epoch:'a -> 'a Poly.t

val gen : t Quickcheck.Generator.t

val ( + ) : t -> int -> t

val ( < ) : t -> t -> bool

val create : epoch:Epoch.t -> slot:Slot.t -> slots_per_epoch:UInt32.t -> t

val of_epoch_and_slot : Epoch.t * Slot.t -> slots_per_epoch:UInt32.t -> t

val zero : slots_per_epoch:UInt32.t -> t

val to_bits : t -> bool list

val epoch : t -> Epoch.t

val slot : t -> Slot.t

val start_time :
     t
  -> genesis_state_timestamp:Block_time.t
  -> epoch_duration:Block_time.Span.t
  -> slot_duration_ms:Block_time.Span.t
  -> Block_time.t

val end_time :
     t
  -> genesis_state_timestamp:Block_time.t
  -> epoch_duration:Block_time.Span.t
  -> slot_duration_ms:Block_time.Span.t
  -> Block_time.t

val time_hum : t -> string

val to_epoch_and_slot : t -> Epoch.t * Slot.t

val of_time_exn : Block_time.t -> coda_constants:Coda_constants.t -> t

val diff : t -> Epoch.t * Slot.t -> epoch_size:UInt32.t -> t

[%%ifdef consensus_mechanism]

open Snark_params.Tick
open Bitstring_lib

module Checked : sig
  open Snark_params.Tick

  type t = Coda_numbers.Global_slot.Checked.t Poly.t

  val ( < ) : t -> t -> (Boolean.var, _) Checked.t

  val to_bits : t -> (Boolean.var Bitstring.Lsb_first.t, _) Checked.t

  val to_input :
       t
    -> ( (Field.Var.t, Snark_params.Tick.Boolean.var) Random_oracle.Input.t
       , _ )
       Checked.t

  val to_epoch_and_slot : t -> (Epoch.Checked.t * Slot.Checked.t, _) Checked.t
end

val typ : (Checked.t, t) Typ.t

[%%endif]

val slot_number : 'a Poly.t -> 'a

val slots_per_epoch : 'a Poly.t -> 'a
