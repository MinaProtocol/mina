open Core_kernel
open Async_kernel

module type Pool_intf = sig
  type t

  val create : parent_log:Logger.t -> t
end

module type Pool_diff_intf = sig
  type pool

  type t [@@deriving sexp]

  val summary : t -> string

  val apply : pool -> t -> t Deferred.Or_error.t
end

module type Network_pool_intf = sig
  type t

  type pool

  type pool_diff

  val create :
    parent_log:Logger.t -> incoming_diffs:pool_diff Linear_pipe.Reader.t -> t

  val of_pool_and_diffs :
       pool
    -> parent_log:Logger.t
    -> incoming_diffs:pool_diff Linear_pipe.Reader.t
    -> t

  val pool : t -> pool

  val broadcasts : t -> pool_diff Linear_pipe.Reader.t

  val apply_and_broadcast : t -> pool_diff -> unit Deferred.t
end

module Snark_pool_diff = Snark_pool_diff

module Make
    (Pool : Pool_intf)
    (Pool_diff : Pool_diff_intf with type pool := Pool.t) :
  Network_pool_intf with type pool := Pool.t and type pool_diff := Pool_diff.t =
struct
  type t =
    { pool: Pool.t
    ; log: Logger.t
    ; write_broadcasts: Pool_diff.t Linear_pipe.Writer.t
    ; read_broadcasts: Pool_diff.t Linear_pipe.Reader.t }

  let pool {pool; _} = pool

  let broadcasts {read_broadcasts; _} = read_broadcasts

  let apply_and_broadcast t pool_diff =
    match%bind Pool_diff.apply t.pool pool_diff with
    | Ok diff' ->
        Logger.debug t.log "Broadcasting %s" (Pool_diff.summary diff') ;
        Linear_pipe.write t.write_broadcasts diff'
    | Error e ->
        Logger.info t.log "Pool diff apply feedback: %s"
          (Error.to_string_hum e) ;
        Deferred.unit

  let of_pool_and_diffs pool ~parent_log ~incoming_diffs =
    let log = Logger.child parent_log __MODULE__ in
    let read_broadcasts, write_broadcasts = Linear_pipe.create () in
    let network_pool = {pool; log; read_broadcasts; write_broadcasts} in
    Linear_pipe.iter incoming_diffs ~f:(fun diff ->
        apply_and_broadcast network_pool diff )
    |> ignore ;
    network_pool

  let create ~parent_log ~incoming_diffs =
    let log = Logger.child parent_log __MODULE__ in
    of_pool_and_diffs (Pool.create ~parent_log:log) ~parent_log ~incoming_diffs
end

let%test_module "network pool test" =
  ( module struct
    module Mock_proof = struct
      type input = Int.t

      type t = Int.t [@@deriving sexp, bin_io]

      let verify _ _ = return true

      let gen = Int.gen
    end

    module Mock_work = Int
    module Mock_snark_pool = Snark_pool.Make (Mock_proof) (Mock_work) (Int)
    module Mock_snark_pool_diff =
      Snark_pool_diff.Make (Mock_proof) (Mock_work) (Int) (Mock_snark_pool)
    module Mock_network_pool = Make (Mock_snark_pool) (Mock_snark_pool_diff)

    let%test_unit "Work that gets fed into apply_and_broadcast will be \
                   recieved in the pool's reader" =
      let pool_reader, _pool_writer = Linear_pipe.create () in
      let network_pool =
        Mock_network_pool.create ~parent_log:(Logger.create ())
          ~incoming_diffs:pool_reader
      in
      let work = 1 in
      let priced_proof = {Mock_snark_pool_diff.proof= 0; fee= 0} in
      let command = Snark_pool_diff.Add_solved_work (work, priced_proof) in
      (fun () ->
        don't_wait_for
        @@ Linear_pipe.iter (Mock_network_pool.broadcasts network_pool)
             ~f:(fun _ ->
               let pool = Mock_network_pool.pool network_pool in
               ( match Mock_snark_pool.request_proof pool 1 with
               | Some {proof; fee= _} -> assert (proof = priced_proof.proof)
               | None -> failwith "There should have been a proof here" ) ;
               Deferred.unit ) ;
        Mock_network_pool.apply_and_broadcast network_pool command )
      |> Async.Thread_safe.block_on_async_exn

    let%test_unit "when creating a network, the incoming diffs in reader pipe \
                   will automatically get process" =
      let works = List.range 0 10 in
      let verify_unsolved_work () =
        let work_diffs =
          List.map works ~f:(fun work ->
              Snark_pool_diff.Add_solved_work
                (work, {Mock_snark_pool_diff.proof= 0; fee= 0}) )
          |> Linear_pipe.of_list
        in
        let network_pool =
          Mock_network_pool.create ~parent_log:(Logger.create ())
            ~incoming_diffs:work_diffs
        in
        don't_wait_for
        @@ Linear_pipe.iter (Mock_network_pool.broadcasts network_pool)
             ~f:(fun work_command ->
               let work =
                 match work_command
                 with Snark_pool_diff.Add_solved_work (work, _) -> work
               in
               assert (List.mem works work ~equal:( = )) ;
               Deferred.unit ) ;
        Deferred.unit
      in
      verify_unsolved_work |> Async.Thread_safe.block_on_async_exn
  end )
