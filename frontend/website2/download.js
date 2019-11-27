const fs = require('fs').promises;
const path = require('path');
const { promisify } = require('util');

const rimraf = promisify(require('rimraf'));
const { createClient } = require('contentful');

const SPACE = process.env.CONTENTFUL_SPACE;
const TOKEN = process.env.CONTENTFUL_TOKEN;

const client = createClient({
  space: SPACE,
  accessToken: TOKEN
});

const downloadEntries = async (dataFolder) => {
  console.log('> Removing old data');
  await rimraf(dataFolder);
  // console.log('> Removing post pages');
  // await rimraf("pages/blog");

  console.log('> Starting download to', dataFolder);
  await fs.mkdir(dataFolder, { recursive: true });

  let contentTypeResponse = await client.getContentTypes();
  let contentTypes = contentTypeResponse.items.map(o => [o.name, o.sys.id]);
  await Promise.all(contentTypes.map(async ([name, id]) => {
    console.log('> Getting', name + 's');
    let contentResponse = await client.getEntries({
      include: 0,
      content_type: id,
    });
    let content  = contentResponse.items.map(o => ({
      // contentfulID: o.sys.id,
      // contentfulCreatedAt: o.sys.createdAt,
      // contentfulUpdatedAt: o.sys.updatedAt,
      ...o.fields,
    }));
    let filePath = path.join(dataFolder, name + ".json");
    console.log('> Creating', filePath);
    await fs.writeFile(filePath, JSON.stringify(content, null, 2));
  }));
};

downloadEntries('contentfulData');
