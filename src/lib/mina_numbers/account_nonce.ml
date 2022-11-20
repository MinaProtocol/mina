module T = Nat.Make32 ()

(** See documentation of the {!Mina_wire_types} library *)
module Wire_types = Mina_wire_types.Mina_numbers.Account_nonce

module Make_sig (A : Wire_types.Types.S) = struct
  module type S = sig
    include Nat.Intf.UInt32_A with type Stable.V1.t = A.V1.t

    include Codable.S with type t := t
  end
end

module Make_str (_ : Wire_types.Concrete) = struct
  include T

  (* while we could use an int encoding for yojson (an OCaml int is 63-bits)
     we've committed to a string encoding
  *)
  include Codable.Make_of_string (T)
end

include Wire_types.Make (Make_sig) (Make_str)
