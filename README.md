# BME Mechatronics Engineering MSc. Thesis

## **Development of a smart contract based system for real-world use cases**

This project was my work for my MSc. thesis that I worked on during 2022. The project is a smart contract based crop insurance system that uses oracles to transmit, and Raspberry Pi IoT weather nodes, as well as centralized weather providers as a source of data.

The core insurance logic is provided by a Solidity smart contract. For testing and development, I used Scaffold-ETH which you can read more about below - that is what this repository is based on. The custom insurance smart contract is located under `packages\hardhat\contracts\YourContract.sol`. It is a state machine, where users can create new insurances or insure other users.

The other part of this is the Chainlink oracle, which you need to self-host by running your own node ([https://docs.chain.link/docs/running-a-chainlink-node/]()). The job for accessing the data from your IoT device is under `chainlink_jobs\iot_weather.toml`. I used Alchemy as a cloud provider instead or self-hosting an Ethereum node.

To access the centralized weather providers through their respective APIs, and parse the data, you can use `weather_scripts\weatherapi.js`. For this, you also need a `.env` file under `weather_scripts` with the respective API keys and endpoints (see `.exampleenv`).

For running your own IoT weather provider (temperature) node, you need a Raspberry Pi, as well as a DHT11 or DHT22 sensor.  You can use `weather_scripts\iot_api.py` to run an API interface on here that will report the measured temperatures. 

You will also need an external adapter to facilitate communication between your Chainlink node and the data sources. For this I used [https://github.com/PatrickAlphaC/CL-EA-NodeJS-Template]() which I modified using `chainlink_jobs\index.js` to provide my data. 

Grade received for the thesis: excellent (5).

---

#### 🏗 Scaffold-ETH

> everything you need to build on Ethereum! 🚀

🧪 Quickly experiment with Solidity using a frontend that adapts to your smart contract:

![image](https://user-images.githubusercontent.com/2653167/124158108-c14ca380-da56-11eb-967e-69cde37ca8eb.png)

# 🏄‍♂️ Quick Start

Prerequisites: [Node (v16 LTS)](https://nodejs.org/en/download/) plus [Yarn](https://classic.yarnpkg.com/en/docs/install/) and [Git](https://git-scm.com/downloads)

> clone/fork 🏗 scaffold-eth:

```bash
git clone https://github.com/scaffold-eth/scaffold-eth.git
```

> install and start your 👷‍ Hardhat chain:

```bash
cd scaffold-eth
yarn install
yarn chain
```

> in a second terminal window, start your 📱 frontend:

```bash
cd scaffold-eth
yarn start
```

> in a third terminal window, 🛰 deploy your contract:

```bash
cd scaffold-eth
yarn deploy
```

🔏 Edit your smart contract `YourContract.sol` in `packages/hardhat/contracts`

📝 Edit your frontend `App.jsx` in `packages/react-app/src`

💼 Edit your deployment scripts in `packages/hardhat/deploy`

📱 Open http://localhost:3000 to see the app

# 📚 Documentation

Documentation, tutorials, challenges, and many more resources, visit: [docs.scaffoldeth.io](https://docs.scaffoldeth.io)

# 🔭 Learning Solidity

📕 Read the docs: https://docs.soliditylang.org

📚 Go through each topic from [solidity by example](https://solidity-by-example.org) editing `YourContract.sol` in **🏗 scaffold-eth**

- [Primitive Data Types](https://solidity-by-example.org/primitives/)
- [Mappings](https://solidity-by-example.org/mapping/)
- [Structs](https://solidity-by-example.org/structs/)
- [Modifiers](https://solidity-by-example.org/function-modifier/)
- [Events](https://solidity-by-example.org/events/)
- [Inheritance](https://solidity-by-example.org/inheritance/)
- [Payable](https://solidity-by-example.org/payable/)
- [Fallback](https://solidity-by-example.org/fallback/)

📧 Learn the [Solidity globals and units](https://solidity.readthedocs.io/en/v0.6.6/units-and-global-variables.html)

# 🛠 Buidl

Check out all the [active branches](https://github.com/scaffold-eth/scaffold-eth/branches/active), [open issues](https://github.com/scaffold-eth/scaffold-eth/issues), and join/fund the 🏰 [BuidlGuidl](https://BuidlGuidl.com)!

- 🚤  [Follow the full Ethereum Speed Run](https://medium.com/@austin_48503/%EF%B8%8Fethereum-dev-speed-run-bd72bcba6a4c)
- 🎟  [Create your first NFT](https://github.com/scaffold-eth/scaffold-eth/tree/simple-nft-example)
- 🥩  [Build a staking smart contract](https://github.com/scaffold-eth/scaffold-eth/tree/challenge-1-decentralized-staking)
- 🏵  [Deploy a token and vendor](https://github.com/scaffold-eth/scaffold-eth/tree/challenge-2-token-vendor)
- 🎫  [Extend the NFT example to make a &#34;buyer mints&#34; marketplace](https://github.com/scaffold-eth/scaffold-eth/tree/buyer-mints-nft)
- 🎲  [Learn about commit/reveal](https://github.com/scaffold-eth/scaffold-eth/tree/commit-reveal-with-frontend)
- ✍️  [Learn how ecrecover works](https://github.com/scaffold-eth/scaffold-eth/tree/signature-recover)
- 👩‍👩‍👧‍👧  [Build a multi-sig that uses off-chain signatures](https://github.com/scaffold-eth/scaffold-eth/tree/meta-multi-sig)
- ⏳  [Extend the multi-sig to stream ETH](https://github.com/scaffold-eth/scaffold-eth/tree/streaming-meta-multi-sig)
- ⚖️  [Learn how a simple DEX works](https://medium.com/@austin_48503/%EF%B8%8F-minimum-viable-exchange-d84f30bd0c90)
- 🦍  [Ape into learning!](https://github.com/scaffold-eth/scaffold-eth/tree/aave-ape)

# 💌 P.S.

🌍 You need an RPC key for testnets and production deployments, create an [Alchemy](https://www.alchemy.com/) account and replace the value of `ALCHEMY_KEY = xxx` in `packages/react-app/src/constants.js` with your new key.

📣 Make sure you update the `InfuraID` before you go to production. Huge thanks to [Infura](https://infura.io/) for our special account that fields 7m req/day!

# 🏃💨 Speedrun Ethereum

Register as a builder [here](https://speedrunethereum.com) and start on some of the challenges and build a portfolio.
