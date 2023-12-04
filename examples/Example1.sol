// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import {Proxy} from "@openzeppelin/contracts/proxy/Proxy.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC721Baseline} from "erc721baseline/contracts/IERC721Baseline.sol";

/**
 * WARNING!!!
 *
 * This contract is just an example and MUST NOT be used as a reference
 * implementation for a proxy/your project.
 */

/**
 * @title {title}
 * @author {author}
 *
 * @dev This contract implements an example ERC721 proxy with some custom functionality.
 * What is not implemented here is delegated to ERC721Baseline which will provide standard ERC721 functionality
 * along with some custom functionality (see ERC721Baseline.sol implementation).
 */
contract Example1 is Proxy {

  // @dev Keep a reference to the ERC721Baseline implementation.
  IERC721Baseline baseline = IERC721Baseline(address(this));

  // @dev Proxy initialization upon deployment.

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

  /**
   * @dev Address that generates the signatures used for minting and updating URIs.
   * Changing this address will result in old signatures being not usable for minting
   * (unless you set _signer back to the address who created them of course).
   */
  address private _signer;

  /**
   * @notice Updates the _signer.
   *
   * @param address The new signer address.
   */
  function setSigner(address newSignerAddress) external {
    // Only admins can update the _signer address.
    // ERC721Baseline's requireAdmin will throw if msg.sender is not an admin.
    baseline.requireAdmin(msg.sender);
    _signer = newSignerAddress;
  }

  /**
   * @notice Retrieves the token URI for a given tokenId.
   * @dev Implements a custom tokenURI that overrides the one from the ERC721Baseline implementation.
   * This is just for the sake of showcasing what can be done.
   *
   * @param tokenId The ID of the token.
   * @return The token URI.
   */
  function tokenURI(uint256 tokenId) external view returns (string memory) {
    // ERC721 throws if the token doesn't exist.
    baseline.ownerOf(tokenId);

    // When block.timestamp is an even number return the actual token URI.
    if (block.timestamp % 2 == 0) {
      return baseline.__tokenURI(tokenId);
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
      _signer != baseline.recoverCalldata(
        keccak256(abi.encodePacked(address(this), tokenId, uri)),
        signature
      ) ||
      msg.sender != baseline.__ownerOf(tokenId)
    ) revert IERC721Baseline.Unauthorized();

    baseline.__setTokenURI(tokenId, uri);
  }

  // @dev Track which tokens have been minted so that they cannot be minted again.
  mapping(uint256 => uint8) private _minted;

  /**
   * @notice Allows a collector to mint a specific tokenId.
   *
   * @param tokenId The ID of the token to mint.
   * @param uri The URI for the token (provided by the creator).
   * @param signature The signature for authorization (provided by the creator).
   */
  function mint(uint256 tokenId, string calldata uri, bytes calldata signature) external {
    if (
      // Can't mint, burn and mint again this.
      true == _minted[tokenId] ||

      // Minting is authorized via signatures.
      //
      // The project owner signs the hash recreated below with _signer's wallet and
      // provides the signature to the collector allowing them to mint.
      //
      // The logic below recovers the signer for the hash (which must be recreated on-chain)
      // and if the recovered address matches _signer the collector is authorized to mint, otherwise we revert.
      _signer != baseline.recoverCalldata(
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

    _minted[tokenId] = true;
    baseline.__mint(msg.sender, tokenId, uri);
  }

  /**
   * @notice Burns a token with the given tokenId.
   *
   * @param tokenId The ID of the token to burn.
   */
  function burn(uint256 tokenId) external {
    if (
      msg.sender != baseline.__ownerOf(tokenId)
    ) revert IERC721Baseline.Unauthorized();

    baseline.__burn(tokenId);
  }
}
