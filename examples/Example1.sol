// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import {ERC721Baseline} from "erc721baseline/contracts/ERC721Baseline.sol";
import {IERC721Baseline} from "erc721baseline/contracts/IERC721Baseline.sol";

/**
 * WARNING!!!
 *
 * This contract is just an example and MUST NOT be used as a reference
 * implementation for a proxy/your project!
 *
 * Be careful when defining variables in your proxy
 * as these might clash with the implementation ones.
 *
 * ERC721Baseline.sol and this example make the assumption that you will
 * define storage slots similarly to EIP-1967 (https://eips.ethereum.org/EIPS/eip-1967)
 * using a struct with your variables and storing it at a specific location
 * eg. bytes32(uint256(keccak256("erc721baseline.storage")) - 1)).
 * Alternatively you can fork ERC721Baseline.sol and add a gap at the beginning,
 * although this approach is discouraged.
 */

/**
 * @title {title}
 * @author {author}
 *
 * @dev This contract implements an example ERC721 proxy with some custom functionality.
 * What is not implemented here is delegated to ERC721BaselineImplementation
 * which will provide standard ERC721 functionality
 * along with some custom functionality (see ERC721BaselineImplementation.sol).
 */
contract Example1 is ERC721Baseline {

  constructor(
    address ERC721BaselineImplementation,
    string memory name,
    string memory symbol
  )
    ERC721Baseline(
      ERC721BaselineImplementation,
      name,
      symbol
    )
  {}

  struct Storage {
    /**
     * @dev Address that generates the signatures used for minting and updating URIs.
     * Changing this address will result in old signatures being not usable for minting
     * (unless you set signer back to the address who created them of course).
     */
    address signer;

    /**
     * @dev Track which tokens have been minted so that they cannot be minted again.
     */
    mapping(uint256 => uint8) minted;
  }

  // @dev bytes32(uint256(keccak256("erc721baseline.storage")) - 1))
  bytes32 internal constant _STORAGE_SLOT = 0x250ff73fa7c77d3cf3d31d526f39469a8af05d982b3c2af50eaf28990fbf68e1;

  function _getStorage() internal pure returns (Storage storage store) {
    assembly {
      store.slot := _STORAGE_SLOT
    }
  }

  /**
   * @notice Updates the signer.
   *
   * @param address The new signer address.
   */
  function setSigner(address newSignerAddress) external {
    // Only admins can update the signer address.
    // ERC721BaselineImplemenation's requireAdmin will throw if msg.sender is not an admin.
    baseline().requireAdmin(msg.sender);
    _getStorage().signer = newSignerAddress;
  }

  /**
   * @notice Retrieves the token URI for a given tokenId.
   * @dev Implements a custom tokenURI that overrides the one from the ERC721BaselineImplemenation.
   * This is just for the sake of showcasing what can be done.
   *
   * @param tokenId The ID of the token.
   * @return The token URI.
   */
  function tokenURI(uint256 tokenId) external view returns (string memory) {
    // ERC721 throws if the token doesn't exist.
    baseline().ownerOf(tokenId);

    // When block.timestamp is an even number return the actual token URI.
    if (block.timestamp % 2 == 0) {
      return baseline().__tokenURI(tokenId);
    }

    // When block.timestamp is an odd number return something else.
    return "Odd.";
  }

  /**
   * @notice Allows the collector to update the token URI for a given tokenId.
   *
   * @param tokenId The ID of the token.
   * @param uri The new URI for the token (provided by the creator).
   * @param signature The signature for authorization (provided by the creator).
   */
  function updateUri(uint256 tokenId, string calldata uri, bytes calldata signature) external {
    if (
      _getStorage().signer != baseline().recoverCalldata(
        keccak256(abi.encodePacked(address(this), tokenId, uri)),
        signature
      ) ||
      msg.sender != baseline().__ownerOf(tokenId)
    ) revert IERC721Baseline.Unauthorized();

    baseline().__setTokenURI(tokenId, uri);
  }

  /**
   * @notice Allows a collector to mint a specific tokenId.
   *
   * @param tokenId The ID of the token to mint.
   * @param uri The URI for the token (provided by the creator).
   * @param signature The signature for authorization (provided by the creator).
   */
  function mint(uint256 tokenId, string calldata uri, bytes calldata signature) external {
    Storage storage store = _getStorage();

    if (
      // Can't mint, burn and mint again this.
      true == store.minted[tokenId] ||

      // Minting is authorized via signatures.
      //
      // The project owner signs the hash recreated below with signer's wallet and
      // provides the signature to the collector allowing them to mint.
      //
      // The logic below recovers the signer for the hash (which must be recreated on-chain)
      // and if the recovered address matches signer the collector is authorized to mint, otherwise we revert.
      store.signer != baseline().recoverCalldata(
        keccak256(
          abi.encodePacked(
            address(this),
            msg.sender,
            tokenId,
            uri
          )
        ),
        signature
      )
    ) revert IERC721Baseline.Unauthorized();

    store.minted[tokenId] = true;
    baseline().__mint(msg.sender, tokenId, uri);
  }

  /**
   * @notice Burns a token with the given tokenId.
   *
   * @param tokenId The ID of the token to burn.
   */
  function burn(uint256 tokenId) external {
    if (
      msg.sender != baseline().__ownerOf(tokenId)
    ) revert IERC721Baseline.Unauthorized();

    baseline().__burn(tokenId);
  }
}
