open Jest;
open Expect;
open Tc;

describe("CallTable", () =>
  testAsync(
    "pending tasks complete",
    ~timeout=10,
    cb => {
      let table = CallTable.make();
      let pending: CallTable.Pending.t('x) =
        CallTable.nextPending(table, ~loc=__LOC__);
      Task.perform(pending.task, ~f=() => cb(expect(true) |> toBe(true)));

      let _ =
        Js.Global.setTimeout(
          () => CallTable.resolve(table, pending.ident),
          1,
        );
      ();
    },
  )
);

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
