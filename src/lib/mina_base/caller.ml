open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type ('account_id, 'bool) t = { id : 'account_id; token_owner : 'bool }
    [@@deriving compare, equal, hash, sexp, yojson, fields, hlist]
  end
end]

let typ =
  Snarky_backendless.Typ.of_hlistable ~var_to_hlist:to_hlist
    ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
    [ Account_id.typ; Pickles.Impls.Step.Boolean.typ ]

let to_input ({ id; token_owner } : _ t) =
  List.reduce_exn ~f:Random_oracle.Input.Chunked.append
    [ Account_id.to_input id
    ; Random_oracle.Input.Chunked.packed (Util.field_of_bool token_owner, 1)
    ]

module Checked = struct
  open Pickles.Impls.Step

  type nonrec t = (Account_id.var, Boolean.var) t

  let if_ b ~then_:(c1 : t) ~else_:(c2 : t) : t =
    { id = run_checked (Account_id.Checked.if_ b ~then_:c1.id ~else_:c2.id)
    ; token_owner = Boolean.if_ b ~then_:c1.token_owner ~else_:c2.token_owner
    }

  let to_input ({ id; token_owner } : t) =
    List.reduce_exn ~f:Random_oracle.Input.Chunked.append
      [ Account_id.Checked.to_input id
      ; Random_oracle.Input.Chunked.packed ((token_owner :> Field.t), 1)
      ]
end
