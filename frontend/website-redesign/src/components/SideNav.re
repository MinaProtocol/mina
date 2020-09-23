module Styles = {
  open Css;
  let sideNav =
    style([
      unsafe("counter-reset", "orderedList"),
      minWidth(rem(15.)),
      listStyleType(`none),
      firstChild([marginLeft(`zero)]),
      padding(`zero),
      media(
        Theme.MediaQuery.tablet,
        [
          marginRight(rem(2.)),
          marginTop(`zero),
          position(`sticky),
          top(rem(2.5)),
        ],
      ),
    ]);

  let cell =
    style([
      minHeight(`rem(2.75)),
      width(`rem(12.)),
      display(`flex),
      justifyContent(`spaceBetween),
      alignItems(`center),
      borderLeft(`px(1), `solid, Theme.Colors.digitalBlackA(0.25)),
      color(Theme.Colors.digitalBlack),
      textDecoration(`none),
    ]);

  let currentCell =
    merge([
      cell,
      style([
        unsafe(
          "background",
          "url(/static/img/MinaSepctrumSecondary.png), linear-gradient(0deg, #2D2D2D, #2D2D2D), #FFFFFF",
        ),
      ]),
    ]);

  let li = style([] /* Inentionally blank, for now */);

  let topLi = isCurrentItem =>
    merge([
      li,
      style([
        display(`flex),
        alignItems(`center),
        before(
          [
            color(Theme.Colors.digitalBlackA(isCurrentItem ? 1. : 0.25)),
            width(`rem(2.)),
            unsafe("counter-increment", "orderedList"),
            unsafe("content", "counter(orderedList, decimal-leading-zero)"),
          ]
          @ Theme.Type.metadata_,
        ),
      ]),
    ]);

  let item =
    merge([
      Theme.Type.sidebarLink,
      style([
        padding2(~v=`rem(0.6), ~h=`zero),
        display(`inlineBlock),
        marginLeft(`rem(1.)),
        minHeight(`rem(1.5)),
      ]),
    ]);

  let currentItem =
    merge([item, style([position(`relative), color(Theme.Colors.white)])]);

  let break = style([flexBasis(`percent(100.)), height(`zero)]);

  let childItem = style([marginLeft(`rem(1.)), listStyleType(`none)]);
  let flip = style([transform(rotate(`deg(90.)))]);

  let chevronWrap = style([height(`rem(1.)), marginRight(`rem(1.))]);
};

module CurrentSlugProvider = {
  let (context, make, makeProps) = ReactExt.createContext("");
};

module SectionSlugProvider = {
  let (context, make, makeProps) = ReactExt.createContext(None);
};

let slugConcat = (n1, n2) => {
  String.length(n2) > 0 ? n1 ++ "/" ++ n2 : n1;
};

module Item = {
  [@react.component]
  let make = (~title, ~slug) => {
    let currentSlug = React.useContext(CurrentSlugProvider.context);
    let folderSlug = React.useContext(SectionSlugProvider.context);
    let (fullSlug, placement) =
      switch (folderSlug) {
      | Some(fs) => (slugConcat(fs, slug), `Inner)
      | None => (slug, `Top)
      };
    let isCurrentItem = currentSlug == fullSlug;
    Js.log4("currentSlug", currentSlug, "fullSlug", fullSlug);
    let href = fullSlug;
    <li
      className={
        switch (placement) {
        | `Inner => Styles.li
        | `Top => Styles.topLi(isCurrentItem)
        }
      }>
      <Next.Link href>
        <a
          className={Css.merge([
            isCurrentItem ? Styles.currentCell : Styles.cell,
          ])}>
          <span
            className={Css.merge([
              isCurrentItem ? Styles.currentItem : Styles.item,
            ])}>
            {React.string(title)}
          </span>
        </a>
      </Next.Link>
    </li>;
  };
};

module Section = {
  [@react.component]
  let make = (~title, ~slug, ~children) => {
    let currentSlug = React.useContext(CurrentSlugProvider.context);
    let hasCurrentSlug = ref(false);

    // Check if the children's props contain the current slug
    ReactExt.Children.forEach(children, (. child) => {
      switch (ReactExt.props(child)##slug) {
      | Some(childSlug) when slugConcat(slug, childSlug) == currentSlug =>
        hasCurrentSlug := true
      | _ => ()
      }
    });

    let (expanded, setExpanded) = React.useState(() => hasCurrentSlug^);

    let toggleExpanded =
      React.useCallback(e => {
        ReactEvent.Mouse.preventDefault(e);
        setExpanded(expanded => !expanded);
      });

    <li key=title className={Styles.topLi(false)}>
      <a
        href="#"
        onClick=toggleExpanded
        ariaExpanded=expanded
        className=Styles.cell>
        <span className=Styles.item> {React.string(title)} </span>
        <div className=Styles.chevronWrap>
          <img
            src="/static/img/ChevronRight.svg"
            width="16"
            height="16"
            className={expanded ? Styles.flip : ""}
          />
        </div>
      </a>
      {!expanded
         ? React.null
         : <SectionSlugProvider value={Some(slug)}>
             <div className=Styles.break>
               <ul className=Styles.childItem> children </ul>
             </div>
           </SectionSlugProvider>}
    </li>;
  };
};

[@react.component]
let make = (~currentSlug, ~className="", ~children) => {
  <aside className>
    <CurrentSlugProvider value=currentSlug>
      <ol role="list" className=Styles.sideNav> children </ol>
    </CurrentSlugProvider>
  </aside>;
};
