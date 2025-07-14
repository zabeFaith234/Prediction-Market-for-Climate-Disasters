# 🌪️ Climate Prediction Market

A decentralized prediction market for climate disasters built on Stacks blockchain. Users can bet on hurricane occurrences while automatically contributing to relief efforts.

## 🌊 Features

- **🎯 Climate Predictions**: Create and bet on hurricane and climate disaster predictions
- **💰 Automatic Relief Fund**: 10% of all bets automatically go to relief efforts
- **🏆 Fair Payouts**: Winners split the pool after relief fund deduction
- **💳 Wallet Integration**: Seamless Stacks wallet integration
- **📱 Responsive Design**: Works on desktop and mobile devices
- **🔒 Secure**: Built with Clarity smart contracts on Stacks blockchain

## 🚀 Quick Start

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- [Node.js](https://nodejs.org/) for the frontend
- Stacks wallet browser extension

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/prediction-market-climate.git
   cd prediction-market-climate
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Start Clarinet console**
   ```bash
   clarinet console
   ```

4. **Deploy the contract**
   ```bash
   clarinet deploy
   ```

5. **Serve the frontend**
   ```bash
   # Simple HTTP server
   python -m http.server 8000
   # Or use Node.js
   npx http-server
   ```

6. **Open in browser**
   Navigate to `http://localhost:8000`

## 🎮 How to Use

### Creating Predictions

1. **Connect Wallet**: Click "Connect Wallet" and approve the connection
2. **Navigate to Create**: Click the "➕ Create Prediction" tab
3. **Fill Details**: 
   - 🏷️ Title: Brief description of the prediction
   - 📝 Description: Detailed information about what you're predicting
   - ⏰ Deadline: Block height when betting closes
4. **Submit**: Click "Create Prediction"

### Placing Bets

1. **Browse Predictions**: View active predictions on the main page
2. **Click "Place Bet"**: Opens the betting modal
3. **Enter Amount**: Specify your bet amount in STX
4. **Choose Side**: Click "✅ Yes" or "❌ No"
5. **Confirm**: Approve the transaction in your wallet

### Managing Funds

1. **Deposit**: Add STX to your contract balance for betting
2. **Withdraw**: Remove unused STX from your contract balance
3. **Claim Winnings**: Collect winnings from resolved predictions

## 🔧 Smart Contract Functions

### Public Functions

- `create-prediction`: Create a new prediction market
- `place-bet`: Place a bet on a prediction
- `resolve-prediction`: Resolve a prediction (admin only)
- `claim-winnings`: Claim winnings from a resolved prediction
- `deposit-funds`: Deposit STX into contract balance
- `withdraw-funds`: Withdraw STX from contract balance
- `withdraw-relief-funds`: Withdraw relief funds (admin only)

### Read-Only Functions

- `get-prediction`: Get prediction details
- `get-user-bet`: Get user's bet on a prediction
- `get-user-balance`: Get user's contract balance
- `get-total-relief-fund`: Get total relief fund amount
- `get-prediction-stats`: Get prediction statistics
- `calculate-potential-winnings`: Calculate potential winnings

## 🎨 Technical Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │   Smart         │    │   Relief        │
│   (HTML/CSS/JS) │◄──►│   Contract      │──► │   Fund          │
│                 │    │   (Clarity)     │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                       │                       │
        │                       │                       │
        ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Stacks        │    │   Prediction    │    │   Disaster      │
│   Blockchain    │    │   Markets       │    │   Relief        │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🧪 Testing

Run contract tests:
```bash
clarinet test
```

Run frontend tests:
```bash
npm test
```

## 📊 Contract Constants

- **Relief Fund Percentage**: 10% of all bets
- **Minimum Bet**: 0.000001 STX
- **Maximum Relief Percentage**: 50% (configurable by admin)

## 🔐 Security Features

- **Authorization**: Only contract owner can resolve predictions
- **Validation**: Comprehensive input validation
- **Overflow Protection**: Safe arithmetic operations
- **Reentrancy Protection**: Secure fund handling

## 🌍 Environmental Impact

This platform turns climate disaster predictions into a force for good:
- 💝 **Automatic Donations**: Every bet contributes to relief efforts
- 🚨 **Awareness**: Raises awareness about climate risks
- 🤝 **Community**: Brings together people concerned about climate change
- 📈 **Funding**: Generates sustainable funding for disaster relief

## 📋 API Reference

### Contract Deployment

```clarity
;; Deploy with default settings
;; Relief fund percentage: 10%
;; Next prediction ID: 1
```

### Error Codes

- `u100`: Unauthorized access
- `u101`: Invalid prediction parameters
- `u102`: Prediction betting is closed
- `u103`: Insufficient funds
- `u104`: Prediction not found
- `u105`: Prediction already resolved
- `u106`: Prediction still active
- `u107`: Invalid amount
- `u108`: No winnings to claim

## 🛠️ Development

### Project Structure

```
prediction-market-climate/
├── contracts/
│   └── prediction-market-climate.clar
├── tests/
│   └── prediction-market-climate_test.ts
├── settings/
│   └── Devnet.toml
├── index.html
├── styles.css
├── script.js
├── package.json
└── README.md
```

### Frontend Dependencies

- **Stacks Connect**: Wallet integration
- **Stacks.js**: Blockchain interaction
- **Vanilla JS**: No framework dependencies

### Smart Contract Dependencies

- **Clarity**: Native Stacks smart contract language
- **Stacks Blockchain**: Layer 1 blockchain

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📜 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- **Stacks Foundation**: For the blockchain platform
- **Clarinet Team**: For the development tools
- **Climate Science Community**: For inspiration and data
- **Disaster Relief Organizations**: For their important work

## 📞 Support

- **Documentation**: Check this README
- **Issues**: Open a GitHub issue
- **Community**: Join our Discord server
- **Email**: contact@climatepredictionmarket.com

---

*Built with ❤️ for climate action and disaster preparedness*

🌡️ **Remember**: Climate change is real. This platform helps fund relief efforts while raising awareness about climate risks.
