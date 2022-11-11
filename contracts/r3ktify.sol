//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

// import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

interface VRFConsumer {
    function getRequestStatusForLastRequest()
        external
        view
        returns (uint256[] memory randomWords);
}

contract R3ktify is Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private roundId;
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

    // temporary ban time
    uint256 public constant TEMPORARY_BAN_TIME = 24 hours;

    // VRFConsumer
    VRFConsumer public _vrfConsumer;

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
        string bountyURI;
    }

    // array
    address[] public projectAddresses;
    // ProjectBounty[] public projectBounties;

    // mappings
    mapping(address => bytes32) private _roles;
    mapping(address => uint256) private _banTime;
    mapping(address => mapping(uint256 => ProjectBounty)) public bounties;
    mapping(uint256 => Report[]) public reports;
    mapping(uint256 => ProjectBounty) public projectBounties;

    // events
    event RewardedR3ktifier(
        uint256 indexed bountyId,
        uint256 reportId,
        address indexed r3ktifier,
        address indexed project
    );

    event LiftBan(uint256 blocktime, address indexed offender, address amdin);

    event BountyCreated(
        string bountyURI,
        uint256 bountyId,
        address indexed _projectAddress
    );

    event ReportSubmitted(
        uint256 indexed bountyId,
        string reportURI,
        address indexed r3ktifierAddress
    );

    event ValidatedReport(
        uint256 indexed bountyId,
        uint256 indexed reportId,
        string _reportURI,
        bool _valid
    );

    uint256 internal immutable projectGroupId = 1;
    uint256 internal immutable r3ktifierGroupId = 2;

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
        // revert if msg.sender is banned
        require(
            !hasRole(TEMPORARY_BAN_ROLE, account),
            "Account temporarily banned"
        );
        require(
            !hasRole(PERMANENT_BAN_ROLE, account),
            "Account permanently banned"
        );
        // revert if msg.sender is not a R3ktifier
        require(hasRole(R3KTIFIER_ROLE, account), "Not a R3KTIFIER");
        _;
    }

    constructor(address _vrfAddress) {
        setAdminRole(ADMIN_ROLE, msg.sender);
        _vrfConsumer = VRFConsumer(_vrfAddress);
    }

    function register(string memory accountType, address accountAddress)
        public
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
            !hasRole(PROJECT_ROLE, accountAddress) ||
                !hasRole(R3KTIFIER_ROLE, accountAddress),
            "Already registered"
        );

        if (_accountType == PROJECT) {
            // add msg.sender to projects array
            _roles[accountAddress] = PROJECT_ROLE;
            projectAddresses.push(accountAddress);

            emit RoleGranted(PROJECT_ROLE, msg.sender, address(this));
        } else {
            // add the user to the registeredR3ktifiers and set role
            _roles[accountAddress] = R3KTIFIER_ROLE;

            emit RoleGranted(R3KTIFIER_ROLE, accountAddress, msg.sender);
        }
    }

    function createBounty(
        string memory bountyURI,
        uint256[5] calldata _rewardBreakdown
    ) public onlyProjectRole(address(msg.sender)) {
        // revert if uri = empty string and rewardBreakdown has 6 values
        require(bytes(bountyURI).length != 0, "Project URI needed");
        require(_rewardBreakdown.length == 5, "5 reward values needed");

        // set Project bounty values
        uint256 currentBountyId = generateId();
        ProjectBounty memory _projectBounty = ProjectBounty({
            bountyId: currentBountyId,
            submissionCount: 0,
            rewardBreakdown: _rewardBreakdown,
            bountyURI: bountyURI
        });

        // write bounty to storage
        bounties[address(msg.sender)][currentBountyId] = _projectBounty;
        projectBounties[currentBountyId] = _projectBounty;

        roundId.increment();

        emit BountyCreated(bountyURI, currentBountyId, msg.sender);
    }

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

        uint256 currentID = generateId();

        //  fill in report values
        Report memory _report = Report({
            reportId: currentID,
            rewardAmount: 0,
            reportUri: _reportURI,
            valid: false,
            r3ktifier: address(msg.sender),
            level: Severity(_severityLevel),
            status: RewardStatus.notRewarded
        });

        //  store in mapping in projectBounty
        reports[bountyId].push(_report);
        _reportId.increment();

        emit ReportSubmitted(bountyId, _reportURI, msg.sender);
    }

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

        emit ValidatedReport(bountyId, reportId, _reportURI, _valid);
    }

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

        reports[bountyId][reportId] = _tempReport;

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

    function getAllBountyForAddress(address _projectBounty, uint256 bountyId)
        public
        view
        returns (ProjectBounty memory)
    {
        return bounties[_projectBounty][bountyId];
    }

    function getAllProjects() public view returns (address[] memory) {
        return projectAddresses;
    }

    function getReports(uint256 bountyId)
        public
        view
        onlyProjectRole(address(msg.sender))
        returns (Report[] memory)
    {
        return reports[bountyId];
    }

    function generateId() private returns (uint256) {
        // get randomness value
        uint256[] memory randomWords = _vrfConsumer
            .getRequestStatusForLastRequest();

        uint8 index = uint8(random() % randomWords.length);

        uint256 randomness = (randomWords[index] % 999999) +
            100000 +
            index +
            roundId.current();

        return randomness;
    }

    function random() private returns (uint256) {
        roundId.increment();
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.difficulty,
                        block.timestamp,
                        roundId.current()
                    )
                )
            );
    }

    function permanentBan(address offenderAddress)
        public
        onlyAdminRole(msg.sender)
    {
        // set offender role
        _roles[offenderAddress] = PERMANENT_BAN_ROLE;
    }

    function temporaryBan(address offenderAddress, uint256 banDuration)
        public
        onlyAdminRole(msg.sender)
    {
        require(
            (banDuration - block.timestamp) > TEMPORARY_BAN_TIME,
            "Ban duration too short"
        );
        require(
            !hasRole(TEMPORARY_BAN_ROLE, offenderAddress),
            "Already on temporary ban"
        );
        // set offender role
        _roles[offenderAddress] = TEMPORARY_BAN_ROLE;
        _banTime[offenderAddress] = banDuration;
    }

    function liftBan(address offenderAddress) public onlyAdminRole(msg.sender) {
        require(
            hasRole(TEMPORARY_BAN_ROLE, offenderAddress),
            "Address not on temporary ban"
        );
        require(
            !hasRole(PERMANENT_BAN_ROLE, offenderAddress),
            "Permanent ban can't be lifted"
        );
        require(
            block.timestamp > _banTime[offenderAddress],
            "Ban still active"
        );

        _roles[offenderAddress] = R3KTIFIER_ROLE;

        emit LiftBan(block.timestamp, offenderAddress, msg.sender);
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return role == _roles[account];
    }

    function setAdminRole(bytes32 role, address account) private {
        _roles[account] = role;

        emit RoleGranted(role, account, msg.sender);
    }

    receive() external payable {}

    fallback() external payable {}
}
