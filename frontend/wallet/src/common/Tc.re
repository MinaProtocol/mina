// As suggested in https://github.com/darklang/tablecloth/commit/07cd22138c91dba4cb09a8976f13e5e86e72b90c
// This module is our "standard library" an extension on top of Tablecloth

module Caml = {
  module String = String;
  module List = List;
  module Array = Array;
};

include (
          Tablecloth:
             (module type of Tablecloth) with
              module Never := Tablecloth.Never and
              module Task := Tablecloth.Task and
              module Result := Tablecloth.Result and
              module Option := Tablecloth.Option
        );

module Task = {
  include Tablecloth.Task;

  let return = a => succeed(a);

  /// Take a `unit => Promise.t('a)`, make it into a `Task.t('x, 'a)`
  let liftPromise = (f, ()) =>
    f() |> Js.Promise.then_(a => Js.Promise.resolve(Belt.Result.Ok(a)));

  /// Take a `unit => Promise.t('a)` which throws err, make it into a `Task.t(err, 'a)`
  let liftErrorPromise = (f, ()) =>
    f()
    |> Js.Promise.then_(a => Js.Promise.resolve(Belt.Result.Ok(a)))
    |> Js.Promise.catch(err => Js.Promise.resolve(Belt.Result.Error(err)));

  let uncallbackifyValue = f => {
    create(cb => f(a => cb(Belt.Result.Ok(a))));
  };

  /// Take a Node.js style ((nullable err) => unit) => unit function and make it
  /// return a task instead
  let uncallbackify0 = f => {
    create(cb =>
      f(err =>
        switch (Js.Nullable.toOption(err)) {
        | Some(err) => cb(Belt.Result.Error(err))
        | None => cb(Belt.Result.Ok())
        }
      )
    );
  };

  /// Take a Node.js style ((nullable err, nullable res) => unit) => unit
  /// function and make it return a task instead
  let uncallbackify = f => {
    create(cb =>
      f((err, x) =>
        switch (Js.Nullable.toOption(err), Js.Nullable.toOption(x)) {
        | (Some(err), _) => cb(Belt.Result.Error(err))
        | (_, Some(x)) => cb(Belt.Result.Ok(x))
        | (_, _) => failwith("The JS call you've bridged is funky")
        }
      )
    );
  };
};

module Result = {
  include Tablecloth.Result;

  let map = (t, ~f) => map(f, t);
  let andThen = (t, ~f) => andThen(~f, t);

  let return = a => Belt.Result.Ok(a);
  let fail = x => Belt.Result.Error(x);

  let onError = (t: t('x, 'a), ~f) =>
    switch (t) {
    | Ok(v) => Belt.Result.Ok(v)
    | Error(e) => f(e)
    };

  let ok_exn = (t: t(Js.Exn.t, 'a)): 'a => {
    let string_of_str_option = s =>
      switch (s) {
      | None => "None"
      | Some(s) => s
      };

    switch (t) {
    | Ok(x) => x
    | Error(e) =>
      Js.Exn.raiseError(string_of_str_option(Js.Exn.stack(Obj.magic(e))))
    };
  };
};

module Option = {
  include Tablecloth.Option;

  let getExn = x => Belt.Option.getExn(x);

  let map2 = (t1, t2, ~f) => {
    switch (t1, t2) {
    | (Some(a), Some(b)) => Some(f(a, b))
    | _ => None
    };
  };
};

module Monad = {
  module type S2 = {
    type t('x, 'a);
    let return: 'a => t('x, 'a);
    let map: (t('x, 'a), ~f: 'a => 'b) => t('x, 'b);
    let andThen: (t('x, 'a), ~f: 'a => t('x, 'b)) => t('x, 'b);
  };

  module Fail = {
    module type S2 = {
      include S2;
      let fail: 'x => t('x, 'a);
      let onError: (t('x, 'a), ~f: 'x => t('y, 'a)) => t('y, 'a);
    };
  };
};
