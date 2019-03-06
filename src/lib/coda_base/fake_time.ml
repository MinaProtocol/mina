module Make (Offset : sig
  val offset : Core_kernel.Time.Span.t
end) =
struct
  module Time : module type of Block_time.Time = struct
    include Block_time.Time

    let now _ =
      sub (of_time (Core_kernel.Time.now ())) (Span.of_time_span Offset.offset)
  end

  module Timeout = Timeout.Make (Time)
end
