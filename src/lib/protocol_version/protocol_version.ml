(* protocol_version.ml *)

[%%import "/src/config.mlh"]

(* see RFC 0049 for details *)

open Core_kernel
module Wire_types = Mina_wire_types.Protocol_version

module Make_sig (A : Wire_types.Types.S) = struct
  module type S = Protocol_version_intf.Full with type Stable.V2.t = A.V2.t
end

module Make_str (A : Wire_types.Concrete) = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t = A.V2.t = { transaction : int; network : int; patch : int }
      [@@deriving compare, equal, sexp, yojson, fields]

      let to_latest = Fn.id
    end
  end]

  let create = Fields.create

  let of_string_exn s =
    let is_digit_string s = String.for_all s ~f:Char.is_digit in
    match String.split s ~on:'.' with
    | [ transaction; network; patch ] ->
        if
          not
            ( is_digit_string transaction
            && is_digit_string network && is_digit_string patch )
        then failwith "Unexpected nondigits in input" ;
        { transaction = Int.of_string transaction
        ; network = Int.of_string network
        ; patch = Int.of_string patch
        }
    | _ ->
        failwith
          "Protocol_version.of_string_exn: expected string of form nn.nn.nn"

  let of_string_opt s = try Some (of_string_exn s) with _ -> None

  let to_string t = sprintf "%u.%u.%u" t.transaction t.network t.patch

  [%%inject "current_transaction", protocol_version_transaction]

  [%%inject "current_network", protocol_version_network]

  [%%inject "current_patch", protocol_version_patch]

  let current =
    { transaction = current_transaction
    ; network = current_network
    ; patch = current_patch
    }

  let (proposed_protocol_version_opt : t option ref) = ref None

  let set_proposed_opt t_opt = proposed_protocol_version_opt := t_opt

  let get_proposed_opt () = !proposed_protocol_version_opt

  let compatible_with_daemon (t : t) =
    (* patch not considered for compatibility *)
    t.transaction = current.transaction && t.network = current.network

  (* when an external transition is deserialized, might contain
     negative numbers
  *)
  let is_valid t = t.transaction >= 1 && t.network >= 1 && t.patch >= 0
end

include Wire_types.Make (Make_sig) (Make_str)
