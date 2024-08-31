(* compressed_poly.ml -- versioned type with parameters for compressed curve point *)

open Core_kernel

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      [@@@with_all_version_tags]

      type ('field, 'boolean) t =
            ('field, 'boolean) Mina_wire_types.Public_key.Compressed.Poly.V1.t =
        { x : 'field; is_odd : 'boolean }
      [@@deriving compare, equal, hash, hlist]
    end
  end]
end
