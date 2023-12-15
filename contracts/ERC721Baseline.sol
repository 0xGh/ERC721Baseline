// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity 0.8.21;

import {Proxy} from "@openzeppelin/contracts/proxy/Proxy.sol";
import {IERC721Baseline} from "./IERC721Baseline.sol";

/**
 * @title ERC721BaselineImplementation
 * @custom:version v0.1.0-alpha.4
 * @notice A baseline ERC721 contract implementation that exposes internal methods to a proxy instance.
 */
contract ERC721Baseline is Proxy {

  struct ImplementationSlot {
    address value;
  }

  bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

  // @dev Proxy initialization upon deployment.
  constructor(
    address ERC721BaselineImplementation,
    string memory name,
    string memory symbol
  ) {
    ImplementationSlot storage implementation;
    assembly {
      implementation.slot := _IMPLEMENTATION_SLOT
    }
    implementation.value = ERC721BaselineImplementation;

    (bool success, ) = ERC721BaselineImplementation.delegatecall(
      abi.encodeCall(IERC721Baseline.initialize, (name, symbol))
    );
    require(success);
  }

  function _implementation() internal view override returns (address) {
    ImplementationSlot storage implementation;
    assembly {
      implementation.slot := _IMPLEMENTATION_SLOT
    }
    return implementation.value;
  }

  // @dev Returns a reference to the ERC721BaselineImplementation.
  function baseline() internal returns (IERC721Baseline) {
    return IERC721Baseline(address(this));
  }
}
