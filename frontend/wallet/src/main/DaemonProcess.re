open Tc;
open Bindings;

module Command = {
  type t = {
    executable: string,
    args: array(string),
    env: option(Js.Dict.t(string)),
  };
};

let (^/) = Filename.concat;
let codaCommand = (~port, ~extraArgs) => {
  let codaPath = "_build/coda-daemon-macos";
  {
    Command.executable: ProjectRoot.resource ^/ codaPath ^/ "coda.exe",
    // yes Js.Array.concat is backwards :(
    args:
      Js.Array.concat(
        extraArgs,
        [|
          "daemon",
          "-rest-port",
          Js.Int.toString(port),
          "-config-directory",
          ProjectRoot.resource ^/ codaPath ^/ "config",
        |],
      ),
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
    let {Command.executable, args} = command;
    print_endline({j|Starting $executable with $args|j});

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

    ChildProcess.ReadablePipe.on(ChildProcess.Process.stdoutGet(p), "data", s =>
      prerr_endline(
        "Daemon "
        ++ command.executable
        ++ " stdout: "
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
            "Daemon process %s died with non-zero exit code: %d\n",
            command.executable,
            code,
          );
        } else {
          print_endline(
            "Shutting down daemon process: " ++ command.executable,
          );
        }
      | `Signal(signal) => {
          Printf.fprintf(
            stderr,
            "Daemon process %s died via signal: %s\n",
            command.executable,
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

  let kill: t => unit = t => ChildProcess.Process.kill(t, "SIGINT");

  let start: list(string) => t =
    args => {
      Process.start(
        codaCommand(~port=0xc0da, ~extraArgs=args |> Array.fromList),
      );
    };
};

let startFaker = port => {
  let graphqlFaker = {
    Command.executable: "node",
    args: [|
      Filename.concat(
        ProjectRoot.resource,
        "node_modules/graphql-faker/dist/index.js",
      ),
      "--port",
      string_of_int(port),
      "--",
      "schema.graphql",
    |],
    env: None,
  };
  let p = Process.start(graphqlFaker);
  () => {
    ChildProcess.Process.kill(p, "SIGINT");
  };
};
