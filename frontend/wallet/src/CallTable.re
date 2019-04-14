open Tc;

module Ident = {
  type t = int;
};

// TODO: GADT this to support responses tthat aren't just unit
// call number -> Task completer
type t = {
  table: Js.Dict.t(unit => unit),
  ident: ref(Ident.t),
};

module Pending = {
  type t('x) = {
    ident: Ident.t,
    task: Task.t('x, unit),
  };
};

let make = () => {table: Js.Dict.empty(), ident: ref(0)};

let nextPending = t => {
  let ident = t.ident^;
  let task =
    Task.create(cb => {
      incr(t.ident);
      Js.Dict.set(t.table, Js.Int.toString(ident), () =>
        cb(Belt.Result.Ok())
      );
    });
  {Pending.ident, task};
};

// assuming responses are one-shot for now
let resolve = (t, ident) => {
  switch (Js.Dict.get(t.table, Js.Int.toString(ident))) {
  | None =>
    Js.log2("Unexpected missing identifier from call table, ignoring ", ident)
  | Some(f) => f()
  };
};
