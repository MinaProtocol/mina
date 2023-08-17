open Core_kernel
module Js = Js_of_ocaml.Js
module Field = Pickles.Impls.Step.Field.Constant

external get_ts_bindings : unit -> Js.Unsafe.any = "getTsBindings"

let lookup (kind : string) (s : string) =
  let prefix_hashes : Js.Unsafe.any =
    Js.Unsafe.get (get_ts_bindings ()) (Js.string kind)
  in
  Js.Optdef.to_option (Js.Unsafe.get prefix_hashes (Js.string s))

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
