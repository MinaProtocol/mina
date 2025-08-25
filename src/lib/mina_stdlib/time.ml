open Core_kernel

module Span = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      (* NOTE:
         `Core_kernel.Time.Stable.Span.V3.t` tracks time in seconds in an IEEE754
         64bit float. Hence conversion to/from float poses no precision lost.
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
