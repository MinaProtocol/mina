open Tc;

module Ident = {
  type t = (int, string);

  let toString = ((i, s)) => Js.Int.toString(i) ++ s;
};

// TODO: GADT this to support responses tthat aren't just unit
// call number -> Task completer
type t = {
  table: Js.Dict.t(unit => unit),
  id: ref(int),
};

module Pending = {
  type t('x) = {
    ident: Ident.t,
    task: Task.t('x, unit),
  };
};

let make = () => {table: Js.Dict.empty(), id: ref(0)};

let nextPending = (t, ~loc) => {
  let id = t.id^;
  let task =
    Task.create(cb => {
      incr(t.id);
      Js.Dict.set(t.table, Ident.toString((id, loc)), () =>
        cb(Belt.Result.Ok())
      );
    });
  {Pending.ident: (id, loc), task};
};

// assuming responses are one-shot for now
let resolve = (t, ident) => {
  switch (Js.Dict.get(t.table, Ident.toString(ident))) {
  | None =>
    Js.log2("Unexpected missing identifier from call table, ignoring ", ident)
  | Some(f) => f()
  };
};
