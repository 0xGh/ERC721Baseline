// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {IERC721Baseline} from "./IERC721Baseline.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {SignatureCheckerLib} from "solady/src/utils/SignatureCheckerLib.sol";

/**
 * @title ERC721Baseline
 * @custom:version v0.1.0-alpha.0
 * @notice A baseline ERC721 contract implementation that exposes internal methods to a proxy instance.
 */

contract ERC721Baseline is ERC721, IERC2981, IERC721Baseline {

  /**
   * @dev The version of the implementation contract.
   */
  string public constant VERSION = "0.1.0-alpha.0";

  constructor() ERC721("", "") {}

  /**
   * @notice Enables a proxy to call selected methods that are implemented in this contract.
   * @dev Throws if called by any account other than the proxy contract itself.
   */
  modifier onlyProxy {
    if (_msgSender() != address(this)) {
      revert NotProxy();
    }
    _;
  }

  /************************************************
   * Supported Interfaces
   ************************************************/

  function supportsInterface(bytes4 interfaceId) public view override(IERC165, ERC721) returns (bool) {
    return (
      interfaceId == /* NFT Royalty Standard */ type(IERC2981).interfaceId ||
      interfaceId == /* Metadata Update Extension */ bytes4(0x49064906) ||
      interfaceId == type(IERC721Baseline).interfaceId ||
      super.supportsInterface(interfaceId)
    );
  }


  /************************************************
   * Initializer
   ************************************************/

  /**
   * @dev Tracks the initialization state.
   */
  bool private _initialized;

  /**
   * @dev See {IERC721Baseline-initialize}.
   */
  function initialize(string memory name, string memory symbol) external {
    if (
      _initialized == true ||
      address(this).code.length != 0
    ) {
      revert Unauthorized();
    }

    _initialized = true;

    _name = name;
    _symbol = symbol;

    _setAdmin(_msgSender(), true);
    _transferOwnership(_msgSender());
  }


  /************************************************
   * Metadata
   ************************************************/

  /**
   * @dev See {IERC721Baseline-totalSupply}.
   */
  uint256 public totalSupply;

  string private _name;
  string private _symbol;

  /**
   * @dev See {IERC721Metadata-name}.
   */
  function name() public view override returns (string memory) {
    return _name;
  }

  /**
   * @dev See {IERC721Metadata-symbol}.
   */
  function symbol() public view override returns (string memory) {
    return _symbol;
  }

  /**
   * Token URI.
   *
   * The tokenURI implementation allows to define uris in the following order:
   *
   * 1. Token-specific URI by ID.
   * 2. Shared URI.
   * 3. Shared base URI + token ID.
   * 4. Empty string if none of the above was found.
   */

  event MetadataUpdate(uint256 tokenId);

  /**
   * @dev See {IERC721Baseline-__tokenURI}.
   */
  mapping(uint256 => string) public __tokenURI;

  /**
   * @dev See {IERC721Baseline-__setTokenURI}.
   */
  function __setTokenURI(uint256 tokenId, string calldata tokenURI) external onlyProxy {
    __tokenURI[tokenId] = tokenURI;
    emit MetadataUpdate(tokenId);
  }

  /**
   * @dev See {IERC721Baseline-__sharedURI}.
   */
  string public __sharedURI;

  /**
   * @dev See {IERC721Baseline-__setSharedURI}.
   */
  function __setSharedURI(string calldata sharedURI) external onlyProxy {
    __sharedURI = sharedURI;
  }

  /**
   * @dev See {IERC721Baseline-__baseURI}.
   */
  string public __baseURI;

  /**
   * @dev See {IERC721Baseline-__setBaseURI}.
   */
  function __setBaseURI(string calldata baseURI) external onlyProxy {
    __baseURI = baseURI;
  }

  function _baseURI() internal view override returns (string memory) {
    return __baseURI;
  }

  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    _requireOwned(tokenId);

    string memory uri = __tokenURI[tokenId];

    if (bytes(uri).length > 0) {
      return uri;
    }

    if (bytes(__sharedURI).length > 0) {
      return __sharedURI;
    }

    if (bytes(__baseURI).length > 0) {
      return super.tokenURI(tokenId);
    }

    return "";
  }

  /************************************************
   * Royalties
   ************************************************/

  /**
   * @notice See `royaltyInfo` in the proxy contract if defined.
   * @dev ERC721Baseline defaults to 0% royalties
   * and therefore the method must be implemented again in the proxy contract in order to customize royalties.
   */
  function royaltyInfo(
    uint256,
    uint256
  ) external pure returns (address receiver, uint256 royaltyAmount) {
    return (address(0), 0);
  }


  /************************************************
   * Internal ERC721 methods exposed to the proxy
   ************************************************/

  /**
   * @dev See {IERC721Baseline-__ownerOf}.
   */
  function __ownerOf(uint256 tokenId) external returns (address) {
    return _ownerOf(tokenId);
  }

  /**
   * @dev See {IERC721Baseline-__update}.
   */
  function __update(address to, uint256 tokenId, address auth) external onlyProxy returns (address) {
    return super._update(to, tokenId, auth);
  }

  /**
   * @dev See {IERC721Baseline-__mint}.
   */
  function __mint(address to, uint256 tokenId) external onlyProxy {
    totalSupply += 1;
    _mint(to, tokenId);
  }

  /**
   * @dev See {IERC721Baseline-__mint}.
   */
  function __mint(address to, uint256 tokenId, string calldata tokenURI) external onlyProxy {
    totalSupply += 1;
    _mint(to, tokenId);
    __tokenURI[tokenId] = tokenURI;
  }

  /**
   * @dev See {IERC721Baseline-__burn}.
   */
  function __burn(uint256 tokenId) external onlyProxy {
    totalSupply -= 1;
    _burn(tokenId);
    if (bytes(__tokenURI[tokenId]).length > 0) {
      delete __tokenURI[tokenId];
    }
  }

  /**
   * @dev See {IERC721Baseline-__transfer}.
   */
  function __transfer(address from, address to, uint256 tokenId) external onlyProxy {
    _transfer(from, to, tokenId);
  }

  /**
   * @dev Tracks whether the proxy's `_beforeTokenTransfer` hook is enabled or not.
   * When enabled, this contract will call the hook when ERC721 calls `_update`.
   */
  bool private _beforeTokenTransferHookEnabled;

  /**
   * @dev See {IERC721Baseline-__setBeforeTokenTransferHookEnabled}.
   */
  function __setBeforeTokenTransferHookEnabled(bool enabled) external onlyProxy {
    _beforeTokenTransferHookEnabled = enabled;
  }

  /**
   * @dev Allows to define a `_beforeTokenTransfer` hook method in the proxy contract that is called when `_beforeTokenTransferHookEnabled` is `true`.
   *
   * The proxy's `_beforeTokenTransfer` method is called with the following params:
   *
   * - address the transaction's _msgSender()
   * - address from
   * - address to
   * - uint256 tokenId
   */
  function _update(
    address to,
    uint256 tokenId,
    address auth
  ) internal override returns (address) {
    if (_beforeTokenTransferHookEnabled == true) {
      (bool success, ) = address(this).delegatecall(
        abi.encodeWithSignature(
          "_beforeTokenTransfer(address,address,address,uint256)",
          _msgSender(),
          _ownerOf(tokenId),
          to,
          tokenId
        )
      );

      assembly {
        switch success
          case 0 {
            returndatacopy(0, 0, returndatasize())
            revert(0, returndatasize())
          }
      }
    }

    return super._update(to, tokenId, auth);
  }

  /**
   * @dev See {IERC721Baseline-__checkOnERC721Received}.
   */
  function __checkOnERC721Received(
    address sender,
    address from,
    address to,
    uint256 tokenId,
    bytes memory data
  ) external {
    if (to.code.length > 0) {
      try IERC721Receiver(to).onERC721Received(sender, from, tokenId, data) returns (bytes4 retval) {
        if (retval != IERC721Receiver.onERC721Received.selector) {
          revert ERC721InvalidReceiver(to);
        }
      } catch (bytes memory reason) {
        if (reason.length == 0) {
          revert ERC721InvalidReceiver(to);
        } else {
          /// @solidity memory-safe-assembly
          assembly {
            revert(add(32, reason), mload(reason))
          }
        }
      }
    }
  }

  /**
   * @dev See {IERC721Baseline-__isAuthorized}.
   */
  function __isAuthorized(address owner, address spender, uint256 tokenId) external view returns (bool) {
    return _isAuthorized(owner, spender, tokenId);
  }

  /**
   * @dev See {IERC721Baseline-__approve}.
   */
  function __approve(address to, uint256 tokenId, address auth, bool emitEvent) external onlyProxy {
    _approve(to, tokenId, auth, emitEvent);
  }

  /**
   * @dev See {IERC721Baseline-__setApprovalForAll}.
   */
  function __setApprovalForAll(address owner, address operator, bool approved) external onlyProxy {
    _setApprovalForAll(owner, operator, approved);
  }


  /************************************************
   * Access control
   ************************************************/

  /**
   * Implements a multi-admin system and a minimal Ownable-compatible API.
   */

  /**
   * @dev Tracks the contract admins.
   */
  mapping(address => bool) private _admins;

  /**
   * Access control > multi-admin system
   */

  /**
   * @dev Internal method: checks if an address is the contract owner or an admin.
   *
   * @param addr address to check
   * @return bool whether the address is an admin or not
   */
  function _isAdmin(address addr) internal view returns (bool) {
    return _owner == addr || _admins[addr] == true;
  }

  /**
   * @dev See {IERC721Baseline-isAdmin}.
   */
  function isAdmin(address addr) external view returns (bool) {
    return _isAdmin(addr);
  }

  /**
   * @dev Internal method: allows to add or remove an admin.
   *
   * @param addr address to add or remove
   * @param add boolean indicating whether the address should be granted or revoked rights
   */
  function _setAdmin(address addr, bool add) internal {
    if (add) {
      _admins[addr] = true;
    } else {
      delete _admins[addr];
    }
    emit AdminSet(addr, add);
  }

  /**
   * @dev See {IERC721Baseline-setAdmin}.
   */
  function setAdmin(address addr, bool add) external {
    if (_isAdmin(_msgSender()) == false) {
      revert Unauthorized();
    }

    _setAdmin(addr, add);
  }

  /**
   * @dev See {IERC721Baseline-__setAdmin}.
   */
  function __setAdmin(address addr, bool add) external onlyProxy {
    _setAdmin(addr, add);
  }

  /**
   * @dev See {IERC721Baseline-requireAdmin}.
   */
  function requireAdmin(address addr) external view {
    if (_isAdmin(addr) == false) {
      revert Unauthorized();
    }
  }

  /**
   * Access control > Ownable-compatible API.
   */

  /**
   * @dev Tracks the contract owner.
   */
  address private _owner;

  /**
   * @dev See {IERC721Baseline-owner}.
   */
  function owner() external view returns (address) {
    return _owner;
  }

  /**
   * @dev Internal method: transfers ownership of the contract to a new account.
   *
   * @param newOwner new owner address
   */
  function _transferOwnership(address newOwner) internal {
     address oldOwner = _owner;
    _owner = newOwner;
    emit OwnershipTransferred(oldOwner, newOwner);
  }

  /**
   * @dev See {IERC721Baseline-transferOwnership}.
   */
  function transferOwnership(address newOwner) external {
    if (_isAdmin(_msgSender()) == false) {
      revert Unauthorized();
    }

    _transferOwnership(newOwner);
  }

  /**
   * @dev See {IERC721Baseline-__transferOwnership}.
   */
  function __transferOwnership(address newOwner) external onlyProxy {
    _transferOwnership(newOwner);
  }

  /**
   * Signature Validation Library.
   * MIT Licensed, (c) 2022-present Solady.
   */

  /**
   * @dev See {SignatureCheckerLib-isValidSignatureNow}.
   */
  function isValidSignatureNow(address signer, bytes32 hash, bytes memory signature)
    external
    view
    returns (bool isValid)
  {
    return SignatureCheckerLib.isValidSignatureNow(signer, hash, signature);
  }

  /**
   * @dev See {SignatureCheckerLib-isValidSignatureNowCalldata}.
   */
  function isValidSignatureNowCalldata(address signer, bytes32 hash, bytes calldata signature)
    external
    view
    returns (bool isValid)
  {
    return SignatureCheckerLib.isValidSignatureNowCalldata(signer, hash, signature);
  }
}
