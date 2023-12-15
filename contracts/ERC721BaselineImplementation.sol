// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity 0.8.21;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {IERC721Baseline} from "./IERC721Baseline.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Utils} from "./Utils.sol";

/**
 * @title ERC721BaselineImplementation
 * @custom:version v0.1.0-alpha.5
 * @notice A baseline ERC721 contract implementation that exposes internal methods to a proxy instance.
 */
contract ERC721BaselineImplementation is ERC721, IERC2981, IERC721Baseline {

  /**
   * @dev The version of the implementation contract.
   */
  string public constant VERSION = "0.1.0-alpha.5";

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

  /**
   * @inheritdoc IERC165
   */
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
   * @inheritdoc IERC721Baseline
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
   * @inheritdoc IERC721Baseline
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
   * Metadata > Token URI
   */

  /**
   * @inheritdoc IERC721Baseline
   */
  mapping(uint256 => string) public __tokenURI;

  /**
   * @inheritdoc IERC721Baseline
   */
  function __setTokenURI(uint256 tokenId, string calldata tokenURI) external onlyProxy {
    __tokenURI[tokenId] = tokenURI;
    emit MetadataUpdate(tokenId);
  }

  /**
   * @inheritdoc IERC721Baseline
   */
  string public __sharedURI;

  /**
   * @inheritdoc IERC721Baseline
   */
  function __setSharedURI(string calldata sharedURI) external onlyProxy {
    __sharedURI = sharedURI;
  }

  /**
   * @inheritdoc IERC721Baseline
   */
  string public __baseURI;

  /**
   * @inheritdoc IERC721Baseline
   */
  function __setBaseURI(string calldata baseURI) external onlyProxy {
    __baseURI = baseURI;
  }

  function _baseURI() internal view override returns (string memory) {
    return __baseURI;
  }

  /**
   * @notice Returns the URI associated with a token ID.
   *
   * @dev The tokenURI implementation allows to define uris in the following order:
   *
   * 1. Token-specific URI by ID.
   * 2. Shared URI.
   * 3. Shared base URI + token ID.
   * 4. Empty string if none of the above was found.
   *
   * @param tokenId token ID
   * @return string the token URI
   */
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
   * See `royaltyInfo` in the proxy contract if defined.
   * ERC721Baseline defaults to 0% royalties
   * and therefore the method must be implemented again in the proxy contract in order to customize royalties.
   *
   * @inheritdoc IERC2981
   */
  function royaltyInfo(
    uint256,
    uint256
  ) external pure returns (address, uint256) {
    return (address(0), 0);
  }


  /************************************************
   * Internal ERC721 methods exposed to the proxy
   ************************************************/

  /**
   * @inheritdoc IERC721Baseline
   */
  function __ownerOf(uint256 tokenId) external view returns (address) {
    return _ownerOf(tokenId);
  }

  /**
   * @inheritdoc IERC721Baseline
   */
  function __update(address to, uint256 tokenId, address auth) external onlyProxy returns (address) {
    return super._update(to, tokenId, auth);
  }

  /**
   * @inheritdoc IERC721Baseline
   */
  function __mint(address to, uint256 tokenId) external onlyProxy {
    totalSupply += 1;
    _mint(to, tokenId);
  }

  /**
   * @inheritdoc IERC721Baseline
   */
  function __mint(address to, uint256 tokenId, string calldata tokenURI) external onlyProxy {
    totalSupply += 1;
    _mint(to, tokenId);
    __tokenURI[tokenId] = tokenURI;
  }

  /**
   * @inheritdoc IERC721Baseline
   */
  function __burn(uint256 tokenId) external onlyProxy {
    totalSupply -= 1;
    _burn(tokenId);
    if (bytes(__tokenURI[tokenId]).length > 0) {
      delete __tokenURI[tokenId];
    }
  }

  /**
   * @inheritdoc IERC721Baseline
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
   * @inheritdoc IERC721Baseline
   */
  function __setBeforeTokenTransferHookEnabled(bool enabled) external onlyProxy {
    _beforeTokenTransferHookEnabled = enabled;
  }

  /**
   * @dev See {ERC721-_update}.
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
   * @inheritdoc IERC721Baseline
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
   * @inheritdoc IERC721Baseline
   */
  function __isAuthorized(address owner, address spender, uint256 tokenId) external view returns (bool) {
    return _isAuthorized(owner, spender, tokenId);
  }

  /**
   * @inheritdoc IERC721Baseline
   */
  function __approve(address to, uint256 tokenId, address auth, bool emitEvent) external onlyProxy {
    _approve(to, tokenId, auth, emitEvent);
  }

  /**
   * @inheritdoc IERC721Baseline
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
   * @inheritdoc IERC721Baseline
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
   * @inheritdoc IERC721Baseline
   */
  function setAdmin(address addr, bool add) external {
    if (_isAdmin(_msgSender()) == false) {
      revert Unauthorized();
    }

    _setAdmin(addr, add);
  }

  /**
   * @inheritdoc IERC721Baseline
   */
  function __setAdmin(address addr, bool add) external onlyProxy {
    _setAdmin(addr, add);
  }

  /**
   * @inheritdoc IERC721Baseline
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
   * @inheritdoc IERC721Baseline
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
   * @inheritdoc IERC721Baseline
   */
  function transferOwnership(address newOwner) external {
    if (_isAdmin(_msgSender()) == false) {
      revert Unauthorized();
    }

    _transferOwnership(newOwner);
  }

  /**
   * @inheritdoc IERC721Baseline
   */
  function __transferOwnership(address newOwner) external onlyProxy {
    _transferOwnership(newOwner);
  }


  /************************************************
   * Utils
   ************************************************/

  /**
   * @inheritdoc IERC721Baseline
   */
  function recover(bytes32 hash, bytes memory signature) external view returns (address) {
    return Utils.recover(Utils.toEthSignedMessageHash(hash), signature);
  }

  /**
   * @inheritdoc IERC721Baseline
   */
  function recoverCalldata(bytes32 hash, bytes calldata signature) external view returns (address) {
    return Utils.recoverCalldata(Utils.toEthSignedMessageHash(hash), signature);
  }

  /**
   * @inheritdoc IERC721Baseline
   */
  function toString(uint256 value) external pure returns (string memory) {
    return Utils.toString(value);
  }

}
