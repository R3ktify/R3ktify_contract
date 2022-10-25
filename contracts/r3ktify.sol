//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

// import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract R3ktify is Ownable {
    // using ByteHasher for bytes;
    using Counters for Counters.Counter;
    Counters.Counter private _bountyId;
    Counters.Counter private _reportId;

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
    // IWorldID internal immutable worldId;

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
    struct Report {
        uint256 reportId;
        uint256 rewardAmount;
        string reportUri;
        bool valid;
        address r3ktifier;
        Severity level;
        RewardStatus status;
    }

    struct ProjectBounty {
        uint256 bountyId;
        uint256 submissionCount;
        uint256[5] rewardBreakdown;
        string projectURI;
    }

    // array
    address[] public projectAddresses;
    ProjectBounty[] public projectBounties;

    // mappings
    mapping(address => bytes32) private _roles;
    mapping(address => ProjectBounty[]) public bounties;
    mapping(uint256 => Report[]) public reports;
    mapping(address => bool) public registeredProjects;
    mapping(address => bool) public registeredR3ktifiers;

    // events
    event RewardedR3ktifier(
        uint256 bountyId,
        uint256 reportId,
        address r3ktifier,
        address project
    );

    // WorldID group IDs
    uint256 internal immutable projectGroupId = 1;
    uint256 internal immutable r3ktifierGroupId = 2;

    // errors
    // error alreadyRegistered;
    // error notAProject;
    // error notAR3ktifier;

    // events
    event RoleGranted(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );

    // modifiers
    modifier onlyAdminRole(address account) {
        // revert if msg.sender is not a Project
        require(hasRole(ADMIN_ROLE, account), "Not an ADMIN");
        _;
    }

    modifier onlyProjectRole(address account) {
        // revert if msg.sender is not a Project
        require(hasRole(PROJECT_ROLE, account), "Not a PROJECT");
        _;
    }

    modifier onlyR3ktifierRole(address account) {
        // revert if msg.sender is not a R3ktifier
        require(hasRole(R3KTIFIER_ROLE, account), "Not a R3KTIFIER");
        _;
    }

    constructor() {
        setAdminRole(ADMIN_ROLE, msg.sender);
    }

    // TODO: Implement register function, should accept accountType (project, r3ktifier)
    // TODO: and assign respective role to the account
    // address input,
    //     uint256 root,
    //     uint256 nullifierHash,
    //     uint256[8] calldata proof

    function register(string memory accountType, address accountAddress)
        public
        payable
        onlyAdminRole(msg.sender)
    {
        bytes32 _accountType = keccak256(abi.encodePacked(accountType));
        // require accountType is one of the accepted types
        require(
            _accountType == PROJECT || _accountType == R3KTIFIER,
            "Unknown account type"
        );

        // check if user is already registered, revert if true.
        require(
            !registeredProjects[accountAddress] ||
                !registeredR3ktifiers[accountAddress]
        );

        if (_accountType == PROJECT) {
            // verify user
            // worldId.verifyProof(
            //     root,
            //     projectGroupId,
            //     abi.encodePacked(input).hashToField(),
            //     nullifierHash,
            //     abi.encodePacked(address(this)).hashToField(),
            //     proof
            // );

            // add the user to the registeredProjects and set role
            registeredProjects[address(accountAddress)] = true;

            // add msg.sender to projects array
            _roles[accountAddress] = PROJECT_ROLE;
            projectAddresses.push(accountAddress);

            emit RoleGranted(PROJECT_ROLE, msg.sender, address(this));
        } else {
            // verify user
            // worldId.verifyProof(
            //     root,
            //     r3ktifierGroupId,
            //     abi.encodePacked(input).hashToField(),
            //     nullifierHash,
            //     abi.encodePacked(address(this)).hashToField(),
            //     proof
            // );

            // add the user to the registeredR3ktifiers and set role
            _roles[accountAddress] = R3KTIFIER_ROLE;
            registeredR3ktifiers[accountAddress] = true;

            emit RoleGranted(R3KTIFIER_ROLE, accountAddress, msg.sender);
        }
    }

    // TODO: Implement createBounty function (only PROJECT_ROLE)
    //? args = rewardBreakdown and projectURI
    function createBounty(
        string memory _projectURI,
        uint256[5] calldata _rewardBreakdown
    ) public onlyProjectRole(address(msg.sender)) {
        // revert if uri = empty string and rewardBreakdown has 6 values
        require(bytes(_projectURI).length != 0, "Project URI needed");
        require(_rewardBreakdown.length == 5, "5 reward values needed");

        // set Project bounty values
        uint256 currentBountyId = _bountyId.current();
        ProjectBounty memory _projectBounty = ProjectBounty({
            bountyId: currentBountyId,
            submissionCount: 0,
            rewardBreakdown: _rewardBreakdown,
            projectURI: _projectURI
        });

        // push to ProjectBounty array in mapping

        // write bounty to storage
        bounties[address(msg.sender)].push(_projectBounty);
        projectBounties.push(_projectBounty);

        // increment _bountyId
        _bountyId.increment();
    }

    // TODO: Implement submitReport function (only R3KTIFIER_ROLE).
    //? args = reportUri, r3ktifier address, and severity level

    function submitReport(
        uint256 bountyId,
        address projectAddress,
        string memory _reportURI,
        uint8 _severityLevel
    ) public onlyR3ktifierRole(msg.sender) {
        // revert if uri = empty string, _severityLevel out of Severity enum range
        require(bytes(_reportURI).length != 0, "Project URI needed");
        require(_severityLevel < 5, "Invalid severity level");
        require(
            projectBounties[bountyId].bountyId == bountyId,
            "Submitting to wrong project"
        );

        // increment number of submissions for projectBounty
        bounties[projectAddress][bountyId].submissionCount++;

        //  fill in report values
        Report memory _report = Report({
            reportId: _reportId.current(),
            rewardAmount: 0,
            reportUri: _reportURI,
            valid: false,
            r3ktifier: address(msg.sender),
            level: Severity(_severityLevel),
            status: RewardStatus.notRewarded
        });

        //  store in mapping in projectBounty
        reports[_reportId.current()].push(_report);

        // increment global report count
        _reportId.increment();
    }

    // TODO: Implement validate report function (only PROJECT_ROLE),
    // TODO: can update valid and severity fields.
    //? args = valid bool and severity level
    function validateReport(
        uint256 bountyId,
        uint256 reportId,
        string memory _reportURI,
        bool _valid,
        uint8 _severityLevel
    ) public onlyProjectRole(address(msg.sender)) {
        // fetch reports data
        Report storage _tempReport = reports[bountyId][reportId];

        require(
            keccak256(abi.encodePacked(_tempReport.reportUri)) ==
                keccak256(abi.encodePacked(_reportURI)),
            "Wrong report data"
        );
        require(_severityLevel < 5, "Invalid severity level");

        // update report data
        _tempReport.valid = _valid;
        _tempReport.level = Severity(_severityLevel);

        // set report to new copy with updated values
        reports[bountyId][reportId] = _tempReport;
    }

    // TODO: Implement rewardR3ktifier function (only PROJECT_ROLE),
    // TODO: recieve reward and reportID. Send reward to r3ktifier address and set rewardStatus to rewarded
    //? args = reportID (reward would be gotten via msg.value)
    function rewardR3ktifier(
        address projectAddress,
        uint256 bountyId,
        uint256 reportId
    ) public payable onlyProjectRole(address(msg.sender)) {
        // fetch reports data
        Report memory _tempReport = reports[bountyId][reportId];

        require(_tempReport.valid, "Report marked as invalid");
        require(
            !hasRole(TEMPORARY_BAN_ROLE, _tempReport.r3ktifier) ||
                !hasRole(PERMANENT_BAN_ROLE, _tempReport.r3ktifier),
            "R3ktifier temporarily/permanantly banned"
        );
        require(
            hasRole(R3KTIFIER_ROLE, _tempReport.r3ktifier),
            "Not a r3ktifier"
        );
        require(
            msg.value >=
                bounties[address(projectAddress)][bountyId].rewardBreakdown[
                    uint8(_tempReport.level)
                ],
            "Wrong reward for severity level"
        );

        // change report reward status
        _tempReport.rewardAmount = msg.value;
        _tempReport.status = RewardStatus.rewarded;

        // send reward to r3ktifier
        (bool sent, ) = _tempReport.r3ktifier.call{value: msg.value}("");
        require(sent, "Failed to reward r3ktifier");

        emit RewardedR3ktifier(
            bountyId,
            reportId,
            _tempReport.r3ktifier,
            address(projectAddress)
        );
    }

    // TODO: Impplement getAllBounties function
    function getAllBountiesForAddress(address _projectBounty)
        public
        view
        returns (ProjectBounty[] memory)
    {
        return bounties[_projectBounty];
    }

    function getAllProjects() public view returns (address[] memory) {
        return projectAddresses;
    }

    // TODO: Implement getReports function, (only PROJECT_ROLE),
    // TODO: and it should filter reports based on bountyID
    function getReports(uint256 bountyId)
        public
        view
        onlyProjectRole(address(msg.sender))
        returns (Report[] memory)
    {
        return reports[bountyId];
    }

    //! CONTROL FUNCTION
    //! Implement banR3ktifier function. Permananetly bans an address from the platform (set PERMANENT_BAN_ROLE)
    // function permanentBan(address offenderAddress) public onlyOwner {
    //     // revoke current role
    // }
    //! Implement restrictR3ktifier function. Temporarily bans an address from submitting reports for a given time (set TEMPORARY_BAN_ROLE)

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return role == _roles[account];
    }

    function setAdminRole(bytes32 role, address account) private {
        _roles[account] = role;

        emit RoleGranted(role, account, msg.sender);
    }
}
