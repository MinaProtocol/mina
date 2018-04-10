

module Make
  (Inputs : Protocols.Minibit_pow.Inputs_intf)
= struct
  open Inputs

  type t = ()
  type change =
    | Tip_change of State.t

  let create ~change_feeder = ()

  let transitions t =
    let (r, w) = Linear_pipe.create () in
    r

end
