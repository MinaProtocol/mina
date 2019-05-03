module Status = {
  type t =
    | Submitted
    | Included
    | Finalized
    | Snarked
    | Failed;
};

type t = {
  status: Status.t,
  estimatedPercentConfirmed: float,
};
