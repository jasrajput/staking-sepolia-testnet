
async function main() {
    const [deployer] = await ethers.getSigners();
  
    console.log("Deploying contracts with the account:", await deployer.getAddress());
  
    // Deploying StakingPool contract
    const StakingPool = await ethers.getContractFactory("StakingPool"); // Replace with your contract name
    const stakingPool = await StakingPool.deploy(
      "0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0",
      1000,
      100,
      60000
    );
  
    await stakingPool.waitForDeployment();
  
    console.log("StakingPool contract deployed to:", await stakingPool.getAddress());
  }
  
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });