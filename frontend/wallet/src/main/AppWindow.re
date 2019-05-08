open BsElectron;
open Tc;

include BrowserWindow.MakeBrowserWindow(Messages);

module Input = {
  type t('a) = {
    path: Route.t,
    settingsOrError: Result.t([> ] as 'a, Settings.t),
  };
};

include Single.Make({
  type input('a) = Input.t('a);

  type t = BrowserWindow.t;

  let listen = (t, settingsOrError) => {
    let cb =
      (. _event, message) =>
        switch (message) {
        | `Set_name(key, name, pendingIdent) =>
          switch (settingsOrError) {
          | Belt.Result.Ok(settings) =>
            let task = SettingsMain.add(settings, ~key, ~name);
            Task.attempt(task, ~f=_res =>
              send(t, `Respond_new_settings((pendingIdent, ())))
            );
          | Belt.Result.Error(_) =>
            // TODO: Anything else we should do here to bubble the error up
            send(t, `Respond_new_settings((pendingIdent, ())))
          }
        };
    RendererCommunication.on(cb);
    cb;
  };

  let make: (~drop: unit => unit, input('a)) => t =
    (~drop, input) => {
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
            ~webPreferences=
              makeWebPreferences(
                ~preload=
                  Filename.concat(
                    [%bs.node __dirname] |> Option.getExn,
                    "../render/Preload.js",
                  ),
                ~nodeIntegration=true,
                (),
              ),
            (),
          ),
        );
      loadURL(
        window,
        "file://"
        ++ Filename.concat(ProjectRoot.resource, "public/index.html")
        ++ "#"
        ++ Route.print(input.path),
      );

      let listener = listen(window, input.settingsOrError);
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

let deepLink = input => {
  let w = get(input);
  // route handling is idempotent so doesn't matter if we also send the message
  // if window already exists
  send(w, `Deep_link(Route.print(input.path)));
  ();
};
