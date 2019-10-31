 module Styles {
  open Css;
  
  let blockRow = style([
    display(`grid),
    gridTemplateColumns([`rem(23.0), `rem(10.0), `rem(23.0), `rem(10.0), `rem(23.0)]),
    gridTemplateRows([`repeat((`num(1), `rem(23.)))]),
    gridColumnGap(`zero),
    justifyContent(`spaceBetween),
    position(`absolute),
    top(`calc(`sub, `percent(50.), `rem(10.0))),
    left(`calc(`sub, `percent(50.), `rem(45.0))),
  ]);
  
  let firstLine = style([
    display(`inlineBlock),
    borderTop(`px(10), `solid, Colors.marine),
    width(`rem(10.)),
    margin2(~v=`rem(11.0), ~h=`zero),
    zIndex(-1),
  ]);
  
  let blink =
    keyframes([
      (0, []),
      (100, [opacity(0.)]),
    ]);
  
  let secondLine = style([
    display(`inlineBlock),
    borderTop(`px(10), `dashed, Colors.moss),
    width(`rem(10.)),
    margin2(~v=`rem(11.0), ~h=`zero),
    zIndex(-1),
    animation(blink, ~duration=1000,~iterationCount=`infinite ),
  ]);
 
}

let firstText = {
  <div>
    <p> {React.string("Block Height: 140")} </p> 
    <p> {React.string("Date: 2019-10-26 12:15:00")} </p>
  </div>
};

let stateHash = {
  {React.string("4ApWEzSMKEsaPF6rYx6Vh6VBbHmxupj8C1EzQDyQDtcbqfmg3pnwtaFrAXWZs4QrhNHj8UtFhp3Af66M1uvoqTBy5RPe3JQmHHwYcPooZSMZgppvrCRxQ1c3DaoQh3heBXCuNAofL8hQv")}
};

[@react.component]
let make = () => {
 <div className=Styles.blockRow> 
      <Square bgColor=Colors.firstBg textColor=Colors.saville borderColor=Colors.navyBlue heading="Last Block" text=firstText/>
        <span className=Styles.firstLine></span>
      <Square bgColor=Colors.secondBg textColor=Colors.hyperlink borderColor=Colors.secondBorder heading="Latest Snark" text=stateHash/>
        <span className=Styles.secondLine></span>
      <Square bgColor=Colors.thirdBg textColor=Colors.jungle borderColor=Colors.thirdBg heading="Verified!" text=stateHash/>
</div>
    };
