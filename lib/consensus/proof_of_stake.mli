open Unsigned

module type Inputs_intf = sig
  module Proof : sig
    type t [@@deriving bin_io, sexp]
  end

  module Ledger_builder_diff : sig
    type t [@@deriving bin_io, sexp]
  end

  module Time : sig
    type t

    module Span : sig
      type t

      val to_ms : t -> Int64.t
    end

    val of_ms : Int64.t -> t

    val to_ms : t -> Int64.t

    val diff : t -> t -> Span.t

    val less_than : t -> t -> bool

    val ( < ) : t -> t -> bool

    val ( >= ) : t -> t -> bool

    val ( + ) : t -> t -> t

    val ( * ) : t -> t -> t
  end

  val genesis_block_timestamp : Time.t

  val slot_interval : Time.t

  val epoch_size : UInt64.t
end

module Make (Inputs : Inputs_intf) : Mechanism.S
