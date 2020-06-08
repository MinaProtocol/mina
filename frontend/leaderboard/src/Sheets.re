open Bindings;

let getClient = (client, cb) => {
  GoogleSheets.getClient(client, (~error, ~token) => {
    switch (Js.Nullable.toOption(error)) {
    | Some(error) => cb(Error(error))
    | None => cb(Ok(token))
    }
  });
};

let getRange = (client, sheetsQuery, cb) => {
  let sheets = GoogleSheets.sheets({version: "v4", auth: client});
  GoogleSheets.get(sheets, sheetsQuery, (~error, ~res) => {
    switch (Js.Nullable.toOption(error)) {
    | None => cb(Ok(res.data.values))
    | Some(error) => cb(Error(error))
    }
  });
};

let updateRange = (client, sheetsUpdate, cb) => {
  let sheets = GoogleSheets.sheets({version: "v4", auth: client});

  GoogleSheets.update(sheets, sheetsUpdate, (~error, ~res) => {
    switch (Js.Nullable.toOption(error)) {
    | None => cb(Ok(res.data.values))
    | Some(error) => cb(Error(error))
    }
  });
};