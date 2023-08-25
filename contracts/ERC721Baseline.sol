// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Admin} from "./Admin.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {IERC4906} from "@openzeppelin/contracts/interfaces/IERC4906.sol";
import {IERC721Baseline} from "./IERC721Baseline.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/**
 * @title ERC721Baseline
 * @custom:version v0.1.0-alpha.0
 * @notice A baseline ERC721 contract implementation that exposes some internal methods so that a proxy can access them.
 */

contract ERC721Baseline is ERC721, Admin, IERC2981, IERC4906, IERC721Baseline {

  constructor() ERC721("", "") {}

  /**
   * @notice Enables a proxy to call selected methods that are implemented in this contract.
   * @dev Throws if called by any account other than the proxy contract itself.
   */
  modifier onlyProxy {
    if (_msgSender() != address(this)) {
      revert OnlyProxy();
    }
    _;
  }

  /************************************************
   * Supported Interfaces
   ************************************************/

  function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
    return (
      interfaceId == /* NFT Royalty Standard */ type(IERC2981).interfaceId ||
      interfaceId == /* Metadata Update Extension */ type(IERC4906).interfaceId ||
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
   * @notice Initializes a proxy contract.
   * @dev This method MUST be called in the proxy constructor
   * to initialize the proxy with a name and symbol for the underlying ERC721.
   *
   * Additionally this method sets the deployer as owner and admin for the proxy.
   *
   * @param name contract name
   * @param symbol contract symbol
   */
  function initialize(string memory name, string memory symbol) external {
    if (_initialized == true || address(this).code.length != 0) {
      revert AlreadyInitialized();
    }

    _initialized = true;

    _name = name;
    _symbol = symbol;

    __Admin_init();
  }


  /************************************************
   * Metadata
   ************************************************/

  string private _name;
  string private _symbol;

  /**
   * @notice The base URI used by the default {IERC721Metadata-tokenURI} implementation.
   */
  string public __baseURI;

  /**
   * @dev Contract version.
   */
  string public constant VERSION = "0.1.0-alpha.0";

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
   * @dev See {ERC721-_baseURI}.
   *
   * @return string the base URI used by the default {IERC721Metadata-tokenURI} implementation
   */
  function _baseURI() internal view override returns (string memory) {
    return __baseURI;
  }

  /**
   * @notice Sets a contract-wide base URI.
   * @dev The default implementation of tokenURI will concatenate the base URI and token ID.
   *
   * @param baseURI shared base URI for the tokens
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
   * and therefore must be implemented in the proxy contract in order to customize royalties.
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
   * @dev Tracks whether the _beforeTokenTransfer hook is enabled in the implementation or not.
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
   * The proxy `_beforeTokenTransfer` method is called with the following params:
   *
   * - address the transaction's msg.sender
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

  /**
   * @dev See {IERC721Baseline-__transferOwnership}.
   */
  function __transferOwnership(address newOwner) external onlyProxy {
    _transferOwnership(newOwner);
  }

  /**
   * @dev See {IERC721Baseline-__setAdmin}.
   */
  function __setAdmin(address addr, bool add) external onlyProxy {
    _setAdmin(addr, add);
  }
}
