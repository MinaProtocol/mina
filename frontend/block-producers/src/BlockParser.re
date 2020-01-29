[%raw "require('isomorphic-fetch')"];

module Result = {
  type t = {creator: string};
};

module BlockPage = {
  type t = {
    next: string,
    results: array(Result.t),
    detail: option(string),
  };
};

let rec parseBlockPages = (pageNumber, creatorsList) => {
  Js.Promise.(
    Fetch.fetch(
      "http://blocks.o1test.net/api/v1/blocks/?page="
      ++ Js.Int.toString(pageNumber),
    )
    |> then_(Fetch.Response.json)
    |> then_(json => {
         let foo: BlockPage.t = Obj.magic(json);
         switch (foo.detail) {
         | None =>
           open Result;
           let creators = foo.results |> Array.map(result => result.creator);
           parseBlockPages(
             pageNumber + 1,
             Js.Array.concat(creators, creatorsList),
           );
         | Some(_) =>
           Js.log("End of pages reached");
           Js.Promise.resolve(creatorsList);
         };
       })
  );
};

module Account = {
  type t = {
    pk: string,
    nickname: string,
    balance: int,
  };
};

[@bs.scope "JSON"] [@bs.val]
external parseAccounts: string => array(Account.t) = "parse";

let supposedBlockProducersList = {
  let supposedBlockProducers = Js.Dict.empty();
  parseAccounts(Node.Fs.readFileSync("src/annotated_ledger.json", `utf8))
  |> Js.Array.filter((account: Account.t) => account.balance == 1000)
  |> Js.Array.forEach((account: Account.t) =>
       Js.Dict.set(supposedBlockProducers, account.pk, account.nickname)
     );
  supposedBlockProducers;
};
