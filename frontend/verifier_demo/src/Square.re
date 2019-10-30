module Colors = {
  let navyBlue = `hex("4782A0");
  let lightBlue = `hex("DDEFFA");
  let lightGreen = `hex("ECF2ED");
  let activeGreen = `hex("2BAC46");
  let saville =  `hex("3D5878");
};

 module Styles = {
    open Css; 
    let square = (bgColor, textColor, borderColor) => style([display(`flex),
    flexDirection(`column),
    justifyContent(`spaceBetween),
    alignItems(`center),
    height(`rem(25.)),
    width(`rem(25.)),
    backgroundColor(bgColor),
    selector("h3", [color(textColor)]),
    border(`px(1), `solid, borderColor)]);
  };
   
  [@react.component]
  let make = (~heading) => 
  <div className={
    Styles.square(Colors.navyBlue,Colors.saville, Colors.saville)}>
    <h1> {React.string(heading)} </h1>
  </div>;
