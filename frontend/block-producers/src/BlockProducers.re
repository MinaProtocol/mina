Js.Promise.(
  BlockParser.parseBlockPages(1, [||])
  |> then_(creators => {
       creators
       |> Js.Array.forEach((creator: string) => {
            switch (
              Js.Dict.get(BlockParser.supposedBlockProducersList, creator)
            ) {
            | Some(_) =>
              Js.Dict.unsafeDeleteKey(.
                BlockParser.supposedBlockProducersList,
                creator,
              )
            | None => ()
            }
          });
       Js.log(BlockParser.supposedBlockProducersList);
       Js.Promise.resolve();
     })
);
