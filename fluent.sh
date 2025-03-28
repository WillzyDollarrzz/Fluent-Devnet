#!/bin/bash

# -------------------------------
# Install Dependencies
# -------------------------------
echo "Installing dependencies..."
sudo apt update && sudo apt upgrade -y

if ! command -v nvm &> /dev/null; then
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  

nvm install 20
npm install -g npm@latest
nvm alias default 20

if ! command -v cargo &> /dev/null; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi

source "$HOME/.cargo/env"

if ! command -v gblend &> /dev/null; then
  cargo install gblend
fi

gblend init <<EOF
1
EOF

npm install

# -------------------------------
# Faucet Check
# -------------------------------
read -p "Have you claimed faucet tokens from https://faucet.dev.gblend.xyz/? (y/n): " faucetClaimed

if [[ "$faucetClaimed" =~ ^[Nn]$ ]]; then
  echo "Please follow these steps to claim your tokens:"
  echo "  1. Visit: https://faucet.dev.gblend.xyz/"
  echo "  2. Input your ETH address."
  echo "  3. Complete the captcha."
  echo "  4. Click 'Request Tokens'."
  
  read -p "Are you done now? (y/n): " doneFaucet
  if [[ ! "$doneFaucet" =~ ^[Yy]$ ]]; then
    echo "PLEASE COMPLETE THE ABOVE STEPS"
    exit 1
  fi
fi

# -------------------------------
# Get Private Key and Update Config
# -------------------------------
read -p "Enter your Private Key (without 0x prefix): " PRIVATE_KEY

CONFIG_FILE="hardhat.config.js"

# Create the new config file content with the provided private key.
# The placeholder "ADD YOUR PRIVATE KEY HERE" is replaced by the user's private key.
cat > "$CONFIG_FILE" <<EOF
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-vyper");
/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  networks: {
    fluent_devnet1: {
      url: 'https://rpc.dev.thefluent.xyz/', 
      chainId: 20993, 
      accounts : [
        \`0x${PRIVATE_KEY}\`
      ], // Replace with the private key of the deploying account
    },
  },
  solidity: {
    version: '0.8.19', 
  },
  vyper: {
    version: "0.3.0",
  },
};
EOF

echo "Updated hardhat.config.js with your private key."

# -------------------------------
# Show Wallet Balance
# -------------------------------
# Create a temporary script to check the wallet balance
cat > check-balance.js <<EOF
const { ethers } = require("hardhat");

async function main() {
  const provider = ethers.getDefaultProvider("https://rpc.dev.thefluent.xyz/");
  // Create a wallet instance using the private key and provider
  const wallet = new ethers.Wallet(process.argv[2], provider);
  const balance = await wallet.getBalance();
  console.log("Your wallet balance is:", ethers.utils.formatEther(balance), "ETH");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
EOF

echo "Fetching your wallet balance..."
node check-balance.js "$PRIVATE_KEY"
rm check-balance.js

# -------------------------------
# Prepare to Compile and Deploy
# -------------------------------
echo "Preparing to Compile Script..."
cd contracts
cat > Hello.sol <<EOF
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
contract Hello {
    function main() public pure returns (string memory) {
        return "Hello there, thanks for deploying on fluent!";
    }
}
EOF

npm run compile

cd ../scripts
cat > deploy-solidity.js <<EOF
const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  const network = await ethers.provider.getNetwork();

  console.log("Deploying contract...");
  console.log("Chain ID:", network.chainId);
  console.log("Your address:", deployer.address);
  console.log(
    "Address balance:",
    ethers.utils.formatEther(await deployer.getBalance()),
    "ETH"
  );

  const ContractFactory = await ethers.getContractFactory("Hello");
  const contract = await ContractFactory.deploy();

  await contract.deployed();

  const transactionHash = contract.deployTransaction.hash;

  console.log("Contract address:", contract.address);

  const explorerUrl = \`https://blockscout.dev.gblend.xyz/tx/\${transactionHash}\`;
  console.log("Transaction link:", explorerUrl);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
EOF

echo "Deployment Process Has Started"
cd ..
npx hardhat run scripts/deploy-solidity.js --network fluent_devnet1

echo "Follow @JustWillzy_ on X For More Guides Like This."
