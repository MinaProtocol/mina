open Core_kernel

type field = Pickles.Impls.Step.Internal_Basic.field

(* Alias to distinguish hashes from inputs *)
type hash = field

type input_t = [ `State of field Oracle.State.t ] * field array

(** Defines a batching hash monad.contents

    Originally started as a specialized variant of Freer monad.
    See: Oleg Kiselyov, and Hiromi Ishii. “Freer Monads, More Extensible Effects.”
    https://okmij.org/ftp/Haskell/extensible/more.pdf

    For better performance it was encoded using Final tagless technique, and now
    looks quite different from its original inspiration.
*)

type request_t =
  { (* request is a non-empty sequence *)
    request : input_t Sequence.t
  ; request_len : int
  }

(* Contract: some implementations of this function may schedule continuation
   to be executed within an async job, they should then return true *)
type impure_t = request_t -> (int -> hash array -> unit) -> unit

type 'a t = impure:impure_t -> ('a -> unit) -> unit

let empty_request = { request = Sequence.empty; request_len = 0 }

let join_requests areq breq =
  { request = Sequence.append areq.request breq.request
  ; request_len = areq.request_len + breq.request_len
  }

let execute_request request =
  Sequence.to_list request |> Oracle.hash_batch |> Array.of_list

let impure_default : impure_t =
 fun { request; _ } cont -> execute_request request |> cont 0

let evaluate : 'a t -> 'a =
 fun v ->
  let res = ref None in
  v ~impure:impure_default (fun r -> res := Some r) ;
  Option.value_exn ~message:"unexpected evaluation" !res

let impure_async ~schedule { request; _ } cont =
  Async.upon (schedule @@ fun () -> execute_request request) (cont 0)

let handle_result_under_mutex ~ready ~not_ready mutex par_job_res =
  match Nano_mutex.try_lock_exn mutex with
  | `Acquired -> (
      let prev_res = !par_job_res in
      par_job_res := None ;
      Nano_mutex.unlock_exn mutex ;
      (* If prev_res is None, this means that there is another job recently launched,
         which didn't acquire the lock yet *)
      match prev_res with None -> not_ready () | Some r -> ready r )
  | `Not_acquired ->
      not_ready ()

let evaluate_async :
       ?how:[ `Alternating | `Parallel | `Max_concurrent_jobs of int ]
    -> ?when_finished:Async.In_thread.When_finished.t
    -> 'a t
    -> 'a Async.Deferred.t =
 fun ?(how = `Parallel) ?when_finished v ->
  let in_thread = Async.In_thread.run ?when_finished ~name:"hash_batch" in
  let impure =
    match how with
    | `Alternating -> (
        let mutex = Nano_mutex.create () in
        (* owned by the thread holding the mutex *)
        let par_job_res = ref None in
        (* owned by main thread *)
        let par_job_cont = ref None in
        let ensure_cont_executed () =
          Option.iter !par_job_cont ~f:(fun prev_cont ->
              handle_result_under_mutex mutex par_job_res ~not_ready:Fn.id
                ~ready:(fun prev_res ->
                  par_job_cont := None ;
                  prev_cont 0 prev_res ) )
        in
        let schedule_parallel req cont =
          par_job_cont := Some cont ;
          Async.upon
            ( in_thread
            @@ fun () ->
            Nano_mutex.critical_section mutex ~f:(fun () ->
                par_job_res := Some (execute_request req.request) ) )
            (fun () -> ensure_cont_executed ())
        in
        fun req cont ->
          match !par_job_cont with
          | None ->
              schedule_parallel req cont
          | Some prev_cont ->
              handle_result_under_mutex mutex par_job_res
                ~not_ready:(fun () -> impure_default req cont)
                ~ready:(fun prev_res ->
                  schedule_parallel req cont ; prev_cont 0 prev_res ) ;
              (* This call is optional, to avoid unnecessary switch of async context *)
              ensure_cont_executed () )
    | `Parallel ->
        impure_async ~schedule:in_thread
    | `Max_concurrent_jobs n ->
        let throttle =
          Async.Throttle.create ~max_concurrent_jobs:n ~continue_on_error:true
        in
        impure_async ~schedule:(fun f ->
            Async.Throttle.enqueue throttle @@ fun () -> in_thread f )
  in
  let res = Async.Ivar.create () in
  v ~impure (Async.Ivar.fill res) ;
  Async.Ivar.read res

module M_basic = struct
  let bind : type a b. a t -> f:(a -> b t) -> b t =
   fun t ~f ~impure handle_res ->
    t ~impure (fun tres -> f tres ~impure handle_res)

  let return : 'a -> 'a t = fun a ~impure:_ handle -> handle a

  let map : type a b. a t -> f:(a -> b) -> b t =
   fun v ~f ~impure handle_res -> v ~impure (Fn.compose handle_res f)
end

let hash ~init data : hash t =
 fun ~(impure : impure_t) handler ->
  impure
    { request = Sequence.return (`State init, data); request_len = 1 }
    (fun i h -> handler @@ Array.get h i)

let batch_drain = 256

let hash_batch data : hash list t =
 fun ~(impure : impure_t) handler ->
  let request_len = List.length data in
  if request_len = 0 then handler []
  else
    impure
      { request = Sequence.of_list data; request_len }
      (fun start_ix hashes ->
        handler
        @@ List.init request_len ~f:(fun i ->
               Array.get hashes @@ (i + start_ix) ) )

(* TODO write a test with random elements to cjeck the order of indexes in continuations *)
let app_impl ~impure ~on_ready start =
  let empty_accum = (empty_request, []) in
  let req_accum = ref empty_accum in
  (* When we start impure, we pass a continuation to it.
     We don't have control over how and when impure will be executed,
     hence we need to count how many continuations were set sail.
     When the last continuation we spawned is finsihed, we need to check that
     request accumulator is emptied.
      Initial value is 1 because `start` routine is treated as initial continuation *)
  let unfinished_continuations = ref 1 in
  let rec on_continuation_done () =
    if !unfinished_continuations = 0 then
      let r, cs = !req_accum in
      if r.request_len = 0 then on_ready ()
      else (
        req_accum := empty_accum ;
        spawn_impure r cs )
  and spawn_impure req conts =
    let cont' start_ix hashes =
      List.iter conts ~f:(fun (exec, ix) -> exec (start_ix + ix) hashes) ;
      unfinished_continuations := !unfinished_continuations - 1 ;
      on_continuation_done ()
    in
    unfinished_continuations := !unfinished_continuations + 1 ;
    impure req cont'
  in
  let impure' req cont =
    let joint_req, conts =
      let r, cs = !req_accum in
      (join_requests r req, (cont, r.request_len) :: cs)
    in
    if joint_req.request_len >= batch_drain then (
      req_accum := empty_accum ;
      spawn_impure joint_req conts )
    else req_accum := (joint_req, conts)
  in
  start impure' ;
  unfinished_continuations := !unfinished_continuations - 1 ;
  on_continuation_done ()

let ( <*> ) : type a b. (a -> b) t -> a t -> b t =
 fun f a ~impure handle_res ->
  let a_res_ref = ref None in
  let f_res_ref = ref None in
  let on_ready () =
    let f' = Option.value_exn ~message:"<*>: no value for f" !f_res_ref in
    let a' = Option.value_exn ~message:"<*>: no value for a" !a_res_ref in
    handle_res (f' a')
  in
  app_impl ~impure ~on_ready (fun impure' ->
      f ~impure:impure' (fun f' -> f_res_ref := Some f') ;
      a ~impure:impure' (fun a' -> a_res_ref := Some a') )

let lift2 f a b ~impure handle = (M_basic.map ~f a <*> b) ~impure handle

let all_impl ~impure ~set_result ~on_ready lst =
  let init impure' i action = action ~impure:impure' (set_result i) in
  app_impl ~impure ~on_ready (fun impure' -> List.iteri ~f:(init impure') lst)

module M : Core_kernel.Monad.S with type 'a t := 'a t = struct
  include M_basic

  module Monad_infix = struct
    let ( >>= ) t f = bind t ~f

    let ( >>| ) t f = map t ~f
  end

  include Monad_infix

  module Let_syntax = struct
    let return = return

    include Monad_infix

    module Let_syntax = struct
      include M_basic

      let both a b = lift2 Tuple2.create a b

      module Open_on_rhs = struct end
    end
  end

  let join t = t >>= ident

  let ignore_m t = map ~f:(const ()) t

  let all : type a. a t list -> a list t =
   fun lst ~impure handle_res ->
    let results = Array.init (List.length lst) ~f:(const None) in
    let set_result i a = Array.set results i (Some a) in
    all_impl ~set_result ~impure lst ~on_ready:(fun () ->
        let missing =
          Array.to_list results
          |> List.filter_mapi ~f:(fun i -> function
               | None -> Some i | Some _ -> None )
        in
        if List.is_empty missing then
          handle_res @@ List.filter_map ~f:Fn.id @@ Array.to_list results
        else
          failwithf "elements missing: %s"
            (String.concat ~sep:", " (List.map ~f:Int.to_string missing))
            () )

  let all_unit : unit t list -> unit t =
   fun lst ~impure on_ready ->
    let set_result _ () = () in
    all_impl ~set_result ~impure lst ~on_ready
end

include M

let map_list ~f = Fn.compose all @@ List.map ~f

let fold_right ~f ~init =
  List.fold_right ~init:(return init) ~f:(fun el -> bind ~f:(f el))

module For_tests = struct
  module Counting_executor () = struct
    let calls = ref 0

    let total = ref 0

    let test_impure : impure_t =
     fun { request; _ } cont ->
      calls := !calls + 1 ;
      let total_els =
        Sequence.fold ~init:0 ~f:(fun a (_, b) -> a + Array.length b) request
      in
      total := !total + total_els ;
      let request = Sequence.(to_list request) in
      let response =
        List.map ~f:(Fn.compose (Fn.flip Array.get 0) snd) request
        |> Array.of_list
      in
      cont 0 response

    let test_evaluate : 'a t -> 'a =
     fun v ->
      let res = ref None in
      v ~impure:test_impure (fun r -> res := Some r) ;
      Option.value_exn ~message:"unexpected evaluation" !res
  end
end

let%test_module "simple test" =
  ( module struct
    open Snark_params.Tick

    open For_tests.Counting_executor ()

    let init = Oracle.salt "bla"

    let zero = Field.zero

    let one = Field.one

    let two = Field.add one one

    let zeros = Array.init ~f:(const zero)

    let ones = Array.init ~f:(const one)

    let single_zero = zeros 1

    let single_one = ones 1

    let triple_zero = zeros 3

    let triple_one = ones 3

    let ten_zero = zeros 10

    let execute (comp, check, total', calls') =
      total := 0 ;
      calls := 0 ;
      let res = test_evaluate comp in
      check res ;
      [%test_eq: int * int] (!total, !calls) (total', calls') ;
      true

    let comp0 =
      hash ~init single_zero
      >>= fun a -> map ~f:(Tuple2.create a) (hash ~init triple_zero)

    let%test "test0" =
      execute (comp0, [%test_eq: Field.t * Field.t] (zero, zero), 4, 2)

    let comp1 =
      map ~f:Tuple2.create (hash ~init single_zero) <*> hash ~init triple_zero

    let%test "test1" =
      execute (comp1, [%test_eq: Field.t * Field.t] (zero, zero), 4, 1)

    let comp2 =
      map ~f:Tuple3.create (hash ~init single_zero)
      <*> hash ~init ten_zero <*> hash ~init triple_zero

    let%test "test2" =
      execute
        ( comp2
        , [%test_eq: Field.t * Field.t * Field.t] (zero, zero, zero)
        , 14
        , 1 )

    let comp3 = hash ~init single_zero >>= fun _ -> hash ~init single_zero

    let%test "test3" = execute (comp3, [%test_eq: Field.t] zero, 2, 2)

    let comp4 =
      hash ~init single_zero
      >>= fun _ ->
      let%map.M a = hash ~init single_zero and b = hash ~init triple_zero in
      (a, b)

    let%test "test4" =
      execute (comp4, [%test_eq: Field.t * Field.t] (zero, zero), 5, 2)

    let comp5 =
      (let%map.M a = hash ~init single_zero and b = hash ~init triple_zero in
       (a, b) )
      >>= fun (a, b) -> map ~f:(Tuple3.create a b) (hash ~init single_one)

    let%test "test5" =
      execute
        (comp5, [%test_eq: Field.t * Field.t * Field.t] (zero, zero, one), 5, 2)

    let comp6 =
      let%bind.M a, b =
        let%map.M a = hash ~init single_one and b = hash ~init triple_one in
        (a, b)
      in
      let%map.M c = hash ~init single_one and d = hash ~init triple_zero in
      (Field.add a c, Field.add b d)

    let%test "test6" =
      execute (comp6, [%test_eq: Field.t * Field.t] (two, one), 8, 2)

    let comp7 =
      let%map.M a, b =
        let%bind.M a = hash ~init single_one in
        let%map.M b = hash ~init triple_one in
        (a, b)
      and c = hash ~init single_one in
      (Field.add a c, b)

    let%test "test7" =
      execute (comp7, [%test_eq: Field.t * Field.t] (two, one), 5, 2)

    let comp8 =
      let%map.M c = hash ~init single_one
      and a, b =
        let%bind.M a = hash ~init single_one in
        let%map.M b = hash ~init triple_one in
        (a, b)
      in
      (Field.add a c, b)

    let%test "test8" =
      execute (comp8, [%test_eq: Field.t * Field.t] (two, one), 5, 2)

    let comp9 =
      let%map.M a, b =
        let%bind.M a = hash ~init single_one in
        let%map.M b = hash ~init triple_one in
        (a, b)
      and c, d =
        let%bind.M c = hash ~init single_one in
        let%map.M d = hash ~init triple_zero in
        (c, d)
      in
      (Field.add a c, Field.add b d)

    let%test "test9" =
      execute (comp9, [%test_eq: Field.t * Field.t] (two, one), 8, 2)

    let double_hash x =
      hash ~init x >>= fun y -> hash ~init (Array.of_list [ y ])

    let comp10 =
      lift2 Tuple3.create (double_hash single_zero) (double_hash ten_zero)
      <*> double_hash triple_zero

    let%test "test10" =
      execute
        ( comp10
        , [%test_eq: Field.t * Field.t * Field.t] (zero, zero, zero)
        , 17
        , 2 )

    let comp11 =
      List.init 10 ~f:(const (single_one, triple_one, ten_zero))
      |> map_list ~f:(fun (a, b, c) ->
             lift2 Tuple3.create (double_hash a) (double_hash b)
             <*> double_hash c )

    let%test "test11" =
      execute
        ( comp11
        , [%test_eq: (Field.t * Field.t * Field.t) list]
            (List.init 10 ~f:(const (one, one, zero)))
        , 170
        , 2 )

    let comp12 =
      lift2 Tuple3.create
        ( List.init
            ((batch_drain * 3) + 5)
            ~f:(const (single_one, triple_one, ten_zero))
        |> map_list ~f:(fun (a, b, c) ->
               lift2 Tuple3.create (double_hash a) (double_hash b)
               <*> double_hash c ) )
        (double_hash triple_one)
      <*> double_hash ten_zero

    let%test "test12" =
      execute
        ( comp12
        , [%test_eq: (Field.t * Field.t * Field.t) list * Field.t * Field.t]
            ( List.init ((batch_drain * 3) + 5) ~f:(const (one, one, zero))
            , one
            , zero )
        , (((batch_drain * 3) + 5) * 17) + 15
        , 20 )

    let comp13 =
      map_list ~f:double_hash
        (List.init ((batch_drain * 2) + 1) ~f:(const triple_one))

    let%test "test13" =
      execute
        ( comp13
        , [%test_eq: Field.t list]
            (List.init ((batch_drain * 2) + 1) ~f:(const one))
        , ((batch_drain * 2) + 1) * 4
        , 6 )
  end )
