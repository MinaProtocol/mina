open Core_kernel

module Span = struct
  [%%versioned
  module Stable = struct
    module V3 = struct
      type t = Core_kernel.Time.Stable.Span.V3.t [@@deriving sexp]

      let to_yojson total = `String (Time.Span.to_string_hum total)

      let of_yojson = function
        | `String time ->
            Ok (Time.Span.of_string time)
        | _ ->
            Error "Mina_stdlib.Time.Span: Could not parse"

      let to_latest = Fn.id
    end
  end]

  [%%define_locally Stable.Latest.(to_yojson, of_yojson)]

  include Core_kernel.Time.Span
end
