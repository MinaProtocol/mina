open Tc;

module Ident: {type t;};

module Pending: {
  type t('x) = {
    ident: Ident.t,
    task: Task.t('x, unit),
  };
};

type t;

let make: unit => t;
let nextPending: t => Pending.t('x);
let resolve: (t, Ident.t) => unit;
