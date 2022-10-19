//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract R3ktify is AccessControl {
    // roles
    bytes32 public constant PROJECT_ROLE = keccak256("PROJECT_ROLE");
    bytes32 public constant R3KTIFIER_ROLE = keccak256("R3KTIFIER_ROLE");
    bytes32 public constant PERMANENT_BAN_ROLE =
        keccak256("PERMANENT_BAN_ROLE");
    bytes32 public constant TEMPORARY_BAN_ROLE =
        keccak256("TEMPORARY_BAN_ROLE");

    // temporary ban time
    uint256 public constant TEMPORARY_BAN_TIME = 24 hours;

    // enums
    enum Severity {
        none,
        low,
        medium,
        high,
        critical
    }

    enum RewardStatus {
        notRewarded,
        rewarded
    }

    // Sturcts
    struct ProjectBounty {
        uint256 bountyId;
        uint256 submissionCount;
        uint256[5] rewardBreakdown;
        string projectURI;
    }

    struct Report {
        uint256 reportId;
        string reportUri;
        bool valid;
        address r3ktifier;
        Severity level;
        RewardStatus status;
    }

    // mappings
    mapping(address => mapping(uint256 => ProjectBounty)) public bounties;
    mapping(uint256 => Report[]) public reports;

    // TODO: Implement register function, should accept accountType (project, r3ktifier)
    // TODO: and assign respective role to the account

    // TODO: Implement createBounty function (only PROJECT_ROLE)
    //? args = rewardBreakdown and projectURI

    // TODO: Implement submitReport function (only R3KTIFIER_ROLE).
    //? args = reportUri, r3ktifier address, and severity level

    // TODO: Implement validate report function (only PROJECT_ROLE),
    // TODO: can update valid and severity fields.
    //? args = valid bool and severity level

    // TODO: Implement rewardR3ktifier function (only PROJECT_ROLE),
    // TODO: recieve reward and reportID. Send reward to r3ktifier address and set rewardStatus to rewarded
    //? args = reportID (reward would be gotten via msg.value)

    // TODO: Impplement getAllBounties function

    // TODO: Implement getReports function, (only PROJECT_ROLE),
    // TODO: and it should filter reports based on caller address

    //! CONTROL FUNCTION
    //! Implement banR3ktifier function. Permananetly bans an address from the platform (set PERMANENT_BAN_ROLE)
    //! Implement restrictR3ktifier function. Temporarily bans an address from submitting reports for a given time (set TEMPORARY_BAN_ROLE)
}
