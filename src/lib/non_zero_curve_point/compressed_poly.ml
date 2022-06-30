(* compressed_poly.ml -- versioned type with parameters for compressed curve point *)

[%%import "/src/config.mlh"]

open Core_kernel

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('field, 'boolean) t =
            ('field, 'boolean) Mina_wire_types.Public_key.Compressed.Poly.t =
        { x : 'field; is_odd : 'boolean }
      [@@deriving compare, equal, hash, hlist]
    end
  end]
end
