// @ts-check
const axios = require("axios");

const getOdosSwapPath = async (tokenIn, amountIn, tokenOut, account) => {
	const data = {
		chainId: 43114,
		gasPrice: 30,
		inputTokens: [
			{
				amount: amountIn,
				tokenAddress: tokenIn
			}
		],
		outputTokens: [
			{
				proportion: 1,
				tokenAddress: tokenOut,
			}
		],
		slippageLimitPercent: 0.3,
		userAddr: account
	};
	const res = await axios.post("https://api.odos.xyz/sor/quote", data);
	// console.log("quote"); /
	// console.log(res.data);
	const res2 = await axios.post("https://api.odos.xyz/sor/assemble", { pathId: res.data.pathId, simulate: false, userAddr: account });
	return res2.data;
}


const main = async () => {
	const [tokenIn, amountIn, tokenOut, account] = process.argv.slice(-4);
	// console.log({tokenIn, amountIn, tokenOut, account});

	// console.log(res2.data);
	const ret = await getOdosSwapPath(tokenIn, amountIn, tokenOut, account);
	console.log(JSON.stringify(ret));
}

main();
