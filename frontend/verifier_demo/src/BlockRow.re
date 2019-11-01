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

type bigint;
[@bs.val] external createBigInt: string => bigint = "BigInt";
[@bs.send] external bigIntToString: (bigint, int) => string = "toString";

let decToB64: string => string = [%bs.raw
  {|
  function decToB64(n) {
  var hex = BigInt(n).toString(16);
  if (hex.length % 2) { hex = '0' + hex; }
  var bin = [];
  var i = 0;
  var d, b;
  while (i < hex.length) {
    d = parseInt(hex.slice(i, i + 2), 16);
    b = String.fromCharCode(d);
    bin.push(b);
    i += 2;
  }
  return btoa(bin.join(''));
} |}
];

module LastBlock = [%graphql
  {|
      query LastBlock {
        blocks(last: 1) {
          nodes {
            protocolStateProof {
              a
              b
              c
              delta_prime
              z
            }
            creator @bsDecoder(fn:"Apollo.Decoders.string")
            stateHash
            protocolState {
              consensusState {
                blockchainLength @bsDecoder(fn:"Apollo.Decoders.string")
              }
              blockchainState {
                date @bsDecoder(fn:"Apollo.Decoders.date")
              }
            }
            }
          }
        }
   |}
];

module LastBlockQuery = ReasonApollo.CreateQuery(LastBlock);

[@react.component]
let make = (~verified) => {
  <div className=Styles.blockRow>
    <LastBlockQuery>
      {({result}) =>
         switch (result) {
         | Loading
         | Error(_) => React.string("We out here loading")
         | Data(data) when Array.length(data##blocks##nodes) == 0 =>
           React.string("No blocks")
         | Data(data) =>
           let node = data##blocks##nodes[0];
           let firstText =
             <div>
               <p>
                 {React.string(
                    "Blockchain Length: "
                    ++
                    node##protocolState##consensusState##blockchainLength,
                  )}
               </p>
               <p>
                 {React.string(
                    "Date: "
                    ++ Js.Date.toString(
                         node##protocolState##blockchainState##date,
                       ),
                  )}
               </p>
             </div>;

           let g1 = values =>
             String.concat("", Array.to_list(Array.map(decToB64, values)));
           let g2 = values =>
             String.concat(
               "",
               Array.to_list(
                 Array.map(
                   l =>
                     String.concat(
                       "",
                       Array.to_list(Array.map(decToB64, l)),
                     ),
                   values,
                 ),
               ),
             );
           let snarkText =
             <div>
               <p>
                 {React.string(
                    g1(node##protocolStateProof##a)
                    ++ g2(node##protocolStateProof##b)
                    ++ g1(node##protocolStateProof##c)
                    ++ g2(node##protocolStateProof##delta_prime)
                    ++ g1(node##protocolStateProof##z),
                  )}
               </p>
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
               text=snarkText
               textSize={`rem(0.005)}
               marginTop={`rem(-1.8)}
             />
             <span className=Styles.secondLine />
             <Square
               bgColor=Colors.thirdBg
               borderColor=Colors.thirdBg
               textColor=Colors.jungle
               text={React.string(node##stateHash)}
               heading={verified ? "Verified!" : "Verifying..."}
               active=verified
             />
           </>;
         }}
    </LastBlockQuery>
  </div>;
};
