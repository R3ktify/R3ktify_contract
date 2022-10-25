import { expect } from "chai";
import { ethers } from "hardhat";
// eslint-disable-next-line node/no-missing-import
import { R3ktify } from "../typechain-types/contracts/r3ktify.sol/R3ktify";

let r3ktify: R3ktify;
const PROJECT_ROLE = ethers.utils.solidityKeccak256(
  ["string"],
  ["PROJECT_ROLE"]
);

const R3KTIFIER_ROLE = ethers.utils.solidityKeccak256(
  ["string"],
  ["R3KTIFIER_ROLE"]
);

describe("r3ktifier", function () {
  it("Should return the new greeting once it's changed", async function () {
    const [operator] = await ethers.getSigners();
    const R3ktify = await ethers.getContractFactory("R3ktify");
    const _r3ktify = await R3ktify.deploy();
    r3ktify = await _r3ktify.deployed();

    expect(await r3ktify.owner()).to.equal(operator.address);
  });

  it("Should register a PROJECT", async function () {
    const [operator, project] = await ethers.getSigners();
    const assignRole = await r3ktify
      .connect(operator)
      .register("PROJECT", project.address);
    await assignRole.wait();

    // const PROJECT_ROLE = String(
    //   ethers.utils.solidityKeccak256(["string"], ["PROJECT_ROLE"])
    // );

    // console.log(PROJECT_ROLE);

    expect(await r3ktify.hasRole(PROJECT_ROLE, project.address)).to.equal(true);
  });

  it("Should register a r3ktifier", async function () {
    const [operator, , r3ktifier] = await ethers.getSigners();
    await r3ktify.connect(operator).register("R3KTIFIER", r3ktifier.address);
  });

  it("Should create a bounty", async function () {
    const [, project] = await ethers.getSigners();

    await r3ktify.connect(project).createBounty("aaa", [1, 2, 3, 4, 5]);
  });

  it("Should allow r3ktifier to submit a report", async function () {
    const [, project, r3ktifier] = await ethers.getSigners();
    await r3ktify.connect(r3ktifier).submitReport(0, project.address, "bbb", 0);
  });

  it("Should not allow non-r3ktifier to submit a report", async function () {
    const [, project] = await ethers.getSigners();

    await expect(
      r3ktify.connect(project).submitReport(0, project.address, "bbb", 0)
    ).to.be.revertedWith("Not a R3KTIFIER");
  });

  // it("Should check role", async function () {
  //   const [, project, r3ktifier] = await ethers.getSigners();
  //   const check = await r3ktify.hasRole(PROJECT_ROLE, project.address);
  //   const role = await r3ktify.PROJECT_ROLE();
  //   console.log("Check: ", check);
  //   console.log("Role: ", role);
  //   console.log(PROJECT_ROLE === role);
  // });
});
