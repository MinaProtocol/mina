module Styles = {
  open Css;
  let container =
    style([
      width(`percent(100.)),
      height(`percent(100.)),
      margin2(~v=`rem(3.), ~h=`zero),
    ]);

  let comparisonContainer =
    style([
      display(`flex),
      justifyContent(`spaceBetween),
      alignItems(`center),
      flexDirection(`column),
      selector("div:last-child", [marginTop(`rem(3.))]),
      media(
        Theme.MediaQuery.desktop,
        [flexDirection(`row), marginTop(`zero)],
      ),
    ]);

  let comparison =
    style([
      display(`inlineFlex),
      justifyContent(`spaceBetween),
      width(`rem(27.)),
      height(`rem(20.)),
      paddingLeft(`rem(0.5)),
      borderLeft(`px(1), `solid, Theme.Colors.digitalBlack),
    ]);

  let comparisonContent =
    style([
      display(`flex),
      flexDirection(`column),
      alignItems(`flexStart),
      justifyContent(`spaceBetween),
      height(`percent(100.)),
    ]);

  let comparisonText =
    style([
      display(`flex),
      flexDirection(`column),
      alignItems(`flexStart),
    ]);

  let comparisonSize =
    style([
      Theme.Typeface.monumentGrotesk,
      fontSize(`rem(5.)),
      lineHeight(`rem(8.)),
    ]);

  let comparisonFormat =
    style([
      Theme.Typeface.monumentGrotesk,
      fontSize(`rem(3.5)),
      lineHeight(`rem(8.)),
    ]);

  let comparisonImage =
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`flexEnd),
      alignContent(`center),
    ]);

  let minaBlockChainImage = style([width(`rem(5.)), height(`rem(5.))]);

  let comparisonLabel =
    merge([Theme.Type.label, style([fontSize(`rem(1.25))])]);

  let otherBlockChainImage =
    style([
      width(`rem(14.25)),
      height(`rem(19.)),
      marginLeft(`rem(3.)),
    ]);
};

[@react.component]
let make = () => {
  <div className=Styles.container>
    <Wrapped>
      <div className=Styles.comparisonContainer>
        <div className=Styles.comparison>
          <div className=Styles.comparisonContent>
            <h3 className=Theme.Type.h3>
              {React.string("Mina Blockchain")}
            </h3>
            <span className=Styles.comparisonText>
              <span className=Css.(style([height(`rem(8.))]))>
                <span className=Styles.comparisonSize>
                  {React.string("22")}
                </span>
                <span className=Styles.comparisonFormat>
                  {React.string("KB")}
                </span>
              </span>
              <span className=Styles.comparisonLabel>
                {React.string("Fixed Size")}
              </span>
            </span>
          </div>
          <div className=Styles.comparisonImage>
            <img
              src="/static/img/MinaBlockchain.png"
              className=Styles.minaBlockChainImage
            />
          </div>
        </div>
        <div className=Styles.comparison>
          <div className=Styles.comparisonContent>
            <h3 className=Theme.Type.h3>
              {React.string("Other Blockchains")}
            </h3>
            <span className=Styles.comparisonText>
              <span className=Css.(style([height(`rem(8.))]))>
                <span className=Styles.comparisonSize>
                  {React.string("300")}
                </span>
                <span className=Styles.comparisonFormat>
                  {React.string("GB")}
                </span>
              </span>
              <span className=Styles.comparisonLabel>
                {React.string("Increasing Size")}
              </span>
            </span>
          </div>
          <div className=Styles.comparisonImage>
            <img
              src="/static/img/OtherBlockchains.png"
              className=Styles.otherBlockChainImage
            />
          </div>
        </div>
      </div>
    </Wrapped>
  </div>;
};
