open Core_kernel
module Params = Group_map.Params

let to_group (type t)
    (module F : Group_map.Field_intf.S_unchecked with type t = t) ~params t =
  let module M =
    Group_map.Make
      (F)
      (struct
        include F

        let constant = Fn.id
      end)
      (struct
        let params = params
      end)
  in
  let {Group_map.Spec.a; b} = Params.spec params in
  let try_decode x =
    let f x = F.((x * x * x) + (a * x) + b) in
    let y = f x in
    if F.is_square y then Some (x, F.sqrt y) else None
  in
  let x1, x2, x3 = M.potential_xs t in
  List.find_map [x1; x2; x3] ~f:try_decode |> Option.value_exn

module Checked = struct
  open Snarky_backendless

  let wrap = Checked_map.wrap

  let to_group (type f) (module M : Snark_intf.Run with type field = f) ~params
      t =
    let module G =
      Checked_map.Make
        (M)
        (struct
          let params = params
        end)
    in
    G.to_group t
end
