open Tc;

// Ignores cancellation
let setTimeout: int => Task.t('x, unit) =
  millis =>
    Task.uncallbackifyValue(cb => ignore(Js.Global.setTimeout(cb, millis)));

module Window = {
  type t;

  [@bs.val] external current: t = "window";

  [@bs.set] external onClick: (t, unit => unit) => unit = "onclick";
};

module Url = {
  type t;
  [@bs.new] external create: string => t = "URL";

  module SearchParams = {
    type t;
    [@bs.send] external get: (t, string) => string = "";
  };

  [@bs.get] external searchParams: t => SearchParams.t = "";
};

module Navigator = {
  module Clipboard = {
    [@bs.val] [@bs.scope ("navigator", "clipboard")]
    external writeText: string => Js.Promise.t(unit) = "";

    let writeTextTask: string => Task.t('x, unit) =
      str => Task.liftPromise(() => writeText(str));
  };
};

module ChildProcess = {
  module ReadablePipe = {
    type t;
    [@bs.send] external on: (t, string, Node.Buffer.t => unit) => unit = "";
  };

  module Error = {
    [@bs.deriving abstract]
    type t = {
      message: string,
      name: string,
    };
  };

  module Process = {
    [@bs.deriving abstract]
    type t = {
      stdout: ReadablePipe.t,
      stderr: ReadablePipe.t,
    };

    [@bs.send] external kill: t => unit = "";

    [@bs.send]
    external onError: (t, [@bs.as "error"] _, Error.t => unit) => unit = "on";

    [@bs.send]
    external onExit:
      (
        t,
        [@bs.as "exit"] _,
        (Js.nullable(float), Js.nullable(string)) => unit
      ) =>
      unit =
      "on";

    let onExit = (t, cb) =>
      onExit(t, (f, s) =>
        switch (Js.Nullable.toOption(f), Js.Nullable.toOption(s)) {
        | (None, None) =>
          failwith("Expected one of code,signal to be non-null")
        | (Some(code), None) => cb(`Code(int_of_float(code)))
        | (None, Some(signal)) => cb(`Signal(signal))
        | (Some(_), Some(_)) =>
          failwith("Expected one of code,signal to be null")
        }
      );
    let onExitTask = t => Task.uncallbackifyValue(onExit(t));
  };
  [@bs.val] [@bs.module "child_process"]
  external spawn: (string, array(string)) => Process.t = "spawn";

  [@bs.val] [@bs.module "child_process"]
  external spawnWithEnv:
    (string, array(string), {. "env": Js.Dict.t(string)}) => Process.t =
    "spawn";
};

module Fs = {
  [@bs.val] [@bs.module "fs"]
  external readFile:
    (
      string,
      string,
      (Js.Nullable.t(Js.Exn.t), Js.Nullable.t(string)) => unit
    ) =>
    unit =
    "";

  [@bs.val] [@bs.module "fs"]
  external writeFile:
    (string, string, string, Js.Nullable.t(Js.Exn.t) => unit) => unit =
    "";

  [@bs.val] [@bs.module "fs"]
  external watchFile: (string, unit => unit) => unit = "";
};

module Fetch = {
  [@bs.module] external fetch: ApolloClient.fetch = "node-fetch";
};

module LocalStorage = {
  [@bs.val] [@bs.scope "localStorage"]
  external setItem: (string, string) => unit = "";

  [@bs.val] [@bs.scope "localStorage"]
  external getItem: string => Js.nullable(string) = "";
};
