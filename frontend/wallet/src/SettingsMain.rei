include Settings.S;

let load:
  unit =>
  Tc.Task.t(
    [>
      | `Decode_error(string)
      | `Error_reading_file(Js.Exn.t)
      | `Json_parse_error
    ],
    Settings.t,
  );
