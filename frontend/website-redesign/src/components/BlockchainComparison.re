module Styles = {
  open Css;
  let componentContainer =
    style([
      width(`percent(100.)),
      height(`percent(100.)),
      margin2(~v=`rem(3.), ~h=`zero),
    ]);

  let flex =
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`spaceBetween),
      marginLeft(`zero),
      media(Theme.MediaQuery.tablet, [flexDirection(`row)]),
    ]);

  let comparisonContainer =
    style([
      display(`flex),
      flexDirection(`column),
      alignItems(`center),
      justifyContent(`spaceBetween),
      width(`percent(100.)),
      height(`percent(100.)),
      marginTop(`rem(3.)),
      media(
        Theme.MediaQuery.notMobile,
        [flexDirection(`row), alignItems(`flexEnd)],
      ),
      media(Theme.MediaQuery.tablet, [maxWidth(`rem(30.))]),
    ]);

  let contentContainer =
    style([
      display(`flex),
      justifyContent(`spaceBetween),
      alignItems(`center),
      flexDirection(`column),
      height(`percent(100.)),
      width(`percent(100.)),
      media(Theme.MediaQuery.notMobile, [height(`rem(14.))]),
      media(
        Theme.MediaQuery.tablet,
        [flexDirection(`row), marginTop(`zero), height(`rem(20.))],
      ),
    ]);

  let content =
    style([
      display(`flex),
      flexDirection(`row),
      justifyContent(`spaceBetween),
      width(`percent(100.)),
      height(`percent(100.)),
      maxWidth(`rem(35.)),
      borderLeft(`px(1), `solid, Theme.Colors.digitalBlack),
      paddingLeft(`rem(0.5)),
      media(Theme.MediaQuery.notMobile, [flexDirection(`column)]),
    ]);

  let textContainer =
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`spaceBetween),
      alignItems(`flexStart),
      marginLeft(`rem(1.)),
      media(
        Theme.MediaQuery.notMobile,
        [marginLeft(`zero), marginTop(`rem(1.))],
      ),
    ]);

  let sizeText =
    style([
      Theme.Typeface.monumentGrotesk,
      fontSize(`rem(4.)),
      lineHeight(`zero),
      media(Theme.MediaQuery.notMobile, [lineHeight(`initial)]),
    ]);

  let formatText =
    style([Theme.Typeface.monumentGrotesk, fontSize(`rem(3.))]);

  let comparisonImage =
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`center),
      alignItems(`center),
      marginTop(`rem(1.5)),
      width(`percent(100.)),
      height(`rem(20.)),
      marginLeft(`zero),
      media(
        Theme.MediaQuery.notMobile,
        [marginLeft(`rem(1.)), width(`rem(21.)), height(`rem(14.))],
      ),
      media(
        Theme.MediaQuery.tablet,
        [justifyContent(`flexEnd), height(`rem(20.))],
      ),
    ]);

  let minaBlockChainImage = style([width(`rem(5.)), height(`rem(5.))]);

  let comparisonLabel =
    merge([Theme.Type.label, style([fontSize(`rem(1.25))])]);

  let otherBlockChainImage =
    style([
      width(`percent(100.)),
      height(`percent(100.)),
      marginLeft(`zero),
      media(Theme.MediaQuery.tablet, [marginLeft(`rem(3.))]),
    ]);
};

[@react.component]
let make = () => {
  <div className=Styles.componentContainer>
    <Wrapped>
      <div className=Styles.flex>
        <div className=Styles.comparisonContainer>
          <div className=Styles.contentContainer>
            <div className=Styles.content>
              <h3 className=Theme.Type.h3>
                {React.string("Mina Blockchain")}
              </h3>
              <span className=Styles.textContainer>
                <span>
                  <span className=Styles.sizeText>
                    {React.string("22")}
                  </span>
                  <span className=Styles.formatText>
                    {React.string("KB")}
                  </span>
                </span>
                <span className=Styles.comparisonLabel>
                  {React.string("Fixed Size")}
                </span>
              </span>
            </div>
          </div>
          <div className=Styles.comparisonImage>
            <img
              src="/static/img/MinaBlockchain.png"
              className=Styles.minaBlockChainImage
              alt="Mina Blockchain Size"
            />
          </div>
        </div>
        <div className=Styles.comparisonContainer>
          <div className=Styles.contentContainer>
            <div className=Styles.content>
              <h3 className=Theme.Type.h3>
                {React.string("Other Blockchains")}
              </h3>
              <span className=Styles.textContainer>
                <span>
                  <span className=Styles.sizeText>
                    {React.string("300")}
                  </span>
                  <span className=Styles.formatText>
                    {React.string("GB")}
                  </span>
                </span>
                <span className=Styles.comparisonLabel>
                  {React.string("Increasing Size")}
                </span>
              </span>
            </div>
          </div>
          <div className=Styles.comparisonImage>
            <img
              src="/static/img/OtherBlockchains.png"
              className=Styles.otherBlockChainImage
              alt="Other Blockchain Size"
            />
          </div>
        </div>
      </div>
    </Wrapped>
  </div>;
};
