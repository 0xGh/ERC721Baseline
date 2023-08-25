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
 * @notice A baseline ERC721 contract that exposes some internal methods so that a proxy can access them.
 */

contract ERC721Baseline is ERC721, Admin, IERC2981, IERC4906, IERC721Baseline {
  bool private _initialized;
  bool private _beforeTokenTransferHookEnabled;

  string private _name;
  string private _symbol;
  string private __baseURI;

  string public constant VERSION = "0.1.0-alpha.0";

  constructor() ERC721("", "") {}

  function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
    return (
      interfaceId == /* NFT Royalty Standard */ type(IERC2981).interfaceId ||
      interfaceId == /* Metadata Update Extension */ type(IERC4906).interfaceId ||
      interfaceId == type(IERC721Baseline).interfaceId ||
      super.supportsInterface(interfaceId)
    );
  }

  /**
   * @dev This method can only be called in the constructor of the Proxy contract
   * to initialize the Proxy with name and symbol and set deployer as owner and admin.
   */
  function initialize(string memory name_, string memory symbol_) external {
    if (_initialized == true || address(this).code.length != 0) revert AlreadyInitialized();
    _initialized = true;

    _name = name_;
    _symbol = symbol_;

    __Admin_init();
  }

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
   * @dev See {IERC2981-royaltyInfo}.
   * @dev Implement this method in the Proxy contract.
   */
  function royaltyInfo(
    uint256,
    uint256
  ) external pure returns (address receiver, uint256 royaltyAmount) {
    return (address(0), 0);
  }

  /**
   * @dev The following are internal ERC721 methods which a proxy can call.
   */

  modifier onlyProxy {
    if (_msgSender() != address(this)) {
      revert OnlyProxy();
    }
    _;
  }

  /**
   * @dev Set contract-wide base URI. The default implementation of tokenURI will concatenate the base URI and token ID.
   * @param baseURI The shared base URI for the tokens.
   */
  function __setBaseURI(string calldata baseURI) external onlyProxy {
    __baseURI = baseURI;
  }

  function _baseURI() internal view override returns (string memory) {
    return __baseURI;
  }

  function __mint(address to, uint256 tokenId) external onlyProxy {
    _mint(to, tokenId);
  }

  function __burn(uint256 tokenId) external onlyProxy {
    _burn(tokenId);
  }

  function __transfer(address from, address to, uint256 tokenId) external onlyProxy {
    _transfer(from, to, tokenId);
  }

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

  function __setBeforeTokenTransferHookEnabled(bool enabled) external onlyProxy {
    _beforeTokenTransferHookEnabled = enabled;
  }

  /**
   * @dev Allows to define a `_beforeTokenTransfer` method in the proxy contract that is called when `_beforeTokenTransferHookEnabled` is `true`.
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

  function __isApprovedOrOwner(address spender, uint256 tokenId) external view onlyProxy returns (bool) {
    return _isApprovedOrOwner(spender, tokenId);
  }

  function __approve(address to, uint256 tokenId) external onlyProxy {
    _approve(to, tokenId);
  }

  function __setApprovalForAll(address owner, address operator, bool approved) external onlyProxy {
    _setApprovalForAll(owner, operator, approved);
  }

  function __transferOwnership(address newOwner) external onlyProxy {
    _transferOwnership(newOwner);
  }

  function __setAdmin(address addr, bool add) external onlyProxy {
    _setAdmin(addr, add);
  }
}
