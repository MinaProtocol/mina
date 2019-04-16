open BsElectron;
open Tc;

include BrowserWindow.MakeBrowserWindow(Messages);

include Single.Make({
  type input = Route.t;
  type t = BrowserWindow.t;

  let listen = (t, settingsOrError) => {
    let cb =
      (. _event, message) =>
        switch (message) {
        | `Set_name(key, name, pendingIdent) =>
          switch (settingsOrError) {
          | `Settings(settings) =>
            let task = SettingsMain.add(settings, ~key, ~name);
            Task.attempt(
              task,
              ~f=_res => {
                Js.log2("Settings updated", settings);
                send(t, `Respond(pendingIdent));
              },
            );
          | _ => send(t, `Respond(pendingIdent))
          }
        };
    RendererCommunication.on(cb);
    cb;
  };

  let make: (~drop: unit => unit, input) => t =
    (~drop, route) => {
      let window =
        make(
          makeWindowConfig(
            ~transparent=true,
            ~width=880,
            ~height=500,
            ~frame=false,
            ~fullscreenable=false,
            ~resizeable=false,
            ~title="Coda Wallet",
            ~backgroundColor=
              "#DD" ++ StyleGuide.Colors.(hexToString(bgColor)),
            (),
          ),
        );
      loadURL(
        window,
        "file://"
        ++ ProjectRoot.path
        ++ "public/index.html#"
        ++ Route.print(route),
      );

      let listener = listen(window, route.settingsOrError);
      on(
        window,
        `Closed,
        () => {
          RendererCommunication.removeListener(listener);
          drop();
        },
      );

      window;
    };
});

let deepLink = route => {
  let w = get(route);
  // route handling is idempotent so doesn't matter if we also send the message
  // if window already exists
  send(w, `Deep_link(Route.print(route)));
  ();
};
