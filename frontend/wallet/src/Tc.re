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
};
