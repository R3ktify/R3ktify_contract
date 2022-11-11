// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";
import * as fs from "fs";
import path from "path";

async function main() {
  // Deploy VRFConsumer
  const _vrf = await ethers.getContractFactory("VRFv2Consumer");
  const vrf = await _vrf.deploy(2479);
  await vrf.deployed();
  console.log("Vrf address 🚀: ", vrf.address);

  // Deploy R3ktify contract
  const r3ktify = await ethers.getContractFactory("R3ktify");
  const R3ktify = await r3ktify.deploy(vrf.address);
  await R3ktify.deployed();
  console.log("R3ktify deployed 🚀: ", R3ktify.address);

  const DeploymentInfo = `
    export const VRFConsumerAddress = "${vrf.address}"
    export const R3ktifyAddress = "${R3ktify.address}"
  `;

  console.log("Saving addresses to cache/mumbai_deploy.ts");
  const data = JSON.stringify(DeploymentInfo);
  fs.writeFileSync(
    path.resolve(__dirname, "../cache/mumbai_deploy.ts"),
    JSON.parse(data)
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
