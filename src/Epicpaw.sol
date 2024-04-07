// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract EPICPAW is ERC20, Ownable, ReentrancyGuard, AccessControl {
    uint256 public constant MAX_SUPPLY = 10_000_000 * (10 ** 18);
    uint8 public constant DECIMALS = 18;

    uint256 public PRE_SALE_START_TIME = 1714482000;
    uint256 public PRE_SALE_END_TIME = 1719752400;
    uint256 public constant PRE_SALE_PRICE_IN_WEI = 170000000000000;

    uint256 public constant ICO_SUPPLY = 2_000_000 * (10 ** 18);
    uint256 public constant TEAM_SUPPLY = 2_000_000 * (10 ** 18);
    uint256 public constant INVESTOR_SUPPLY = 1_000_000 * (10 ** 18);
    uint256 public constant MARKETING_SUPPLY = 1_500_000 * (10 ** 18);
    uint256 public constant RESERVE_SUPPLY = 3_500_000 * (10 ** 18);

    uint256 public teamLockEndTime;
    uint256 public investorLockEndTime;
    bool public emergencyPaused;

    uint256 public constant TEAM_RELEASE_PERIOD = 90 days;
    uint256 public constant INVESTOR_RELEASE_PERIOD = 180 days;

    bytes32 public constant EMERGENCY_STOPPER_ROLE =
        keccak256("EMERGENCY_STOPPER_ROLE");

    mapping(address => bool) private blacklisted;

    event ICOFinished();
    event TeamTokensLocked(uint256 lockEndTime);
    event InvestorTokensLocked(uint256 lockEndTime);
    event TokensPurchased(address indexed buyer, uint256 amount, uint256 value);
    event EmergencyPaused(bool paused);
    event PreSaleTimeUpdated(uint256 newStartTime, uint256 newEndTime);
    event Blacklist(address indexed _address, bool _blacklisted);

    error SenderIsBlacklisted();
    error ReceiverIsBlacklisted();

    modifier onlyWhenNotPaused() {
        require(!emergencyPaused, "Contract is paused");
        _;
    }

    constructor() ERC20("EPICPAW", "EPIC") Ownable(msg.sender) {
        _mint(msg.sender, MAX_SUPPLY);
        _transfer(owner(), address(this), ICO_SUPPLY);
        // _transfer(owner(), owner(), MARKETING_SUPPLY);
        // _transfer(owner(), owner(), RESERVE_SUPPLY);
        teamLockEndTime = block.timestamp + 4 * 365 days;
        investorLockEndTime = block.timestamp + 2 * 365 days;
        grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        grantRole(EMERGENCY_STOPPER_ROLE, msg.sender);
    }

    function _update(address from, address to, uint256 value) internal override {
        if(blacklisted[from]) revert SenderIsBlacklisted();
        if(blacklisted[to]) revert ReceiverIsBlacklisted();
        super._update(from, to, value);
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function checkAndReleaseTeamTokens() external onlyOwner {
        require(
            teamLockEndTime != 0 && block.timestamp >= teamLockEndTime,
            "Team tokens are not locked or not yet releasable"
        );
        uint256 elapsedSinceLock = block.timestamp - teamLockEndTime;
        uint256 totalReleasePeriods = elapsedSinceLock / TEAM_RELEASE_PERIOD;
        if (totalReleasePeriods > 0) {
            uint256 tokensPerPeriod = TEAM_SUPPLY/16;
            uint256 tokensToRelease = totalReleasePeriods*tokensPerPeriod;
            tokensToRelease = min(tokensToRelease, TEAM_SUPPLY);
            _transfer(address(this), owner(), tokensToRelease);
            teamLockEndTime += totalReleasePeriods * TEAM_RELEASE_PERIOD;
        }
    }

    function checkAndReleaseInvestorTokens() public onlyOwner {
        require(
            investorLockEndTime != 0 && block.timestamp >= investorLockEndTime,
            "Investor tokens are not locked or not yet releasable"
        );
        uint256 elapsedSinceLock = block.timestamp - investorLockEndTime;
        uint256 totalReleasePeriods = elapsedSinceLock / INVESTOR_RELEASE_PERIOD;
        if (totalReleasePeriods > 0) {
            uint256 tokensPerPeriod = INVESTOR_SUPPLY / 4;
            uint256 tokensToRelease = totalReleasePeriods * tokensPerPeriod;
            tokensToRelease = min(tokensToRelease, INVESTOR_SUPPLY);
            _transfer(address(this), owner(), tokensToRelease);
            investorLockEndTime += totalReleasePeriods * INVESTOR_RELEASE_PERIOD;
        }
    }

    function buyTokens() external payable onlyWhenNotPaused nonReentrant {
        require(msg.value >= PRE_SALE_PRICE_IN_WEI, "Amount too low");
        require(
            block.timestamp >= PRE_SALE_START_TIME &&
                block.timestamp <= PRE_SALE_END_TIME,
            "Pre-Sale is not active"
        );

        uint256 amountToBuy = (msg.value * (10 ** DECIMALS)) /
            PRE_SALE_PRICE_IN_WEI;
        require(
            totalSupply() + amountToBuy <= MAX_SUPPLY,
            "Purchase exceeds max supply"
        );
        _mint(msg.sender, amountToBuy);
        emit TokensPurchased(msg.sender, amountToBuy, msg.value);
    }

    function emergencyPause(
        bool pause
    ) external onlyRole(EMERGENCY_STOPPER_ROLE) {
        emergencyPaused = pause;
        emit EmergencyPaused(pause);
    }

    function updatePreSaleTime(
        uint256 newStartTime,
        uint256 newEndTime
    ) external onlyOwner {
        require(newEndTime > newStartTime, "End time must be after start time");
        PRE_SALE_START_TIME = newStartTime;
        PRE_SALE_END_TIME = newEndTime;
        emit PreSaleTimeUpdated(newStartTime, newEndTime);
    }

    function burn(uint256 _amount) external onlyOwner {
        super._burn(msg.sender, _amount);
    }

    function mint(uint256 _amount) external onlyOwner {
        super._mint(msg.sender, _amount);
    }

    function addBlacklist(address _address) external onlyOwner {
        blacklisted[_address] = true;
        emit Blacklist(_address, true);
    }

    function removeBlacklist(address _address) external onlyOwner {
        blacklisted[_address] = false;
        emit Blacklist(_address, false);
    }

    function isBlacklisted(address _address) external view returns (bool) {
        return blacklisted[_address];
    }
}