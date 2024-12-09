# NFTStaking Contract

## Overview

The `NFTStaking` contract allows users to stake their NFTs to earn rewards based on the amount of time they hold the NFTs in the staking contract. Users can also unstake NFTs after a set unbonding period and claim rewards after a defined delay. The contract supports staking and unstaking multiple NFTs, as well as reward calculations and claiming.

## Features

- **Staking:** Users can stake multiple NFTs at once and start earning rewards based on the amount of time they are staked.
- **Unstaking:** NFTs can be unstaked, initiating an unbonding period before they can be withdrawn.
- **Rewards:** Users earn rewards based on the amount of time their NFTs are staked, with rewards calculated per block.
- **Claiming:** Users can claim rewards after a reward delay.
- **Pause/Unpause:** The contract owner can pause and unpause staking activities.
- **Adjustable Parameters:** The contract owner can adjust parameters such as the reward per block, unbonding period, reward delay, and multiplier.

## Prerequisites

- Solidity 0.8.20 or above.
- OpenZeppelin contracts for `Ownable` and `Pausable`.
- A working instance of the `DZapCollection` (NFT contract) and `DZapRewards` (token contract).

## Contract Structure

### State Variables

- `totalStaked`: The total number of NFTs currently staked.
- `rewardPerBlock`: The amount of reward issued per block for each staked NFT.
- `unbondingPeriod`: The period users must wait before withdrawing unstaked NFTs.
- `rewardDelay`: The delay before users can claim rewards after unstaking.
- `multiplier`: A multiplier that affects the reward calculation.

### Events

- `NFTStaked(address owner, uint256 tokenId, uint256 value)`: Emitted when an NFT is staked.
- `NFTUnstaked(address owner, uint256 tokenId, uint256 value)`: Emitted when an NFT is unstaked.
- `Claimed(address owner, uint256 amount)`: Emitted when a user claims rewards.

### Structs

- `Stake`: Holds information about each NFT stake, including the owner, token ID, staked time, and unstaked time.

### Functions

#### 1. `staking(uint256[] calldata tokenIds)`
Allows users to stake one or more NFTs by providing their token IDs. The contract verifies the ownership of the NFTs and transfers them to the contract.

#### 2. `unstaking(uint256 tokenId)`
Initiates the unbonding period for a single NFT, preventing it from being withdrawn until the unbonding period has passed.

#### 3. `unstakeMany(uint256[] calldata tokenIds)`
Allows users to unstake multiple NFTs, initiating the unbonding period for each.

#### 4. `claimed(uint256[] calldata tokenIds)`
Allows users to claim rewards for their unstaked NFTs, based on the staking time and reward delay.

#### 5. `withdraw(uint256[] calldata tokenIds)`
Allows users to withdraw unstaked NFTs after the unbonding period has passed.

#### 6. `earningInfo(uint256 tokenId)`
Returns the earned rewards and reward rate for a specific NFT token ID.

#### 7. `balanceOf(address account)`
Returns the total number of NFTs staked by the given address.

#### 8. `tokensOfOwner(address account)`
Returns the list of token IDs staked by the given address.

#### 9. `pause()`
Allows the contract owner to pause the staking contract.

#### 10. `unpause()`
Allows the contract owner to unpause the staking contract.

#### 11. `setRewardPerBlock(uint256 _rewardPerBlock)`
Allows the contract owner to set the reward per block.

#### 12. `setMultiplier(uint48 _multiplier)`
Allows the contract owner to set the reward multiplier.

#### 13. `setUnbondingPeriod(uint256 _unbondingPeriod)`
Allows the contract owner to set the unbonding period.

#### 14. `setRewardDelay(uint256 _rewardDelay)`
Allows the contract owner to set the reward delay.

### Internal Functions

- `_calculateRewards(uint48 stakedAt, uint48 unstakedAt)`
Calculates the rewards earned by an NFT based on the staking duration and the multiplier.
  
- `_removeUserToken(address user, uint256 tokenId)`
Removes the given token ID from the user's list of staked tokens.

## How to Use

1. **Deploy the Contracts:**
   - Deploy the `DZapCollection` (NFT contract) and `DZapRewards` (token contract) first.
   - Then deploy the `NFTStaking` contract, providing the appropriate parameters (NFT contract, token contract, reward per block, unbonding period, etc.).

2. **Staking NFTs:**
   - Call `staking(uint256[] calldata tokenIds)` to stake your NFTs.

3. **Unstaking NFTs:**
   - Call `unstaking(uint256 tokenId)` to initiate the unbonding period for a single NFT.
   - Call `unstakeMany(uint256[] calldata tokenIds)` to unstake multiple NFTs.

4. **Claiming Rewards:**
   - Call `claimed(uint256[] calldata tokenIds)` to claim your rewards for unstaked NFTs after the reward delay.

5. **Withdrawing NFTs:**
   - After the unbonding period has passed, call `withdraw(uint256[] calldata tokenIds)` to withdraw your NFTs.

## Security Considerations

- Ensure that the contract's owner is properly secured, as they can pause/unpause the contract and change key parameters.
- All user interactions, such as staking, claiming, and unstaking, are validated to ensure that the user owns the NFTs they are interacting with.

## License

This contract is licensed under the MIT License.

