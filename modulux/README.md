# Modulux

A modular automated market maker (AMM) protocol built on Stacks blockchain using Clarity smart contracts. Modulux provides a component-based architecture for decentralized token swapping and liquidity provision with a 0.3% system fee.

## Features

### Core Functionality
- **Token Swapping**: Bi-directional token exchanges (Component A ↔ Component B)
- **Liquidity Management**: Add and remove liquidity with proportional share allocation
- **Modular Design**: Component-based architecture for flexibility and upgradability
- **Activity Logging**: Comprehensive transaction history tracking
- **Fee Structure**: Built-in 0.3% fee on all swaps

### Key Components
- **System Administration**: Centralized admin controls for system management
- **Component State Modules**: Track reserves and share distributions
- **Calculation Engine**: Automated pricing using constant product formula
- **Activity Logger**: Transaction history and audit trail
- **Interface Protocol**: Standardized token interface compatibility

## Architecture

### Component Interface
The system uses a trait-based interface that requires tokens to implement:
- `transfer`: Token transfer functionality
- `get-name`: Token name retrieval
- `get-symbol`: Token symbol retrieval  
- `get-decimals`: Decimal precision
- `get-balance`: Balance queries
- `get-total-supply`: Total supply information
- `get-token-uri`: Token metadata URI

### State Management
- **Component A Reserve**: STX token reserve
- **Component B Reserve**: Custom token reserve
- **Share Distribution**: LP token allocation mapping
- **Activity Logs**: Historical transaction data

## Usage

### Initialize System
```clarity
(initialize-system interface component-a-init component-b-init)
```
Sets up the AMM with initial liquidity for both tokens.

### Add Liquidity
```clarity
(extend-system interface component-a-amount component-b-amount min-share-allocation)
```
Adds liquidity to existing pools with proportional share allocation.

### Remove Liquidity
```clarity
(contract-system interface share-allocation min-component-a min-component-b)
```
Removes liquidity and withdraws proportional amounts of both tokens.

### Token Swaps
```clarity
;; STX → Token
(process-a-to-b-flow interface component-a-input min-component-b-output)

;; Token → STX  
(process-b-to-a-flow interface component-b-input min-component-a-output)
```

### Query Functions
```clarity
(query-component-reserves)      ;; Get current reserves
(query-share-balance holder)    ;; Get LP token balance
(query-total-shares)           ;; Get total LP tokens
(query-system-status)          ;; Check if system is active
```

## Error Codes

| Code | Description |
|------|-------------|
| 700 | Unauthorized access |
| 701 | Insufficient reserves/depleted |
| 702 | Invalid input parameters |
| 703 | Slippage tolerance exceeded |
| 704 | Component interface mismatch |
| 705 | Execution error |
| 706 | System already active |
| 707 | System not active |

## Security Features

- **Access Control**: Admin-only system initialization
- **Input Validation**: Comprehensive parameter checking
- **Slippage Protection**: Minimum output guarantees
- **Interface Verification**: Contract interface matching
- **State Consistency**: Atomic transaction processing

## Pricing Formula

Modulux uses the constant product formula with fees:
```
output = (input × 997 × output_reserve) / ((input_reserve × 1000) + (input × 997))
```

Where the 0.3% fee is built into the calculation (997/1000 ratio).

## Development

### Prerequisites
- Stacks blockchain environment
- Clarity development tools
- Compatible token contracts implementing the component interface

### Deployment
1. Deploy token contracts with required interface
2. Deploy Modulux AMM contract
3. Initialize system with initial liquidity
4. Configure component interface references
