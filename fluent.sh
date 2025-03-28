#!/bin/bash
curl -s "https://raw.githubusercontent.com/WillzyDollarrzz/willzy/main/inscription.txt" \
  | sed 's/\\\\033/\033/g' \
  | while IFS= read -r line; do
      echo -e "$line"
    done

sleep 2

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

while true; do
  read -p "Have you claimed faucet tokens from https://faucet.dev.gblend.xyz/? (y/n): " faucetClaimed

  if [[ "$faucetClaimed" =~ ^[Yy]$ ]]; then
    break
  fi

  echo "Please follow these steps to claim devnet token:"
  echo "  1. Visit: https://faucet.dev.gblend.xyz/"
  echo "  2. Input your ETH address."
  echo "  3. Complete the captcha."
  echo "  4. Click 'Request Tokens'."
  
  while true; do
    read -p "Completed now? (y/n): " doneFaucet
    if [[ "$doneFaucet" =~ ^[Yy]$ ]]; then
      break 2
    fi
    echo "PLEASE COMPLETE THE ABOVE STEPS"
  done

done

read -p "enter your private key: " PRIVATE_KEY

if [[ $PRIVATE_KEY != 0x* ]]; then
  PRIVATE_KEY="0x$PRIVATE_KEY"
fi

CONFIG_FILE="hardhat.config.js"

cat > "$CONFIG_FILE" <<EOF
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-vyper");
/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  networks: {
    fluent_devnet1: {
      url: 'https://rpc.dev.gblend.xyz', 
      chainId: 20993, 
      accounts: [
        "${PRIVATE_KEY}"
      ], 
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


echo "updated hardhat.config.js with your private key."

cat > check-balance.js <<EOF
const { ethers } = require("hardhat");

async function main() {
  const provider = ethers.getDefaultProvider("https://rpc.dev.gblend.xyz/");
  const wallet = new ethers.Wallet(process.argv[2], provider);
  const balance = await wallet.getBalance();
  console.log("Your fluent eth balance is:", ethers.utils.formatEther(balance), "ETH");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
EOF

echo "fetching your wallet balance..."
node check-balance.js "$PRIVATE_KEY"
rm check-balance.js

echo "preparing to compile script..."
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
