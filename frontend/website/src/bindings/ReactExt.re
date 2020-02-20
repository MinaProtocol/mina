[@bs.get]
external props: React.element => {.. "children": React.element} = "props";

module Children = {
  [@bs.val] [@bs.module "react"] [@bs.scope "Children"]
  external only: React.element => React.element = "only";

  [@bs.val] [@bs.module "react"] [@bs.scope "Children"]
  external forEach: (React.element, (. React.element) => 'a) => unit =
    "forEach";

  [@bs.val] [@bs.module "react"] [@bs.scope "Children"]
  external toArray: React.element => array(React.element) = "toArray";
};
