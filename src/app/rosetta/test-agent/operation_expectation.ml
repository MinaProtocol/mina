open Core_kernel
open Rosetta_models
open Rosetta_lib
open Async

module Reason = struct
  type t =
    | Amount
    | Account
    | Account_pk
    | Account_token_id
    | Status
    | Target
    | Type
  [@@deriving eq, sexp, show]
end

module Account = struct
  type t = {pk: string; token_id: Unsigned.UInt64.t}
end

type t =
  { amount: int option
  ; account: Account.t option
  ; status: string
  ; _type: string
  ; target: string option }

(** Returns a validation of the reasons it is not similar or unit if it is *)
let similar ~logger:_ t (op : Operation.t) =
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
  and _ =
    opt_eq t.target op.metadata ~err:Target ~f:(fun target metadata ->
        match metadata with
        | `Assoc [("delegate_change_target", `String y)] ->
            test String.(equal y target) Target
        | _ ->
            fail Target )
  and _ = test String.(equal t._type op._type) Type in
  ()

(** Result of the first expected operation that is wrong. Shows the "closest"
 * match by selecting the one with minimal error reasons *)
let assert_similar_operations ~logger ~situation ~expected ~actual =
  let rec choose_similar t least_bad_err rest = function
    | [] ->
        (* TODO: This may raise if we are expecting more ops than we get *)
        Error (fst (Option.value_exn least_bad_err))
    | op :: ops -> (
      match similar ~logger t op with
      | Ok _ ->
          (* Return the operations with this one removed *)
          Ok (rest @ ops)
      | Error es ->
          let l = List.length es in
          let least_bad_err =
            match least_bad_err with
            | Some (_, l') when l' <= l ->
                least_bad_err
            | _ ->
                Some ((op, es), l)
          in
          choose_similar t least_bad_err (op :: rest) ops )
  in
  List.fold_result expected ~init:actual ~f:(fun actual t ->
      choose_similar t None [] actual )
  |> Result.map_error ~f:(fun (op, es) ->
         Errors.create
           ~context:
             (sprintf
                !"Unexpected operations in %s reasons: %{sexp: Reason.t \
                  list}, raw: %s"
                situation es (Operation.show op))
           `Invariant_violation )
  |> Result.ignore |> Deferred.return
