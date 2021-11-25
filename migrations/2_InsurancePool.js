// ---------------------------- Load the Smart Contracts -------------------------------- //
const DegisToken = artifacts.require("DegisToken");
const LPToken = artifacts.require("LPToken"); // only deploy once
const InsurancePool = artifacts.require("InsurancePool");

const PolicyFlow = artifacts.require("PolicyFlow");
const PolicyToken = artifacts.require("PolicyToken"); // only deploy once
const EmergencyPool = artifacts.require("EmergencyPool");
const FlightOracle = artifacts.require("FlightOracle");
const SigManager = artifacts.require("SigManager");
const FarmingPool = artifacts.require("FarmingPool");

// ---------------------------- Const Addresses -------------------------------- //
const degis_rinkeby = "0x77E4DC6B670B618dfE00fea8AD36d445a48D0181";
const usdc_rinkeby = "0x4379a39c8Bd46D651eC4bdA46C32E2725b217860";

// This is my own address
const lottery_rinkeby = "0xe4387ce54d33B49c963cFC440cA110989CF6988f";

// Rinkeby VRF
const RINKEBY_VRF_COORDINATOR = "0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B";

// own oracle address, jobId is inside the contract
const RINKEBY_CHAINLINK_ORACLE = "0xD68a20bf40908Bb2a4Fa1D0A2f390AA4Bd128FBB"; //dzz
const RINKEBY_LINKTOKEN = "0x01be23585060835e02b77ef475b0cc51aa1e0709";
const RINKEBY_KEYHASH =
  "0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311";

const buyerToken = "0x4F99CE3294E7e650CEBb8f94e6cD7C629C4f494D";

const fs = require("fs");

module.exports = async function (deployer, network) {
  if (network.startsWith("rinkeby")) {
    // await deployer.deploy(MockUSD);
    await deployer.deploy(LPToken);
    await deployer.deploy(PolicyToken);

    await deployer.deploy(EmergencyPool, usdc_rinkeby);
    await deployer.deploy(
      InsurancePool,
      degis_rinkeby,
      EmergencyPool.address,
      LPToken.address,
      lottery_rinkeby,
      usdc_rinkeby
    );

    await deployer.deploy(SigManager);

    await deployer.deploy(
      PolicyFlow,
      InsurancePool.address,
      PolicyToken.address,
      SigManager.address,
      buyerToken
    );

    await deployer.deploy(FlightOracle, PolicyFlow.address);

    await deployer.deploy(FarmingPool, degis_rinkeby);

    const addressList = {
      LPToken: LPToken.address,
      PolicyToken: PolicyToken.address,
      EmergencyPool: EmergencyPool.address,
      InsurancePool: InsurancePool.address,
      PolicyFlow: PolicyFlow.address,
      SigManager: SigManager.address,
      FlightOracle: FlightOracle.address,
      FarmingPool: FarmingPool.address,
    };

    const data = JSON.stringify(addressList);

    fs.writeFile("address.json", data, (err) => {
      if (err) {
        throw err;
      }
    });
    // await deployer.deploy(PolicyToken, '0x8336b18796CAb07a4897Ea0F133f214F4B5D7378')
  } else if (network.startsWith("development")) {
    await deployer.deploy(MockUSD);
    await deployer.deploy(DegisToken);
    await deployer.deploy(LPToken);
    await deployer.deploy(EmergencyPool, MockUSD.address);
    await deployer.deploy(
      InsurancePool,
      DegisToken.address,
      EmergencyPool.address,
      LPToken.address,
      lottery_rinkeby,
      MockUSD.address
    );
  }
};
