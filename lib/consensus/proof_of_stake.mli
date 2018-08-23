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

      val of_ms : Int64.t -> t

      val ( + ) : t -> t -> t

      val ( * ) : t -> t -> t
    end

    val ( < ) : t -> t -> bool

    val ( >= ) : t -> t -> bool

    val diff : t -> t -> Span.t

    val to_span_since_epoch : t -> Span.t

    val of_span_since_epoch : Span.t -> t

    val add : t -> Span.t -> t
  end

  val genesis_state_timestamp : Time.t

  val genesis_ledger_total_currency : Currency.Amount.t

  val coinbase : Currency.Amount.t

  val slot_interval : Time.Span.t

  val epoch_size : UInt32.t
end

module Make (Inputs : Inputs_intf) :
  Mechanism.S
  with type Proof.t = Inputs.Proof.t
   and type Internal_transition.Ledger_builder_diff.t = Inputs.Ledger_builder_diff.t
   and type External_transition.Ledger_builder_diff.t = Inputs.Ledger_builder_diff.t
