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

describe("Settings", () =>
  describe("serialization", () =>
    testAll(
      "print/parse roundtrip",
      // TODO: Quickcheck this
      [
        Route.{path: Home, settingsOrError: `Error(`Json_parse_error)},
        Route.{path: Send, settingsOrError: `Error(`Decode_error("Oops"))},
        Route.{
          path: DeleteWallet,
          settingsOrError:
            `Error(
              `Error_reading_file(
                Obj.magic(
                  Route.SettingsOrError.Decode.Error.create(
                    ~name="Error",
                    ~message="an error",
                    ~stack="some stack trace",
                  ),
                ),
              ),
            ),
        },
        Route.{
          path: Home,
          settingsOrError:
            `Settings({
              Settings.state:
                Js.Dict.fromList([
                  ("a123", "Test Wallet1"),
                  ("a234", "Test Wallet2"),
                ]),
            }),
        },
      ],
      a =>
      expect(a |> Route.print |> Route.parse) |> toEqual(Some(a))
    )
  )
);

describe("Bindings", () =>
  describe("spawn", () =>
    testAsync(
      "spawn echo and get stdout and exit code",
      ~timeout=10,
      cb => {
        open Bindings.Child_process;
        let echoProcess = spawn("echo", [|"hello"|]);
        echoProcess
        |> Spawn.stdoutGet
        |> (
          x =>
            x.Event.on("data", data =>
              cb(expect(Node.Buffer.toString(data)) |> toEqual("hello"))
            )
        );
      },
    )
  )
);
