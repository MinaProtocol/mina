let log = (section, sev, fmt) => {
  let sevStr =
    switch (sev) {
    | `Warn => "Warn"
    | `Error => "Error"
    | `Info => "Info"
    };
  Printf.ksprintf(
    s => {
      let date = Js.Date.(now() |> fromFloat |> toUTCString);
      Printf.printf("%s [%s] %s: %s\n", date, sevStr, section, s);
    },
    fmt,
  );
};
