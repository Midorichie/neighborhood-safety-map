# Neighborhood Safety Map

A decentralized neighborhood safety reporting and management system built on the Stacks blockchain using Clarity smart contracts.

## 🚀 Phase 2 Enhancements

This project has been enhanced with significant improvements in Phase 2:

### 🐛 Bug Fixes
- **Fixed timestamp bug**: Replaced incorrect `(as-exp unix-epoch)` with proper `get-block-info?` time function
- **Enhanced input validation**: Added comprehensive parameter validation with proper error handling

### 🔒 Security Improvements
- **Emergency pause mechanism**: Contract owner can pause operations during security incidents
- **Anti-spam protection**: Users cannot verify their own reports
- **Duplicate verification prevention**: Each user can only verify a report once
- **Authorization checks**: All public functions verify contract state before execution

### ✨ New Functionality
- **Community verification system**: Reports gain credibility through community verification
- **Reporter reputation system**: Track reporter reliability with reputation scores (0-100)
- **Safety zones management**: New contract for managing community safety resources
- **Zone rating system**: Community can rate and review safety zones
- **Incident tracking**: Monitor incidents near safety zones

## 📋 Features

### Main Contract (`neighborhood-safety-map.clar`)
- **Report Safety Issues**: Submit geo-located safety reports with severity levels
- **Community Verification**: Verify reports to build community trust
- **Reputation System**: Track reporter credibility and reliability
- **Emergency Pause**: Admin control for emergency situations

### Safety Zones Contract (`safety-zones.clar`)
- **Zone Management**: Add and manage safety zones (safe houses, police stations, hospitals, etc.)
- **Community Rating**: Rate and review safety zones
- **Verification System**: Authority verification for legitimate safety zones
- **Incident Tracking**: Monitor safety incidents near zones

## 🛠 Technical Specifications

### Data Structures

#### Reports
```clarity
{
  latitude: int,        // ±90° scaled by 1e6
  longitude: int,       // ±180° scaled by 1e6
  reporter: principal,
  timestamp: uint,
  severity: uint,       // 1-5 scale
  note: (optional (buff 256)),
  verification-count: uint,
  is-verified: bool
}
```

#### Safety Zones
```clarity
{
  name: (buff 128),
  latitude: int,
  longitude: int,
  zone-type: uint,      // 1=Safe House, 2=Police, 3=Hospital, etc.
  radius: uint,         // Coverage radius in meters
  contact-info: (optional (buff 256)),
  verified: bool,
  created-by: principal,
  created-at: uint
}
```

### Security Features
- Input validation for all coordinates and parameters
- Principal-based authorization
- Emergency pause mechanisms
- Anti-spam and duplicate prevention
- Reputation-based trust system

## 📊 Error Codes

| Code | Description |
|------|------------|
| 100-199 | Input validation errors |
| 200-299 | Data retrieval errors |
| 300-399 | Authorization errors |
| 400-499 | Business logic errors |
| 500-599 | Safety zones errors |

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Basic understanding of Clarity smart contracts

### Installation
1. Clone the repository
```bash
git clone <repository-url>
cd neighborhood-safety-map
```

2. Check contract syntax
```bash
clarinet check
```

3. Run tests
```bash
clarinet test
```

4. Start local development
```bash
clarinet console
```

## 🧪 Usage Examples

### Adding a Safety Report
```clarity
(contract-call? .neighborhood-safety-map add-report 
  40750000      ;; latitude (40.75° * 1e6)
  -73980000     ;; longitude (-73.98° * 1e6)
  u3            ;; severity (1-5)
  (some 0x48656c70))  ;; note: "Help" in hex
```

### Verifying a Report
```clarity
(contract-call? .neighborhood-safety-map verify-report u1)
```

### Adding a Safety Zone
```clarity
(contract-call? .safety-zones add-safety-zone
  0x506f6c6963652053746174696f6e  ;; name: "Police Station"
  40750000      ;; latitude
  -73980000     ;; longitude
  u2            ;; zone type (police station)
  u500          ;; radius (500 meters)
  (some 0x3931312d555344))  ;; contact: "911-USD"
```

## 🏗 Architecture

### Contract Structure
```
contracts/
├── neighborhood-safety-map.clar    # Main reporting contract
└── safety-zones.clar              # Safety zones management
```

### Key Components
1. **Report Management**: Core functionality for safety incident reporting
2. **Verification System**: Community-driven report validation
3. **Reputation Tracking**: Reporter credibility system
4. **Safety Zones**: Community resource management
5. **Emergency Controls**: Admin pause/unpause mechanisms

## 🛡 Security Considerations

- All coordinates are validated to prevent invalid geo-data
- Users cannot verify their own reports to prevent manipulation
- Emergency pause functionality for critical security issues
- Reputation system helps identify reliable vs unreliable reporters
- Authorization checks prevent unauthorized access to admin functions

## 🔄 Future Enhancements (Phase 3+)

- Geographic querying for area-based report retrieval
- Advanced reputation algorithms with time decay
- Integration with external data sources
- Mobile app integration
- DAO governance for community management
- NFT badges for trusted reporters
- Real-time incident alerts

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request
