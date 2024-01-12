open Core_kernel
open Async_kernel
open Pipe_lib

let trust_system = Trust_system.null ()

module Transaction_snark_work = Transaction_snark_work
module Base_ledger = Mina_ledger.Ledger

module Staged_ledger = struct
  type t = Base_ledger.t [@@deriving sexp]

  let ledger = Fn.id
end

module Transition_frontier = struct
  type table = int Transaction_snark_work.Statement.Table.t [@@deriving sexp]

  type diff = Extensions.Snark_pool_refcount.view [@@deriving sexp]

  type best_tip_diff = unit

  module Breadcrumb = struct
    type t = Staged_ledger.t

    let staged_ledger = Fn.id
  end

  type t =
    { refcount_table : table
    ; mutable best_tip_table : Transaction_snark_work.Statement.Set.t
    ; mutable ledger : Base_ledger.t
    ; diff_writer : (diff Broadcast_pipe.Writer.t[@sexp.opaque])
    ; diff_reader : (diff Broadcast_pipe.Reader.t[@sexp.opaque])
    }
  [@@deriving sexp]

  let add_statements table stmts =
    List.iter stmts ~f:(fun s ->
        Transaction_snark_work.Statement.Table.change table s ~f:(function
          | None ->
              Some 1
          | Some count ->
              Some (count + 1) ) )

  (*Create tf with some statements referenced to be able to add snark work for those statements to the pool*)
  let create _stmts : t =
    let refcount_table = Transaction_snark_work.Statement.Table.create () in
    (*add_statements table stmts ;*)
    let diff_reader, diff_writer =
      Broadcast_pipe.create { Extensions.Snark_pool_refcount.removed_work = [] }
    in
    { refcount_table
    ; best_tip_table = Transaction_snark_work.Statement.Set.empty
    ; ledger = Mina_ledger.Ledger.create_ephemeral ~depth:10 ()
    ; diff_writer
    ; diff_reader
    }

  let best_tip t = t.ledger

  module Extensions = struct
    module Work = Transaction_snark_work.Statement
  end

  let snark_pool_refcount_pipe (t : t) : diff Broadcast_pipe.Reader.t =
    t.diff_reader

  let best_tip_diff_pipe _ =
    let r, _ = Broadcast_pipe.create () in
    r

  let work_is_referenced t = Hashtbl.mem t.refcount_table

  let best_tip_table t = t.best_tip_table

  (*Adds statements to the table of referenced work. Snarks for only the referenced statements are added to the pool*)
  let refer_statements (t : t) stmts =
    let open Deferred.Let_syntax in
    add_statements t.refcount_table stmts ;
    t.best_tip_table <- List.fold ~f:Set.add ~init:t.best_tip_table stmts ;
    let%bind () =
      Broadcast_pipe.Writer.write t.diff_writer
        { Transition_frontier.Extensions.Snark_pool_refcount.removed_work = [] }
    in
    Async.Scheduler.yield_until_no_jobs_remain ()

  let remove_from_best_tip (t : t) stmts =
    t.best_tip_table <- List.fold ~f:Set.remove ~init:t.best_tip_table stmts ;
    let%bind () =
      Broadcast_pipe.Writer.write t.diff_writer
        { Transition_frontier.Extensions.Snark_pool_refcount.removed_work = [] }
    in
    Async.Scheduler.yield_until_no_jobs_remain ()
end
