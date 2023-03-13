import {Unwind} from "src/Unwind.sol";
import {Script} from "forge-std/Script.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {Surl} from "surl/src/Surl.sol";
import {LibString} from "solady/utils/LibString.sol";
import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {stdJson} from "forge-std/StdJson.sol";

contract UnwindScript is Script, Test {
    ERC20 aAvaUSDC = ERC20(0x625E7708f30cA75bfd92586e17077590C60eb4cD);
    address USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
    address USDT = 0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7;
    address openOcean = 0x6352a56caadC4F1E25CD6c75970Fa768A3304e64;

    function run() external {
        vm.startBroadcast();
        Unwind unwind = new Unwind();
        aAvaUSDC.approve(address(unwind), type(uint).max);
        uint usdtAmount = 15600e6;
        uint usdcAmount = 15750e6;

        (address swapper, bytes memory swapData) = _getOdosSwapData(
            USDC,
            usdcAmount,
            USDT,
            address(unwind)
        );
        unwind.unwind(USDT, usdtAmount, 2, USDC, usdcAmount, swapper, swapData);
    }

    function _getOdosSwapData(
        address _tokenIn,
        uint _amountIn,
        address _tokenOut,
        address _receiver
    ) internal returns (address to, bytes memory ret) {
        string[] memory cmd = new string[](6);
        cmd[0] = "node";
        cmd[1] = "odos.js";
        cmd[2] = LibString.toHexStringChecksumed(_tokenIn);
        cmd[3] = LibString.toString(_amountIn);
        cmd[4] = LibString.toHexStringChecksumed(_tokenOut);
        cmd[5] = LibString.toHexStringChecksumed(_receiver);
        ret = vm.ffi(cmd);
        to = stdJson.readAddress(string(ret), ".transaction.to");
        ret = stdJson.readBytes(string(ret), ".transaction.data");

        // console.log(to, LibString.toHexString(ret));
    }

    function _getOpenOceanSwapData(
        address _tokenIn,
        uint _amountIn,
        address _tokenOut,
        address _receiver
    ) internal returns (bytes memory ret) {
        string memory url = _getSwapUrl(
            _tokenIn,
            _amountIn,
            _tokenOut,
            _receiver
        );
        uint status;
        console.log(url);
        (status, ret) = Surl.get(url);
        require(status == 200, "Surl.get failed");
        ret = stdJson.readBytes(string(ret), ".data.data");
    }

    function _getSwapUrl(
        address _tokenIn,
        uint _amountIn,
        address _tokenOut,
        address _receiver
    ) internal view returns (string memory url) {
        url = "https://open-api.openocean.finance/v3/avax/swap_quote?inTokenAddress=";
        url = string.concat(url, LibString.toHexStringChecksumed(_tokenIn));
        url = string.concat(url, "&outTokenAddress=");
        url = string.concat(url, LibString.toHexStringChecksumed(_tokenOut));
        url = string.concat(url, "&amount=");
        url = string.concat(url, LibString.toString(_amountIn / 1e6));
        url = string.concat(
            url,
            "&gasPrice=100000000000&slippage=0.5&account="
        );
        url = string.concat(url, LibString.toHexStringChecksumed(_receiver));
    }
}
