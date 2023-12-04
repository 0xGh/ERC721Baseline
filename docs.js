const solcOutput = require("./build/contracts/ERC721Baseline.json");
const { docgen } = require("solidity-docgen");

async function run() {
  // @todo this won't work because Truffle's output isa subset of solc's
  await docgen([{ output: solcOutput }], {
    outputDir: "build/docs",
  });
}

run();
