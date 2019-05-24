open Tc;
open Bindings;

module Command = {
  type t = {
    executable: string,
    args: array(string),
    env: option(Js.Dict.t(string)),
  };

  let addArgs = (t, args) => {...t, args: Js.Array.concat(t.args, args)};
};

let (^/) = Filename.concat;
let baseCodaCommand = port => {
  let codaPath = "_build/coda-daemon-macos";
  {
    Command.executable: ProjectRoot.resource ^/ codaPath ^/ "coda.exe",
    args: [|
      "daemon",
      "-rest-port",
      Js.Int.toString(port),
      "-config-directory",
      ProjectRoot.resource ^/ codaPath ^/ "config",
    |],
    env:
      Some(
        Js.Dict.fromList([
          (
            "CODA_KADEMLIA_PATH",
            ProjectRoot.resource ^/ codaPath ^/ "kademlia",
          ),
        ]),
      ),
  };
};

module Process = {
  let start = (command: Command.t) => {
    print_endline("Starting graphql-faker");

    let p =
      switch (command.env) {
      | None => ChildProcess.spawn(command.executable, command.args)
      | Some(env) =>
        ChildProcess.spawnWithEnv(
          command.executable,
          command.args,
          {"env": env},
        )
      };

    ChildProcess.Process.onError(p, e =>
      prerr_endline(
        "Daemon process "
        ++ command.executable
        ++ " crashed: "
        ++ ChildProcess.Error.messageGet(e),
      )
    );

    ChildProcess.ReadablePipe.on(ChildProcess.Process.stderrGet(p), "data", s =>
      prerr_endline(
        "Daemon "
        ++ command.executable
        ++ " error: "
        ++ Node.Buffer.toString(s),
      )
    );

    ChildProcess.Process.onExit(
      p,
      fun
      | `Code(code) =>
        if (code != 0) {
          Printf.fprintf(
            stderr,
            "Daemon process died with non-zero exit code: %d\n",
            code,
          );
        } else {
          print_endline("Shutting down daemon process.");
        }
      | `Signal(signal) => {
          Printf.fprintf(
            stderr,
            "Daemon process died via signal: %s\n",
            signal,
          );
        },
    );

    p;
  };
};

module CodaProcess = {
  type t = ChildProcess.Process.t;

  let waitExit: t => Task.t('x, [> | `Code(int) | `Signal(string)]) =
    t => ChildProcess.Process.onExitTask(t);

  let kill: t => unit = t => ChildProcess.Process.kill(t);

  let start: list(string) => Result.t(string, t) =
    args => {
      let p =
        Process.start(
          Command.addArgs(baseCodaCommand(0xc0da), args |> Array.fromList),
        );
      Belt.Result.Ok(p);
    };
};

let startAll = (~fakerPort, ~codaPort) => {
  let graphqlFaker = {
    Command.executable: "node",
    args: [|
      Filename.concat(
        ProjectRoot.resource,
        "node_modules/graphql-faker/dist/index.js",
      ),
      "--port",
      string_of_int(fakerPort),
      "--",
      "schema.graphql",
    |],
    env: None,
  };
  let codaPath = "_build/coda-daemon-macos";
  let coda = {
    Command.executable: ProjectRoot.resource ^/ codaPath ^/ "coda.exe",
    args: [|
      "daemon",
      "-rest-port",
      Js.Int.toString(codaPort),
      "-config-directory",
      ProjectRoot.resource ^/ codaPath ^/ "config",
    |],
    env:
      Some(
        Js.Dict.fromList([
          (
            "CODA_KADEMLIA_PATH",
            ProjectRoot.resource ^/ codaPath ^/ "kademlia",
          ),
        ]),
      ),
  };
  let p1 = Process.start(graphqlFaker);
  let p2 = Process.start(coda);
  () => {
    ChildProcess.Process.kill(p1);
    ChildProcess.Process.kill(p2);
  };
};
