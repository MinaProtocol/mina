open Core_kernel
open Models
open Lib
open Async

module Reason = struct
  type t = Amount | Account | Account_pk | Account_token_id | Status | Type
  [@@deriving eq, sexp, show]
end

module Account = struct
  type t = {pk: string; token_id: Unsigned.UInt64.t}
end

type t =
  {amount: int option; account: Account.t option; status: string; _type: string}

(** Returns a validation of the reasons it is not similar or unit if it is *)
let similar t (op : Operation.t) =
  let open Validation in
  let open Validation.Let_syntax in
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
  let%map _ =
    opt_eq t.amount op.amount ~err:Amount ~f:(fun x y ->
        test String.(equal (string_of_int x) y.Amount.value) Amount )
  and _ =
    opt_eq t.account op.account ~err:Account ~f:(fun x y ->
        let%map _ =
          test
            String.(equal x.Account.pk y.Account_identifier.address)
            Account_pk
        and _ =
          match y.metadata with
          | Some (`Assoc [("token_id", `String y)]) ->
              test
                String.(equal (Unsigned.UInt64.to_string x.token_id) y)
                Account_token_id
          | _ ->
              fail Account_token_id
        in
        () )
  and _ = test String.(equal t.status op.status) Status
  and _ = test String.(equal t._type op._type) Type in
  ()

(** Result of the first expected operation that is wrong. Shows the "closest"
 * match by selecting the one with minimal error reasons *)
let assert_similar_operations ~situation ~expected ~actual =
  List.fold expected ~init:(Result.return ()) ~f:(fun acc t ->
      let open Result.Let_syntax in
      let%bind () = acc in
      let validation, op =
        (* Test against all actuals *)
        List.map actual ~f:(fun op -> (similar t op, op))
        (* Take the "best" *)
        |> List.max_elt ~compare:(fun (v1, _) (v2, _) ->
               match (v1, v2) with
               | Ok _, _ ->
                   1
               | _, Ok _ ->
                   -1
               | Error es, Error es' ->
                   -1 * (List.length es - List.length es') )
        |> Option.value_exn
      in
      Result.map_error validation ~f:(fun e -> (e, op)) )
  |> Result.map_error ~f:(fun (es, op) ->
         Errors.create
           ~context:
             (sprintf
                !"Unexpected operations in %s reasons: %{sexp: Reason.t \
                  list}, raw: %s"
                situation es (Operation.show op))
           `Invariant_violation )
  |> Deferred.return
