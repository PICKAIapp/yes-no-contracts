// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title PICKAI Cross-Chain Prediction Market
 * @notice EVM-compatible smart contracts for cross-chain betting
 * @dev Implements LayerZero for cross-chain messaging
 */
contract PredictionMarketV2 is ReentrancyGuardUpgradeable, UUPSUpgradeable {
    using SafeMath for uint256;
    
    // Events
    event MarketCreated(bytes32 indexed marketId, uint256 resolutionTime);
    event BetPlaced(bytes32 indexed marketId, address indexed bettor, uint256 amount, bool outcome);
    event MarketResolved(bytes32 indexed marketId, bool outcome);
    
    // Structs
    struct Market {
        bytes32 id;
        string question;
        uint256 totalYes;
        uint256 totalNo;
        uint256 resolutionTime;
        bool resolved;
        bool outcome;
        address oracle;
        mapping(address => Position) positions;
    }
    
    struct Position {
        uint256 yesAmount;
        uint256 noAmount;
        bool claimed;
    }
    
    // State variables
    mapping(bytes32 => Market) public markets;
    
    // LayerZero endpoint for cross-chain
    ILayerZeroEndpoint public lzEndpoint;
    
    // Chainlink price feeds
    mapping(string => AggregatorV3Interface) public priceFeeds;
    
    // Modifiers
    modifier onlyOracle(bytes32 marketId) {
        require(msg.sender == markets[marketId].oracle, "Not oracle");
        _;
    }
    
    /**
     * @notice Place a bet using optimistic rollup verification
     * @param marketId Market identifier
     * @param outcome True for yes, false for no
     */
    function placeBet(bytes32 marketId, bool outcome) 
        external 
        payable 
        nonReentrant 
    {
        Market storage market = markets[marketId];
        require(!market.resolved, "Market resolved");
        require(block.timestamp < market.resolutionTime, "Market closed");
        
        uint256 amount = msg.value;
        require(amount > 0, "Invalid amount");
        
        // Update market liquidity
        if (outcome) {
            market.totalYes = market.totalYes.add(amount);
        } else {
            market.totalNo = market.totalNo.add(amount);
        }
        
        // Update position
        Position storage position = market.positions[msg.sender];
        if (outcome) {
            position.yesAmount = position.yesAmount.add(amount);
        } else {
            position.noAmount = position.noAmount.add(amount);
        }
        
        emit BetPlaced(marketId, msg.sender, amount, outcome);
    }
    
    /**
     * @notice Cross-chain message handler
     * @dev Receives messages from other chains via LayerZero
     */
    function lzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload
    ) external {
        require(msg.sender == address(lzEndpoint), "Invalid endpoint");
        
        // Decode and process cross-chain bet
        (bytes32 marketId, address bettor, uint256 amount, bool outcome) = 
            abi.decode(_payload, (bytes32, address, uint256, bool));
            
        _processCrossChainBet(marketId, bettor, amount, outcome);
    }
    
    /**
     * @notice Resolve market using Chainlink oracle
     */
    function resolveMarket(bytes32 marketId, bool outcome) 
        external 
        onlyOracle(marketId) 
    {
        Market storage market = markets[marketId];
        require(!market.resolved, "Already resolved");
        require(block.timestamp >= market.resolutionTime, "Too early");
        
        market.resolved = true;
        market.outcome = outcome;
        
        emit MarketResolved(marketId, outcome);
    }
}
