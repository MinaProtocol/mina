open Core_kernel

module Span = struct
  [%%versioned
  module Stable = struct
    module V3 = struct
      (* This span could track time in seconds with float under the hood.
         Hence we use that as well, so no actual conversion is happening.
         Accuracy is lost only when float has accuracy loss.
      *)
      type t = Core_kernel.Time.Stable.Span.V3.t [@@deriving sexp]

      let to_yojson span = `Float (Time.Span.to_sec span)

      let of_yojson = function
        | `Float span ->
            Ok (Time.Span.of_sec span)
        | _ ->
            Error "Mina_stdlib.Time.Span: Could not parse"

      let to_latest = Fn.id
    end
  end]

  [%%define_locally Stable.Latest.(to_yojson, of_yojson)]

  include Core_kernel.Time.Span
end
