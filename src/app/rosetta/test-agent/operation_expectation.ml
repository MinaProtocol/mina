open Core_kernel
open Models

module Reason = struct
  type t = Amount | Account | Account_pk | Account_token_id | Status | Type
  [@@deriving eq, sexp, show]
end

module Account = struct
  type t = {pk: string; token_id: Unsigned.UInt64.t}
end

type t =
  {amount: int option; account: Account.t option; status: string; _type: string}

let similar t (op : Operation.t) =
  let open Result in
  let open Result.Let_syntax in
  let open Reason in
  let opt_eq ~f a b ~err =
    match (a, b) with
    | Some x, Some y ->
        f x y
    | None, None ->
        return ()
    | _ ->
        fail err
  in
  let test b err = if b then return () else fail err in
  let%bind () =
    opt_eq t.amount op.amount ~err:Amount ~f:(fun x y ->
        test String.(equal (string_of_int x) y.Amount.value) Amount )
  in
  let%bind () =
    opt_eq t.account op.account ~err:Account ~f:(fun x y ->
        let%bind () =
          test
            String.(equal x.Account.pk y.Account_identifier.address)
            Account_pk
        in
        let%bind y_token_id =
          match y.metadata with
          | Some (`Assoc [("token_id", `String x)]) ->
              return x
          | _ ->
              fail Account_token_id
        in
        test
          String.(equal (Unsigned.UInt64.to_string x.token_id) y_token_id)
          Account_token_id )
  in
  let%bind () = test String.(equal t.status op.status) Status in
  test String.(equal t._type op._type) Type
