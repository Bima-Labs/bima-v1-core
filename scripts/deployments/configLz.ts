import { ethers } from "hardhat";

async function main() {


  const DEBT_TOKEN_ADDRESS ='' // contract address of debtToken  
  const ENCPOINT_CHAIN_ID = '' // Layer Zero Endpoint Id
  const ENDPOINT_PEER_ADDRESS = '' // byte32 of debtToken Address  

  const [owner] = await ethers.getSigners();
  const debtToken = await ethers.getContractAt("DebtToken",DEBT_TOKEN_ADDRESS);

  console.log("configuring Endpoint");
  const isconfig = await debtToken.isTrustedRemote(ENCPOINT_CHAIN_ID,ENDPOINT_PEER_ADDRESS);

  if (isconfig){
    console.log("The given Endpoint is allready configured as trusted remote");
  }else{
    const config = await debtToken.setTrustedRemote(ENCPOINT_CHAIN_ID,ENDPOINT_PEER_ADDRESS);
    console.log("Configured endpoint as trusted remote",config.hash);  
  }

  console.log("----Sending Tokens----");
  
  const tx = await debtToken.sendFrom(
    owner.address,
    ENCPOINT_CHAIN_ID,
    ENDPOINT_PEER_ADDRESS,
    ethers.parseEther("1"),
    owner.address,
    owner.address,
    "0x"
)

console.log("Tokens Transfered Successfully",tx.hash);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
