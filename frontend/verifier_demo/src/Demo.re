module Colors = {
  open Css;
  let navyBlue = color(`hex("4782A0"));
  let lightBlue = color(`hex("DDEFFA"));
  let lightGreen = color(`hex("ECF2ED"));
  let activeGreen = color(`hex("2BAC46"));
  let saville=  color(`hex("3D5878"));
};

module Styles {
  open Css;
  
  let container = style([
    width(`vw(100.)),
    maxHeight(`vh(100.)),
    overflow(`hidden),
  ]);
  
  let curveRotation =
    keyframes([
      (0, [transform(rotate(`deg(0.)))]),
      (100, [transform(rotate(`deg(359.)))]),
    ]);
  
  let curve = style([
    position(`absolute),
    top(`calc(`sub, `percent(50.), `px(1000))),
    left(`calc(`sub, `percent(50.), `px(1000))),
     animation(curveRotation, ~duration=20000, ~iterationCount=`infinite, ~timingFunction=`linear), 
     height(`px(2000)),
  ]);
  
  let ring = style([
    position(`absolute),
    top(`calc(`sub, `percent(50.), `rem(12.5))),
    left(`calc(`sub, `percent(50.), `rem(12.5))),
     animation(curveRotation, ~duration=20000, ~iterationCount=`infinite, ~timingFunction=`linear), 
     height(`rem(25.)),
  ]);
  
  let banner = style([
    display(`flex),
    justifyContent(`spaceAround),
    alignItems(`center),
    position(`absolute),
    top(`rem(2.)),
    left(`rem(5.)),
  ]);
  
  let ibmplexsans =
    fontFace(
      ~fontFamily="IBM Plex Sans",
      ~src=[url("/static/fonts/IBMPlexSans-SemiBold-Latin1.woff2")],
      ~fontStyle=`normal,
      ~fontWeight=`semiBold,
      (),
    );
  
  let headerSaville = style([
    marginLeft(`rem(2.)),
    fontFamily(ibmplexsans),
    fontSize(`rem(3.625)),
    color(`hex("3D5878")),
  ]);    
  
  let headerRed = style([
    color(`rgb((163, 83, 111))),
  ]); 
  
  let logo = style([
    maxHeight(`rem(3.)),
  ]);
  
  let blockRow = style([
    display(`grid),
    gridTemplateColumns([`repeat((`num(3), `fr(1.0)))]),
    gridTemplateRows([`repeat((`num(1), `rem(7.5)))]),
    gridColumnGap(rem(1.0)),
    justifyContent(`spaceBetween),
    position(`absolute),
    top(`rem(20.)),
    left(`rem(5.)),
  ]);
}
 
module Spacer = {
  [@react.component]
  let make = (~width=0., ~height=0.) =>
    <div
      className={Css.style([
        Css.width(`rem(width)),
        Css.height(`rem(height)),
        Css.flexShrink(0.),
      ])}
    />;
};


[@react.component]
let make = () => {
  <div> 
    <div className=Styles.container>
      <img className=Styles.curve src="/static/img/EllipticSeal.svg"> </img>
      <img className=Styles.ring src="/static/img/O1EstablishedRing.svg"> </img>
    </div>
    
    <div className=Styles.banner>
        <img src="/static/img/codaLogo.png" className=Styles.logo></img> 
        <p className=Styles.headerSaville> {React.string("was verified in the browser in ")} <span className=Styles.headerRed> {React.string("42 milliseconds")} </span> </p>
    </div>
    
    <Spacer height=5.0/>
    
    <div className=Styles.blockRow> 
      <Square heading="Last Block"/>
      <Square heading="Latest Snark"/>
      <Square heading="Verified!"/>
    </div> 
  </div>
};
