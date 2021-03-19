const puppeteer = require("puppeteer");
const { LOGIN_CA, LOGIN_COM, COM_DOMAIN, CA_DOMAIN } = require("../constants");

let scrape = ({ email, password, mainWindow, domain }) => {
  return new Promise(async (resolve, reject) => {
    let browser;
    try {
      browser = await puppeteer.launch();
      let creditScore;
      if (domain === COM_DOMAIN) {
        mainWindow.webContents.send(LOGIN_COM);
        creditScore = await scrapeSpecifiedDomain({
          email,
          password,
          browser,
          url: COM_DOMAIN,
        });
      } else if (domain === CA_DOMAIN) {
        mainWindow.webContents.send(LOGIN_CA);
        creditScore = await scrapeSpecifiedDomain({
          email,
          password,
          browser,
          url: CA_DOMAIN,
        });
      }
      resolve(creditScore);
    } catch (err) {
      reject(err);
    } finally {
      await browser.close();
    }
  });
};

let scrapeSpecifiedDomain = ({ email, password, browser, url }) => {
  return new Promise(async (resolve, reject) => {
    let page;
    try {
      page = await browser.newPage();
      await page.goto(url, {
        waitUntil: "domcontentloaded",
      });

      await page.waitForSelector("[type=submit]");
      await page.type("[type=email]", email);
      await page.type("[type=password]", password);
      await page.waitForTimeout(750);
      await page.click("[type=submit]");

      await page.waitForSelector(".score-dial", { timeout: 20000 });
      const creditScore = await page.evaluate(() => {
        const creditContainer = document.querySelector(".score-dial");
        // Return credit score value
        for (let i = 0; i < creditContainer.children.length; i++) {
          const child = creditContainer.children[i];
          if (child.textContent > 0 && child.textContent < 850) {
            return child.textContent;
          }
        }
        return 0;
      });
      return resolve(creditScore);
    } catch (err) {
      return reject(err);
    } finally {
      await page.close();
    }
  });
};

exports.scrape = scrape;
