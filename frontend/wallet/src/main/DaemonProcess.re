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
  let start = (command: Command.t, port) => {
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

    ChildProcess.Process.onExit(p, (n, s) =>
      if (n == 1) {
        Printf.fprintf(
          stderr,
          "Daemon process exited with non-zero exit code: Exit:%d, msg:%s%!\n",
          n,
          Option.withDefault(
            s,
            ~default="Port " ++ Js.Int.toString(port) ++ " already in use?",
          ),
        );
      } else {
        print_endline("Shutting down daemon process.");
      }
    );

    p;
  };
};

module CodaProcess = {
  type t = ChildProcess.Process.t;

  let kill: t => unit = t => ChildProcess.Process.kill(t);

  let start:
    list(string) =>
    Result.t(string, (ChildProcess.Process.t, Task.t('x, [> | `Ready]))) =
    args => {
      let p =
        Process.start(
          Command.addArgs(baseCodaCommand(0xc0da), args |> Array.fromList),
          0xc0da,
        );
      // TODO: Actually detect when graphql is ready. According to experimentation,
      //    waiting around 5 seconds is sufficient for now
      Belt.Result.Ok((
        p,
        Bindings.setTimeout(5000) |> Task.map(~f=() => `Ready),
      ));
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
  let p1 = Process.start(graphqlFaker, fakerPort);
  let p2 = Process.start(coda, codaPort);
  () => {
    ChildProcess.Process.kill(p1);
    ChildProcess.Process.kill(p2);
  };
};
