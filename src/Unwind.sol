import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {DataTypes} from "aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";
import {IFlashLoanSimpleReceiver, IPoolAddressesProvider} from "aave-v3-core/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";

using SafeTransferLib for ERC20;

interface IFlashLoanRecipient {
    /**
     * @dev When `flashLoan` is called on the Vault, it invokes the `receiveFlashLoan` hook on the recipient.
     *
     * At the time of the call, the Vault will have transferred `amounts` for `tokens` to the recipient. Before this
     * call returns, the recipient must have transferred `amounts` plus `feeAmounts` for each token back to the
     * Vault, or else the entire flash loan will revert.
     *
     * `userData` is the same value passed in the `IVault.flashLoan` call.
     */
    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external;
}

interface IVault {
    function flashLoan(
        IFlashLoanRecipient recipient,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external;
}

contract Unwind is IFlashLoanRecipient, IFlashLoanSimpleReceiver {
    error InsufficientOutput(address _token, uint _expected, uint _actual);

    IVault constant vault = IVault(0xad68ea482860cd7077a5D0684313dD3a9BC70fbB);
    IPool constant pool = IPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);

    bool initiated = false;
    address caller = address(0);

    function unwind(
        address _debtToken,
        uint _debtToRepay,
        uint _rateMode,
        address _collToken,
        uint _collToWithdraw,
        address _swapper,
        bytes calldata _swapData
    ) external initiate withCaller {
        // _balancerFlashLoan(_debtToken, _debtToRepay);
        _aaveV3FlashLoan(_debtToken, _debtToRepay);
    }

    function _aaveV3FlashLoan(address _debtToken, uint _debtToRepay) internal {
        pool.flashLoanSimple(
            address(this),
            _debtToken,
            _debtToRepay,
            msg.data[4:],
            0
        );
    }

    function _balancerFlashLoan(
        address _debtToken,
        uint _debtToRepay
    ) internal {
        address[] memory tokens = new address[](1);
        tokens[0] = _debtToken;
        uint[] memory amounts = new uint[](1);
        amounts[0] = _debtToRepay;
        vault.flashLoan(
            IFlashLoanRecipient(this),
            tokens,
            amounts,
            msg.data[4:]
        );
    }

    function _afterFlashLoan(
        address _flashBorrowedAsset,
        uint _flashBorrowedAmount,
        uint _flashBorrowFee,
        address _borrowedFrom,
        bytes calldata userData
    ) internal {
        (
            address _debtToken,
            uint _debtToRepay,
            uint _rateMode,
            address _collToken,
            uint _collToWithdraw,
            address _swapper,
            bytes memory _swapData
        ) = abi.decode(
                userData,
                (address, uint, uint, address, uint, address, bytes)
            );

        // repay debt with flashloaned assets
        ERC20(_debtToken).safeApprove(address(pool), _debtToRepay);
        pool.repay(_debtToken, _debtToRepay, _rateMode, caller);

        // pull aToken from user, withdraw collateral, and transfer back the remainder
        DataTypes.ReserveData memory assetReserveData = pool.getReserveData(
            _collToken
        );
        ERC20 collateralAToken = ERC20(assetReserveData.aTokenAddress);
        collateralAToken.safeTransferFrom(
            caller,
            address(this),
            _collToWithdraw
        );
        pool.withdraw(_collToken, _collToWithdraw, address(this));
        collateralAToken.safeTransfer(
            caller,
            collateralAToken.balanceOf(address(this))
        );

        // swap the collateral for debt token
        uint totalRepay = _flashBorrowedAmount + _flashBorrowFee;
        ERC20(_collToken).safeApprove(_swapper, _collToWithdraw);
        (bool success, ) = _swapper.call(_swapData);
        if (ERC20(_debtToken).balanceOf(address(this)) < totalRepay)
            revert InsufficientOutput(
                _debtToken,
                totalRepay,
                ERC20(_debtToken).balanceOf(address(this))
            );

        // repay the flashloan
        ERC20(_debtToken).safeApprove(address(pool), totalRepay);
        // ERC20(_debtToken).safeTransfer(_borrowedFrom, totalRepay);

        // transfer back the remainders to the caller
        ERC20(_debtToken).safeTransfer(
            caller,
            ERC20(_debtToken).balanceOf(address(this)) - totalRepay
        );
        ERC20(_collToken).safeTransfer(
            caller,
            ERC20(_collToken).balanceOf(address(this))
        );
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes calldata userData
    ) external override onlyInitiated {
        require(msg.sender == address(vault), "Unwind: unauthorized");
        require(
            tokens.length == amounts.length &&
                tokens.length == feeAmounts.length,
            "Unwind: invalid arrays"
        );

        _afterFlashLoan(
            tokens[0],
            amounts[0],
            feeAmounts[0],
            address(vault),
            userData
        );
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external override onlyInitiated returns (bool) {
        require(msg.sender == address(pool), "Unwind: unauthorized");
        require(initiator == address(this), "Unwind: unauthorized");

        _afterFlashLoan(asset, amount, premium, initiator, params);
        return true;
    }

    function ADDRESSES_PROVIDER()
        external
        view
        returns (IPoolAddressesProvider)
    {
        return pool.ADDRESSES_PROVIDER();
    }

    function POOL() external view returns (IPool) {
        return pool;
    }

    modifier initiate() {
        require(!initiated, "Unwind: already initiated");
        initiated = true;
        _;
        initiated = false;
    }

    modifier onlyInitiated() {
        require(initiated, "Unwind: not initiated");
        _;
    }

    modifier withCaller() {
        require(caller == address(0), "Unwind: already called");
        caller = msg.sender;
        _;
        caller = address(0);
    }
}
