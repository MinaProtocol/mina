open Core
open Import

module T = struct
  type t =
    {fee: Currency.Fee.Stable.V1.t; prover: Public_key.Compressed.Stable.V1.t}
  [@@deriving bin_io, sexp]
end

include T

let create ~fee ~prover = {fee; prover}

module Digest = struct
  module Stable = struct
    module V1 = struct
      include Random_oracle.Digest
    end
  end

  include Stable.V1

  let default = of_string (String.init length_in_bytes ~f:(fun _ -> '\000'))
end

let digest t = Random_oracle.digest_string (Binable.to_string (module T) t)
