open Core_kernel
open Async_kernel
open Pipe_lib

let trust_system = Trust_system.null ()

module Transaction_snark_work = Transaction_snark_work
module Ledger_proof = Ledger_proof.Debug

module Base_ledger = struct
  open Coda_base

  type t = Account.t Account_id.Map.t [@@deriving sexp]

  module Location = struct
    type t = Account_id.t
  end

  let location_of_account _t k = Some k

  let get t l = Map.find t l

  let detached_signal _ = Deferred.never ()
end

module Staged_ledger = struct
  type t = Base_ledger.t [@@deriving sexp]

  let ledger = Fn.id
end

module Transition_frontier = struct
  type table = int Transaction_snark_work.Statement.Table.t [@@deriving sexp]

  type diff = int * table [@@deriving sexp]

  type best_tip_diff = unit

  module Breadcrumb = struct
    type t = Staged_ledger.t

    let staged_ledger = Fn.id
  end

  type t =
    { refcount_table: table
    ; mutable ledger: Base_ledger.t
    ; diff_writer: diff Broadcast_pipe.Writer.t sexp_opaque
    ; diff_reader: diff Broadcast_pipe.Reader.t sexp_opaque }
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
    let table = Transaction_snark_work.Statement.Table.create () in
    (*add_statements table stmts ;*)
    let diff_reader, diff_writer = Broadcast_pipe.create (0, table) in
    { refcount_table= table
    ; ledger= Coda_base.Account_id.Map.empty
    ; diff_writer
    ; diff_reader }

  let best_tip t = t.ledger

  module Extensions = struct
    module Work = Transaction_snark_work.Statement
  end

  let snark_pool_refcount_pipe (t : t) :
      (int * int Transaction_snark_work.Statement.Table.t)
      Broadcast_pipe.Reader.t =
    t.diff_reader

  let best_tip_diff_pipe _ =
    let r, _ = Broadcast_pipe.create () in
    r

  (*Adds statements to the table of referenced work. Snarks for only the referenced statements are added to the pool*)
  let refer_statements (t : t) stmts =
    let open Deferred.Let_syntax in
    add_statements t.refcount_table stmts ;
    let%bind () =
      Broadcast_pipe.Writer.write t.diff_writer (0, t.refcount_table)
    in
    Async.Scheduler.yield_until_no_jobs_remain ()
end
