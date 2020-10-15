module Styles = {
  open Css;

  let resourceGrid =
    style([
      display(`grid),
      gridGap(`rem(1.)),
      gridTemplateColumns([`fr(1.), `fr(1.)]),
      media(
        Theme.MediaQuery.tablet,
        [gridTemplateColumns([`fr(1.), `fr(1.), `fr(1.)])],
      ),
    ]);

  let resource =
    style([width(`auto), selector("img", [width(`percent(100.))])]);
};

module Resource = {
  type t = ContentType.KnowledgeBaseResource.t;

  [@react.component]
  let make = (~resource: t) =>
    <a
      href={resource.url}
      className=Css.(style([textDecoration(`none)]))
      target="_blank">
      <div className=Styles.resource>
        <img src={resource.image.fields.file.url} />
        <Spacer height=1. />
        <span className=Theme.Type.h4> {React.string(resource.title)} </span>
        <Spacer height=0.5 />
        <Link href={resource.url} />
      </div>
    </a>;
};

module Category = {
  type t = {
    title: string,
    resources: array(ContentType.KnowledgeBaseResource.t),
  };

  [@react.component]
  let make = (~category) => {
    <div>
      <hr />
      <Spacer height=1. />
      <h3 className=Theme.Type.h3> {React.string(category.title)} </h3>
      <Spacer height=2. />
      <div className=Styles.resourceGrid>
        {Array.map(resource => <Resource resource />, category.resources)
         |> React.array}
      </div>
    </div>;
  };
};

let fetchResource = id => {
  Contentful.getEntry(Lazy.force(Contentful.client), id, {"include": 1})
  |> Promise.map((result: ContentType.KnowledgeBaseResource.entry) => {
       result.fields
     });
};

let fetchCategories = () => {
  ContentType.(
    Contentful.getEntries(
      Lazy.force(Contentful.client),
      {"include": 0, "content_type": KnowledgeBaseCategory.id},
    )
    |> Js.Promise.then_((entries: KnowledgeBaseCategory.entries) => {
         Array.map(
           // For each category fetch the corresponding resources, feat. some Promise hacks
           (e: KnowledgeBaseCategory.entry) => {
             (
               Js.Promise.resolve(e.fields.title),
               Js.Promise.all(
                 e.fields.resources
                 |> Array.map((link: KnowledgeBaseResource.entry) =>
                      fetchResource(link.sys.id)
                    ),
               ),
             )
             |> Js.Promise.all2
             |> Promise.map(((title, resources)) => {
                  {Category.title, resources}
                })
           },
           entries.items,
         )
         |> Js.Promise.all
       })
  );
};

[@react.component]
let make = () => {
  let (categories, setCategories) = React.useState(() => [||]);

  let _ =
    React.useEffect0(() => {
      fetchCategories()
      |> Promise.map(result => setCategories(_ => result))
      |> ignore;

      None;
    });

  <div>
    <h2 className=Theme.Type.h2> {React.string("Knowledge Base")} </h2>
    <Spacer height=1. />
    <p className=Theme.Type.sectionSubhead>
      {React.string(
         {j|
           Here, we’ve organized our favorite go-to resources so you can explore more about how Mina works.
         |j},
       )}
    </p>
    <Spacer height=4. />
    {Array.map(category => {<Category category />}, categories) |> React.array}
  </div>;
};
