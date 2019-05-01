open Tc;

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
    [@bs.send] external onError: (t, string, Error.t => unit) => unit = "on";
    let onError = (t, cb) => onError(t, "error", cb);

    [@bs.send]
    external onExit: (t, string, (float, Js.nullable(string)) => unit) => unit =
      "on";
    let onExit = (t, cb) =>
      onExit(t, "exit", (f, s) =>
        cb(int_of_float(f), Js.Nullable.toOption(s))
      );
  };
  [@bs.val] [@bs.module "child_process"]
  external spawn: (string, array(string)) => Process.t = "";
};
