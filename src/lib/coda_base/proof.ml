open Core
open Snark_params

module Stable = struct
  module V1 = struct
    (* TODO: This should be stable. *)
    module T = struct
      (* Tock.Proof.t is not bin_io; should we wrap that snarky type? *)
      type t = Tock.Proof.t [@@deriving version {asserted}]

      let to_string = Binable.to_string (module Tock_backend.Proof)

      let of_string = Binable.of_string (module Tock_backend.Proof)
    end

    include T
    include Sexpable.Of_stringable(T)

    let to_yojson t = `String (to_string t)

    let of_yojson = function
      | `String x -> Ok (of_string x)
      | _ -> Error "expected `String"
  end

  module Latest = V1
end

type t = Stable.Latest.t

let dummy = Tock.Proof.dummy

include Sexpable.Of_stringable (Stable.Latest)

[%%define_locally
Stable.Latest.(to_yojson, of_yojson)]
