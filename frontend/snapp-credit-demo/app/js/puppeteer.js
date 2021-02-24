const puppeteer = require("puppeteer");

let scrape = (username, password) => {
  return new Promise(async (resolve, reject) => {
    const browser = await puppeteer.launch();
    try {
      const page = await browser.newPage();
      // TODO: Targeting .ca, should be changed and verified to work on .com
      await page.goto("https://www.creditkarma.ca/login", {
        waitUntil: "domcontentloaded",
      });

      await page.waitForSelector("[type=submit]");
      await page.type("[type=email]", username);
      await page.type("[type=password]", password);
      await page.waitForTimeout(500);
      await page.click("[type=submit]");

      await page.waitForSelector(".score-dial", { timeout: 8000 });
      let creditScore = await page.evaluate(() => {
        let creditContainer = document.querySelectorAll(".score-dial");
        // Return credit score value
        return creditContainer[0]?.children[3].textContent;
      });
      browser.close();
      return resolve(creditScore);
    } catch (err) {
      if (browser) browser.close();
      return reject(err);
    }
  });
};

exports.scrape = scrape;
