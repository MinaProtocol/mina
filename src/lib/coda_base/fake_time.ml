module Make (Offset : sig
  val offset : Core_kernel.Time.Span.t
end) : Protocols.Coda_pow.Time_intf = struct
  module Time = struct
    include Block_time.Time

    let now _ = sub (now ()) (Span.of_time_span Offset.offset)
  end

  include Time
  module Timeout = Timeout.Make (Time)
end
