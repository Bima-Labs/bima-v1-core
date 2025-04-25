const { getBalance, getDefaultAccount } = require("@midl-xyz/midl-js-core");

async function main(hre) {
    // your deploy function code
    await hre.midl.initialize();
    const config = await hre.midl.getConfig();
    console.log("config", config);
    if (!config) {
        return null;
    }

    const account = await getDefaultAccount(config);

    const balance = await getBalance(config, account.address);
    console.log("balance", balance);
    console.log("account", account);
}

main(hre);
