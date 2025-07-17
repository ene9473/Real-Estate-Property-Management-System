# Real Estate Property Management System

A comprehensive blockchain-based property management system built with Clarity smart contracts for the Stacks blockchain.

## Overview

This system provides a complete solution for managing real estate properties, including ownership tracking, rental agreements, property valuations, maintenance requests, and escrow services.

## Contracts

### 1. Property Registry Contract (`property-registry.clar`)
- Records legal property ownership and title transfers
- Maintains property details and metadata
- Tracks ownership history
- Handles property registration and transfers

### 2. Rental Agreement Contract (`rental-agreement.clar`)
- Automates lease terms and rental payments
- Manages tenant-landlord relationships
- Tracks payment history and lease status
- Handles lease renewals and terminations

### 3. Property Valuation Contract (`property-valuation.clar`)
- Maintains current market assessments
- Records professional appraisals
- Tracks property value history
- Provides valuation data for transactions

### 4. Maintenance Request Contract (`maintenance-request.clar`)
- Tracks repair and upkeep activities
- Manages maintenance requests and assignments
- Records completion status and costs
- Maintains property maintenance history

### 5. Escrow Management Contract (`escrow-management.clar`)
- Secures transaction funds during property sales
- Manages multi-party escrow agreements
- Handles fund release conditions
- Provides secure transaction processing

## Features

- **Decentralized Ownership**: Immutable property ownership records
- **Automated Payments**: Smart contract-based rental payments
- **Transparent Valuations**: On-chain property assessments
- **Maintenance Tracking**: Complete repair and upkeep history
- **Secure Transactions**: Trustless escrow services

## Data Types

### Property
- Property ID (uint)
- Owner (principal)
- Address (string)
- Property type
- Square footage
- Registration date

### Rental Agreement
- Agreement ID (uint)
- Property ID (uint)
- Tenant (principal)
- Landlord (principal)
- Monthly rent amount
- Lease duration
- Security deposit

### Valuation
- Valuation ID (uint)
- Property ID (uint)
- Appraiser (principal)
- Assessed value
- Valuation date
- Valuation type

### Maintenance Request
- Request ID (uint)
- Property ID (uint)
- Requester (principal)
- Description
- Priority level
- Status
- Assigned contractor

### Escrow Agreement
- Escrow ID (uint)
- Property ID (uint)
- Buyer (principal)
- Seller (principal)
- Amount
- Conditions
- Status

## Error Codes

- `ERR-NOT-AUTHORIZED (u100)`: Caller not authorized for this action
- `ERR-NOT-FOUND (u101)`: Requested item not found
- `ERR-ALREADY-EXISTS (u102)`: Item already exists
- `ERR-INVALID-INPUT (u103)`: Invalid input parameters
- `ERR-INSUFFICIENT-FUNDS (u104)`: Insufficient funds for transaction
- `ERR-INVALID-STATUS (u105)`: Invalid status for operation
- `ERR-EXPIRED (u106)`: Agreement or request has expired

## Usage

### Property Registration
\`\`\`clarity
(contract-call? .property-registry register-property
"123 Main St"
"residential"
u2000)
\`\`\`

### Create Rental Agreement
\`\`\`clarity
(contract-call? .rental-agreement create-lease
u1
'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7
u1200
u12
u2400)
\`\`\`

### Submit Property Valuation
\`\`\`clarity
(contract-call? .property-valuation submit-valuation
u1
u350000
"market-assessment")
\`\`\`

### Create Maintenance Request
\`\`\`clarity
(contract-call? .maintenance-request create-request
u1
"Leaky faucet in kitchen"
u2)
\`\`\`

### Initialize Escrow
\`\`\`clarity
(contract-call? .escrow-management create-escrow
u1
'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7
u350000)
\`\`\`

## Testing

Run the test suite:
\`\`\`bash
npm test
\`\`\`

## Deployment

1. Install Clarinet CLI
2. Configure your deployment settings in `Clarinet.toml`
3. Deploy contracts to testnet/mainnet

## Security Considerations

- All contracts include proper authorization checks
- Input validation prevents invalid data entry
- State transitions are carefully controlled
- No cross-contract dependencies for security isolation

## License

MIT License - see LICENSE file for details
