// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import {Proxy} from "@openzeppelin/contracts/proxy/Proxy.sol";
import {IERC721Baseline} from "./IERC721Baseline.sol";

/**
 * @title ERC721Baseline
 * @custom:version v0.1.0-alpha.6
 * @notice A minimal proxy contract for ERC721BaselineImplementation.
 *
 * @dev !!WARNING!! Be careful when defining variables in your proxy
 * as these might clash with the implementation ones.
 *
 * This contract makes the assumption that you will define storage slots
 * similarly to EIP-1967 (https://eips.ethereum.org/EIPS/eip-1967)
 * defining a struct with your variables and storing it at a specific location
 * eg. bytes32(uint256(keccak256("erc721baseline.storage")) - 1)).
 * Alternatively you can fork this contract and add a gap at the beginning,
 * although this approach is discouraged.
 */
contract ERC721Baseline is Proxy {

  struct ImplementationSlot {
    address value;
  }

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
