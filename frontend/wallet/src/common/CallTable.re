open Tc;

module Make =
       (
         Typ: {
           type t('a);
           let if_eq:
             (
               t('a),
               t('b),
               'b,
               ~is_equal: 'a => unit,
               ~not_equal: 'b => unit
             ) =>
             unit;
         },
       ) => {
  module Ident = {
    type t('a) = {
      id: int,
      loc: string,
      typ: Typ.t('a),
    };

    module Encode = {
      type t0('a) = t('a);
      type t = (int, string);
      let t = ({id, loc, typ: _}) => (id, loc);
    };
    module Decode = {
      let t = ((id, loc), typ) => {id, loc, typ};
    };

    let toString = ({id, loc, typ: _}) => Js.Int.toString(id) ++ loc;
  };

  module Any = {
    type t =
      | T('a, Typ.t('a)): t;
  };

  type t = {
    table: Js.Dict.t(Any.t => unit),
    id: ref(int),
  };

  module Pending = {
    type t('x, 'a) = {
      ident: Ident.t('a),
      task: Task.t('x, 'a),
    };
  };

  let make = () => {table: Js.Dict.empty(), id: ref(0)};

  let nextPending = (type a, t, typ: Typ.t(a), ~loc) => {
    let id = t.id^;
    incr(t.id);
    // immediately create a task
    let task =
      Task.create(cb => {
        let key = Ident.toString({id, loc, typ});
        // but don't resolve it until the callback inside the dictionary is invoked
        Js.Dict.set(t.table, key, (Any.T(v, typ2)) =>
          Typ.if_eq(
            typ,
            typ2,
            v,
            ~is_equal=
              a => {
                // if the two type witnesses are the same, we can free the memory in the dictionary
                Js.Dict.set(t.table, key, Obj.magic(Js.Nullable.undefined));
                // and complete the task
                cb(Belt.Result.Ok(a));
              },
            ~not_equal=
              b =>
                Js.log2(
                  "Type witnesses are different, not resolving call table pending",
                  b,
                ),
          )
        );
      });
    {
      Pending.ident: {
        id,
        loc,
        typ,
      },
      task,
    };
  };

  // assuming responses are one-shot for now
  let resolve = (type a, t, ident: Ident.t(a), v: a) => {
    // reolve a task by calling the callback in the dictionary
    switch (Js.Dict.get(t.table, Ident.toString(ident))) {
    | None =>
      Js.log2(
        "Unexpected missing identifier from call table, ignoring ",
        ident,
      )
    | Some(f) => f(Any.T(v, ident.typ))
    };
  };
};
