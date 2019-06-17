open Tc;
open Bindings;

module Command = {
  type t = {
    executable: string,
    args: array(string),
    env: Js.Dict.t(string),
    logfileName: string,
  };
};

let (^/) = Filename.concat;

let codaCommand = (~port, ~extraArgs) => {
  let codaPath = "_build/coda-daemon-macos";
  {
    Command.executable: ProjectRoot.resource ^/ codaPath ^/ "coda.exe",
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
      Js.Dict.fromArray(
        Js.Array.concat(
          [|
            (
              "CODA_KADEMLIA_PATH",
              ProjectRoot.resource ^/ codaPath ^/ "kademlia",
            ),
          |],
          Js.Dict.entries(ChildProcess.Process.env),
        ),
      ),
    logfileName: "daemon",
  };
};

module Process = {
  let start = (command: Command.t) => {
    let {Command.executable, args, logfileName} = command;
    print_endline(
      {j|Starting $executable with $args. Logging to `$logfileName.log`|j},
    );

    /*
     child_process.spawn communicates with processes using sockets.
     When the proposer process starts up in the daemon, stdout and stderr
     are accessed using a helper function from async_unix:
     https://github.com/janestreet/async_unix/blob/ff13d69c96f4b857737263910b3f6b08311b5dfc/src/writer0.ml#L1465
     This causes async_unix to attempt to infer the type of stdout/err
     using and check if it has SO_ACCEPTCONN set using getsockopt.
     This flag is not supported on Mac, so it crashes with "Protocol not available"

     As a workaround, we have to redirect all output to a file.

     If this issue is ever resolved or we stop using async_unix, this code can be simplified:
     https://github.com/janestreet/async_unix/issues/15
     */

    let log = Fs.openSync(command.logfileName ++ ".log", "w");
    let process =
      ChildProcess.spawn(
        command.executable,
        command.args,
        {
          "env": command.env,
          "stdio":
            ChildProcess.makeIOTriple(`Ignore, `Stream(log), `Stream(log)),
        },
      );

    ChildProcess.Process.onError(process, e =>
      prerr_endline(
        "Daemon process "
        ++ command.executable
        ++ " crashed. Logs are in `"
        ++ command.logfileName
        ++ ".log`. Error:"
        ++ ChildProcess.Error.messageGet(e),
      )
    );

    ChildProcess.Process.onExit(
      process,
      fun
      | `Code(code) =>
        if (code != 0) {
          Printf.fprintf(
            stderr,
            "Daemon process %s died with non-zero exit code: %d. Logs are in `%s.log`\n",
            command.executable,
            code,
            command.logfileName,
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

    process;
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
    env: ChildProcess.Process.env,
    logfileName: "faker",
  };
  let p = Process.start(graphqlFaker);
  () => {
    ChildProcess.Process.kill(p, "SIGINT");
  };
};
