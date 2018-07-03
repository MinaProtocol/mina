open Core_kernel
open Async_kernel
open Snark_pool

module type Pool_intf = sig
  type t

  val create_pool : unit -> t
end

module type Pool_diff_intf = sig
  type pool

  type t

  val apply : pool -> t -> unit Or_error.t
end

module type Network_pool_intf = sig
  type t

  type pool

  type pool_diff

  val create :
    pool_diff Linear_pipe.Reader.t -> (pool -> pool_diff -> bool) -> t

  val verify_diff : t -> pool_diff -> bool

  val pool : t -> pool

  val broadcasts : t -> pool_diff Linear_pipe.Reader.t

  val apply_and_broadcast : t -> pool_diff -> unit Deferred.t
end

module Make
    (Pool : Pool_intf)
    (Pool_diff : Pool_diff_intf with type pool := Pool.t) :
  Network_pool_intf with type pool := Pool.t and type pool_diff := Pool_diff.t =
struct
  type t =
    { pool: Pool.t
    ; write_broadcasts: Pool_diff.t Linear_pipe.Writer.t
    ; read_broadcasts: Pool_diff.t Linear_pipe.Reader.t
    ; verify_change: Pool.t -> Pool_diff.t -> bool }

  let pool {pool} = pool

  let broadcasts {read_broadcasts} = read_broadcasts

  let verify_diff {verify_change; pool} pool_diff =
    verify_change pool pool_diff

  let apply_and_broadcast t pool_diff =
    if verify_diff t pool_diff then
      match Pool_diff.apply t.pool pool_diff with
      | Ok () -> Linear_pipe.write t.write_broadcasts pool_diff
      | Error e -> (* TODO: Log error *)
                   Deferred.unit
    else Deferred.unit

  let create (external_changes: Pool_diff.t Linear_pipe.Reader.t) verify_change =
    let pool = Pool.create_pool () in
    let read_broadcasts, write_broadcasts = Linear_pipe.create () in
    let network_pool =
      {pool; read_broadcasts; write_broadcasts; verify_change}
    in
    Linear_pipe.iter external_changes ~f:(fun diff ->
        apply_and_broadcast network_pool diff )
    |> ignore ;
    network_pool
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

    module Mock_Priced_proof = struct
      type t = {proof: Mock_proof.t; fee: Int.t}
      [@@deriving sexp, bin_io, fields]

      let proof t = t.proof

      type proof = Mock_proof.t

      type fee = Int.t
    end

    module Mock_snark_pool = Snark_pool.Make (Mock_proof) (Mock_work) (Int)
    module Mock_snark_pool_diff =
      Snark_pool_diff.Make (Mock_proof) (Mock_work) (Int) (Mock_snark_pool)
    module Mock_network_pool = Make (Mock_snark_pool) (Mock_snark_pool_diff)

    let%test_unit "work will broadcasted throughout the entire network" =
      let pool_reader, pool_writer = Linear_pipe.create () in
      let network_pool =
        Mock_network_pool.create pool_reader (fun _ _ -> true)
      in
      let work = 1 in
      let command = Snark_pool_diff.Add_unsolved work in
      (fun () ->
        don't_wait_for
        @@ Linear_pipe.iter (Mock_network_pool.broadcasts network_pool) ~f:
             (fun _ ->
               let pool = Mock_network_pool.pool network_pool in
               let requested_work = Mock_snark_pool.request_work pool in
               assert (requested_work = Some work) ;
               Deferred.unit ) ;
        Mock_network_pool.apply_and_broadcast network_pool command )
      |> Async.Thread_safe.block_on_async_exn

    let is_even work = work % 2 = 0

    let filter_odd_work _ = function
      | Snark_pool_diff.Add_unsolved work
       |Snark_pool_diff.Add_solved_work (work, _) ->
          is_even work

    let%test_unit "adding a set of work via Add_unsolved will be broadcasted" =
      let verify_unsolved_work unsolved_works () =
        let work_diffs =
          List.map unsolved_works ~f:(fun work ->
              Snark_pool_diff.Add_unsolved work )
          |> Linear_pipe.of_list
        in
        let network_pool =
          Mock_network_pool.create work_diffs filter_odd_work
        in
        don't_wait_for
        @@ Linear_pipe.iter (Mock_network_pool.broadcasts network_pool) ~f:
             (fun work_command ->
               let work =
                 match work_command with
                 | Snark_pool_diff.Add_unsolved work -> work
                 | Snark_pool_diff.Add_solved_work (work, _) -> work
               in
               assert (is_even work) ;
               Deferred.unit ) ;
        Deferred.unit
      in
      Quickcheck.test ~sexp_of:[%sexp_of : Mock_work.t list]
        (Quickcheck.Generator.list Mock_work.gen) ~f:(fun unsolved_works ->
          verify_unsolved_work unsolved_works
          |> Async.Thread_safe.block_on_async_exn )
  end )
