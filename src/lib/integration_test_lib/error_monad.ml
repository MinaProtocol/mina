open Core_kernel
open Async_kernel

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

module ErrorReporting = Monad.Make (struct
  type 'a t = ('a Accumulator.t, Hard_fail.t) Deferred.Result.t

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

let%test_unit "error_monad_unit_test_1" =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let open Deferred.Let_syntax in
      let%map test1 =
        let open ErrorReporting.Let_syntax in
        let f nm =
          let%bind n = nm in
          Deferred.return
            (Ok {Accumulator.computation_result= n + 1; soft_errors= []})
        in
        f (f (f (f (f (return 0)))))
      in
      [%test_eq: (int Accumulator.t, Hard_fail.t) Result.t] test1
        (Ok {Accumulator.computation_result= 6; soft_errors= []}) )

let%test_unit "error_monad_unit_test_2" =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let open Deferred.Let_syntax in
      let%map test2 =
        let open ErrorReporting.Let_syntax in
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
        let open ErrorReporting.Let_syntax in
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
        let open ErrorReporting.Let_syntax in
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
        let open ErrorReporting.Let_syntax in
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
        let open ErrorReporting.Let_syntax in
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
