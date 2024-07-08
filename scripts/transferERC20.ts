// Import the required packages
const { ethers } = require("hardhat");

async function main() {
  // Specify the addresses and the amount to transfer
  const tokenAddress = "0xYourTokenAddress";
  const recipient = "0xRecipientAddress";
  const amount = ethers.utils.parseUnits("1.0", 18); // Adjust the amount and decimals

  // Get the signer (account) that will initiate the transfer
  const [signer] = await ethers.getSigners();

  // Connect to the ERC20 token contract
  const ERC20 = await ethers.getContractAt("IERC20", tokenAddress);

  // Check the signer's balance
  const balance = await ERC20.balanceOf(signer.address);
  console.log(`Sender balance: ${ethers.utils.formatUnits(balance, 18)}`);

  // Ensure the signer has enough tokens
  if (balance.lt(amount)) {
    console.log("Not enough balance to make the transfer.");
    return;
  }

  // Transfer the tokens
  const tx = await ERC20.transfer(recipient, amount);
  console.log("Transaction hash:", tx.hash);

  // Wait for the transaction to be mined
  await tx.wait();
  console.log("Transfer completed!");
}

// Run the main function and handle errors
main().catch((error) => {
  console.error("Error:", error);
  process.exit(1);
});
