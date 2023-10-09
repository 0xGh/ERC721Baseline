// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import {Proxy} from "@openzeppelin/contracts/proxy/Proxy.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IERC721Baseline} from "../IERC721Baseline.sol";

/// @title {title}
/// @author {name}

contract ERC721ProxyMock is Proxy {

  IERC721Baseline baseline = IERC721Baseline(address(this));

  function onlyProxy_setTokenURI(uint256 tokenId, string calldata tokenURI) external {
    baseline.__setTokenURI(tokenId, tokenURI);
  }

  function onlyProxy_setSharedURI(string calldata sharedURI) external {
    baseline.__setSharedURI(sharedURI);
  }

  function onlyProxy_setBaseURI(string calldata baseURI) external {
    baseline.__setBaseURI(baseURI);
  }

  function onlyProxy_mint(address to, uint256 tokenId) external returns (uint256 newBalance) {
    baseline.__mint(to, tokenId);
    return baseline.balanceOf(to);
  }

  function onlyProxy_mint(address to, uint256 tokenId, string calldata tokenURI) external returns (uint256 newBalance) {
    baseline.__mint(to, tokenId, tokenURI);
    return baseline.balanceOf(to);
  }

  function adminMint(address to, uint256 tokenId) external returns (uint256 newBalance) {
    baseline.requireAdmin(msg.sender);
    baseline.__mint(to, tokenId);
    return baseline.balanceOf(to);
  }

  function onlyProxy_burn(uint256 tokenId) external returns (uint256 newBalance) {
    address owner = baseline.ownerOf(tokenId);
    require(msg.sender == owner, "Not owner");
    baseline.__burn(tokenId);
    return baseline.balanceOf(owner);
  }

  function onlyProxy_transfer(address from, address to, uint256 tokenId) external {
    baseline.__transfer(from, to, tokenId);
  }

  function onlyProxy_update(address to, uint256 tokenId, address auth) external {
    baseline.__update(to, tokenId, auth);
  }

  bool private _beforeTokenTransferHookEnabled;
  function onlyProxy_setBeforeTokenTransferHookEnabled(bool enabled) external {
    _beforeTokenTransferHookEnabled = enabled;
    baseline.__setBeforeTokenTransferHookEnabled(_beforeTokenTransferHookEnabled);
  }

  function toggleBeforeTokenTransferHook() external {
    baseline.requireAdmin(msg.sender);
    _beforeTokenTransferHookEnabled = !_beforeTokenTransferHookEnabled;
    baseline.__setBeforeTokenTransferHookEnabled(_beforeTokenTransferHookEnabled);
  }

  // Alter this in the hook to test that the proxy can alter its state without affecting the implementation state.
  string public __baseURI;
  event BeforeTokenTransferCalled();

  function _beforeTokenTransfer(address sender, address, address to, uint256) external {
    emit BeforeTokenTransferCalled();

    require(_beforeTokenTransferHookEnabled, 'not enabled');

    // @todo Try to alter state and make sure it is not reflected in the implementation.

    if (sender == to) {
      revert('Call to self');
    }

    __baseURI = "altered";
  }

  function onlyProxy_approve(address to, uint256 tokenId, address auth, bool emitEvent) external {
    baseline.__approve(to, tokenId, auth, emitEvent);
  }

  function onlyProxy_setApprovalForAll(address owner, address operator, bool approved) external {
    baseline.__setApprovalForAll(owner, operator, approved);
  }

  function onlyProxy_setAdmin(address addr, bool add) external {
    baseline.__setAdmin(addr, add);
  }

  function onlyProxy_transferOwnership(address newOwner) external {
    baseline.__transferOwnership(newOwner);
  }

  /**
   * Proxy initialization.
   */
  address public immutable implementation;

  constructor(
    address ERC721BaselineImplementation,
    string memory name,
    string memory symbol
  ) {
    implementation = ERC721BaselineImplementation;

    Address.functionDelegateCall(
      implementation,
      abi.encodeWithSignature(
        "initialize(string,string)",
        name,
        symbol
      )
    );
  }

  function _implementation() internal view override returns (address) {
    return implementation;
  }
}
