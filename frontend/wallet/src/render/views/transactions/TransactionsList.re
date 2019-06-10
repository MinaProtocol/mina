open Tc;

module Styles = {
  open Css;

  let row =
    style([
      display(`grid),
      gridTemplateColumns([`rem(16.), `fr(1.), `px(200)]),
      gridGap(Theme.Spacing.defaultSpacing),
      alignItems(`flexStart),
      padding2(~h=`rem(1.), ~v=`zero),
      borderBottom(`px(1), `solid, Theme.Colors.savilleAlpha(0.1)),
      borderTop(`px(1), `solid, white),
      lastChild([borderBottom(`px(0), `solid, white)]),
    ]);

  let sectionHeader =
    style([
      padding2(~v=`rem(0.25), ~h=`rem(1.)),
      textTransform(`uppercase),
      alignItems(`center),
      color(Theme.Colors.slateAlpha(0.7)),
      backgroundColor(Theme.Colors.midnightAlpha(0.06)),
      marginTop(`rem(1.5)),
    ]);

  let body =
    style([
      width(`percent(100.)),
      overflow(`auto),
      maxHeight(`calc((`sub, `percent(100.), `rem(2.)))),
    ]);
};

[@react.component]
let make = (~transactions, ~pending, ~onLoadMore: unit => Js.Promise.t('a)) => {
  let (isFetchingMore, setFetchingMore) = React.useState(() => false);

  <div className=Styles.body>
    {Array.mapi(
       ~f=
         (i, transaction) =>
           <div className=Styles.row key={string_of_int(i)}>
             <TransactionCell transaction pending=true />
           </div>,
       pending,
     )
     |> React.array}
    {Array.mapi(
       ~f=
         (i, transaction) =>
           <div className=Styles.row key={string_of_int(i)}>
             <TransactionCell transaction />
           </div>,
       transactions,
     )
     |> React.array}
    {!isFetchingMore
       ? <Waypoint
           onEnter={_ => {
             setFetchingMore(_ => true);
             let _ =
               onLoadMore()
               |> Js.Promise.then_(() => {
                    setFetchingMore(_ => false);
                    Js.Promise.resolve();
                  });
             ();
           }}
           topOffset="100px"
         />
       : <div className=Css.(style([margin2(~v=`rem(1.5), ~h=`auto)]))>
           <Loader />
         </div>}
  </div>;
};
