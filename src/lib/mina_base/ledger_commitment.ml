open Core_kernel

(* This record is used for committing to a "ledger" which
   consists of both the next available token ID, and the merkle tree
   root. *)
[%%versioned
module Stable = struct
  module V1 = struct
    type ('tree, 'token_id) t =
      { tree : 'tree; next_available_token : 'token_id }
    [@@deriving compare, equal, hash, sexp, yojson, hlist]
  end
end]

let to_input ({ tree; next_available_token } : (Ledger_hash.t, Token_id.t) t) :
    _ Random_oracle_input.Chunked.t =
  Random_oracle.Input.Chunked.append
    (Ledger_hash.to_input tree)
    (Token_id.to_input next_available_token)

open Pickles.Impls.Step

let typ : _ Typ.t =
  Typ.of_hlistable
    [ Ledger_hash.typ; Token_id.typ ]
    ~var_of_hlist:of_hlist ~value_of_hlist:of_hlist ~var_to_hlist:to_hlist
    ~value_to_hlist:to_hlist

type value = (Ledger_hash.t, Token_id.t) t
[@@deriving compare, equal, sexp, yojson, hash]

module Value = struct
  type t = value [@@deriving compare, equal, sexp, yojson, hash]
end

let gen =
  let open Quickcheck.Generator.Let_syntax in
  let%map tree = Frozen_ledger_hash.gen
  and next_available_token = Token_id.gen_non_default in
  { tree; next_available_token }

module Checked = struct
  type nonrec t = (Ledger_hash.var, Token_id.var) t

  module Assert = struct
    let equal (t1 : t) (t2 : t) =
      run_checked (Ledger_hash.assert_equal t1.tree t2.tree) ;
      run_checked
        (Token_id.Checked.Assert.equal t1.next_available_token
           t2.next_available_token)
  end

  let if_ b ~then_:(t1 : t) ~else_:(t2 : t) : t =
    { tree = run_checked (Ledger_hash.if_ b ~then_:t1.tree ~else_:t2.tree)
    ; next_available_token =
        run_checked
          (Token_id.Checked.if_ b ~then_:t1.next_available_token
             ~else_:t2.next_available_token)
    }

  let to_input ({ tree; next_available_token } : t) :
      _ Random_oracle_input.Chunked.t =
    Random_oracle.Input.Chunked.append
      (Ledger_hash.var_to_input tree)
      (Token_id.Checked.to_input next_available_token)

  let equal (t1 : t) (t2 : t) : Boolean.var =
    Boolean.all
      [ run_checked (Ledger_hash.equal_var t1.tree t2.tree)
      ; run_checked
          (Token_id.Checked.equal t1.next_available_token
             t2.next_available_token)
      ]
end
