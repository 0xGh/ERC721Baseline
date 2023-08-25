// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

/**
 * @title IAdmin
 * @custom:version v0.1.0-alpha.0
 */

interface IAdmin {
  function owner() external view returns (address);
  function setOwner(address newOwner) external;
  function isAdmin(address addr) external view returns (bool);
  function setAdmin(address addr, bool add) external;

  event AdminSet(address indexed addr, bool indexed add);
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
}
