pragma solidity ^0.8.13;

import {IllegalState} from "../../base/Errors.sol";

import {IERC20Metadata} from "../../interfaces/IERC20Metadata.sol";
import {ITokenAdapter} from "../../interfaces/ITokenAdapter.sol";
import {IStaticAToken} from "../../interfaces/external/aave/IStaticAToken.sol";

import {TokenUtils} from "../../libraries/TokenUtils.sol";

contract AAVETokenAdapter is ITokenAdapter {
    string public constant override version = "1.0.0"; 
    address public override token;
    address public override underlyingToken;

    constructor(address _token, address _underlyingToken) {
        token = _token;
        underlyingToken = _underlyingToken;
    }

    /// @inheritdoc ITokenAdapter
    function price() external view override returns (uint256) {
        return IStaticAToken(token).staticToDynamicAmount(10**TokenUtils.expectDecimals(token));
    }

    /// @inheritdoc ITokenAdapter
    function wrap(uint256 amount, address recipient) external override returns (uint256) {
        TokenUtils.safeTransferFrom(underlyingToken, msg.sender, address(this), amount);
        TokenUtils.safeApprove(underlyingToken, token, amount);
        return IStaticAToken(token).deposit(recipient, amount, 0, true);
    }

    /// @inheritdoc ITokenAdapter
    function unwrap(uint256 amount, address recipient) external override returns (uint256) {
        TokenUtils.safeTransferFrom(token, msg.sender, address(this), amount);
        (uint256 amountBurnt, uint256 amountWithdrawn) = IStaticAToken(token).withdraw(recipient, amount, true);
        if (amountBurnt != amount) {
           revert IllegalState();
        }
        return amountWithdrawn;
    }
} 