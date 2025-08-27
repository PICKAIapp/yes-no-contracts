// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract YesNoMarket is ReentrancyGuard, Ownable {
    struct Market {
        string question;
        uint256 endTime;
        uint256 totalYesShares;
        uint256 totalNoShares;
        bool resolved;
        bool outcome;
        uint256 liquidity;
    }
    
    mapping(uint256 => Market) public markets;
    mapping(uint256 => mapping(address => uint256)) public yesBalances;
    mapping(uint256 => mapping(address => uint256)) public noBalances;
    
    uint256 public nextMarketId;
    IERC20 public immutable collateralToken;
    
    event MarketCreated(uint256 indexed marketId, string question, uint256 endTime);
    event SharesPurchased(uint256 indexed marketId, address indexed buyer, bool isYes, uint256 amount);
    event MarketResolved(uint256 indexed marketId, bool outcome);
    
    constructor(address _collateralToken) {
        collateralToken = IERC20(_collateralToken);
    }
    
    function createMarket(string memory _question, uint256 _endTime) external returns (uint256) {
        uint256 marketId = nextMarketId++;
        markets[marketId] = Market({
            question: _question,
            endTime: _endTime,
            totalYesShares: 0,
            totalNoShares: 0,
            resolved: false,
            outcome: false,
            liquidity: 0
        });
        
        emit MarketCreated(marketId, _question, _endTime);
        return marketId;
    }
    
    function buyShares(uint256 _marketId, bool _isYes, uint256 _amount) external nonReentrant {
        Market storage market = markets[_marketId];
        require(!market.resolved, "Market already resolved");
        require(block.timestamp < market.endTime, "Market expired");
        
        uint256 cost = calculateCost(_marketId, _isYes, _amount);
        require(collateralToken.transferFrom(msg.sender, address(this), cost), "Transfer failed");
        
        if (_isYes) {
            yesBalances[_marketId][msg.sender] += _amount;
            market.totalYesShares += _amount;
        } else {
            noBalances[_marketId][msg.sender] += _amount;
            market.totalNoShares += _amount;
        }
        
        emit SharesPurchased(_marketId, msg.sender, _isYes, _amount);
    }
    
    function calculateCost(uint256 _marketId, bool _isYes, uint256 _amount) public view returns (uint256) {
        Market memory market = markets[_marketId];
        // Implement LMSR (Logarithmic Market Scoring Rule) pricing
        // Simplified version for demonstration
        uint256 currentShares = _isYes ? market.totalYesShares : market.totalNoShares;
        return (_amount * (1e18 + currentShares)) / 1e18;
    }
}
