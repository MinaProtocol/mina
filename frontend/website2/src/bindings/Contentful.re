let spaceID = Next.Config.contentful_space;
let contentAPIToken = Next.Config.contentful_token;

type clientArgs = {
  space: string,
  accessToken: string,
};

type client;

[@bs.module "contentful"] [@bs.val]
external createClient: clientArgs => client = "createClient";

let client =
  lazy(createClient({space: spaceID, accessToken: contentAPIToken}));

[@bs.send]
external getEntries:
  (client, Js.t('args)) => Js.Promise.t(ContentType.System.entries('entry)) =
  "getEntries";
