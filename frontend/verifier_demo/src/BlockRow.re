module Styles = {
  open Css;

  let blockRow =
    style([
      display(`grid),
      gridTemplateColumns([
        `rem(23.0),
        `rem(10.0),
        `rem(23.0),
        `rem(10.0),
        `rem(23.0),
      ]),
      gridTemplateRows([`repeat((`num(1), `rem(23.)))]),
      gridColumnGap(`zero),
      justifyContent(`spaceBetween),
      position(`absolute),
      top(`calc((`sub, `percent(50.), `rem(10.0)))),
      left(`calc((`sub, `percent(50.), `rem(45.0)))),
    ]);

  let firstLine =
    style([
      display(`inlineBlock),
      borderTop(`px(10), `solid, Colors.marine),
      width(`rem(10.)),
      margin2(~v=`rem(11.0), ~h=`zero),
      zIndex(-1),
    ]);

  let blink = keyframes([(0, []), (100, [opacity(0.)])]);

  let secondLine =
    style([
      display(`inlineBlock),
      borderTop(`px(10), `dashed, Colors.moss),
      width(`rem(10.)),
      margin2(~v=`rem(11.0), ~h=`zero),
      zIndex(-1),
      animation(blink, ~duration=1000, ~iterationCount=`infinite),
    ]);
};

module LastBlock =
    [%graphql
      {|
      query LastBlock {
        blocks(last: 1) {
          nodes {
            stateHash
            creator
            protocolState {
              consensusState {
                blockchainLength @bsDecoder(fn:"Apollo.Decoders.string")
              }
              blockchainState {
                date
              }
            }
          }
        }
      }
   |}
    ];

module LastBlockQuery = ReasonApollo.CreateQuery(LastBlock);

[@react.component]
let make = (~verified as _) => {
  <div className=Styles.blockRow>
    <LastBlockQuery>
      {({result}) =>
         switch (result) {
         | Loading
         | Error(_) => {React.string("Error")}
         | Data(data) when Array.length(data##blocks##nodes) == 0 => React.string("No blocks")
         | Data(data) =>
           let node = Array.get(data##blocks##nodes, 0);
           let firstText =
             <div>
               <p>
                 {React.string(
                    "Blockchain Length: " ++ node##protocolState##consensusState##blockchainLength,
                  )}
               </p>
                <p> {React.string("Creator: " ++ node##creator)} </p>
               <p> {React.string("Date: " ++ node##protocolState##blockchainState##date)} </p>
             </div>;
           <>
             <Square
               bgColor=Colors.firstBg
               textColor=Colors.saville
               borderColor=Colors.navyBlue
               heading="Last Block"
               text=firstText
             />
             <span className=Styles.firstLine />
             <Square
               bgColor=Colors.secondBg
               textColor=Colors.hyperlink
               borderColor=Colors.secondBorder
               heading="Latest Snark"
               text={React.string(node##stateHash)}
             />
             <span className=Styles.secondLine />
             <Square
               bgColor=Colors.thirdBg
               textColor=Colors.jungle
               borderColor=Colors.thirdBg
               heading="Verified!"
               text={React.string(node##stateHash)}
             />
           </>;
         }}
    </LastBlockQuery>
  </div>;
};
