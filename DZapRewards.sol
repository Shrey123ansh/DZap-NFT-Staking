// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.20;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";


contract DZapRewards is ERC20, ERC20Burnable, Ownable {  
  constructor()  ERC20("DZapRewards", "DZP") Ownable(msg.sender){ }

  function mint(address to, uint256 amount) external {
    _mint(to, amount);
  }

}