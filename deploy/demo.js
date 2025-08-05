const deploy = async ({ midl }) => {
    console.log("Starting deployment process...");

    await midl.initialize();
    const config = await midl.getConfig();
    console.log("config", config);
    const owner = midl.getEVMAddress();
    console.log("owner", owner);

    await midl.execute();
};

deploy.tags = ["NewBimaWrappedCollateralFactory", "Demo"];

module.exports = deploy;
