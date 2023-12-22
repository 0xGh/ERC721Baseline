// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import {Proxy} from "@openzeppelin/contracts/proxy/Proxy.sol";
import {IERC721Baseline} from "../IERC721Baseline.sol";

contract InitializationMock is Proxy {
  address private _impl;

  constructor(address implementation, bool initialize) {
    _impl = implementation;

    if (initialize) {
      (bool success, bytes memory result) = implementation.delegatecall(
        abi.encodeCall(IERC721Baseline.initialize, ("InitializationMock", "IM"))
      );

      if (!success) {
        if (result.length == 0) revert("Initialization Failed.");
        assembly {
          revert(add(32, result), mload(result))
        }
      }
    }
  }

  function init() external {
    (bool success, bytes memory result) = _implementation().delegatecall(
      abi.encodeCall(IERC721Baseline.initialize, ("InitializationMock", "IM"))
    );

    if (!success) {
      if (result.length == 0) revert("Initialization Failed.");
      assembly {
        revert(add(32, result), mload(result))
      }
    }
  }


  function _implementation() internal view override returns (address) {
    return _impl;
  }
}
