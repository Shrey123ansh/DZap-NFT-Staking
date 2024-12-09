// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./DZapRewards.sol";
import "./DZapCollection.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
 // Testing
  // _nft: 0x1234...abcd,  _token: 0x5678...efgh,_rewardPerBlock: 10000000000000000000,
  //_unbondingPeriod: 10, _rewardDelay: 5, _multiplier: 2
contract NFTStaking is Ownable,Pausable {

  uint256 public totalStaked;
  uint256 public rewardPerBlock; 
    uint256 public unbondingPeriod;
    uint256 public rewardDelay; 
    uint48 public multiplier;
  
  //hold the owner, token, and earning values of stake
  struct Stake {
    uint24 tokenId;
    address owner;
    uint48 stakedTime;
    uint48 unstakedTime;
  }

  event NFTStaked(address owner, uint256 tokenId, uint256 value);
  event NFTUnstaked(address owner, uint256 tokenId, uint256 value);
  event Claimed(address owner, uint256 amount);

  // reference to the Block NFT contract
  DZapCollection nft;
  DZapRewards token;

  // map for stake to  tokenId
  mapping(uint256 => Stake) public vault; 
    mapping(address => uint256[]) private userTokens;

   constructor(DZapCollection _nft, DZapRewards _token,
        uint256 _unbondingPeriod,
        uint256 _rewardPerBlock,
        uint256 _rewardDelay, 
        uint48 _multiplier
        ) Ownable(msg.sender){ 
        nft =_nft;
        token =_token;
        rewardDelay = _rewardDelay;
        unbondingPeriod =_unbondingPeriod;
        rewardPerBlock = _rewardPerBlock;
        multiplier =_multiplier;
  }

  
    /// @notice stake one or more NFTs.
    /// @param tokenIds NFT  token IDs to stake.
  function staking(uint256[] calldata tokenIds) external whenNotPaused{
        uint256 tokenId;
        totalStaked += tokenIds.length;
        for (uint i = 0; i < tokenIds.length; i++) {
        tokenId = tokenIds[i];

        require(nft.ownerOf(tokenId) == msg.sender, "not your token");
        require(vault[tokenId].tokenId == 0, 'already staked');

        nft.transferFrom(msg.sender, address(this), tokenId);
        userTokens[msg.sender].push(tokenId);

        emit NFTStaked(msg.sender, tokenId, block.timestamp);

        vault[tokenId] = Stake({
        owner: msg.sender,
        tokenId: uint24(tokenId),
        stakedTime: uint48(block.timestamp),
        unstakedTime: uint48(0)
      });
    }


    }

/// @notice Unstake single nft, initiatialize the unbonding period.
  function unstaking(uint256 tokenId) external whenNotPaused{
        Stake storage staked = vault[tokenId];
        require(staked.owner == msg.sender, "not the owner");

        require(staked.unstakedTime == 0, "already unstaking");
        staked.unstakedTime = uint48(block.timestamp);
    }

  /// @notice unstakeMany single nft, initiatialize the unbonding period.
  /// @param tokenIds NFT token IDs to unstake
  function unstakeMany(uint256[] calldata tokenIds) internal whenNotPaused{
     for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            Stake storage staked = vault[tokenId];
            require(staked.owner == msg.sender, "not the owner");

            require(staked.unstakedTime == 0, "already unstaking");
            staked.unstakedTime = uint48(block.timestamp);
        }
  }

  /// @notice  claim based on delay after you unstaked.
  /// @param tokenIds NFT token IDs  for claim.
  function claimed(uint256[] calldata tokenIds) external whenNotPaused{

      uint256 totalRewards = 0;
      for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            Stake storage staked = vault[tokenId];
            require(block.timestamp >= staked.stakedTime + rewardDelay, "Reward delay not met");
            require(staked.owner == msg.sender, "not the owner");
            require(staked.unstakedTime == 0, "already unstaking");

            uint256 rewards = _calculateRewards(staked.stakedTime, staked.unstakedTime);
            staked.stakedTime = uint48(block.timestamp);

            totalRewards += rewards;
        }
        if (totalRewards > 0) {
            token.mint(msg.sender, totalRewards);
            emit Claimed(msg.sender, totalRewards);
        }
  }

  
  /// @notice  withdraw based on unbonding period after you unstaked.
  /// @param tokenIds NFT token  IDs for withdraw nft's.
  function withdraw(uint256[] calldata tokenIds) external whenNotPaused{
    for (uint256 i = 0; i < tokenIds.length; i++) {
        uint256 tokenId = tokenIds[i];
        Stake storage staked = vault[tokenId];
        require(staked.owner == msg.sender, "not the owner");

        require(staked.unstakedTime > 0, "not unstaking");

        require(block.timestamp >= staked.unstakedTime + unbondingPeriod, "Unbonding period not met");

        delete vault[tokenId];
        _removeUserToken(msg.sender, tokenId);

        nft.transferFrom(address(this), msg.sender, tokenId);
        totalStaked--;

        emit NFTUnstaked(msg.sender, tokenId, block.timestamp);
    }
  }
  
  /// @notice earningInfo returns earned amount and reward per second
  /// @param tokenId earning of  pparticular tokenId
  function earningInfo(uint256 tokenId) external view whenNotPaused returns (uint256[2] memory info) {
     uint256 earned = 0;
      Stake memory staked = vault[tokenId];
      uint48 stakedAt = staked.stakedTime;
      uint48 currTime = staked.stakedTime;
      earned =_calculateRewards(stakedAt, currTime);
  
    // earned,  earnRatePerSecond
    return [earned, rewardPerBlock];
  }

  /// @notice  balanceOf shows  total number of nft staked by user.
  function balanceOf(address account) public view returns (uint256) {
    return userTokens[account].length;
  }

    /// @notice View  all nfts staked by a user.
  function tokensOfOwner(address account) public view returns (uint256[] memory ownerTokens) {
    return userTokens[account];
  }

  /// @notice Pause the staking  (Owner).
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause the staking (Owner).
    function unpause() external onlyOwner {
        _unpause();
    }

     /// @notice Update  reward per block (Owner).
    function setRewardPerBlock(uint256 _rewardPerBlock) external onlyOwner {
        rewardPerBlock = _rewardPerBlock;
    }

     /// @notice Update  multiplier per block (Owner).
    function setMultiplier(uint48 _multiplier) external onlyOwner {
        multiplier = _multiplier;
    }

    /// @notice Update bonding  period (Owner).
    function setUnbondingPeriod(uint256 _unbondingPeriod) external onlyOwner {
        unbondingPeriod = _unbondingPeriod;
    }

    /// @notice Update reward delay (Owner).
    function setRewardDelay(uint256 _rewardDelay) external onlyOwner {
        rewardDelay = _rewardDelay;
    }

    function _calculateRewards(uint48 stakedAt, uint48 unstakedAt) internal view returns (uint256) {
        uint256 blocks = (unstakedAt > 0 ? unstakedAt : block.timestamp) - stakedAt;
        return blocks * rewardPerBlock * multiplier;
    }

    function _removeUserToken(address user, uint256 tokenId) internal {
        uint256[] storage tokens = userTokens[user];
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == tokenId) {
                tokens[i] = tokens[tokens.length - 1];
                tokens.pop();
                return;
            }
        }
    }


  
}