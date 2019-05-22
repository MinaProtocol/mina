### How to build the website

First get the code:
1. Clone the repo via SSH: `git clone git@github.com:CodaProtocol/coda.git`
2. Navigate into `coda/frontend/wallet`
3. Run `yarn` to install dependencies (alternatively `npm install`)

To develop:

4. Run `yarn dev` to build (with a watcher) and start a server (alternatively `npm run dev`)
5. Open `localhost:8000` in your browser to see the site. You can edit files in `src` and save to see changes.

## To create a new blog post
1. Follow the build instructions above
2. Create a new markdown file in `coda/frontend/wallet/posts`. You can use the other files in that folder as an example. It should start with something like this:

```
---
title: My blog post
subtitle: This is what my blog post is about (optional)
date: 2019-01-01
author: My Name
author_website: https://twitter.com/my_twitter_username (optional)
---
```

3. Leave `yarn dev` running as you edit and save your post to make `localhost:8000` reload.
