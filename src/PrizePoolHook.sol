// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {CurrencyLibrary, Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDeltaLibrary, BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

import {Hooks} from "v4-core/libraries/Hooks.sol";
import {console} from "forge-std/console.sol";

contract PrizePoolHook is BaseHook, ERC20 {
	
	using CurrencyLibrary for Currency;
    using BalanceDeltaLibrary for BalanceDelta;

	// Initialize BaseHook and ERC20
    constructor(
        IPoolManager _manager,
        string memory _name,
        string memory _symbol
    ) BaseHook(_manager) ERC20(_name, _symbol, 18) {}

	// Set up hook permissions to return `true`
	// for the two hook functions we are using
    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterAddLiquidity: true,
                afterRemoveLiquidity: true,
                beforeSwap: false,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    // Before swap, we need to check if the swap is valid
    function beforeSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata swapParams,
        bytes calldata hookData
    ) external override onlyPoolManager returns (bytes4, BeforeSwapDelta, uint24) {
        return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

	// Stub implementation of `afterSwap`
	function afterSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata swapParams,
        BalanceDelta delta,
        bytes calldata hookData
    ) external override onlyPoolManager returns (bytes4, int128) {

		// If this is not an ETH-TOKEN pool with this hook attached, ignore
        if (!key.currency0.isAddressZero()) return (this.afterSwap.selector, 0);

        // We only mint points if user is buying TOKEN with ETH
        if (!swapParams.zeroForOne) return (this.afterSwap.selector, 0);

        // Mint points equal to 20% of the amount of ETH they spent
        // Since its a zeroForOne swap:
        // if amountSpecified < 0:
        //      this is an "exact input for output" swap
        //      amount of ETH they spent is equal to |amountSpecified|
        // if amountSpecified > 0:
        //      this is an "exact output for input" swap
        //      amount of ETH they spent is equal to BalanceDelta.amount0()

        uint256 amount0 = uint256(int256(-delta.amount0()));
        uint256 tioketsCount = amount0 / 5;

        // Mint the points
        _issueTickets(hookData, tioketsCount);

        return (this.afterSwap.selector, 0);
	}


	// After adding liquidity, mint points equal to the amount of ETH they added
	function afterAddLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta delta,
		BalanceDelta,
        bytes calldata hookData
    ) external override onlyPoolManager returns (bytes4, BalanceDelta) {

        // If this is not an ETH-TOKEN pool with this hook attached, ignore
        if (!key.currency0.isAddressZero()) return (this.afterSwap.selector, delta);

        // Mint points equivalent to how much ETH they're adding in liquidity
        uint256 ticketsCount = uint256(int256(-delta.amount0()));

        // Mint the points
        _issueTickets(hookData, ticketsCount);

        return (this.afterAddLiquidity.selector, delta);
    }

    // function afterRemoveLiquidity(
    //     address,
    //     PoolKey calldata key,
    //     IPoolManager.ModifyLiquidityParams calldata,
    //     BalanceDelta delta,
	// 	BalanceDelta,
    //     bytes calldata hookData
    // ) external override onlyPoolManager returns (bytes4, BalanceDelta) {

    //     if (!key.currency0.isAddressZero()) return (this.afterSwap.selector, delta);

    //     // uint256 ticketsCount = uint256(int256(-delta.amount0()));

    //     // Mint the points
    //     // _burnTickets(hookData, ticketsCount);

    //     return (this.afterAddLiquidity.selector, delta);
    // }

    function _issueTickets(bytes calldata hookData, uint256 tikets) internal {
        if (hookData.length == 0) return;
        address account = abi.decode(hookData, (address));
        if (account == address(0)) return;
        // Mint tickets
        _mint(account, tikets);
    }

    function _burnTickets(bytes calldata hookData, uint256 tikets) internal {
        if (hookData.length == 0) return;
        address account = abi.decode(hookData, (address));
        if (account == address(0)) return;
        // Burn the tickets
        _burn(account, tikets);
    }
}