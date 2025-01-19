## Prerequisites

To set up and run the project locally, ensure you have [the following installed](https://foundry-rs.github.io/starknet-foundry/getting-started/installation.html#install-rust-version--1801):

- [**Starknet Foundry**](https://foundry-rs.github.io/starknet-foundry/index.html)
- [**Scarb**](https://docs.swmansion.com/scarb/download.html)
- [**ASDF Version Manager**](https://asdf-vm.com/guide/getting-started.html)

## Installation

1. **Fork the Repository**

2. **Clone the Repository to your local machine**

```bash
   git clone https://github.com/hackinsync/musicstrk
   cd musicstrk
```

3. **Set Up Development Environment**
   To set up development environment:

```bash
    # Configure Scarb version
    asdf local scarb 2.8.5

    # Configure StarkNet Foundry
   asdf local starknet-foundry 0.35.1
```


4. Build the Project:

```bash
   scarb build
```

## Development

### Building

The project uses Scarb as its build tool. To build the contracts:

```bash
scarb build
```