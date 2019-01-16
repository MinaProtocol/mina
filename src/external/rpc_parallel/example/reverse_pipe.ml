open Core
open Async

module Shard = struct
  module T = struct
    type 'worker functions =
      ('worker, int * int Pipe.Reader.t, string list) Rpc_parallel.Function.t

    module Worker_state = struct
      type t        = int
      type init_arg = int
      [@@deriving bin_io]
    end

    module Connection_state = struct
      type t        = unit
      type init_arg = unit
      [@@deriving bin_io]
    end

    module Functions
        (Creator : Rpc_parallel.Creator
         with type worker_state = Worker_state.t
          and type connection_state = Connection_state.t) = struct

      let functions =
        Creator.create_reverse_pipe
          ~bin_query:Int.bin_t
          ~bin_update:Int.bin_t
          ~bin_response:(List.bin_t String.bin_t)
          ~f:(fun ~worker_state:id ~conn_state:() prefix numbers ->
            Pipe.fold_without_pushback numbers ~init:[] ~f:(fun acc number ->
              sprintf "worker %d got %d:%d" id prefix number :: acc))
          ()
      ;;

      let init_worker_state = return
      ;;

      let init_connection_state ~connection:_ ~worker_state:_ () = Deferred.unit
      ;;
    end
  end
  include T
  include Rpc_parallel.Make (T)
end

let main () =
  let shards = 10 in
  let%bind connections =
    Array.init shards ~f:(fun id ->
      Shard.spawn_exn
        ~shutdown_on:Disconnect
        ~redirect_stdout:`Dev_null
        ~redirect_stderr:`Dev_null
        ~on_failure:Error.raise
        ~connection_state_init_arg:()
        id)
    |> Deferred.Array.all
  in
  let readers =
    let readers, writers =
      Array.init shards ~f:(fun (_ : int) -> Pipe.create ()) |> Array.unzip
    in
    let write_everything =
      let%map () =
        Sequence.init 1_000 ~f:Fn.id
        |> Sequence.delayed_fold
             ~init:()
             ~f:(fun () i ~k -> Pipe.write writers.(i % shards) i >>= k)
             ~finish:return
      in
      Array.iter writers ~f:Pipe.close
    in
    don't_wait_for write_everything;
    readers
  in
  let%bind () =
    Array.mapi connections ~f:(fun i connection ->
      Shard.Connection.run_exn connection ~f:Shard.functions ~arg:(i, readers.(i)))
    |> Deferred.Array.all
    >>| printf !"%{sexp: string list array}\n"
  in
  Array.map connections ~f:Shard.Connection.close
  |> Deferred.Array.all_unit
;;

let () =
  Rpc_parallel.start_app
    (Command.async ~summary:"Demonstrate using Rpc_parallel with reverse pipes"
       (Command.Param.return main))
;;
