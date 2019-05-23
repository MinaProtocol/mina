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
    "pending task completes synchronously",
    ~timeout=10,
    cb => {
      let table = CallTable.make();

      let pendingInt: CallTable.Pending.t('x, int) =
        CallTable.nextPending(table, Typ.Int, ~loc=__LOC__);
      CallTable.resolve(table, pendingInt.ident, 1);
      Task.perform(pendingInt.task, ~f=i => cb(expect(i) |> toBe(1)));
    },
  );

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

describe("Time", () => {
  let testNow =
    Js.Date.makeWithYMDHMS(
      ~year=2019.,
      ~month=0.,
      ~date=23.,
      ~hours=14.,
      ~minutes=33.,
      ~seconds=22.,
      (),
    );
  let f = Time.render(~now=testNow);
  test("same day ago", () => {
    let date =
      Js.Date.makeWithYMDHMS(
        ~year=2019.,
        ~month=0.,
        ~date=23.,
        ~hours=2.,
        ~minutes=33.,
        ~seconds=15.,
        (),
      );
    expect(f(~date)) |> toBe("2:33am");
  });
  test("same day midnightish am", () => {
    let date =
      Js.Date.makeWithYMDHMS(
        ~year=2019.,
        ~month=0.,
        ~date=23.,
        ~hours=0.,
        ~minutes=33.,
        ~seconds=15.,
        (),
      );
    expect(f(~date)) |> toBe("12:33am");
  });
  test("same day pm", () => {
    let date =
      Js.Date.makeWithYMDHMS(
        ~year=2019.,
        ~month=0.,
        ~date=23.,
        ~hours=13.,
        ~minutes=33.,
        ~seconds=15.,
        (),
      );
    expect(f(~date)) |> toBe("1:33pm");
  });
  test("same day noonish pm", () => {
    let date =
      Js.Date.makeWithYMDHMS(
        ~year=2019.,
        ~month=0.,
        ~date=23.,
        ~hours=12.,
        ~minutes=33.,
        ~seconds=15.,
        (),
      );
    expect(f(~date)) |> toBe("12:33pm");
  });

  test("further back ago", () => {
    let date =
      Js.Date.makeWithYMDHMS(
        ~year=2018.,
        ~month=5.,
        ~date=23.,
        ~hours=12.,
        ~minutes=33.,
        ~seconds=15.,
        (),
      );
    expect(f(~date)) |> toBe("June 23rd - 12:33pm");
  });
});

describe("AddressBook", () =>
  describe("serialization", () =>
    test("roundtrip", () => {
      let before =
        Js.Dict.fromList([
          ("pk1", Js.Json.string("name")),
          ("pk2", Js.Json.string("name 2")),
          ("pk3", Js.Json.string("name-3")),
        ])
        |> Js.Json.object_
        |> Js.Json.stringify;

      let after =
        before |> AddressBook.fromJsonString |> AddressBook.toJsonString;

      expect(before) |> toEqual(after);
    })
  )
);

module TestProcess = {
  module Counts = {
    type t = {
      stopped: int,
      started: int,
      ready: int,
    };

    let empty = {stopped: 0, started: 0, ready: 0};

    // HACK: counts keyed on the first arg used (so we can differentiate between
    // tests).
    let t: Js.Dict.t(t) = Js.Dict.empty();

    let key = args => List.getAt(~index=0, args) |> Option.getExn;

    let get = args => {
      Js.Dict.get(t, key(args)) |> Option.getExn;
    };

    let zero = args => {
      Js.Dict.set(t, key(args), empty);
    };

    let write = (counts, args) => {
      Js.Dict.set(t, key(args), counts(get(args)));
    };

    let stop = write(c => {...c, stopped: c.stopped + 1});
    let start = write(c => {...c, started: c.started + 1});
    let makeReady = write(c => {...c, ready: c.ready + 1});
  };

  module State = {
    type t =
      | Stopped
      | Started
      | Ready;
  };

  type t = {
    state: ref(State.t),
    args: list(string),
  };

  let kill = (t: t) => {
    assert(t.state^ != State.Stopped);
    Counts.stop(t.args);
    t.state := State.Stopped;
  };

  let start = args => {
    let t = {state: ref(State.Started), args};
    Counts.start(args);
    Belt.Result.Ok((
      t,
      Bindings.setTimeout(30)
      |> Task.map(~f=() => {
           t.state := State.Ready;
           Counts.makeReady(args);
           `Ready;
         }),
    ));
  };
};

module TestWindow = {
  module CallTable = Messages.CallTable;

  let callTable = CallTable.make();

  type t = ref(list(Messages.mainToRendererMessages));

  let controlCodaDaemon = maybeArgs => {
    let pending =
      CallTable.nextPending(
        callTable,
        Messages.Typ.ControlCodaResponse,
        ~loc=__LOC__,
      );
    (
      Action.ControlCoda(maybeArgs, CallTable.Ident.Encode.t(pending.ident)),
      pending.task,
    );
  };

  let send = (t, message) => {
    t := [message, ...t^];
    switch (message) {
    | `Respond_control_coda(ident, response) =>
      CallTable.resolve(
        callTable,
        CallTable.Ident.Decode.t(ident, Messages.Typ.ControlCodaResponse),
        response,
      )
    | _ => ()
    };
  };
};

module TestApplication = Application.Make(TestProcess, TestWindow);

describe("ApplicationReducer", () => {
  let baseState = {
    Application.State.wallets: [||],
    coda: Application.State.CodaProcessState.Stopped(Belt.Result.Ok()),
    window: Some(ref([])),
  };

  describe("CodaProcess", () => {
    module Counts = TestProcess.Counts;

    let setup = () => {
      ...baseState,
      coda: Application.State.CodaProcessState.Stopped(Belt.Result.Ok()),
    };
    let store = initialState =>
      TestApplication.Store.create(
        initialState, ~onNewState=(_oldState, _state)
        // Js.log2("Old", Application.State.toString(oldState));
        // Js.log2("New", Application.State.toString(state));
        => ());
    let dispatch = TestApplication.Store.apply((), store(setup()));

    testAsync(
      "Start a stopped Coda",
      ~timeout=50,
      cb => {
        let args = ["test0", "a", "b"];
        Counts.zero(args);
        let (action, task) = TestWindow.controlCodaDaemon(Some(args));
        TestApplication.Store.apply((), store(setup()), action);
        Task.perform(task, ~f=res =>
          cb(expect(res) |> toEqual(Belt.Result.Ok(true)))
        );
      },
    );

    testAsync(
      "Start a stopped Coda few times with the same args",
      ~timeout=300,
      cb => {
        let args = ["test1", "a", "b"];
        Counts.zero(args);

        let run = () => {
          let (action, task) = TestWindow.controlCodaDaemon(Some(args));
          dispatch(action);
          task;
        };

        let task =
          Task.map3(
            // start it immediately
            run(),
            // start it after 2ms (before graphql on)
            Bindings.setTimeout(0) |> Task.andThen(~f=() => run()),
            // start it after 50ms (after graphql on)
            Bindings.setTimeout(50) |> Task.andThen(~f=() => run()),
            ~f=(r1, r2, r3) =>
            (r1, r2, r3)
          );

        Task.perform(
          task,
          ~f=((r1, r2, r3)) => {
            let ok = Belt.Result.Ok(true);
            cb(
              expect((r1, r2, r3, Counts.get(args).started))
              |> toEqual((ok, ok, ok, 1)),
            );
          },
        );
      },
    );

    testAsync(
      "Stop a coda",
      ~timeout=200,
      cb => {
        let args = ["test2", "a", "b"];
        Counts.zero(args);

        // start coda
        let (action, coda1) = TestWindow.controlCodaDaemon(Some(args));
        dispatch(action);

        // after we're ready, stop it
        let task =
          coda1
          |> Task.andThen(~f=res => {
               assert(res == Belt.Result.Ok(true));
               let (action, coda2) = TestWindow.controlCodaDaemon(None);
               dispatch(action);
               coda2;
             });

        Task.perform(
          task,
          ~f=res => {
            let counts = Counts.get(args);
            cb(
              expect((res, counts.ready, counts.stopped))
              |> toEqual((Belt.Result.Ok(false), 1, 1)),
            );
          },
        );
      },
    );

    testAsync(
      "Start coda with different args",
      ~timeout=200,
      cb => {
        let args1 = ["test3", "a", "b"];
        let args2 = ["test3", "a", "b", "c"];
        Counts.zero(args1);

        // start coda
        let (action, coda1) = TestWindow.controlCodaDaemon(Some(args1));
        dispatch(action);

        // after we're ready, start it again with different args
        let task =
          coda1
          |> Task.andThen(~f=res => {
               assert(res == Belt.Result.Ok(true));
               let (action, coda2) =
                 TestWindow.controlCodaDaemon(Some(args2));
               dispatch(action);
               coda2;
             });

        Task.perform(
          task,
          ~f=res => {
            let counts = Counts.get(args1);
            cb(
              expect((res, counts.ready, counts.stopped))
              |> toEqual((Belt.Result.Ok(true), 2, 1)),
            );
          },
        );
      },
    );
  });
});
