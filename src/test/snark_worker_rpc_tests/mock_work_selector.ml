open Core
open Work_selector.Intf
module Work = Snark_work_lib

type selector_pair =
  { selection_method : (module Selection_method_intf)
  ; after_partitioner_recombine_work : Work.Selector.Result.t -> unit
  }

module Seen_key = struct
  type t = Transaction_snark.Statement.t One_or_two.t
  [@@deriving compare, sexp, hash]
end

let mock_selector_pair ~logger ~seed : selector_pair =
  let work_generated : (Seen_key.t, Time.t) Hashtbl_intf.Hashtbl.t =
    Hashtbl.create (module Seen_key)
  in
  let selection_method : (module Selection_method_intf) =
    ( module struct
      type snark_pool = unit

      type staged_ledger = unit

      type work = Work.Selector.Single.Spec.Stable.Latest.t

      type transition_frontier = Transition_frontier.t

      module State = Work_selector.State

      let work ~snark_pool:() ~fee:_ ~logger _state =
        let gen = One_or_two.gen Work.Selector.Single.Spec.Stable.Latest.gen in
        let spec = Quickcheck.random_value ~seed gen in
        let key = One_or_two.map ~f:Work.Work.Single.Spec.statement spec in
        Hashtbl.add_exn work_generated ~key ~data:(Time.now ()) ;
        let work_ids_json =
          key |> Transaction_snark_work.Statement.compact_json
        in
        [%log info] "Selector work distributed"
          ~metadata:[ ("work_ids", work_ids_json) ] ;
        Some spec
    end )
  in
  let after_partitioner_recombine_work (result : Work.Selector.Result.t) =
    let key =
      One_or_two.map ~f:Work.Work.Single.Spec.statement result.spec.instances
    in
    let work_ids_json = key |> Transaction_snark_work.Statement.compact_json in
    let distributed =
      Hashtbl.find_and_remove work_generated key
      |> Option.value_exn
           ~message:
             "Partitioner trying to submit non-existent selector work result"
    in
    let elapsed_json = `Float Time.(diff (now ()) distributed |> Span.to_sec) in
    [%log info] "Selector work combined by partitioner"
      ~metadata:[ ("work_ids", work_ids_json); ("elapsed", elapsed_json) ] ;
    failwith "TODO: verify the result is valid"
  in

  { selection_method; after_partitioner_recombine_work }

let mock_selector_state ~logger =
  let pipe_r, _ = Pipe_lib.Broadcast_pipe.create None in
  Work_selector.State.init ~logger ~reassignment_wait:9999999999
    ~frontier_broadcast_pipe:pipe_r
