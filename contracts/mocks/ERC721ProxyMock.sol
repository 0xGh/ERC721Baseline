// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import "@openzeppelin/contracts/proxy/Proxy.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import {IERC721Baseline} from "../IERC721Baseline.sol";

/// @title {title}
/// @author {name}

contract ERC721ProxyMock is Proxy {
  uint256 public totalSupply;

  function mint(address to) external {
    IAdmin(address(this)).requireAdmin(msg.sender);

    IERC721Baseline(address(this)).__mint(to, ++totalSupply);
  }

  bool private _beforeTokenTransferHookEnabled;
  function toggleBeforeTokenTransferHook() external {
    IAdmin(address(this)).requireAdmin(msg.sender);
    _beforeTokenTransferHookEnabled = !_beforeTokenTransferHookEnabled;
    IERC721Baseline(address(this)).__setBeforeTokenTransferHookEnabled(_beforeTokenTransferHookEnabled);
  }

  function _beforeTokenTransfer(address sender, address, address to, uint256) external view {
    require(_beforeTokenTransferHookEnabled);

    if (sender == to) {
      revert('Call to self');
    }
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

interface IAdmin {
  function requireAdmin(address addr) external;
}

