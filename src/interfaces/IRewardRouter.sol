pragma solidity ^0.8.13;

interface IRewardRouter {
    /// @notice Gets the current version.
    ///
    /// @return The version.
    function version() external view returns (string memory);

    /// @notice Gets the rewardcollector params.
    function getRewardCollector(address) external view returns (address, address, uint256);

    /// @notice Distributes rewards from grants and triggers collectors to claim rewards and donate.
    ///
    /// @param  token                The yield token to claim rewards for.
    /// @param  minimumAmountOut     The minimum returns to accept.
    ///
    /// @return claimed              The amount of reward tokens claimed.
    function distributeRewards(address token, uint256 minimumAmountOut) external returns (uint256 claimed);
}