# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a Hardhat Ignition module that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat ignition deploy ./ignition/modules/Lock.ts
```

Run unit tests and coverage report with:
```shell
forge test --no-match-contract TroveManagerSanityTest

# coverage summary
forge coverage --no-match-contract TroveManagerSanityTest --no-match-coverage contracts/mock/

# coverage detailed
mkdir coverage
forge coverage --no-match-contract TroveManagerSanityTest --no-match-coverage contracts/mock/ --report lcov --report-file coverage/fuzz.coverage.lcov
genhtml coverage/fuzz.coverage.lcov -o coverage
# open coverage/index.html in your browser and navigate to the relevant source file to see line-by-line execution records
```