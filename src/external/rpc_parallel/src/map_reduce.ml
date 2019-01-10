open Core
open Async

module Half_open_interval = struct
  module T = struct
    type t = int * int [@@deriving sexp]
    let create_exn l u =
      if l >= u then failwiths "Lower bound must be less than upper bound"
                       (l, u) [%sexp_of: int * int];
      (l, u)
    let lbound t = fst t
    let ubound t = snd t
    let intersects t1 t2 = (lbound t1 < ubound t2) && (lbound t2 < ubound t1)
    let compare t1 t2 =
      if t1 = t2 then
        0
      else
        (if intersects t1 t2 then
           failwiths "Cannot compare unequal intersecting intervals"
             (t1, t2) [%sexp_of: t * t];
         Int.compare (lbound t1) (lbound t2))
  end
  include T
  include Comparable.Make(T)
end

let append_index reader =
  let index = ref 0 in
  Pipe.map reader ~f:(fun item ->
    let item_index = !index in
    index := !index + 1;
    (item, item_index))

type packed_remote = Packed_remote : 'remote Remote_executable.t -> packed_remote

module Config = struct
  type t =
    { local           : int
    ; remote          : (packed_remote * int) list
    ; cd              : string option
    ; redirect_stderr : [ `Dev_null | `File_append of string ]
    ; redirect_stdout : [ `Dev_null | `File_append of string ]
    }

  let default_cores () =
    (ok_exn Linux_ext.cores) ()

  let create ?(local = 0) ?(remote = []) ?cd
        ~redirect_stderr ~redirect_stdout () =
    let (local, remote) =
      if local = 0 && (List.is_empty remote) then
        (default_cores (), remote)
      else
        (local, remote)
    in
    { local; remote = List.map remote ~f:(fun (remote, n) -> (Packed_remote remote, n));
      cd; redirect_stderr; redirect_stdout }
end

(* Wrappers for generic worker *)
module type Worker = sig
  type t
  type param_type
  type run_input_type
  type run_output_type

  val spawn_config_exn : Config.t -> param_type -> t list Deferred.t
  val run_exn : t -> run_input_type -> run_output_type Deferred.t
  val shutdown_exn : t -> unit Deferred.t
end

module type Rpc_parallel_worker_spec = sig
  type state_type
  module Param : Binable
  module Run_input : Binable
  module Run_output : Binable

  val init : Param.t -> state_type Deferred.t
  val execute : state_type -> Run_input.t -> Run_output.t Deferred.t
end

module Make_rpc_parallel_worker(S : Rpc_parallel_worker_spec) = struct
  module Parallel_worker = struct
    module T = struct
      type 'worker functions =
        { execute  : ('worker, S.Run_input.t, S.Run_output.t) Parallel.Function.t }

      module Worker_state = struct
        type init_arg = S.Param.t [@@deriving bin_io]
        type t   = S.state_type
      end

      module Connection_state = struct
        type init_arg = unit [@@deriving bin_io]
        type t =  unit
      end

      module Functions(C : Parallel.Creator
                       with type worker_state := Worker_state.t
                        and type connection_state := Connection_state.t) = struct
        let execute =
          C.create_rpc
            ~f:(fun ~worker_state ~conn_state:() -> S.execute worker_state)
            ~bin_input:S.Run_input.bin_t ~bin_output:S.Run_output.bin_t ()

        let functions = { execute }

        let init_worker_state = S.init

        let init_connection_state ~connection:_ ~worker_state:_ () = return ()
      end
    end

    include Parallel.Make (T)
  end

  type t = Parallel_worker.Connection.t
  type param_type = S.Param.t
  type run_input_type = S.Run_input.t
  type run_output_type = S.Run_output.t

  let spawn_exn where param ?cd ~redirect_stderr ~redirect_stdout =
    Parallel_worker.spawn_exn ~where ?cd ~shutdown_on:Disconnect
      ~redirect_stderr ~redirect_stdout param ~on_failure:Error.raise
      ~connection_state_init_arg:()

  let spawn_config_exn
        { Config.local; remote; cd; redirect_stderr; redirect_stdout }
        param =
    if local < 0 then
      failwiths "config.local must be nonnegative" local Int.sexp_of_t;
    (match List.find remote ~f:(fun (_remote, n) -> n < 0) with
     | Some remote ->
       failwiths "remote number of workers must be nonnegative" (snd remote) Int.sexp_of_t
     | None -> ());
    if local = 0 &&
       not (List.exists remote ~f:(fun (_remote, n) -> n > 0)) then
      failwiths "total number of workers must be positive"
        (local, List.map remote ~f:snd) [%sexp_of: int * int list];
    let spawn_n where n =
      Deferred.List.init n ~f:(fun _i ->
        spawn_exn where param ?cd
          ~redirect_stderr:(redirect_stderr :> Fd_redirection.t)
          ~redirect_stdout:(redirect_stdout :> Fd_redirection.t))
    in
    Deferred.both
      (spawn_n Local local)
      (Deferred.List.concat_map ~how:`Parallel remote
         ~f:(fun (Packed_remote remote, n) -> spawn_n (Remote remote) n))
    >>| fun (local_workers, remote_workers) ->
    local_workers @ remote_workers

  let run_exn t input =
    Parallel_worker.Connection.run_exn t
      ~f:Parallel_worker.functions.execute ~arg:input

  let shutdown_exn conn = Parallel_worker.Connection.close conn
end

(* Map *)

module type Map_function = sig
  module Param : Binable
  module Input : Binable
  module Output : Binable

  module Worker : Worker
    with type param_type = Param.t
    with type run_input_type = Input.t
    with type run_output_type = Output.t
end

module type Map_function_with_init_spec = sig
  type state_type
  module Param : Binable
  module Input : Binable
  module Output : Binable

  val init : Param.t -> state_type Deferred.t
  val map : state_type -> Input.t -> Output.t Deferred.t
end

module Make_map_function_with_init(S : Map_function_with_init_spec) = struct
  module Param = S.Param
  module Input = S.Input
  module Output = S.Output

  module Worker = Make_rpc_parallel_worker(struct
      type state_type = S.state_type
      module Param = Param
      module Run_input = Input
      module Run_output = Output

      let init = S.init
      let execute = S.map
    end)
end

module type Map_function_spec = sig
  module Input : Binable
  module Output : Binable

  val map : Input.t -> Output.t Deferred.t
end

module Make_map_function(S : Map_function_spec) =
  Make_map_function_with_init(struct
    type state_type = unit
    module Param = struct
      type t = unit [@@deriving bin_io]
    end
    module Input = S.Input
    module Output = S.Output

    let init = return
    let map () = S.map
  end)

(* Map-combine *)

module type Map_reduce_function = sig
  module Param : Binable
  module Accum : Binable
  module Input : Binable

  module Worker : Worker
    with type param_type = Param.t
    with type run_input_type =
           [ `Map of Input.t
           | `Combine of Accum.t * Accum.t
           | `Map_right_combine of Accum.t * Input.t (* combine accum (map input) *)
           ]
    with type run_output_type = Accum.t
end

module type Map_reduce_function_with_init_spec = sig
  type state_type
  module Param : Binable
  module Accum : Binable
  module Input : Binable

  val init : Param.t -> state_type Deferred.t
  val map : state_type -> Input.t -> Accum.t Deferred.t
  val combine : state_type -> Accum.t -> Accum.t -> Accum.t Deferred.t
end

module Make_map_reduce_function_with_init(S : Map_reduce_function_with_init_spec) =
struct
  module Param = S.Param
  module Accum = S.Accum
  module Input = S.Input

  module Worker = Make_rpc_parallel_worker(struct
      type state_type = S.state_type
      module Param = Param
      module Run_input = struct
        type t =
          [ `Map of Input.t
          | `Combine of Accum.t * Accum.t
          | `Map_right_combine of Accum.t * Input.t
          ]
        [@@deriving bin_io]
      end
      module Run_output = Accum

      let init = S.init
      let execute state = function
        | `Map input -> S.map state input
        | `Combine (accum1, accum2) -> S.combine state accum1 accum2
        | `Map_right_combine (accum1, input) ->
          S.map state input >>= fun accum2 -> S.combine state accum1 accum2
    end)
end

module type Map_reduce_function_spec = sig
  module Accum : Binable
  module Input : Binable

  val map : Input.t -> Accum.t Deferred.t
  val combine : Accum.t -> Accum.t -> Accum.t Deferred.t
end

module Make_map_reduce_function(S : Map_reduce_function_spec) =
  Make_map_reduce_function_with_init(struct
    type state_type = unit
    module Param = struct
      type t = unit [@@deriving bin_io]
    end
    module Accum = S.Accum
    module Input = S.Input

    let init = return
    let map () = S.map
    let combine () = S.combine
  end)

let map_unordered (type param) (type a) (type b)
      config input_reader ~m  ~(param : param) =
  let module Map_function = (val m : Map_function
                             with type Param.t = param
                              and type Input.t = a
                              and type Output.t = b)
  in
  Map_function.Worker.spawn_config_exn config param
  >>= fun workers ->
  let input_with_index_reader = append_index input_reader in
  let (output_reader, output_writer) = Pipe.create () in
  let consumer =
    Pipe.add_consumer
      input_with_index_reader
      ~downstream_flushed:(fun () -> Pipe.downstream_flushed output_writer)
  in
  let rec map_loop worker =
    Pipe.read ~consumer input_with_index_reader
    >>= function
    | `Eof -> Map_function.Worker.shutdown_exn worker
    | `Ok (input, index) ->
      Map_function.Worker.run_exn worker input
      >>= fun output ->
      Pipe.write output_writer (output, index)
      >>= fun () ->
      map_loop worker
  in
  don't_wait_for (
    Deferred.all_unit (List.map workers ~f:map_loop)
    >>| fun () ->
    Pipe.close output_writer
  );
  return output_reader

let map config input_reader ~m ~param =
  map_unordered config input_reader ~m ~param
  >>= fun mapped_reader ->
  let (new_reader, new_writer) = Pipe.create () in
  let expecting_index = ref 0 in
  let out_of_order_output =
    Heap.create ~cmp:(fun (_, index1) (_, index2) -> Int.compare index1 index2) ()
  in
  (* Pops in-order output until we reach a gap. *)
  let rec write_out_of_order_output () =
    match Heap.top out_of_order_output with
    | Some (output, index) when index = !expecting_index ->
      expecting_index := !expecting_index + 1;
      Heap.remove_top out_of_order_output;
      Pipe.write new_writer output
      >>= fun () ->
      write_out_of_order_output ()
    | _ -> Deferred.unit
  in
  don't_wait_for (
    Pipe.iter mapped_reader ~f:(fun ((output, index) as output_and_index) ->
      if index = !expecting_index then
        (expecting_index := !expecting_index + 1;
         Pipe.write new_writer output
         >>= fun () ->
         write_out_of_order_output ())
      else if index > !expecting_index then
        (Heap.add out_of_order_output output_and_index;
         Deferred.unit)
      else assert false
    )
    >>| fun () ->
    Pipe.close new_writer
  );
  return new_reader

let find_map (type param) (type a) (type b)
      config input_reader ~m ~(param : param) =
  let module Map_function = (val m : Map_function
                             with type Param.t = param
                              and type Input.t = a
                              and type Output.t = b option)
  in
  Map_function.Worker.spawn_config_exn config param
  >>= fun workers ->
  let found_value = ref None in
  let rec find_loop worker =
    Pipe.read input_reader
    >>= function
    | `Eof -> Map_function.Worker.shutdown_exn worker
    | `Ok input ->
      (* Check result and exit early if we've found something. *)
      match !found_value with
      | Some _ -> Map_function.Worker.shutdown_exn worker
      | None ->
        Map_function.Worker.run_exn worker input
        >>= function
        | Some value ->
          found_value := Some value;
          Map_function.Worker.shutdown_exn worker
        | None ->
          find_loop worker
  in
  Deferred.all_unit (List.map workers ~f:find_loop)
  >>| fun () ->
  !found_value

let map_reduce_commutative (type param) (type a) (type accum)
      config input_reader ~m ~(param : param) =
  let module Map_reduce_function = (val m : Map_reduce_function
                                    with type Param.t = param
                                     and type Input.t = a
                                     and type Accum.t = accum)
  in
  Map_reduce_function.Worker.spawn_config_exn config param
  >>= fun workers ->
  let rec map_and_combine_loop worker acc =
    Pipe.read input_reader
    >>= function
    | `Eof -> return acc
    | `Ok input ->
      (match acc with
       | Some acc ->
         Map_reduce_function.Worker.run_exn worker (`Map_right_combine (acc, input))
       | None ->
         Map_reduce_function.Worker.run_exn worker (`Map input))
      >>= fun acc ->
      map_and_combine_loop worker (Some acc)
  in
  let combined_acc = ref None in
  let rec combine_loop worker acc =
    match !combined_acc with
    | Some other_acc ->
      combined_acc := None;
      Map_reduce_function.Worker.run_exn worker (`Combine (other_acc, acc))
      >>= combine_loop worker
    | None ->
      combined_acc := Some acc;
      Map_reduce_function.Worker.shutdown_exn worker
  in
  Deferred.all_unit (List.map workers ~f:(fun worker ->
    map_and_combine_loop worker None
    >>= function
    | Some acc -> combine_loop worker acc
    | None -> Map_reduce_function.Worker.shutdown_exn worker))
  >>| fun () ->
  !combined_acc

let map_reduce (type param) (type a) (type accum)
      config input_reader ~m ~(param : param) =
  let module Map_reduce_function = (val m : Map_reduce_function
                                    with type Param.t = param
                                     and type Input.t = a
                                     and type Accum.t = accum)
  in
  Map_reduce_function.Worker.spawn_config_exn config param
  >>= fun workers ->
  let input_with_index_reader = append_index input_reader in
  let module H = Half_open_interval in
  let acc_map = ref H.Map.empty in
  let rec combine_loop worker key acc
            (dir : [ `Left | `Left_nothing_right | `Right | `Right_nothing_left ]) =
    match dir with
    | `Left | `Left_nothing_right as dir' ->
      (match H.Map.closest_key !acc_map `Less_than key with
       | Some (left_key, left_acc) when H.ubound left_key = H.lbound key ->
         (* combine acc_{left_lbound, left_ubound} acc_{this_lbound, this_ubound}
            -> acc_{left_lbound, this_ubound} *)
         (* We need to remove both nodes from the tree to indicate that we are working on
            combining them. *)
         acc_map := H.Map.remove (H.Map.remove !acc_map key) left_key;
         Map_reduce_function.Worker.run_exn worker (`Combine (left_acc, acc))
         >>= fun new_acc ->
         let new_key = H.create_exn (H.lbound left_key) (H.ubound key) in
         acc_map := H.Map.set !acc_map ~key:new_key ~data:new_acc;
         (* Continue searching in the same direction. (See above comment.) *)
         combine_loop worker new_key new_acc `Left
       | _ ->
         match dir' with
         | `Left -> combine_loop worker key acc `Right_nothing_left
         | `Left_nothing_right -> Deferred.unit)
    | `Right | `Right_nothing_left as dir' ->
      (match H.Map.closest_key !acc_map `Greater_than key with
       | Some (right_key, right_acc) when H.lbound right_key = H.ubound key ->
         (* combine acc_{this_lbound, this_ubound} acc_{right_lbound, right_ubound}
            -> acc_{this_lbound, right_ubound} *)
         acc_map := H.Map.remove (H.Map.remove !acc_map key) right_key;
         Map_reduce_function.Worker.run_exn worker (`Combine (acc, right_acc))
         >>= fun new_acc ->
         let new_key = H.create_exn (H.lbound key) (H.ubound right_key) in
         acc_map := H.Map.set !acc_map ~key:new_key ~data:new_acc;
         combine_loop worker new_key new_acc `Right
       | _ ->
         match dir' with
         | `Right -> combine_loop worker key acc `Left_nothing_right
         | `Right_nothing_left -> Deferred.unit)
  in
  let rec map_and_combine_loop worker =
    Pipe.read input_with_index_reader
    >>= function
    | `Eof -> Map_reduce_function.Worker.shutdown_exn worker
    | `Ok (input, index) ->
      let key = H.create_exn index (index + 1) in
      (match H.Map.closest_key !acc_map `Less_than key with
       | Some (left_key, left_acc) when H.ubound left_key = H.lbound key ->
         (* combine acc_{left_lbound, left_ubound} (map a_index)
            -> acc_{left_lbound, index + 1} *)
         acc_map := H.Map.remove !acc_map left_key;
         Map_reduce_function.Worker.run_exn worker (`Map_right_combine (left_acc, input))
         >>= fun acc ->
         let key = H.create_exn (H.lbound left_key) (H.ubound key) in
         acc_map := H.Map.set !acc_map ~key ~data:acc;
         combine_loop worker key acc `Left
       | _ ->
         (* map a_index -> acc_{index, index + 1} *)
         Map_reduce_function.Worker.run_exn worker (`Map input)
         >>= fun acc ->
         acc_map := H.Map.set !acc_map ~key ~data:acc;
         combine_loop worker key acc `Left)
      >>= fun () ->
      map_and_combine_loop worker
  in
  Deferred.all_unit (List.map workers ~f:map_and_combine_loop)
  >>| fun () ->
  assert (Map.length !acc_map <= 1);
  Option.map (Map.min_elt !acc_map) ~f:snd
