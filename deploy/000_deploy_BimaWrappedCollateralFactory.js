const deploy = async ({ midl }) => {
    console.log("Starting deployment process...");

    await midl.initialize();
    await midl.deploy("BimaWrappedCollateralFactory", { args: [] });

    await midl.execute();
};

deploy.tags = ["main", "BimaWrappedCollateralFactory"]; 

module.exports = deploy;