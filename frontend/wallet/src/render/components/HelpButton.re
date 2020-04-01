[@react.component]
let make =
    (
      ~label,
      ~onClick=?,
      ~style=Button.HyperlinkBlue,
      ~disabled=false,
      ~width=10.5,
      ~height=3.,
      ~padding=1.,
      ~icon=?,
      ~type_="button",
      ~onMouseEnter=?,
      ~onMouseLeave=?,
      ~link=?,
    ) =>
  <button
    disabled
    ?onClick
    ?onMouseEnter
    ?onMouseLeave
    className={Css.merge([
      disabled ? Button.Styles.Button.disabled : "",
      Css.style([
        Css.minWidth(`rem(width)),
        Css.height(`rem(height)),
        Css.padding2(~v=`zero, ~h=`rem(padding)),
        Css.paddingLeft(`rem(0.1)),
        Css.paddingTop(`px(1)),
      ]),
      Button.Styles.Button.styles(style),
    ])}
    type_>
    {switch (link, icon) {
     | (Some(link), Some(icon)) =>
       <>
         <HelpIcon kind=icon />
         <a href=link className=Button.Styles.Button.link target="_blank">
           {React.string(label)}
         </a>
       </>
     | (None, None) => React.string(label)
     | (None, Some(icon)) =>
       <>
         <HelpIcon kind=icon />
         <Spacer width=0.1375 />
         <span className={Css.style([Css.fontSize(`px(13))])}>
           {React.string(label)}
         </span>
       </>
     | (Some(link), None) =>
       <a href=link target="_blank"> {React.string(label)} </a>
     }}
  </button>;
