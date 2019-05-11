open Bindings;

module Command = {
  type t = {
    executable: string,
    args: array(string),
    env: Js.Dict.t(string),
  };
};

module Process = {
  let start = (command: Command.t, port) => {
    print_endline("Starting graphql-faker");

    let p =
      ChildProcess.spawn(
        command.executable,
        command.args,
        {"env": command.env},
      );

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
          Tc.Option.withDefault(
            s,
            ~default="Port " ++ Js.Int.toString(port) ++ " already in use?",
          ),
        );
      } else {
        print_endline("Shutting down daemon process.");
      }
    );

    () => ChildProcess.Process.kill(p);
  };
};

let (^/) = Filename.concat;

let startAll = (~fakerPort, ~codaPort) => {
  let graphqlFaker = {
    Command.executable: "/run/current-system/sw/bin/node",
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
    env: Js.Dict.empty(),
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
      Js.Dict.fromList([
        (
          "CODA_KADEMLIA_PATH",
          ProjectRoot.resource ^/ codaPath ^/ "kademlia",
        ),
      ]),
  };
  let kill1 = Process.start(graphqlFaker, fakerPort);
  let kill2 = Process.start(coda, codaPort);
  () => {
    kill1();
    kill2();
  };
};
