open Core_kernel

module Make (S : T) = struct
  type t = { job : S.t; assigned : Time.t }

  let is_old (item : t) ~now ~limit =
    let delta = Time.diff now item.assigned in
    Time.Span.( > ) delta limit

  let issue_now (job : S.t) : t = { job; assigned = Time.now () }
end
