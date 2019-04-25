module Params = Group_map.Params

let to_group = Group_map.to_group

module Checked = struct
  open Snarky

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
