let baseUrl = "https://sheets.googleapis.com/v4/spreadsheets/";

let fetchRange = (~sheet, ~range) => {
  ReFetch.fetch(
    baseUrl
    ++ sheet
    ++ "/values/"
    ++ range
    ++ "?key="
    ++ Next.Config.google_api_key,
    ~method_=Get,
    ~headers={
      "Accept": "application/json",
      "Content-Type": "application/json",
    },
  )
  |> Promise.bind(Bs_fetch.Response.json)
  |> Promise.map(r => {
       let results =
         Option.bind(Js.Json.decodeObject(r), o => Js.Dict.get(o, "values"));

       switch (Option.bind(results, Js.Json.decodeArray)) {
       | Some(resultsArr) => resultsArr
       | None => [||]
       };
     })
  |> Js.Promise.catch(_ => Promise.return([||]));
};
