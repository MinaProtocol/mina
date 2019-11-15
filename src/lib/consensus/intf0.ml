(** HACK: This intf0 file was created to prevent having cyclic dependencies between global_slot.ml and proof_of_stake.ml  *)
open Core_kernel

open Coda_base
module Time = Block_time

module type Global_slot = sig
  module Stable : sig
    module V1 : sig
      type t [@@deriving bin_io, sexp, eq, compare, hash, yojson, version]
    end

    module Latest = V1
  end

  include Coda_numbers.Nat.Intf.S_unchecked with type t = Stable.Latest.t

  val ( + ) : t -> int -> t

  val create : epoch:Epoch.t -> slot:Slot.t -> t

  val of_epoch_and_slot : Epoch.t * Slot.t -> t

  val to_uint32 : t -> Unsigned.uint32

  val of_uint32 : Unsigned.uint32 -> t

  val epoch : t -> Epoch.t

  val slot : t -> Slot.t

  val start_time : t -> Time.t

  val end_time : t -> Time.t

  val time_hum : t -> string

  val to_epoch_and_slot : t -> Epoch.t * Slot.t

  val of_time_exn : Time.t -> t

  module Checked : sig
    include Coda_numbers.Nat.Intf.S_checked with type unchecked := t

    open Snark_params.Tick

    val to_epoch_and_slot :
      t -> (Epoch.Checked.t * Slot.Checked.t, _) Checked.t
  end
end

(** Constants are defined with a single letter (latin or greek) based on
 * their usage in the Ouroboros suite of papers *)
module type Constants = sig
  (** The timestamp for the genesis block *)
  val genesis_state_timestamp : Coda_base.Block_time.t

  (** [k] is the number of blocks required to reach finality *)
  val k : int

  (** The amount of money minted and given to the proposer whenever a block
   * is created *)
  val coinbase : Currency.Amount.t

  val block_window_duration_ms : int

  (** The window duration in which blocks are created *)
  val block_window_duration : Coda_base.Block_time.Span.t

  (** [delta] is the number of slots in the valid window for receiving blocks over the network *)
  val delta : int

  (** [c] is the number of slots in which we can probalistically expect at least 1
   * block. In sig, it's exactly 1 as blocks should be produced every slot. *)
  val c : int

  val inactivity_ms : int

  (** Number of slots in one epoch *)
  val slots_per_epoch : Unsigned.UInt32.t
end
