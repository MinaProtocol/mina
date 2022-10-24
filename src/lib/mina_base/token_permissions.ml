[%%import "/src/config.mlh"]

open Core_kernel
open Snark_params.Step

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      | Token_owned of { disable_new_accounts : bool }
      | Not_owned of { account_disabled : bool }
    [@@deriving compare, equal, sexp, hash, yojson]

    let to_latest = Fn.id
  end
end]

let default = Not_owned { account_disabled = false }

let to_input t =
  let bs =
    match t with
    | Token_owned { disable_new_accounts } ->
        [ true; disable_new_accounts ]
    | Not_owned { account_disabled } ->
        [ false; account_disabled ]
  in
  Random_oracle.Input.Chunked.packed (Field.project bs, List.length bs)

[%%ifdef consensus_mechanism]

open Snark_params.Step

type var = { token_owner : Boolean.var; token_locked : Boolean.var }

let var_of_t = function
  | Token_owned { disable_new_accounts } ->
      { token_owner = Boolean.true_
      ; token_locked = Boolean.var_of_value disable_new_accounts
      }
  | Not_owned { account_disabled } ->
      { token_owner = Boolean.false_
      ; token_locked = Boolean.var_of_value account_disabled
      }

let typ : (var, t) Typ.t =
  let open Typ in
  Boolean.typ * Boolean.typ
  |> Typ.transport_var
       ~back:(fun (token_owner, token_locked) -> { token_owner; token_locked })
       ~there:(fun { token_owner; token_locked } -> (token_owner, token_locked))
  |> Typ.transport
       ~there:(function
         | Token_owned { disable_new_accounts } ->
             (true, disable_new_accounts)
         | Not_owned { account_disabled } ->
             (false, account_disabled) )
       ~back:(fun (token_owner, token_locked) ->
         if token_owner then Token_owned { disable_new_accounts = token_locked }
         else Not_owned { account_disabled = token_locked } )

let var_to_input { token_owner; token_locked } =
  let bs = [ token_owner; token_locked ] in
  Random_oracle.Input.Chunked.packed (Field.Var.project bs, List.length bs)

[%%endif]

let gen =
  let open Quickcheck.Generator.Let_syntax in
  let%bind token_owner = Quickcheck.Generator.bool in
  let%map token_locked = Quickcheck.Generator.bool in
  if token_owner then Token_owned { disable_new_accounts = token_locked }
  else Not_owned { account_disabled = token_locked }
