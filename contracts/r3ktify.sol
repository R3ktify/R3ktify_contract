//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import {ByteHasher} from "./helpers/ByteHasher.sol";
import {IWorldID} from "./interfaces/IWorldID.sol";

contract R3ktify is AccessControl {
    using ByteHasher for bytes;
    using Counters for Counters.Counter;
    Counters.Counter private _bountyId;

    // roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PROJECT_ROLE = keccak256("PROJECT_ROLE");
    bytes32 public constant R3KTIFIER_ROLE = keccak256("R3KTIFIER_ROLE");
    bytes32 public constant PERMANENT_BAN_ROLE =
        keccak256("PERMANENT_BAN_ROLE");
    bytes32 public constant TEMPORARY_BAN_ROLE =
        keccak256("TEMPORARY_BAN_ROLE");

    // account types
    bytes32 public constant PROJECT = keccak256("PROJECT");
    bytes32 public constant R3KTIFIER = keccak256("R3KTIFIER");

    // immutables
    IWorldID internal immutable worldId;

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
    mapping(address => bool) public registeredProjects;
    mapping(address => bool) public registeredR3ktifiers;

    // WorldID group IDs
    uint256 internal immutable projectGroupId = 1;
    uint256 internal immutable r3ktifierGroupId = 2;

    // errors
    error alreadyRegistered();
    error notAProject();

    constructor(IWorldID _worldID) {
        // set contract as admin for AccessControl
        _setupRole(ADMIN_ROLE, address(this));
        worldId = _worldID;
    }

    // TODO: Implement register function, should accept accountType (project, r3ktifier)
    // TODO: and assign respective role to the account

    function register(
        bytes32 accountType,
        address input,
        uint256 root,
        uint256 nullifierHash,
        uint256[8] calldata proof
    ) public {
        // require accountType is one of the accepted types
        require(
            accountType == PROJECT || accountType == R3KTIFIER,
            "Unknown account type"
        );

        // check if user is already registered, revert if true.
        if (
            registeredProjects[address(msg.sender)] ||
            registeredR3ktifiers[address(msg.sender)]
        ) revert alreadyRegistered();

        if (accountType == PROJECT) {
            // verify user
            worldId.verifyProof(
                root,
                projectGroupId,
                abi.encodePacked(input).hashToField(),
                nullifierHash,
                abi.encodePacked(address(this)).hashToField(),
                proof
            );

            // add the user to the registeredProjects and set role
            grantRole(PROJECT_ROLE, address(msg.sender));
            registeredProjects[address(msg.sender)] = true;
        } else {
            // check if user is already registered
            if (registeredR3ktifiers[address(msg.sender)])
                revert alreadyRegistered();

            // verify user
            worldId.verifyProof(
                root,
                r3ktifierGroupId,
                abi.encodePacked(input).hashToField(),
                nullifierHash,
                abi.encodePacked(address(this)).hashToField(),
                proof
            );

            // add the user to the registeredR3ktifiers and set role
            grantRole(R3KTIFIER_ROLE, address(msg.sender));
            registeredR3ktifiers[address(msg.sender)] = true;
        }
    }

    // TODO: Implement createBounty function (only PROJECT_ROLE)
    //? args = rewardBreakdown and projectURI
    function createBounty(
        string memory _projectURI,
        uint256[5] calldata _rewardBreakdown
    ) public {
        require(bytes(_projectURI).length != 0, "Project URI needed");
        require(_rewardBreakdown.length == 6, "6 reward values needed");

        // revert is msg.sender is not a project
        if (!hasRole(PROJECT_ROLE, address(msg.sender))) revert notAProject();

        // set Project bounty values
        uint256 currentBountyId = _bountyId.current();
        ProjectBounty memory _projectBounty = bounties[address(msg.sender)][
            currentBountyId
        ];

        // fill in values
        _projectBounty.bountyId = currentBountyId;
        _projectBounty.projectURI = _projectURI;
        _projectBounty.rewardBreakdown = _rewardBreakdown;

        // write bounty to storage
        bounties[address(msg.sender)][currentBountyId] = _projectBounty;

        // increment _bountyId
        _bountyId.increment();
    }

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
