open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type ('caller, 'parties) t =
      { caller : 'caller; caller_caller : 'caller; calls : 'parties }
    [@@deriving make, fields, sexp, yojson]
  end
end]

type value =
  ( (Account_id.t, bool) Caller.t
  , (Party.t, Parties.Digest.t) Parties.Call_forest.t )
  t

let to_input (type p)
    ({ caller; caller_caller; calls } :
      ( (Account_id.t, bool) Caller.t
      , (p, Parties.Digest.t) Parties.Call_forest.t )
      t) =
  List.reduce_exn ~f:Random_oracle.Input.Chunked.append
    [ Caller.to_input caller
    ; Caller.to_input caller_caller
    ; Random_oracle.Input.Chunked.field (Parties.Call_forest.hash calls)
    ]

let hash frame =
  Random_oracle.hash ~init:Hash_prefix_states.party_stack_frame
    (Random_oracle.pack_input (to_input frame))

module Checked = struct
  type nonrec 'parties t = (Caller.Checked.t, 'parties) t

  let if_ f b ~then_ ~else_ =
    { caller = Caller.Checked.if_ b ~then_:then_.caller ~else_:else_.caller
    ; caller_caller =
        Caller.Checked.if_ b ~then_:then_.caller_caller
          ~else_:else_.caller_caller
    ; calls = f b ~then_:then_.calls ~else_:else_.calls
    }
end
