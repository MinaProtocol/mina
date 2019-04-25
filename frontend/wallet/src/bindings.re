open Tc;

module Navigator = {
  module Clipboard = {
    [@bs.val] [@bs.scope ("navigator", "clipboard")]
    external writeText: string => Js.Promise.t(unit) = "";

    let writeTextTask: string => Task.t('x, unit) =
      str => Task.liftPromise(() => writeText(str));
  };
};

module Child_process = {
  module Event = {
    type t('a) = {on: (string, 'a => unit) => unit};
  };

  module Spawn = {
    [@bs.deriving abstract]
    type t = {
      stdout: Event.t(Node.Buffer.t),
      stderr: Event.t(Node.Buffer.t),
      on: (string, int => unit) => unit,
    };
  };
  [@bs.val] [@bs.module "child_process"]
  external spawn: (string, array(string)) => Spawn.t = "";
};
