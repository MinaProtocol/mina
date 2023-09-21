open Core_kernel
module Js = Js_of_ocaml.Js
module Field = Pickles.Impls.Step.Field.Constant

external get_ts_bindings : unit -> Js.Unsafe.any Js.Optdef.t = "getTsBindings"

(* the ?. operator from JS *)
let ( |. ) (value : _ Js.Optdef.t) (key : string) =
  Js.(
    if phys_equal value undefined then undefined
    else Unsafe.get value (string key))

let lookup kind prefix =
  get_ts_bindings () |. kind |. prefix |> Js.Optdef.to_option

let of_js x =
  Js.to_array x |> Array.map ~f:(Fn.compose Field.of_string Js.to_string)

let salt s =
  match lookup "prefixHashes" s with
  | Some state ->
      of_js state |> Random_oracle.State.of_array
  | None ->
      Random_oracle.salt s

let salt_legacy s =
  match lookup "prefixHashesLegacy" s with
  | Some state ->
      of_js state |> Random_oracle.Legacy.State.of_array
  | None ->
      Random_oracle.Legacy.salt s
