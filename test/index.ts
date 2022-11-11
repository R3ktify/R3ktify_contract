import { expect } from "chai";
import { ethers } from "hardhat";
import moment from "moment";
// eslint-disable-next-line node/no-missing-import
import { R3ktify } from "../typechain-types/contracts/r3ktify.sol/R3ktify";

let r3ktify: R3ktify;
let vrf: any;
const PROJECT_ROLE = ethers.utils.solidityKeccak256(
  ["string"],
  ["PROJECT_ROLE"]
);

const R3KTIFIER_ROLE = ethers.utils.solidityKeccak256(
  ["string"],
  ["R3KTIFIER_ROLE"]
);

function convertInput(date: string) {
  const splitDate: any = date.split(" ");
  const value: number = parseInt(splitDate[0]);
  const interval: any = splitDate[1];

  const epoch = moment(new Date()).add(value, interval).toDate();
  const _epoch = moment(epoch).unix();

  return _epoch;
}

describe("VRF", function () {
  it("Should deploy the VRF", async function () {
    const [operator] = await ethers.getSigners();
    const VRF = await ethers.getContractFactory("VRFv2Consumer");
    const _vrf = await VRF.deploy(1);
    vrf = await _vrf.deployed();

    expect(await vrf.owner()).to.equal(operator.address);
  });
});

describe("r3ktifier", function () {
  it("Should return the new greeting once it's changed", async function () {
    const [operator] = await ethers.getSigners();
    const R3ktify = await ethers.getContractFactory("R3ktify");
    const _r3ktify = await R3ktify.deploy(vrf.address);
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

    await r3ktify
      .connect(project)
      .createBounty("aaa", [
        ethers.utils.parseUnits("1", "ether"),
        ethers.utils.parseUnits("2", "ether"),
        ethers.utils.parseUnits("3", "ether"),
        ethers.utils.parseUnits("4", "ether"),
        ethers.utils.parseUnits("5", "ether"),
      ]);
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

  it("Should allow project to validate a report", async function () {
    const [, project] = await ethers.getSigners();

    await r3ktify.connect(project).validateReport(0, 0, "bbb", true, 3);
  });

  it("Should get report data", async function () {
    const report = await r3ktify.reports(0, 0);

    expect(report.level).to.be.equal(3);
  });

  it("Should allow rewarding of r3ktifier", async function () {
    const [, project] = await ethers.getSigners();
    const reward: any = ethers.utils.parseUnits("4", "ether");
    const projectBalance = Number(
      ethers.utils.formatEther(await project.getBalance())
    );

    await r3ktify
      .connect(project)
      .rewardR3ktifier(project.address, 0, 0, { value: reward });

    expect(projectBalance - reward).to.be.lessThan(projectBalance);
  });

  it("All get endpoints", async function () {
    const [, project] = await ethers.getSigners();
    const bounties = await r3ktify.getAllBountiesForAddress(project.address);
    const allProjects = await r3ktify.getAllProjects();
    const reports = await r3ktify.connect(project).getReports(0);

    console.log(`Bounties for ${project.address}: `, bounties);
    console.log("All projects: ", allProjects);
    console.log("All reports: ", reports);
  });
});

describe("r3ktifier bans", function () {
  it("Should ban r3ktifier and prevent submission", async function () {
    const [operator, project, r3ktifier] = await ethers.getSigners();
    const banTime = await convertInput("25 hours");
    //  initiate ban
    const ban = await r3ktify
      .connect(operator)
      .temporaryBan(r3ktifier.address, banTime);
    ban.wait();

    // try to submit a report with banned account
    await expect(
      r3ktify.connect(r3ktifier).submitReport(0, project.address, "bbb", 0)
    ).to.be.revertedWith("Account temporarily banned");
  });

  it("Should fail to ban a banned account", async function () {
    const [operator, , r3ktifier] = await ethers.getSigners();
    const banTime = await convertInput("25 hours");
    // try to initiate ban
    await expect(
      r3ktify.connect(operator).temporaryBan(r3ktifier.address, banTime)
    ).to.be.revertedWith("Already on temporary ban");
  });

  it("Should not allow banned (TEMPORARY) account to submit report", async function () {
    it("Should not allow non-r3ktifier to submit a report", async function () {
      const [, project] = await ethers.getSigners();

      await expect(
        r3ktify.connect(project).submitReport(0, project.address, "bbb", 0)
      ).to.be.revertedWith("Account temporarily banned");
    });
  });

  it("Should not allow lifting of ban until cooldown is over", async function () {
    const [operator, , r3ktifier] = await ethers.getSigners();

    await expect(
      r3ktify.connect(operator).liftBan(r3ktifier.address)
    ).to.be.revertedWith("Ban still active");
  });
});
