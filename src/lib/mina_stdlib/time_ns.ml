open Core_kernel

open struct
  module Time_ns_Span_v2 = struct
    include Time_ns.Stable.Span.V2

    (* HACK: This is so versioned type works. *)
    let __versioned__ = true
  end
end

module Span = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Time_ns_Span_v2.t [@@deriving sexp]

      (* NOTE:
         `Core_kernel.Time_ns.Stable.Span.V2.t` tracks time in an Int63
      *)
      let to_yojson span =
        `String (Time_ns_Span_v2.to_int63 span |> Int63.to_string)

      let of_yojson = function
        | `String span ->
            Or_error.try_with (fun () ->
                Int63.of_string span |> Time_ns_Span_v2.of_int63_exn )
            |> Result.map_error ~f:Error.to_string_hum
        | _ ->
            Error "Mina_stdlib.Time_ns.Span: Could not parse"

      let to_latest = Fn.id
    end
  end]

  [%%define_locally Stable.Latest.(to_yojson, of_yojson)]

  include Time_ns.Span
end
