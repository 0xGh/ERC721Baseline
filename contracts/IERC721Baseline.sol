// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import {IAdmin} from "./IAdmin.sol";

/**
 * @title IERC721Baseline
 * @custom:version v0.1.0-alpha.0
 */

interface IERC721Baseline {
  function initialize(string memory name_, string memory symbol_) external;
  function __setBaseURI(string calldata baseURI) external;
  function __mint(address to, uint256 tokenId) external;
  function __burn(uint256 tokenId) external;
  function __transfer(address from, address to, uint256 tokenId) external;
  function __checkOnERC721Received(address sender, address from, address to, uint256 tokenId, bytes memory data) external returns (bool);
  function __setBeforeTokenTransferHookEnabled(bool enabled) external;
  function __isApprovedOrOwner(address spender, uint256 tokenId) external returns (bool);
  function __approve(address to, uint256 tokenId) external;
  function __setApprovalForAll(address owner, address operator, bool approved) external;
  function __transferOwnership(address newOwner) external;
  function __setAdmin(address addr, bool add) external;

  error AlreadyInitialized();
  error OnlyProxy();
}
