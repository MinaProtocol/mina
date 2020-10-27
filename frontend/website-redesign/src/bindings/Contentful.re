let spaceID = Next.Config.contentful_space;
let contentAPIToken = Next.Config.contentful_token;
let host = Next.Config.contentful_host;

type clientArgs = {
  space: string,
  accessToken: string,
  host: string,
};

type client;

[@bs.module "contentful"] [@bs.val]
external createClient: clientArgs => client = "createClient";

let client =
  lazy(createClient({space: spaceID, accessToken: contentAPIToken, host}));

[@bs.send]
external getEntries:
  (client, Js.t('args)) => Js.Promise.t(ContentType.System.entries('entry)) =
  "getEntries";

[@bs.send]
external getEntry:
  (client, string, Js.t('args)) => Js.Promise.t(ContentType.System.entry('entry)) =
  "getEntry";
