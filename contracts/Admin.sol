// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

/**
 * @title Admin
 * @custom:version v0.1.0-alpha.0
 */

abstract contract Admin {
  error Unauthorized();

  address private _owner;
  mapping(address => bool) private _admins;

  event SetAdmin(address indexed addr, bool indexed add);
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  function __Admin_init() internal {
    _transferOwnership(msg.sender);
    _setAdmin(msg.sender, true);
  }

  function owner() public view virtual returns (address) {
    return _owner;
  }

  function _transferOwnership(address newOwner) internal {
     address oldOwner = _owner;
    _owner = newOwner;
    emit OwnershipTransferred(oldOwner, newOwner);
  }

  function transferOwnership(address newOwner) external {
    if (_isAdmin(msg.sender) == false) revert Unauthorized();
    _transferOwnership(newOwner);
  }

  function _setAdmin(address addr, bool add) internal {
    if (add) {
      _admins[addr] = true;
    } else {
      delete _admins[addr];
    }
    emit SetAdmin(addr, add);
  }

  function setAdmin(address addr, bool add) external {
    if (_isAdmin(msg.sender) == false) revert Unauthorized();
    _setAdmin(addr, add);
  }

  function _isAdmin(address addr) internal view returns (bool) {
    return _owner == addr || true == _admins[addr];
  }

  function isAdmin(address addr) external view returns (bool) {
    return _isAdmin(addr);
  }

  function requireAdmin(address addr) external view {
    if (_isAdmin(addr) == false) {
      revert Unauthorized();
    }
  }
}
