// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import {IERC721Baseline} from "../IERC721Baseline.sol";

/// @title {title}
/// @author {name}

contract ERC721ConstructorAttackerMock {
  constructor(address ERC721BaselineImplementation) {
    IERC721Baseline(ERC721BaselineImplementation).initialize("hack", "HACK");
  }
}
