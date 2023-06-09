# aave-unwind

## Contract

[`Unwind.sol`](./src/Unwind.sol) can be used by users to unwind their levered
positions by:
1. Flashloaning the debt/borrowed asset from Balancer/Aave-v3.
2. Repaying the debt with the flashloaned assets.
3. Withdrawing the freed up collateral.
4. Dumping the freed collateral for debt asset.
5. Repaying the flashloan from the swapped collateral.

This allows users to unwind their levered positions without looping through
number of withdraw collateral, swap, repay debt transaction cycles by utilizing
flashloans.

Note: Users have to approve their collateral aToken to the contract so it can
`tranferFrom` the user and withdraw the collateral.

At the end of `Unwind.unwind` transaction all the remainder collateral and debt
token assets are returned back to the user.

---

A similar contract and script can also be written for levering up. Maybe something for
future if I find some personal use for that case. New users can also just use something
like DefiSaver or InstaDapp DSAs to open/close levered positions. I personally needed
this script for an existing position on an EOA.

---

This repo can serve as a good example of how to integrate and utilize flashloans
securely with relevant checks on callbacks, forge FFI in scripts, and also generally
how you can use forge scripts to orchestrate actions from your EOAs too.

## Script

[`Unwind.s.sol`](./script/Unwind.s.sol) can be used by users to unwind their positions
as a series of necessary txs and encoding calldata, etc. It has code for using [OpenOcean](https://openocean.finance)
and [Odos](https://odos.xyz) aggregators and their APIs for figuring out the
swap paths for optimal collateral swap outputs. More aggregators can be
integrated similarly.

```bash
forge script ./script/Unwind.s.sol --rpc-url ... --private-key ... --broadcast
```
