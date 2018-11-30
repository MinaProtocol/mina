open Currency

module type Inputs_intf = sig
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

  module Genesis_ledger : sig
    val t : Coda_base.Ledger.t
  end

  val genesis_state_timestamp : Time.t

  val coinbase : Amount.t

  val slot_interval : Time.Span.t

  val unforkable_transition_count : int

  val probable_slots_per_transition_count : int

  val expected_network_delay : Time.Span.t

  val approximate_network_diameter : int
end

module Make (Inputs : Inputs_intf) : Intf.S
