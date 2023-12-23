// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import {Proxy} from "@openzeppelin/contracts/proxy/Proxy.sol";
import {IERC721Baseline} from "./IERC721Baseline.sol";

/**
 * @title ERC721Baseline
 * @custom:version v0.1.0-alpha.7
 * @notice A minimal proxy contract for ERC721BaselineImplementation.
 *
 * @dev ERC721BaselineImplementation uses ERC-7201 (Namespaced Storage Layout)
 * to prevent collisions with the proxies storage.
 * See https://eips.ethereum.org/EIPS/eip-7201.
 *
 * Proxies are encouraged, but not required, to use a similar pattern for storage.
 */
contract ERC721Baseline is Proxy {

  struct ImplementationSlot {
    address value;
  }

  /**
   * @dev Storage slot with the address of the current implementation.
   * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
   */
  bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

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

    (bool success, bytes memory reason) = ERC721BaselineImplementation.delegatecall(
      abi.encodeCall(IERC721Baseline.initialize, (name, symbol))
    );

    if (success == false) {
      if (reason.length == 0) revert("Initialization Failed.");
      assembly {
        revert(add(32, reason), mload(reason))
      }
    }
  }

  function _implementation() internal view override returns (address) {
    ImplementationSlot storage implementation;
    assembly {
      implementation.slot := _IMPLEMENTATION_SLOT
    }
    return implementation.value;
  }

  function implementation() external view returns (address) {
    return _implementation();
  }

  /**
   * @notice Returns a reference to the ERC721BaselineImplementation contract.
   */
  function baseline() internal view returns (IERC721Baseline) {
    return IERC721Baseline(address(this));
  }
}
