# Bima Protocol

Run unit tests and coverage report with:

```shell
forge test --no-match-contract TroveManagerSanityTest

# coverage summary
forge coverage --no-match-contract TroveManagerSanityTest --no-match-coverage "(contracts/mock/|test/)"

# coverage detailed
mkdir coverage
forge coverage --no-match-contract TroveManagerSanityTest --no-match-coverage "(contracts/mock/|test/)" --report lcov --report-file coverage/fuzz.coverage.lcov
genhtml coverage/fuzz.coverage.lcov -o coverage
# open coverage/index.html in your browser and navigate to the relevant source file to see line-by-line execution records
```
