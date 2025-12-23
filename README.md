# Prediction Market Protocol

A modular, permissionless protocol for creating and trading on prediction markets. The protocol supports collateral management, outcome tokens, and flexible oracle integration.

## Architecture

The protocol is organized into several key modules:

### Core Logic
Handles market creation, registration, and metadata management.
- `MarketRegistry`: The central source of truth for all markets.
- `MarketFactory`: Facilitates permissionless market creation.
- `MarketTypes`: Common data structures used across the system.

### Outcome Tokens
Shares in a market outcome are represented as ERC20 tokens.
- `OutcomeToken`: Individual tokens for each possible outcome.
- `OutcomeTokenFactory`: Deploys outcome tokens for new markets.

### Vault and Accounting
Manages collateral safety and internal balance tracking.
- `CollateralVault`: Securely holds underlying assets (e.g., USDC).
- `VaultAccounting`: Tracks market-specific liquidity and payouts.

### Oracle System
Abstracted interface for various resolution mechanisms.
- `IOracle`: Standard interface for all oracle adapters.
- `OptimisticOracleAdapter`: Integration with decentralized oracle systems (e.g., UMA).
- `ManualOracle`: Permissioned resolution for specific use cases.

### Settlement and Trading
Handles the lifecycle of a market from trading to resolution.
- `SettlementEngine`: Manages final payouts and token redemptions.
- `AtomicSwap`: Basic mechanism for minting/burning outcome tokens against collateral.

---

## Getting Started

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Installation
```bash
git clone <repository-url>
cd prediction-market-protocol
forge install
```

### Build
```bash
forge build
```

### Test
```bash
forge test
```

## Directory Structure

```text
prediction-market-protocol/
├── src/
│   ├── core/          # Registry and Factory logic
│   ├── outcome/       # ERC20 Outcome tokens
│   ├── settlement/    # Payout and trading logic
│   ├── vault/         # Collateral management
│   ├── oracle/        # Oracle adapters
│   ├── fees/          # Fee collection and management
│   ├── governance/    # Protocol administration
│   └── libs/          # Shared utilities
├── test/              # Test suite
└── script/            # Deployment scripts
```

## License

MIT
