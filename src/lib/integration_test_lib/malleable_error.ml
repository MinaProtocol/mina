open Core_kernel
open Async_kernel

(** The is a monad which is conceptually similar to `Deferred.Or_error.t`,
 *  except that there are 2 types of errors which can be returned at each bind
 *  point in a computation: soft errors, and hard errors. Soft errors do not
 *  effect the control flow of the monad, and are instead accumulated for later
 *  extraction. Hard errors effect the control flow of the monad in the same
 *  way an `Error` constructor for `Or_error.t` would.
 It remains similar to Deferred.Or_error.t in that it is a specialization of Deferred.Result.t
 *)

module Hard_fail = struct
  type t =
    { hard_error: Error.t
          [@equal
            fun a b ->
              String.equal (Error.to_string_hum a) (Error.to_string_hum b)]
    ; soft_errors: Error.t list
          [@equal
            List.equal (fun a b ->
                String.equal (Error.to_string_hum a) (Error.to_string_hum b) )]
    }
  [@@deriving eq, sexp_of, compare]
end

module Accumulator = struct
  type 'a t =
    { computation_result: 'a
    ; soft_errors: Error.t list
          [@equal
            List.equal (fun a b ->
                String.equal (Error.to_string_hum a) (Error.to_string_hum b) )]
    }
  [@@deriving eq, sexp_of, compare]
end

type 'a t = ('a Accumulator.t, Hard_fail.t) Deferred.Result.t

module T = Monad.Make (struct
  type nonrec 'a t = 'a t

  let return a =
    Deferred.return (Ok {Accumulator.computation_result= a; soft_errors= []})

  let bind res ~f =
    match%bind res with
    | Ok {Accumulator.computation_result= prev_result; soft_errors= err_list}
      -> (
        let execProg = f prev_result in
        match%bind execProg with
        | Ok {Accumulator.computation_result= comp; soft_errors= next_list} ->
            Deferred.return
              (Ok
                 { Accumulator.computation_result= comp
                 ; Accumulator.soft_errors= List.append err_list next_list })
        | Error
            {Hard_fail.hard_error= hard_err; Hard_fail.soft_errors= next_list}
          ->
            Deferred.return
              (Error
                 { Hard_fail.hard_error= hard_err
                 ; soft_errors= List.append err_list next_list }) )
    | Error _ as error ->
        Deferred.return error

  let map = `Define_using_bind
end)

include T

let return_without_deferred a =
  Ok {Accumulator.computation_result= a; soft_errors= []}

let return_unit_without_deferred =
  Ok {Accumulator.computation_result= (); soft_errors= []}

let ok_unit = return ()

let ok_exn (res : 'a t) : 'a Deferred.t =
  let open Deferred.Let_syntax in
  match%bind res with
  | Ok {Accumulator.computation_result= x; soft_errors= _} ->
      Deferred.return x
  | Error {Hard_fail.hard_error= err; Hard_fail.soft_errors= _} ->
      Error.raise err

let error_string message =
  Deferred.return
    (Error {Hard_fail.hard_error= Error.of_string message; soft_errors= []})

let errorf format = Printf.ksprintf error_string format

let return_of_error a =
  Deferred.return (Error {Hard_fail.hard_error= a; soft_errors= []})

let or_error_to_malleable_error (or_err : 'a Deferred.Or_error.t) : 'a t =
  let open Deferred.Let_syntax in
  match%map or_err with
  | Ok x ->
      Ok {Accumulator.computation_result= x; soft_errors= []}
  | Error err ->
      Error {Hard_fail.hard_error= err; soft_errors= []}

let try_with ?(backtrace = false) (f : unit -> 'a) : 'a t =
  try
    Deferred.return
      (Ok {Accumulator.computation_result= f (); soft_errors= []})
  with exn ->
    Deferred.return
      (Error
         { Hard_fail.hard_error=
             Error.of_exn exn ?backtrace:(if backtrace then Some `Get else None)
         ; soft_errors= [] })

let rec malleable_error_list_iter ls ~f =
  let open T.Let_syntax in
  match ls with
  | [] ->
      return ()
  | h :: t ->
      let%bind () = f h in
      malleable_error_list_iter t ~f

let rec malleable_error_list_map ls ~f =
  let open T.Let_syntax in
  match ls with
  | [] ->
      return []
  | h :: t ->
      let%bind h' = f h in
      let%map t' = malleable_error_list_map t ~f in
      h' :: t'

let rec malleable_error_list_fold_left_while ls ~init ~f =
  let open T.Let_syntax in
  match ls with
  | [] ->
      return init
  | h :: t -> (
      match%bind f init h with
      | `Stop init' ->
          return init'
      | `Continue init' ->
          malleable_error_list_fold_left_while t ~init:init' ~f )

let malleable_error_of_option opt msg : 'a t =
  Option.value_map opt
    ~default:
      (Deferred.return
         (Error
            { Hard_fail.hard_error= Error.of_string msg
            ; Hard_fail.soft_errors= [] }))
    ~f:T.return

(* Unit tests to follow *)

let%test_unit "error_monad_unit_test_1" =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let open Deferred.Let_syntax in
      let%map test1 =
        let open T.Let_syntax in
        let f nm =
          let%bind n = nm in
          Deferred.return
            (Ok {Accumulator.computation_result= n + 1; soft_errors= []})
        in
        f (f (f (f (f (return 0)))))
      in
      [%test_eq: (int Accumulator.t, Hard_fail.t) Result.t] test1
        (Ok {Accumulator.computation_result= 5; soft_errors= []}) )

let%test_unit "error_monad_unit_test_2" =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let open Deferred.Let_syntax in
      let%map test2 =
        let open T.Let_syntax in
        let%bind () =
          Deferred.return
            (Ok {Accumulator.computation_result= (); soft_errors= []})
        in
        Deferred.return
          (Ok {Accumulator.computation_result= "123"; soft_errors= []})
      in
      [%test_eq: (string Accumulator.t, Hard_fail.t) Result.t] test2
        (Ok {Accumulator.computation_result= "123"; soft_errors= []}) )

let%test_unit "error_monad_unit_test_3" =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let open Deferred.Let_syntax in
      let%map test3 =
        let open T.Let_syntax in
        let%bind () =
          Deferred.return
            (Ok
               { Accumulator.computation_result= ()
               ; soft_errors= [Error.of_string "a"] })
        in
        Deferred.return
          (Ok
             { Accumulator.computation_result= "123"
             ; soft_errors= [Error.of_string "b"] })
      in
      [%test_eq: (string Accumulator.t, Hard_fail.t) Result.t] test3
        (Ok
           { Accumulator.computation_result= "123"
           ; soft_errors= List.map ["a"; "b"] ~f:Error.of_string }) )

let%test_unit "error_monad_unit_test_4" =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let open Deferred.Let_syntax in
      let%map test4 =
        let open T.Let_syntax in
        let%bind () =
          Deferred.return
            (Ok {Accumulator.computation_result= (); soft_errors= []})
        in
        Deferred.return
          (Error {Hard_fail.hard_error= Error.of_string "xyz"; soft_errors= []})
      in
      [%test_eq: (string Accumulator.t, Hard_fail.t) Result.t] test4
        (Error {Hard_fail.hard_error= Error.of_string "xyz"; soft_errors= []})
  )

let%test_unit "error_monad_unit_test_5" =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let open Deferred.Let_syntax in
      let%map test5 =
        let open T.Let_syntax in
        let%bind () =
          Deferred.return
            (Ok
               { Accumulator.computation_result= ()
               ; soft_errors= [Error.of_string "a"] })
        in
        Deferred.return
          (Error {Hard_fail.hard_error= Error.of_string "xyz"; soft_errors= []})
      in
      [%test_eq: (string Accumulator.t, Hard_fail.t) Result.t] test5
        (Error
           { Hard_fail.hard_error= Error.of_string "xyz"
           ; soft_errors= [Error.of_string "a"] }) )

let%test_unit "error_monad_unit_test_6" =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let open Deferred.Let_syntax in
      let%map test6 =
        let open T.Let_syntax in
        let%bind () =
          Deferred.return
            (Ok
               { Accumulator.computation_result= ()
               ; soft_errors= [Error.of_string "a"] })
        in
        Deferred.return
          (Error
             { Hard_fail.hard_error= Error.of_string "xyz"
             ; soft_errors= [Error.of_string "b"] })
      in
      [%test_eq: (string Accumulator.t, Hard_fail.t) Result.t] test6
        (Error
           { Hard_fail.hard_error= Error.of_string "xyz"
           ; soft_errors= [Error.of_string "a"; Error.of_string "b"] }) )
