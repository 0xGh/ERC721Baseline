// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {IERC721Baseline} from "./IERC721Baseline.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

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
   * @notice The base URI used by the default {IERC721Metadata-tokenURI} implementation.
   */
  string public __baseURI;

  /**
   * @dev See {ERC721-_baseURI}.
   *
   * @return string the base URI used by the default {IERC721Metadata-tokenURI} implementation
   */
  function _baseURI() internal view override returns (string memory) {
    return __baseURI;
  }

  /**
   * @dev See {IERC721Baseline-__setBaseURI}.
   */
  function __setBaseURI(string calldata baseURI) external onlyProxy {
    __baseURI = baseURI;
  }


  /************************************************
   * Royalties
   ************************************************/

  /**
   * @notice See `royaltyInfo` in the proxy contract.
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
   * @dev See {IERC721Baseline-__mint}.
   */
  function __mint(address to, uint256 tokenId) external onlyProxy {
    _mint(to, tokenId);
  }

  /**
   * @dev See {IERC721Baseline-__burn}.
   */
  function __burn(uint256 tokenId) external onlyProxy {
    _burn(tokenId);
  }

  /**
   * @dev See {IERC721Baseline-__transfer}.
   */
  function __transfer(address from, address to, uint256 tokenId) external onlyProxy {
    _transfer(from, to, tokenId);
  }

  /**
   * @dev Tracks whether the `_beforeTokenTransfer` hook is enabled or not.
   * When enabled, this contract will call the hook on `_beforeTokenTransfer`.
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
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId,
    uint256
  ) internal override {
    if (_beforeTokenTransferHookEnabled == false) {
      return;
    }

    (bool success, ) = address(this).delegatecall(
      abi.encodeWithSignature(
        "_beforeTokenTransfer(address,address,address,uint256)",
        _msgSender(),
        from,
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

  /**
   * @dev See {IERC721Baseline-__checkOnERC721Received}.
   */
  function __checkOnERC721Received(
    address sender,
    address from,
    address to,
    uint256 tokenId,
    bytes memory data
  ) external onlyProxy returns (bool) {
    if (to.code.length > 0) { // to.isContract()
      try IERC721Receiver(to).onERC721Received(sender, from, tokenId, data) returns (bytes4 retval) {
        return retval == IERC721Receiver.onERC721Received.selector;
      } catch (bytes memory reason) {
        if (reason.length == 0) {
          revert("ERC721: transfer to non ERC721Receiver implementer");
        } else {
          /// @solidity memory-safe-assembly
          assembly {
            revert(add(32, reason), mload(reason))
          }
        }
      }
    } else {
      return true;
    }
  }

  /**
   * @dev See {IERC721Baseline-__isApprovedOrOwner}.
   */
  function __isApprovedOrOwner(address spender, uint256 tokenId) external view onlyProxy returns (bool) {
    return _isApprovedOrOwner(spender, tokenId);
  }

  /**
   * @dev See {IERC721Baseline-__approve}.
   */
  function __approve(address to, uint256 tokenId) external onlyProxy {
    _approve(to, tokenId);
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
}
