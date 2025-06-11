# CollabraChain Smart Contracts

CollabraChain is a decentralized platform for managing freelance projects, milestone-based payments, and on-chain reputation using Soul-Bound Tokens (SBTs). This repository contains the core smart contracts and deployment scripts for the CollabraChain protocol.

## Features

- **Project Factory:** Deploys and manages freelance project contracts.
- **Project Contracts:** Handle milestone-based payments, dispute resolution, and project completion.
- **Reputation System:** Issues non-transferable ERC721 SBTs to freelancers upon successful project completion.
- **USDC Payments:** All payments are handled in USDC (configurable).

## Contracts Overview

### 1. CollabraChainReputation

- ERC721-based Soul-Bound Token (SBT) contract.
- Mints non-transferable reputation tokens to freelancers after project completion.
- Each token is linked to a project and includes a metadata URI.

### 2. CollabraChainFactory

- Deploys new `CollabraChainProject` contracts.
- Tracks all projects, and projects by client/freelancer.
- Manages agent/admin roles for project creation.

### 3. CollabraChainProject

- Represents a freelance project with milestone-based payments.
- Handles project funding, milestone approval, payment release, and dispute resolution.
- On full completion, mints a reputation SBT to the freelancer.

## Directory Structure

```
src/
  CollabraChainReputation.sol
  CollabraChainFactory.sol
  CollabraChainProject.sol
  Interface.sol
script/
  DeployAll.s.sol         # Deploys all core contracts
out/                      # Compiled contract artifacts
test/                     # (Add your tests here)
lib/
  openzeppelin-contracts/ # OpenZeppelin v5.3.0
  forge-std/              # Forge Standard Library v1.9.7
```

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/) (for `forge` and `cast`)
- Node.js (for dependency management, if needed)

### Install Dependencies

```sh
forge install
```

### Compile Contracts

```sh
forge build
```
### Contract Deployment

To deploy all contracts only:

```sh
forge script script/DeployAll.s.sol --rpc-url <YOUR_RPC_URL> --private-key <YOUR_PRIVATE_KEY> --broadcast
```
