

module Make
  (Transition_with_witness : Minibit.Transition_with_witness_intf)
  (Inputs : Protocols.Minibit_pow.Inputs_intf)
= struct
  open Inputs

  type t = 
    { transitions : Transition_with_witness.t Linear_pipe.Reader.t
    }
  type change =
    | Tip_change of State.t

  let create ~change_feeder = 
    let (transition_reader, transition_writer) = Linear_pipe.create () in
    { transitions = transition_reader }

  let transitions t =
    t.transitions

end
