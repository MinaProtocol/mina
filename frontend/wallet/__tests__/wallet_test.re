open Jest;
open Expect;
open Tc;

module Typ = {
  type t('a) =
    | Int: t(int)
    | Str: t(string);

  let if_eq =
      (
        type a,
        type b,
        ta: t(a),
        tb: t(b),
        v: b,
        ~is_equal: a => unit,
        ~not_equal: b => unit,
      ) => {
    switch (ta, tb) {
    | (Int, Int) => is_equal(v)
    | (Str, Str) => is_equal(v)
    | (_, _) => not_equal(v)
    };
  };
};
module CallTable = CallTable.Make(Typ);

describe("CallTable", () => {
  testAsync(
    "pending int task completes",
    ~timeout=10,
    cb => {
      let table = CallTable.make();

      let pendingInt: CallTable.Pending.t('x, int) =
        CallTable.nextPending(table, Typ.Int, ~loc=__LOC__);
      Task.perform(pendingInt.task, ~f=i => cb(expect(i) |> toBe(1)));

      let _ =
        Js.Global.setTimeout(
          () => CallTable.resolve(table, pendingInt.ident, 1),
          1,
        );
      ();
    },
  );

  testAsync(
    "pending str task completes",
    ~timeout=10,
    cb => {
      let table = CallTable.make();

      let pendingStr: CallTable.Pending.t('x, string) =
        CallTable.nextPending(table, Typ.Str, ~loc=__LOC__);
      Task.perform(pendingStr.task, ~f=s => cb(expect(s) |> toBe("hello")));

      let _ =
        Js.Global.setTimeout(
          () => CallTable.resolve(table, pendingStr.ident, "hello"),
          1,
        );
      ();
    },
  );
});

describe("Bindings", () =>
  describe("Spawn", () => {
    open Bindings;
    testAsync(
      "echo and get stdout",
      ~timeout=10,
      cb => {
        let echoProcess = ChildProcess.spawn("echo", [|"hello"|]);
        let stdout = ChildProcess.Process.stdoutGet(echoProcess);
        ChildProcess.ReadablePipe.on(stdout, "data", data =>
          cb(expect(Node.Buffer.toString(data)) |> toEqual("hello\n"))
        );
      },
    );
    testAsync(
      "kill sleep and get exit code",
      ~timeout=10,
      cb => {
        let pauseProcess = ChildProcess.spawn("sleep", [|"10"|]);
        ChildProcess.Process.onExit(pauseProcess, (n, _) =>
          cb(expect(n) |> toEqual(0))
        );
        ChildProcess.Process.kill(pauseProcess);
      },
    );
    testAsync(
      "detect error",
      ~timeout=10,
      cb => {
        let pauseProcess =
          ChildProcess.spawn("this-program-doesn't-exist", [||]);
        ChildProcess.Process.onError(pauseProcess, _ => cb(pass));
      },
    );
  })
);
