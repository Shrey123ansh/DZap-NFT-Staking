    // SPDX-License-Identifier: MIT
    pragma solidity ^0.8.20;

    import "./DZapRewards.sol";
    import "./DZapCollection.sol";
    import "@openzeppelin/contracts/access/Ownable.sol";
    import "@openzeppelin/contracts/security/Pausable.sol";
    import "@openzeppelin/contracts/utils/math/SafeMath.sol";
    // Testing
  // _nft: 0x1234...abcd,  _token: 0x5678...efgh,_rewardPerBlock: 10000000000000000000,
  //_unbondingPeriod: 10, _rewardDelay: 5
    contract NFTStaking is Ownable, Pausable {

        using SafeMath for uint256;

        uint256 public totalStaked;
        uint256 public rewardPerBlock;
        uint256 public unbondingPeriod;
        uint256 public rewardDelay;
        uint256 public lastClaimAt;
        uint256 public lastRewardBlock;
        uint256 public accRewardPerShare;
        
        //hold the owner, token, and earning values of stake
        struct Stake {
            uint24 tokenId;
            address owner;
            uint256 stakedTime;
            uint256 unstakedTime;
            uint256 lastClaimAt;
        }

        event NFTStaked(address indexed owner, uint256 tokenId, uint256 value);
        event NFTUnstaked(address indexed owner, uint256 tokenId, uint256 value);
        event Claimed(address indexed owner, uint256 amount);

        // reference to the Block NFT contract
        DZapCollection public nft;
        DZapRewards public token;

        // map for stake to  tokenId
        mapping(uint256 => Stake) public vault;
        mapping(address => uint256[]) private userTokens;

        constructor(
            DZapCollection _nft,
            DZapRewards _token,
            uint256 _rewardPerBlock,
            uint256 _unbondingPeriod,
            uint256 _rewardDelay
        ) Ownable(msg.sender){
            nft = _nft;
            token = _token;
            rewardPerBlock = _rewardPerBlock;
            unbondingPeriod = _unbondingPeriod;
            rewardDelay = _rewardDelay;
            lastRewardBlock = block.timestamp;
            accRewardPerShare = 0;
        }

        // Update rewards for all staked NFTs
        function updatePool() internal {
            if (block.timestamp <= lastRewardBlock) {
                return;
            }

            uint256 blocks = block.timestamp.sub(lastRewardBlock);
            if (totalStaked > 0) {
                uint256 rewards = blocks.mul(rewardPerBlock);
                accRewardPerShare = accRewardPerShare.add(rewards);
            }
            lastRewardBlock = block.timestamp;
        }

        /// @notice stake one or more NFTs.
        /// @param tokenIds NFT  token IDs to stake.
        function staking(uint256[] calldata tokenIds) external whenNotPaused {
            updatePool();

            for (uint256 i = 0; i < tokenIds.length; i++) {
                uint256 tokenId = tokenIds[i];

                require(nft.ownerOf(tokenId) == msg.sender, "Not your token");
                require(vault[tokenId].tokenId == 0, "Already staked");

                nft.transferFrom(msg.sender, address(this), tokenId);
                userTokens[msg.sender].push(tokenId);

                vault[tokenId] = Stake({
                    owner: msg.sender,
                    tokenId: uint24(tokenId),
                    stakedTime: uint256(block.timestamp),
                    lastClaimAt: 0,
                    unstakedTime: 0
                });

                emit NFTStaked(msg.sender, tokenId, block.timestamp);
            }

            totalStaked = totalStaked.add(tokenIds.length);
        }

        /// @notice Unstake single nft, initiatialize the unbonding period.
        function unstaking(uint256 tokenId) external whenNotPaused{
            Stake storage staked = vault[tokenId];
            require(staked.owner == msg.sender, "not the owner");

            require(staked.unstakedTime == 0, "already unstaking");
            staked.unstakedTime = block.timestamp;
        }

        /// @notice unstakeMany single nft, initiatialize the unbonding period.
        /// @param tokenIds NFT token IDs to unstake
        function unstakeMany(uint256[] calldata tokenIds) external whenNotPaused{
            for (uint256 i = 0; i < tokenIds.length; i++) {
                    uint256 tokenId = tokenIds[i];
                    Stake storage staked = vault[tokenId];
                    require(staked.owner == msg.sender, "not the owner");

                    require(staked.unstakedTime == 0, "already unstaking");
                    staked.unstakedTime = block.timestamp;
                }
        }

        /// @notice  claim based on delay after you unstaked.
        /// @param tokenIds NFT token IDs  for claim.
        function claim(uint256[] calldata tokenIds) external whenNotPaused {
            updatePool();

            uint256 totalRewards = 0;
            for (uint256 i = 0; i < tokenIds.length; i++) {
                uint256 tokenId = tokenIds[i];
                Stake storage staked = vault[tokenId];
                // require(staked.owner == msg.sender, "Not the owner");
                require(block.timestamp >= staked.lastClaimAt + rewardDelay, "claim again after delay period");

                uint256 currentAccRewardPerShare = accRewardPerShare;

                    if (staked.unstakedTime > 0 && block.timestamp > staked.unstakedTime + unbondingPeriod) {
                        revert("please withdraw your nft");
                    }else{
                            uint256 blocks = block.timestamp.sub(lastRewardBlock);
                            uint256 rewards = blocks.mul(rewardPerBlock);
                            currentAccRewardPerShare = currentAccRewardPerShare.add(rewards);
                    }

                    uint256 pendings = currentAccRewardPerShare;
                    staked.lastClaimAt = uint256(block.timestamp);
                    totalRewards = totalRewards.add(pendings);
                    token.mint(staked.owner, totalRewards);
                }
            
            if (totalRewards > 0) {
                emit Claimed(msg.sender, totalRewards);
            }
        }

        /// @notice  withdraw based on unbonding period after you unstaked.
        /// @param tokenIds NFT token  IDs for withdraw nft's.
        function withdraw(uint256[] calldata tokenIds) external whenNotPaused {
            uint256 totalRewards = 0;

            for (uint256 i = 0; i < tokenIds.length; i++) {
                uint256 tokenId = tokenIds[i];
                Stake storage staked = vault[tokenId];

                require(staked.owner == msg.sender, "not the owner"); 
                require(staked.unstakedTime > 0, "not unstaking");
                require(block.timestamp >= staked.unstakedTime + unbondingPeriod, "unbonding period not met");
                
                nft.transferFrom(address(this), msg.sender, tokenId);

                uint256 currentAccRewardPerShare = accRewardPerShare;
                if(staked.unstakedTime + unbondingPeriod > lastRewardBlock){
                    uint256 timespan = staked.unstakedTime + unbondingPeriod;
                    uint256 blocks = timespan.sub(lastRewardBlock);
                    uint256 rewards = blocks.mul(rewardPerBlock);
                    currentAccRewardPerShare = currentAccRewardPerShare.add(rewards);
                    uint256 pendings = currentAccRewardPerShare;
                    totalRewards = totalRewards.add(pendings);
                }
            }
            totalStaked = totalStaked.sub(tokenIds.length);
            token.mint(msg.sender, totalRewards);
        }

        function set() external onlyOwner {
            updatePool();
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
            updatePool();
            rewardPerBlock = _rewardPerBlock;
        }

        /// @notice Update bonding  period (Owner).
        function setUnbondingPeriod(uint256 _unbondingPeriod) external onlyOwner {
            unbondingPeriod = _unbondingPeriod;
        }

        /// @notice Update reward delay (Owner).
        function setRewardDelay(uint256 _rewardDelay) external onlyOwner {
            rewardDelay = _rewardDelay;
        }
    }
