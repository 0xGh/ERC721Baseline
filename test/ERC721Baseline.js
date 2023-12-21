const ERC721Baseline = artifacts.require("ERC721BaselineImplementation");
const ERC721ProxyMock = artifacts.require("ERC721ProxyMock");
const ERC721ConstructorAttackerMock = artifacts.require(
  "ERC721ConstructorAttackerMock",
);

/**
 * ERC721Baseline tests
 * –––––––––––––––––––––
 *
 * # Overview
 *
 * This file contains tests for the ERC721Baseline.sol contract
 * which is instantiated once and available via the `implementation` variable.
 *
 * A `proxy` contract to this implementation is instantiated for each test,
 * and since the instance won't have the ABI to call delegated methods to ERC721Baseline,
 * you get another `proxyDelegate` variable that is `ERC721Baseline.at(proxy.address)`.
 *
 * You can use `proxyDelegate` to call methods implemented in ERC721Baseline
 * but not in the proxy (for example standard ERC721 methods).
 *
 * When necessary a test or a group of them (a describe block) include comments to
 * facilitate the review and understanding of what is being tested and how.
 */

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
    // ERC721Baseline.
    let implementation;

    // proxy to ERC721Baseline - this is what a dev would deploy.
    let proxy;
    // proxyDelegate is the ERC721Baseline.at(proxy.address)
    // this allows to call methods that are delegated to ERC721Baseline.
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
      it("initialization: attacker and implementation owner cannot call initialize", async () => {
        await expectRevert(
          implementation.initialize("Malicious", "M", {
            from: attacker,
          }),
          "Unauthorized",
        );

        await expectRevert(
          implementation.initialize("Malicious", "M", {
            from: implementationDeployer,
          }),
          "Unauthorized",
        );

        await expectRevert(
          ERC721ConstructorAttackerMock.new(implementation.address, {
            from: attacker,
          }),
          "Unauthorized",
        );
      });

      it("onlyProxy: attacker and implementation owner cannot call onlyProxy method", async () => {
        await expectRevert(
          implementation.__mint(attacker, 1, {
            from: attacker,
          }),
          "NotProxy",
        );

        await expectRevert(
          proxyDelegate.__mint(attacker, 1, {
            from: attacker,
          }),
          "NotProxy",
        );

        await expectRevert(
          proxyDelegate.__mint(attacker, 1, {
            from: deployer,
          }),
          "NotProxy",
        );

        await expectRevert(
          implementation.__mint(attacker, 1, {
            from: implementationDeployer,
          }),
          "NotProxy",
        );
      });

      getOnlyProxyMethods().forEach(([method, ...args]) => {
        it(`${method} is not callable`, async () => {
          await expectRevert(proxyDelegate[method](...args), "NotProxy");
        });
      });

      it("is not affected by state changes and multiple proxies", async () => {
        assert.equal(
          false,
          await implementation.isAdmin(await proxyDelegate.owner()),
        );

        // Deploy another proxy
        const deployer2 = accounts[0];
        const proxy2 = await ERC721ProxyMock.new(
          implementation.address,
          "Test",
          "TEST",
          { from: deployer2 },
        );
        const proxy2Delegate = await ERC721Baseline.at(proxy2.address);

        // implementation is not affected
        assert.equal(
          false,
          await implementation.isAdmin(await proxy2Delegate.owner()),
        );

        // other proxies are not affected
        assert.equal(false, await proxyDelegate.isAdmin(deployer2));
        assert.equal(false, await proxy2Delegate.isAdmin(deployer));
      });
    });

    describe("Proxy", () => {
      describe("onlyProxy methods", async () => {
        it("onlyProxy method works", async () => {
          // adminMint is a method that uses the ERC721Baseline __mint method
          // which is available only to proxy contracts.
          await proxy.adminMint(user, 1);

          // successfully minted
          assert.equal(1, await proxyDelegate.totalSupply());
          assert.equal(1, await proxyDelegate.balanceOf(user));

          // this operation didn't affect the implementation
          assert.equal(0, await implementation.balanceOf(user));
        });

        getOnlyProxyMethods().forEach(([method, ...args]) => {
          it(`${method} is callable`, async () => {
            // The Proxy mock contract used in these tests
            // has a matching method for `method` which is prefixed with onlyProxy_
            // We call this here and make sure it doesn't revert with a NotProxy error.
            assert.equal(
              true,
              await proxy[
                /*onlyProxy_methodName*/ `onlyProxy${method.slice(1)}`
              ](...args)
                .then(() => true)
                // Some methods (eg. burn) might require existing state therefore they will revert.
                // That's fine. In this test we just want to check that they don't revert with NotProxy.
                .catch((revert) => {
                  const reasonId = web3.utils
                    .keccak256("NotProxy()")
                    .substr(0, 10);
                  return revert.data.result.includes(reasonId) === false;
                }),
            );
          });
        });
      });

      describe("admin", () => {
        it("requireAdmin check works", async () => {
          // adminMint uses the ERC721Baseline requireAdmin test to only allow admins.
          await expectRevert(
            proxy.adminMint(user, 1, { from: attacker }),
            "Unauthorized",
          );
        });

        it("admin can add admins", async () => {
          const anotherAdmin = accounts[0];

          // Non-admins can't add a new admin.
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

          // Non-admins can't transfer ownership.
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

      describe("_beforeTokenTransfer", () => {
        it("can register a _beforeTokenTransfer hook", async () => {
          const tokenId = 1;

          assert.equal(
            false,
            await proxy._beforeTokenTransferHookEnabledProxy(),
          );

          await proxy.adminMint(user, tokenId);

          // Make sure that an attacker can't enable the hook.
          await expectRevert(
            proxy.toggleBeforeTokenTransferHook({ from: attacker }),
            "Unauthorized",
          );

          assert.equal(
            false,
            await proxy._beforeTokenTransferHookEnabledProxy(),
          );

          // Enable hook.
          await proxy.toggleBeforeTokenTransferHook();

          assert.equal(
            true,
            await proxy._beforeTokenTransferHookEnabledProxy(),
          );

          // Token owner approves an operator (eg. marketplace) to manage the token.
          await proxyDelegate.approve(operator, tokenId, { from: user });

          // operator transfers the token to anotherUser.
          const anotherUser = accounts[0];
          const receipt = await proxyDelegate.transferFrom(
            user,
            anotherUser,
            tokenId,
            {
              from: operator,
            },
          );

          assert.equal(anotherUser, await proxyDelegate.ownerOf(tokenId));

          // The proxy mock contract emits BeforeTokenTransferCalled when _beforeTokenTransfer is enabled.
          await expectEvent.inTransaction(
            receipt.tx,
            proxy,
            "BeforeTokenTransferCalled",
          );

          // user cannot approve anymore because they are not the token owner.
          await expectRevert(
            proxyDelegate.approve(operator, tokenId, { from: user }),
            `ERC721InvalidApprover(address)`,
          );

          // anotherUser can approve operator.
          await proxyDelegate.approve(operator, tokenId, { from: anotherUser });

          // The Proxy mock contract used in these tests has a check
          // in _beforeTokenTransfer which compares the msg.sender (from: below)
          // with recipient (to or operator below).
          // When those match it reverts with "Call to self".
          //
          // The purpose of this check and test is to make sure that `from:` below
          // (the msg.sender) is passed correctly to _beforeTokenTransfer (between implementation and proxy).
          await expectRevertMessage(
            proxyDelegate.transferFrom(anotherUser, operator, tokenId, {
              from: operator,
            }),
            "Call to self",
          );

          // Disable _beforeTokenTransfer hook so that it doesn't revert with "Call to self"
          // and make sure that the transferFrom call completes successfully.
          await proxy.toggleBeforeTokenTransferHook();

          await proxyDelegate.transferFrom(anotherUser, operator, tokenId, {
            from: operator,
          });

          // All good the token has been transferred.
          assert.equal(operator, await proxyDelegate.ownerOf(tokenId));
        });

        it("tx sender (first arg) is set correctly", async () => {
          const tokenId = 1;
          await proxy.adminMint(user, tokenId);

          // Make sure that an attacker can't enable the hook.
          await expectRevert(
            proxy.toggleBeforeTokenTransferHook({ from: attacker }),
            "Unauthorized",
          );

          // Enable hook
          await proxy.toggleBeforeTokenTransferHook();
          await proxyDelegate.approve(operator, tokenId, { from: user });

          const sender = operator;
          const to = operator;
          // The contract reverts when sender == to
          // When that's the case it means that msg.sender has been forwarded
          // to _beforeTokenTransfer correctly
          await expectRevertMessage(
            proxyDelegate.transferFrom(user, to, tokenId, {
              from: sender,
            }),
            "Call to self",
          );
        });

        it("can alter proxy state without affecting the implementation state", async () => {
          await proxy.toggleBeforeTokenTransferHook();

          const tokenId = 1;
          await proxy.adminMint(user, tokenId);

          const anotherUser = accounts[0];
          const receipt = await proxyDelegate.transferFrom(
            user,
            anotherUser,
            tokenId,
            { from: user },
          );

          await expectEvent.inTransaction(
            receipt.tx,
            proxy,
            "BeforeTokenTransferCalled",
          );

          assert.equal("altered", await proxy.__baseURI());
          assert.equal("", await implementation.__baseURI());
        });

        it("_update override does not interfere with __update onlyProxy method", async () => {
          await proxy.toggleBeforeTokenTransferHook();

          const tokenId = 1;
          await proxy.adminMint(user, tokenId);

          const anotherUser = accounts[0];

          const receipt = await proxy.onlyProxy_update(
            anotherUser,
            tokenId,
            ZERO_ADDRESS,
          );

          await expectEvent.notEmitted.inTransaction(
            receipt.tx,
            proxy,
            "BeforeTokenTransferCalled",
          );
        });
      });

      describe("Metadata", () => {
        it("sets name and symbols", async () => {
          assert.equal("Test", await proxyDelegate.name());
          assert.equal("TEST", await proxyDelegate.symbol());
        });

        it("updates totalSupply correctly", async () => {
          await proxy.onlyProxy_mint(user, 3);
          assert.equal(1, await proxyDelegate.totalSupply());
          await proxy.onlyProxy_burn(3, { from: user });
          assert.equal(0, await proxyDelegate.totalSupply());
        });

        describe("token URI", () => {
          const tokenId = 3;

          beforeEach(async () => {
            await proxy.onlyProxy_mint(user, tokenId);
          });

          it("throws if the token does not exist", async () => {
            await expectRevert(
              proxyDelegate.tokenURI(100),
              "ERC721NonexistentToken(uint256)",
            );
          });

          it("returns empty string when nothing is set", async () => {
            assert.equal("", await proxyDelegate.tokenURI(tokenId));
          });

          it("returns token-specific URI when set", async () => {
            const anotherTokenId = tokenId + 1;
            const uri = "ipfs://test";

            await proxy.onlyProxy_mint(user, anotherTokenId, uri);

            assert.equal(uri, await proxyDelegate.tokenURI(anotherTokenId));
            assert.equal(uri, await proxyDelegate.__tokenURI(anotherTokenId));

            assert.equal("", await proxyDelegate.tokenURI(tokenId));
          });

          it("can update token-specific URI and emits MetadataUpdate", async () => {
            const uri = "ipfs://updated";
            const receipt = await proxy.onlyProxy_setTokenURI(tokenId, uri);

            await expectEvent.inTransaction(
              receipt.tx,
              proxyDelegate,
              "MetadataUpdate",
              {
                _tokenId: String(tokenId),
              },
            );

            assert.equal(uri, await proxyDelegate.tokenURI(tokenId));
            assert.equal(uri, await proxyDelegate.__tokenURI(tokenId));
          });

          it("can define shared URI", async () => {
            const uri = "ipfs://shared";

            const anotherTokenId = tokenId + 1;
            await proxy.onlyProxy_mint(user, anotherTokenId);

            await proxy.onlyProxy_setSharedURI(uri);

            assert.equal(uri, await proxyDelegate.tokenURI(anotherTokenId));
            assert.equal(
              await proxyDelegate.tokenURI(tokenId),
              await proxyDelegate.tokenURI(anotherTokenId),
            );
          });

          it("can set base URI", async () => {
            const uri = "ipfs://base/";
            await proxy.onlyProxy_setBaseURI(uri);

            assert.equal(uri + tokenId, await proxyDelegate.tokenURI(tokenId));
          });
        });
      });

      describe("Royalties", () => {
        it("returns zero address and 0 amount when unset", async () => {
          const { 0: receiver, 1: amount } = await proxyDelegate.royaltyInfo(
            10,
            100000,
          );
          assert.equal(receiver, ZERO_ADDRESS);
          assert.equal(amount, 0);
        });

        it("returns zero address and 0 amount when only one is set", async () => {
          await proxy.onlyProxy_configureRoyalties(ZERO_ADDRESS, 1000);

          let { 0: receiver, 1: amount } = await proxyDelegate.royaltyInfo(
            10,
            100000,
          );
          assert.equal(receiver, ZERO_ADDRESS);
          assert.equal(amount, 0);

          await proxy.onlyProxy_configureRoyalties(deployer, 0);

          ({ 0: receiver, 1: amount } = await proxyDelegate.royaltyInfo(
            10,
            100000,
          ));
          assert.equal(receiver, ZERO_ADDRESS);
          assert.equal(amount, 0);
        });

        it("returns right amount of royalties when configured", async () => {
          await proxy.onlyProxy_configureRoyalties(deployer, 1500);

          const salePrice = web3.utils.toWei("12.25");
          const { 0: receiver, 1: amount } = await proxyDelegate.royaltyInfo(
            10,
            salePrice,
          );
          assert.equal(receiver, deployer);
          assert.equal(amount, web3.utils.toWei(String(12.25 * 0.15)));
        });
      });

      describe("Utils", () => {
        describe("recover", () => {
          const signer = web3.eth.accounts.create();

          ["recover", "recoverCalldata"].forEach((method) => {
            it(`${method} works`, async () => {
              const hash = web3.utils.soliditySha3("test");
              const { messageHash, signature } = web3.eth.accounts.sign(
                hash,
                signer.privateKey,
              );

              assert.equal(
                signer.address,
                await proxyDelegate[method](hash, signature),
              );
            });

            it(`${method} reverts when the signature is invalid`, async () => {
              const hash = web3.utils.soliditySha3("test");

              const invalidSigner = web3.eth.accounts.create();

              const { signature } = web3.eth.accounts.sign(
                hash,
                invalidSigner.privateKey,
              );

              assert.notEqual(
                ZERO_ADDRESS,
                await proxyDelegate[method](hash, signature),
              );

              assert.notEqual(
                signer.address,
                await proxyDelegate[method](hash, signature),
              );

              await expectRevert(
                proxyDelegate[method](hash, "0x1234"),
                "InvalidSignature",
              );
            });
          });
        });

        describe("toString", () => {
          it("convert uint256 to string", async () => {
            assert.equal(
              "1234567",
              await proxyDelegate.methods["toString(uint256)"](1234567),
            );
            assert.equal(
              "0",
              await proxyDelegate.methods["toString(uint256)"](0),
            );
          });
        });
      });
    });

    function getOnlyProxyMethods() {
      const methods = ERC721Baseline.abi
        .filter(
          (method) =>
            method.name &&
            method.name.startsWith("__") &&
            new RegExp(`function\\s+${method.name}.*onlyProxy[^{]*{`).test(
              ERC721Baseline.source,
            ),
        )
        // Prepare some fixtures for the ERC721Baseline OnlyProxy methods so that we can call them in bulk.
        .map((method) => [
          method.name,
          ...method.inputs.map((arg, index) => {
            switch (arg.type) {
              case "uint256":
                return 1;
              case "string":
                return "test";
              case "address":
                return accounts[index];
              case "bool":
                return true;
              case "bytes":
                return "";
              default:
                throw new Error(
                  `onlyProxyMethods: Missing fixture for type ${arg.type} (method: ${method.name})`,
                );
            }
          }),
        ]);

      assert.equal(
        methods.length,
        ERC721Baseline.source.match(/onlyProxy/g).length - 1, // -1 because the modifier definition does not count.
      );

      return methods;
    }
  },
);

async function expectRevert(promise, reason) {
  try {
    await promise;
    expect.fail(`Expected promise to throw with ${reason} but it didn't.`);
  } catch (revert) {
    if (reason) {
      const reasonId = web3.utils
        .soliditySha3(reason.endsWith(")") ? reason : reason + "()")
        .substr(0, 10);

      if (!revert.data) {
        throw new Error(revert.message || "Unknown Error.");
      }

      expect(
        typeof revert.data === "string" ? revert.data : revert.data.result,
        `Expected custom error ${reason} (${reasonId})`,
      ).to.include(reasonId);
    }
  }
}
