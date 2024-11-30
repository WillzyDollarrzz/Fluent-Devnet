#!/bin/bash
echo "Installing dependencies..."
sudo apt update && sudo apt upgrade -y

if ! command -v nvm &> /dev/null; then
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
  source ~/.bashrc
fi

nvm install 20
npm install -g npm@latest
nvm alias default 20

if ! command -v gblend &> /dev/null; then
  cargo install gblend
fi

gblend init <<EOF
1
EOF

npm install

read -p "Enter your Private Key: " PRIVATE_KEY

CONFIG_FILE="hardhat.config.js"
if [ -f "$CONFIG_FILE" ]; then
  sed -i "s/ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80/$PRIVATE_KEY/" "$CONFIG_FILE"
else
  echo "Error: $CONFIG_FILE not found."
  exit 1
fi

echo "Preparing to Compile Script..."
cd contracts
cat > Hello.sol <<EOF
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Hello {
    function greeting() public pure returns (string memory) {
        return "Hello ser/ma'am, I'm Willzy Dollarrzz, thanks for using my guide!";
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

echo "Follow @WillzyDollarrzz on X For More Guides Like This."
