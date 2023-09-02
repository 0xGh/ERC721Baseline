const ERC721Baseline = artifacts.require("ERC721Baseline");
const ERC721ProxyMock = artifacts.require("ERC721ProxyMock");

const {
  expectRevert: expectRevertMessage,
  expectEvent,
  constants: { ZERO_ADDRESS },
} = require("@openzeppelin/test-helpers");

contract(
  "ERC721Baseline",
  function ([
    deployer,
    implementationDeployer,
    user,
    attacker,
    operator,
    ...accounts
  ]) {
    let implementation;

    // proxy to implementation
    let proxy;
    // proxyDelegate is the ERC721Baseline.at(proxy.address)
    // this allows to call methods that are delegated to ERC721Baseline
    let proxyDelegate;

    // Assume that ERC721Baseline (the implementation) is deployed once.
    before(async () => {
      implementation = await ERC721Baseline.new({
        from: implementationDeployer,
      });
    });

    beforeEach(async () => {
      proxy = await ERC721ProxyMock.new(implementation.address, "Test", "TEST");
      proxyDelegate = await ERC721Baseline.at(proxy.address);
    });

    describe("implementation", () => {
      it("attacker and implementation owner cannot call initialize", async () => {
        await expectRevert(
          implementation.initialize("Malicious", "M", {
            from: attacker,
          }),
          "AlreadyInitialized",
        );

        await expectRevert(
          implementation.initialize("Malicious", "M", {
            from: implementationDeployer,
          }),
          "AlreadyInitialized",
        );
      });

      it("attacker and implementation owner cannot call onlyProxy method", async () => {
        await expectRevert(
          implementation.__mint(attacker, 1, {
            from: attacker,
          }),
          "OnlyProxy",
        );

        await expectRevert(
          proxyDelegate.__mint(attacker, 1, {
            from: attacker,
          }),
          "OnlyProxy",
        );

        await expectRevert(
          proxyDelegate.__mint(attacker, 1, {
            from: deployer,
          }),
          "OnlyProxy",
        );

        await expectRevert(
          implementation.__mint(attacker, 1, {
            from: implementationDeployer,
          }),
          "OnlyProxy",
        );
      });
    });

    describe("Proxy", () => {
      it("onlyProxy method works", async () => {
        // mint is a method that uses the internal onlyProxy __mint method.
        await proxy.mint(user);

        // successfully minted
        assert.equal(1, await proxy.totalSupply());
        assert.equal(1, await proxyDelegate.balanceOf(user));

        // this operation didn't affect the implementation
        assert.equal(0, await implementation.balanceOf(user));
      });

      describe("admin", () => {
        it("requireAdmin check works", async () => {
          // Admin check works.
          await expectRevert(
            proxy.mint(user, { from: attacker }),
            "Unauthorized",
          );
        });

        it("admin can add admins", async () => {
          const anotherAdmin = accounts[0];

          await expectRevert(
            proxyDelegate.setAdmin(attacker, true, { from: attacker }),
            "Unauthorized",
          );

          const receipt = await proxyDelegate.setAdmin(anotherAdmin, true);

          assert.equal(true, await proxyDelegate.isAdmin(anotherAdmin));

          await expectEvent(receipt, "AdminSet", {
            addr: anotherAdmin,
            add: true,
          });
        });

        it("admin can remove admins", async () => {
          const anotherAdmin = accounts[0];
          await proxyDelegate.setAdmin(anotherAdmin, true);

          assert.equal(true, await proxyDelegate.isAdmin(anotherAdmin));

          const receipt = await proxyDelegate.setAdmin(anotherAdmin, false);
          assert.equal(false, await proxyDelegate.isAdmin(anotherAdmin));

          await expectEvent(receipt, "AdminSet", {
            addr: anotherAdmin,
            add: false,
          });
        });

        it("can transfer ownership", async () => {
          const anotherOwner = accounts[0];

          await expectRevert(
            proxyDelegate.transferOwnership(attacker, { from: attacker }),
            "Unauthorized",
          );

          const receipt = await proxyDelegate.transferOwnership(anotherOwner);

          await expectEvent(receipt, "OwnershipTransferred", {
            previousOwner: deployer,
            newOwner: anotherOwner,
          });
          assert.equal(anotherOwner, await proxyDelegate.owner());
        });
      });

      it("can register a _beforeTokenTransfer hook", async () => {
        const tokenId = 1;
        await proxy.mint(user);

        await expectRevert(
          proxy.toggleBeforeTokenTransferHook({ from: attacker }),
          "Unauthorized",
        );

        await proxy.toggleBeforeTokenTransferHook();
        await proxyDelegate.approve(operator, tokenId, { from: user });

        await expectRevertMessage(
          proxyDelegate.transferFrom(user, operator, tokenId, {
            from: operator,
          }),
          "Call to self",
        );

        const anotherUser = accounts[0];
        await proxyDelegate.transferFrom(user, anotherUser, tokenId, {
          from: operator,
        });

        assert.equal(anotherUser, await proxyDelegate.ownerOf(tokenId));

        await expectRevertMessage(
          proxyDelegate.approve(operator, tokenId, { from: user }),
          "owner",
        );

        await proxyDelegate.approve(operator, tokenId, { from: anotherUser });

        await expectRevertMessage(
          proxyDelegate.transferFrom(anotherUser, operator, tokenId, {
            from: operator,
          }),
          "Call to self",
        );

        await proxy.toggleBeforeTokenTransferHook();

        await proxyDelegate.transferFrom(anotherUser, operator, tokenId, {
          from: operator,
        });

        assert.equal(operator, await proxyDelegate.ownerOf(tokenId));
      });
    });
  },
);

async function expectRevert(promise, reason) {
  try {
    await promise;
    expect.fail("Expected promise to throw but it didn't");
  } catch (revert) {
    if (reason) {
      const reasonId = web3.utils.keccak256(reason + "()").substr(0, 10);
      expect(
        JSON.stringify(revert),
        `Expected custom error ${reason} (${reasonId})`,
      ).to.include(reasonId);
    }
  }
}
