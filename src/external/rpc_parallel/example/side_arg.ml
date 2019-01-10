open Core
open Async

module Side_arg_map_function = Rpc_parallel.Map_reduce.Make_map_function_with_init(struct
    type state_type = string
    module Param = struct
      type t = string [@@deriving bin_io]
    end
    module Input = struct
      type t = unit [@@deriving bin_io]
    end
    module Output = struct
      type t = string [@@deriving bin_io]
    end

    let init param =
      Random.self_init ();
      return (sprintf "[%i] %s" (Random.bits ()) param)
    let map state () =
      return state
  end)

let command =
  Command.async_spec ~summary:"Pass a side arg"
    Command.Spec.(
      empty
      +> flag "ntimes" (optional_with_default 100 int) ~doc:" Number of things to map"
      +> flag "nworkers" (optional_with_default 4 int) ~doc:" Number of workers"
    )
    (fun ntimes nworkers () ->
       let list = (Pipe.of_list (List.init ntimes ~f:(fun _i -> ()))) in
       let config =
         Rpc_parallel.Map_reduce.Config.create ~local:nworkers ()
           ~redirect_stderr:`Dev_null ~redirect_stdout:`Dev_null
       in
       Rpc_parallel.Map_reduce.map_unordered
         config
         list
         ~m:(module Side_arg_map_function)
         ~param:"Message from the master"
       >>= fun output_reader ->
       Pipe.iter output_reader ~f:(fun (message, index) ->
         printf "%i: %s\n" index message;
         Deferred.unit
       )
    )

let () = Rpc_parallel.start_app command
