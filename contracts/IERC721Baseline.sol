// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

/**
 * @title IERC721Baseline
 * @custom:version v0.1.0-alpha.0
 * @notice A baseline ERC721 contract implementation that exposes internal methods to a proxy instance.
 */

interface IERC721Baseline {

  /**
   * @dev The version of the implementation contract.
   */
  function VERSION() external view returns (string memory);

  /**
   * Indicates an unauthorized operation or access attempt.
   */
  error Unauthorized();


  /************************************************
   * Initializer
   ************************************************/

  /**
   * @notice Initializes a proxy contract.
   * @dev This method MUST be called in the proxy constructor via delegatecall
   * to initialize the proxy with a name and symbol for the underlying ERC721.
   *
   * Additionally this method sets the deployer as owner and admin for the proxy.
   *
   * @param name contract name
   * @param symbol contract symbol
   */
  function initialize(string memory name, string memory symbol) external;


  /************************************************
   * Metadata
   ************************************************/

  /**
   * @notice The base URI used by the default {IERC721Metadata-tokenURI} implementation.
   */
  function __baseURI() external view returns (string memory);

  /**
   * @notice Sets a contract-wide base URI.
   * @dev The default implementation of {IERC721Metadata-tokenURI} will concatenate the base URI and token ID.
   *
   * @param baseURI shared base URI for the tokens
   */
  function __setBaseURI(string calldata baseURI) external;


  /************************************************
   * Internal ERC721 methods exposed to the proxy
   ************************************************/

  /**
   * Indicates an invalid attempt to call a method from outside of the proxy.
   */
  error NotProxy();

  /**
   * @dev See {ERC721-_mint}.
   * This method is internal and only the proxy contract can call it.
   */
  function __mint(address to, uint256 tokenId) external;

  /**
   * @dev See {ERC721-_burn}.
   * This method is internal and only the proxy contract can call it.
   */
  function __burn(uint256 tokenId) external;

  /**
   * @dev See {ERC721-_transfer}.
   * This method is internal and only the proxy contract can call it.
   */
  function __transfer(address from, address to, uint256 tokenId) external;

  /**
   * @notice Allows to enable or disable a `_beforeTokenTransfer` hook method defined in the proxy contract.
   * @dev This method is internal and only the proxy contract can call it.
   *
   * When enabled, the proxy's `_beforeTokenTransfer` hook method is invoked prior to a transfer.
   *
   * The proxy's `_beforeTokenTransfer` method is called with the following params:
   *
   * - address the transaction's _msgSender()
   * - address from
   * - address to
   * - uint256 tokenId
   *
   * This method is internal and only the proxy contract can call it.
   */
  function __setBeforeTokenTransferHookEnabled(bool enabled) external;

  /**
   * @dev See {ERC721-_checkOnERC721Received}.
   * This method is internal and only the proxy contract can call it.
   *
   * @dev NOTE that this method accepts an additional first parameter that is the original transaction's msg.sender
   */
  function __checkOnERC721Received(address sender, address from, address to, uint256 tokenId, bytes memory data) external returns (bool);

  /**
   * @dev See {ERC721-_isApprovedOrOwner}.
   * This method is internal and only the proxy contract can call it.
   */
  function __isApprovedOrOwner(address spender, uint256 tokenId) external returns (bool);

  /**
   * @dev See {ERC721-_approve}.
   * This method is internal and only the proxy contract can call it.
   */
  function __approve(address to, uint256 tokenId) external;

  /**
   * @dev See {ERC721-_setApprovalForAll}.
   * This method is internal and only the proxy contract can call it.
   */
  function __setApprovalForAll(address owner, address operator, bool approved) external;


  /************************************************
   * Access control
   ************************************************/

  /**
   * Implements a multi-admin system and a minimal Ownable-compatible API.
   */

  /**
   * Access control > multi-admin system
   */

  /**
   * @notice Checks if an address is the contract owner or an admin.
   *
   * @param addr address to check
   * @return bool whether the address is an admin or not
   */
  function isAdmin(address addr) external view returns (bool);

  /**
   * @dev Emits when an admin is added or removed.
   *
   * @param addr address that is being added or removed as an admin
   * @param add boolean indicating whether the address was grented or revoked admin rights
   */
  event AdminSet(address indexed addr, bool indexed add);

  /**
   * @notice Allows to add or remove an admin.
   * Can only be called by an admin.
   *
   * @param addr address to add or remove
   * @param add boolean indicating whether the address should be granted or revoked rights
   */
  function setAdmin(address addr, bool add) external;

  /**
   * @notice Checks whether an address is an admin and reverts with an `Unauthorized` error if not.
   * @dev Call `requireAdmin` in proxies to implement admin-only public methods.
   *
   * @param addr the address to check
   */
  function requireAdmin(address addr) external view;

  /**
   * @notice Allows to add or remove an admin.
   * @dev This method is internal and only the proxy contract can call it.
   *
   * @param addr address to add or remove
   * @param add boolean indicating whether the address should be granted or revoked rights
   */
  function __setAdmin(address addr, bool add) external;

  /**
   * Access control > Ownable-compatible API.
   */

  /**
   * @notice Returns the address of the contract owner.
   *
   * @return address of the contract owner
   */
  function owner() external view returns (address);

  /**
   * @dev Emits when the contract ownership is transferred.
   *
   * @param previousOwner old owner address
   * @param newOwner new owner address
   */
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  /**
   * @notice Transfers ownership of the contract to a new account.
   * Can only be called by an admin.
   *
   * @param newOwner new owner address
   */
  function transferOwnership(address newOwner) external;

  /**
   * @notice Transfers ownership of the contract to a new account.
   * @dev This method is internal and only the proxy contract can call it.
   *
   * @param newOwner new owner address
   */
  function __transferOwnership(address newOwner) external;
}
