open Async_kernel

type 'event t = 'event Pipe.Writer.t

let create ~handle =
  let reader, writer = Pipe.create () in
  don't_wait_for (Pipe.iter_without_pushback reader ~f:handle) ;
  writer

let submit = Pipe.write_without_pushback

let%test_module "Event_loop" =
  ( module struct
    open Core_kernel

    let handled_after f =
      Async.Thread_safe.block_on_async_exn (fun () ->
          let handled = ref [] in
          let loop_ref = ref None in
          let loop =
            create ~handle:(fun event ->
                handled := event :: !handled ;
                (* Handling 1 submits 4, which runs after those already
                   queued. *)
                if Int.equal event 1 then submit (Option.value_exn !loop_ref) 4 )
          in
          loop_ref := Some loop ;
          f loop ;
          let%map () = Async.Scheduler.yield_until_no_jobs_remain () in
          List.rev !handled )

    let%test_unit "Events are handled in the order they are submitted" =
      [%test_eq: int list]
        (handled_after (fun loop ->
             submit loop 1 ; submit loop 2 ; submit loop 3 ) )
        [ 1; 2; 3; 4 ]
  end )
