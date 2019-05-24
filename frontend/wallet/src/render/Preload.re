let downloadRoot = "https://s3-us-west-1.amazonaws.com/proving-key-2018-10-01/";

let downloadKey = (keyName, chunkCb, doneCb) =>
  DownloadLogic.download(
    keyName,
    downloadRoot ++ keyName,
    "binary",
    1,
    chunkCb,
    doneCb,
  );

[%bs.raw "window.downloadKey = downloadKey"];
