// Removes .html from a slug for backwards compatibility
let stripHTMLSuffix = s =>
  switch (String.split_on_char('.', s)) {
  | [] => ""
  | [slug, "html"] => slug
  | [slug, ..._] => slug
  };

module System = {
  type contentType = {id: string};
  type contentTypeSys = {sys: contentType};

  type sys = {
    id: string,
    contentType: contentTypeSys,
    createdAt: string,
    updatedAt: string,
  };

  type entry('a) = {
    sys,
    fields: 'a,
  };
  type entries('a) = {items: array(entry('a))};
};

module BlogPost = {
  let id = "test";
  type t = {
    title: string,
    snippet: string,
    slug: string,
    subtitle: Js.Undefined.t(string),
    author: string,
    authorWebsite: Js.Undefined.t(string),
    date: string,
    text: string,
  };
  type entry = System.entry(t);
  type entries = System.entries(t);
};

module JobPost = {
  let id = "jobPost";
  type t = {
    title: string,
    jobDescription: string,
    slug: string,
  };
  type entry = System.entry(t);
  type entries = System.entries(t);
};

module KnowledgeBase = {
  let id = "knowledgeBase";
  type link = {
    title: string,
    url: string,
  };
  type links = {
    articles: array(link),
    videos: array(link),
  };
  type t = {links};
  type entry = System.entry(t);
  type entries = System.entries(t);
};

module Image = {
  type file = {url: string};
  type t = {file};

  type entry = System.entry(t);
  type entries = System.entries(t);
};

module GenesisProfile = {
  let id = "genesisProfile";
  type t = {
    name: string,
    profilePhoto: Image.entry,
    quote: string,
    memberLocation: string,
    twitter: string,
    github: option(string),
    publishDate: string,
    blogPost: BlogPost.entry,
  };
  type entry = System.entry(t);
  type entries = System.entries(t);
};

module Press = {
  let id = "press";
  type t = {
    title: string,
    image: Image.entry,
    link: string,
    featured: bool,
    description: option(string),
    publisher: string,
    datePublished: string,
  };
  type entry = System.entry(t);
  type entries = System.entries(t);
};
