# SatoshiThreads

## Decentralized Social Identity + Monetization Protocol

## Overview

SatoshiThreads is a decentralized social infrastructure protocol built on Stacks Layer 2, secured by Bitcoin finality. It provides comprehensive primitives for on-chain identity management, content creation, peer-to-peer monetization, and community governance - creating a censorship-resistant, fully composable social ecosystem.

## Key Features

- **On-Chain Identity**: Secure user profiles with unique handles and reputation systems
- **Content Monetization**: Direct STX tipping with automated protocol fee distribution
- **Social Graph**: Decentralized follower/following relationships
- **Community Governance**: Tokenized communities with native governance capabilities
- **Engagement Tracking**: Verifiable metrics and reputation incentives
- **Bitcoin Security**: Full composability backed by Bitcoin's finality guarantees

## System Architecture

### Core Components

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   User Profiles │    │    Content      │    │   Communities   │
│                 │    │   Management    │    │   & Governance  │
│ • Identity      │    │                 │    │                 │
│ • Reputation    │◄──►│ • Posts/Media   │◄──►│ • Social Tokens │
│ • Social Graph  │    │ • Monetization  │    │ • Member Roles  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   Engagement    │
                    │    Tracking     │
                    │                 │
                    │ • Tips & Rewards│
                    │ • Reputation    │
                    │ • Analytics     │
                    └─────────────────┘
```

## Contract Architecture

### Data Models

#### User Profiles

```clarity
{
  owner: principal,
  handle: string-ascii,
  bio: string-utf8,
  avatar-url: optional string-ascii,
  reputation-score: uint,
  total-tips-received: uint,
  total-tips-sent: uint,
  content-count: uint,
  follower-count: uint,
  following-count: uint,
  created-at: uint,
  verified: bool
}
```

#### Content Posts

```clarity
{
  author-id: uint,
  content-text: string-utf8,
  content-type: string-ascii,
  media-url: optional string-ascii,
  tip-count: uint,
  total-tips: uint,
  engagement-score: uint,
  created-at: uint,
  community-id: optional uint
}
```

#### Communities

```clarity
{
  name: string-ascii,
  description: string-utf8,
  creator-id: uint,
  token-symbol: string-ascii,
  total-supply: uint,
  member-count: uint,
  created-at: uint,
  governance-threshold: uint
}
```

### Core Functions

#### Profile Management

- `create-profile()` - Register new on-chain identity
- `update-profile()` - Modify profile information
- `follow-user()` - Establish social connections
- `verify-profile()` - Admin verification system

#### Content Operations

- `create-content()` - Publish posts with media support
- `tip-content()` - Direct STX monetization with fees

#### Community Features

- `create-community()` - Launch tokenized communities
- `join-community()` - Member onboarding system

## Data Flow

### Content Creation & Monetization Flow

```
User Creates Content
        │
        ▼
┌───────────────┐
│   Validation  │ ◄─── Content Type, Length, URL Validation
│   & Storage   │
└───────┬───────┘
        │
        ▼
┌───────────────┐
│   Engagement  │ ◄─── Update Author Stats & Tracking
│   Tracking    │
└───────┬───────┘
        │
        ▼
┌───────────────┐
│  Tipping Flow │ ◄─── STX Transfer + Protocol Fees
│               │
└───────┬───────┘
        │
        ▼
┌───────────────┐
│  Reputation   │ ◄─── Score Updates & Incentives
│   Updates     │
└───────────────┘
```

### Social Graph Management

```
Follow Request
        │
        ▼
┌───────────────┐
│   Profile     │ ◄─── Handle Resolution & Validation
│   Resolution  │
└───────┬───────┘
        │
        ▼
┌───────────────┐
│  Connection   │ ◄─── Duplicate Check & Storage
│   Creation    │
└───────┬───────┘
        │
        ▼
┌───────────────┐
│   Counter     │ ◄─── Update Follower/Following Counts
│   Updates     │
└───────────────┘
```

## Technical Specifications

### Protocol Configuration

- **Protocol Fee**: 2.5% (250 basis points)
- **Minimum Tip**: 1,000 microSTX
- **Maximum Lengths**:
  - Handle: 32 characters
  - Bio: 256 characters
  - Content: 1,024 characters
  - URLs: 256 characters
- **Reputation**: Starts at 100 points
- **Engagement Periods**: Weekly (2,016 blocks)

### Security Features

#### Input Validation

- Comprehensive string length checks
- URL format validation (http/https schemes)
- Content type validation
- Duplicate prevention mechanisms

#### Access Control

- Owner-only administrative functions
- Profile ownership verification
- Protocol pause mechanism
- Community moderation roles

#### Economic Security

- Minimum tip thresholds
- Protocol fee collection
- Self-tipping prevention
- Duplicate tip protection

## Error Handling

| Error Code | Description |
|------------|-------------|
| `ERR_UNAUTHORIZED` (100) | Access denied |
| `ERR_ALREADY_EXISTS` (101) | Duplicate resource |
| `ERR_NOT_FOUND` (102) | Resource not found |
| `ERR_INVALID_AMOUNT` (103) | Invalid tip amount |
| `ERR_INSUFFICIENT_FUNDS` (104) | Insufficient balance |
| `ERR_INVALID_PARAMS` (105) | Invalid parameters |
| `ERR_PROFILE_NOT_FOUND` (106) | Profile does not exist |
| `ERR_CONTENT_NOT_FOUND` (107) | Content does not exist |
| `ERR_ALREADY_TIPPED` (108) | Already tipped content |
| `ERR_SELF_TIP` (109) | Cannot tip own content |

## API Reference

### Read-Only Functions

```clarity
(get-profile-by-id (profile-id uint))
(get-profile-by-handle (handle string-ascii))
(get-profile-by-principal (user principal))
(get-content (content-id uint))
(get-tip (content-id uint) (tipper principal))
(is-following (follower-handle string-ascii) (following-handle string-ascii))
(get-community (community-id uint))
(get-protocol-stats)
```

### State-Changing Functions

```clarity
(create-profile (handle string-ascii) (bio string-utf8) (avatar-url optional string-ascii))
(update-profile (bio string-utf8) (avatar-url optional string-ascii))
(follow-user (target-handle string-ascii))
(create-content (content-text string-utf8) (content-type string-ascii) (media-url optional string-ascii) (community-id optional uint))
(tip-content (content-id uint) (amount uint) (message optional string-utf8))
(create-community (name string-ascii) (description string-utf8) (token-symbol string-ascii) (initial-supply uint))
(join-community (community-id uint))
```

## Deployment & Integration

### Prerequisites

- Stacks blockchain environment
- STX tokens for gas and tipping
- Clarity smart contract deployment tools

### Integration Points

- **Frontend dApps**: Full API access for social applications
- **Wallet Integration**: STX tipping and fee handling
- **Community Tools**: Token-based governance systems
- **Analytics Platforms**: On-chain engagement metrics

## Governance & Economics

### Protocol Governance

- Contract owner administrative controls
- Protocol fee recipient management
- Emergency pause/unpause mechanisms
- Profile verification system

### Economic Model

- **Revenue**: 2.5% protocol fees on all tips
- **Incentives**: Reputation-based rewards system
- **Community Tokens**: Native governance and utility
- **Engagement Rewards**: Weekly tracking periods

## Future Enhancements

- Cross-chain bridge integrations
- Advanced content moderation tools
- NFT profile picture support
- Decentralized identity verification
- Layer 2 scaling solutions
- Enhanced governance mechanisms

## License

This project is open-source and available under standard blockchain development licenses.

## Contributing

Contributions are welcome! Please ensure all smart contract changes include comprehensive tests and security audits.
