module Styles = {
  open Css;

  let sectionBackgroundImage = backgroundImg =>
    style([
      height(`percent(100.)),
      width(`percent(100.)),
      paddingBottom(`rem(6.)),
      important(backgroundSize(`cover)),
      backgroundImage(`url(backgroundImg)),
    ]);
};

module Section = {
  module SectionStyles = {
    open Css;
    let rowContainer = (~reverse=false, ()) =>
      style([
        display(`flex),
        flexDirection(`column),
        justifyContent(`spaceBetween),
        alignItems(`center),
        marginTop(`rem(2.)),
        media(
          Theme.MediaQuery.tablet,
          [
            reverse ? flexDirection(`rowReverse) : flexDirection(`row),
            marginTop(`rem(6.)),
          ],
        ),
        media(
          Theme.MediaQuery.desktop,
          [
            reverse ? flexDirection(`rowReverse) : flexDirection(`row),
            marginTop(`rem(12.5)),
          ],
        ),
      ]);

    let textContainer =
      style([maxWidth(`rem(29.)), width(`percent(100.))]);

    let title = merge([Theme.Type.h2, style([marginTop(`rem(1.5))])]);

    let paragraphText =
      merge([Theme.Type.paragraph, style([marginTop(`rem(1.5))])]);

    let icon =
      style([
        display(`flex),
        alignItems(`center),
        justifyContent(`center),
        marginLeft(`rem(0.5)),
        marginTop(`rem(0.2)),
        color(Theme.Colors.orange),
      ]);

    let image =
      style([width(`percent(100.)), height(`auto), maxWidth(`rem(29.))]);
  };
  module SimpleRow = {
    type t = {
      title: string,
      description: string,
      buttonCopy: string,
      buttonUrl: string,
      image: string,
    };

    module Styles = {
      open Css;

      let seperator =
        style([borderBottom(`px(1), `solid, Theme.Colors.digitalBlack)]);

      let button = style([marginTop(`rem(2.))]);
    };

    [@react.component]
    let make = (~rows) => {
      rows
      |> Array.mapi((idx, row) => {
           <div
             key={row.title}
             className={SectionStyles.rowContainer(
               ~reverse={
                 idx mod 2 != 0;
               },
               (),
             )}>
             <div className=SectionStyles.textContainer>
               <div className=Styles.seperator />
               <h2 className=SectionStyles.title>
                 {React.string(row.title)}
               </h2>
               <p className=SectionStyles.paragraphText>
                 {React.string(row.description)}
               </p>
               <div className=Styles.button>
                 <Button bgColor=Theme.Colors.white>
                   {React.string(row.buttonCopy)}
                   <span className=SectionStyles.icon>
                     <Icon kind=Icon.ArrowRightMedium />
                   </span>
                 </Button>
               </div>
             </div>
             <img src={row.image} className=SectionStyles.image />
           </div>
         })
      |> React.array;
    };
  };

  module FeaturedRow = {
    type t = {
      title: string,
      description: string,
      linkCopy: string,
      linkUrl: string,
      image: string,
    };

    module Styles = {
      open Css;
      let linkText =
        merge([
          Theme.Type.link,
          style([
            marginTop(`rem(1.5)),
            display(`flex),
            alignItems(`center),
            cursor(`pointer),
          ]),
        ]);

      let seperator = seperatorNumber =>
        style([
          display(`flex),
          alignItems(`center),
          borderBottom(`px(1), `solid, Theme.Colors.digitalBlack),
          before([
            contentRule(seperatorNumber),
            Theme.Typeface.monumentGrotesk,
            color(Theme.Colors.digitalBlack),
            lineHeight(`rem(1.5)),
            letterSpacing(`px(-1)),
          ]),
        ]);
    };

    [@react.component]
    let make = (~rows) => {
      rows
      |> Array.mapi((idx, row) => {
           <div
             key={row.title}
             className={SectionStyles.rowContainer(
               ~reverse={
                 idx mod 2 != 0;
               },
               (),
             )}>
             <div className=SectionStyles.textContainer>
               <div
                 className={Styles.seperator("0" ++ string_of_int(idx + 1))}
               />
               <h2 className=SectionStyles.title>
                 {React.string(row.title)}
               </h2>
               <p className=SectionStyles.paragraphText>
                 {React.string(row.description)}
               </p>
               <Next.Link href={row.linkUrl}>
                 <span className=Styles.linkText>
                   <span> {React.string(row.linkCopy)} </span>
                   <span className=SectionStyles.icon>
                     <Icon kind=Icon.ArrowRightMedium />
                   </span>
                 </span>
               </Next.Link>
             </div>
             <img src={row.image} className=SectionStyles.image />
           </div>
         })
      |> React.array;
    };
  };

  type t =
    | SimpleRow(array(SimpleRow.t))
    | FeaturedRow(array(FeaturedRow.t));
};

[@react.component]
let make = (~backgroundImg, ~sections: Section.t) => {
  <div className={Styles.sectionBackgroundImage(backgroundImg)}>
    <Wrapped>
      {switch (sections) {
       | Section.FeaturedRow(rows) => <Section.FeaturedRow rows />
       | Section.SimpleRow(rows) => <Section.SimpleRow rows />
       }}
    </Wrapped>
  </div>;
};
