module Styles = {
  open Css;
  let componentContainer =
    style([
      width(`percent(100.)),
      height(`percent(100.)),
      marginBottom(`rem(3.)),
      media(Theme.MediaQuery.tablet, [margin2(~v=`rem(3.), ~h=`zero)]),
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
      marginTop(`rem(5.)),
      media(
        Theme.MediaQuery.tablet,
        [flexDirection(`row), alignItems(`flexEnd), maxWidth(`rem(30.))],
      ),
      media(Theme.MediaQuery.desktop, [maxWidth(`rem(40.))]),
    ]);

  let contentContainer =
    style([
      display(`flex),
      justifyContent(`spaceBetween),
      alignItems(`center),
      flexDirection(`column),
      height(`percent(100.)),
      width(`percent(100.)),
      media(
        Theme.MediaQuery.tablet,
        [
          flexDirection(`row),
          marginTop(`zero),
          width(`percent(50.)),
          height(`rem(20.)),
        ],
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
      paddingLeft(`rem(1.5)),
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
      width(`rem(30.)),
      height(`rem(30.)),
      marginLeft(`zero),
      overflow(`hidden),
      media(
        Theme.MediaQuery.notMobile,
        [width(`percent(50.)), maxWidth(`rem(26.)), height(`rem(14.))],
      ),
      media(Theme.MediaQuery.tablet, [height(`rem(20.))]),
    ]);

  let minaBlockChainImage = style([height(`percent(90.))]);

  let comparisonLabel =
    merge([Theme.Type.label, style([fontSize(`rem(1.25))])]);

  let otherBlockChainImage =
    style([height(`percent(100.)), marginLeft(`zero)]);
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
              src="/static/img/mina-cubes.gif"
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
              src="/static/img/mina-heavy.gif"
              className=Styles.otherBlockChainImage
              alt="Other Blockchain Size"
            />
          </div>
        </div>
      </div>
    </Wrapped>
  </div>;
};
