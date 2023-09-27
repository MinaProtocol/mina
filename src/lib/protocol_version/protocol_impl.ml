(* protocol_impl.ml *)

[%%import "/src/config.mlh"]

open Core_kernel
module Wire_types = Mina_wire_types.Protocol_impl

module Make_sig (A : Wire_types.Types.S) = struct
  module type S =
    Protocol_impl_intf.Full with type Stable.V1.t = A.V1.t
end

module Make_str (A : Wire_types.Concrete) = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = A.V1.t = { api : int; patch : int; tag : string option }
      [@@deriving compare, equal, sexp, yojson, fields]

      let to_latest = Fn.id
    end
  end]

  let of_string_exn s : t =
    let is_digit_string s = String.for_all s ~f:Char.is_digit in
    let get_api_and_patch api_patch =
      match String.split api_patch ~on:'.' with
      | [ api; patch ] ->
          if not (is_digit_string api && is_digit_string patch) then
            failwith "Unexpected nondigits in input" ;
          (Int.of_string api, Int.of_string patch)
      | _ ->
          failwith
            "Protocol_impl.of_string_exn: expected string of form \
             nn.nn"
    in
    match String.index s '-' with
    | None ->
        (* no tag *)
        let api, patch = get_api_and_patch s in
        { api; patch; tag = None }
    | Some n ->
        (* tag allowed to contain hyphen *)
        let before_tag = String.sub s ~pos:0 ~len:n in
        let tag = String.sub s ~pos:(n + 1) ~len:(String.length s - n - 1) in
        let api, patch = get_api_and_patch before_tag in
        { api; patch; tag = Some tag }

  let to_string t =
    sprintf "%u.%u%s" t.api t.patch
      (Option.value_map t.tag ~default:"" ~f:(fun tag -> "-" ^ tag))

  [%%inject "current_string", current_protocol_implementation]

  let current = of_string_exn current_string

  let is_valid t = t.api >= 1 && t.patch >= 0
end

include Wire_types.Make (Make_sig) (Make_str)
