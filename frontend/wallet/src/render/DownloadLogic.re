module Https = {
  module Request = {
    type t;

    [@bs.send]
    external onError: (t, [@bs.as "error"] _, string => unit) => unit = "on";
  };

  module Response = {
    type t;

    module Headers = {
      [@bs.deriving abstract]
      type t =
        pri {
          location: string,
          [@bs.as "content-length"]
          contentLength: string,
        };
    };

    [@bs.get] external getStatusCode: t => int = "statusCode";

    [@bs.get] external getHeaders: t => Headers.t = "headers";

    [@bs.send] external setEncoding: (t, string) => unit = "setEncoding";

    [@bs.send]
    external onData:
      (t, [@bs.as "data"] _, Bindings.Stream.Chunk.t => unit) => unit =
      "on";

    [@bs.send]
    external onEnd: (t, [@bs.as "end"] _, unit => unit) => unit = "on";
  };

  [@bs.module "https"]
  external get: (string, Response.t => unit) => Request.t = "get";
};

module Unzipper = {
  type extractOpts = {. "path": string};
  [@bs.module "unzipper"]
  external extract: extractOpts => Bindings.Stream.Writable.t = "Extract";
};

let handleResponse = (response, filename, dataEncoding, chunkCb, doneCb) => {
  Https.Response.setEncoding(response, dataEncoding);
  let total =
    response
    |> Https.Response.getHeaders
    |> Https.Response.Headers.contentLengthGet
    |> int_of_string;
  let stream =
    Bindings.Stream.Writable.create(filename, {"encoding": dataEncoding})
    ->Bindings.Stream.Writable.onFinish(() => doneCb(Belt.Result.Ok()))
    ->Bindings.Stream.Writable.onError(e =>
        doneCb(
          Error(Tc.Option.withDefault(~default="", Js.Exn.message(e))),
        )
      );

  Https.Response.onData(
    response,
    chunk => {
      Bindings.Stream.Writable.write(stream, chunk);
      chunkCb(chunk##length, total);
    },
  );

  Https.Response.onEnd(response, () =>
    Bindings.Stream.Writable.endStream(stream)
  );
};

/**
  Recusively follows redirects until non-redirect resource is hit, or
  we reach `maxRedirects`, then passes onto handleResonse.
 */
let rec download = (filename, url, encoding, maxRedirects, chunkCb, doneCb) => {
  let request =
    Https.get(url, response =>
      switch (Https.Response.getStatusCode(response)) {
      | 301
      | 306
      | 307 =>
        if (maxRedirects <= 0) {
          let redirectUrl =
            response
            |> Https.Response.getHeaders
            |> Https.Response.Headers.locationGet;
          download(
            filename,
            redirectUrl,
            encoding,
            maxRedirects - 1,
            chunkCb,
            doneCb,
          );
        } else {
          doneCb(Belt.Result.Error("Too many redirects."));
        }
      | 200 => handleResponse(response, filename, encoding, chunkCb, doneCb)
      | status =>
        doneCb(
          Belt.Result.Error(
            "Unable to download the daemon. Status: " ++ string_of_int(status),
          ),
        )
      }
    );
  Https.Request.onError(request, e => doneCb(Error(e)));
};

// TODO: Make this an env var
let codaRepo = "https://wallet-daemon.s3-us-west-1.amazonaws.com/";

[@bs.module "electron"] [@bs.scope ("remote", "app")]
external getPath: string => string = "getPath";

let extractZip = (src, dest, doneCb) => {
  let extractArgs = {"path": dest};

  let _ =
    Bindings.Stream.Readable.create(src)
    ->(Bindings.Stream.Readable.pipe(Unzipper.extract(extractArgs)))
    ->Bindings.Stream.Writable.onFinish(() => doneCb(Belt.Result.Ok()))
    ->Bindings.Stream.Writable.onError(err =>
        doneCb(
          Belt.Result.Error(
            "Error while unzipping the daemon bundle: "
            ++ (
              Js.Exn.message(err)
              |> Tc.Option.withDefault(~default="an unknown error occured.")
            ),
          ),
        )
      );

  ();
};

let installCoda = (tempPath, doneCb) => {
  let installPath = getPath("userData") ++ "/coda";
  let keysPath = "/usr/local/var/coda/keys/";
  let rec moveKeys = files =>
    switch (files) {
    | [] => ()
    | [hd, ...rest] =>
      Bindings.Fs.renameSync(installPath ++ "/keys/" ++ hd, keysPath ++ hd);
      moveKeys(rest);
    };
  extractZip(tempPath, installPath, res =>
    switch (res) {
    | Belt.Result.Ok () =>
      Bindings.Fs.chmodSync(installPath ++ "/mina.exe", 0o755);
      Bindings.Fs.chmodSync(installPath ++ "/libp2p_helper", 0o755);
      Bindings.Fs.readdirSync(installPath ++ "/keys")
      |> Array.to_list
      |> moveKeys;
      doneCb(res);
    | Belt.Result.Error(_) => doneCb(res)
    }
  );
  ();
};

let downloadCoda = (version, chunkCb, doneCb) => {
  let filename = "coda-daemon-" ++ version ++ ".zip";
  let tempPath = getPath("temp") ++ "/" ++ filename;
  download(tempPath, codaRepo ++ filename, "binary", 1, chunkCb, res =>
    switch (res) {
    | Belt.Result.Error(_) => doneCb(res)
    | _ => installCoda(tempPath, doneCb)
    }
  );
};
