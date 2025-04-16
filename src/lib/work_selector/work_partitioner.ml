(* work partitioner split the work produced by a Work_selector into smaller tasks,
   and issue them to the actual worker. It's also in charge of aggregating
   the response from worker. We have this layer because we don't want to
   touch the Work_selector and break a lot of places.

   Ideally, we should refactor so this integrates into Work_selector
*)

module State = struct
  type t = unit
end
