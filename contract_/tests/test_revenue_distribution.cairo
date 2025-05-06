use contract_::IRevenueDistribution::{
    Category, IRevenueDistributionDispatcher, IRevenueDistributionDispatcherTrait,
};
use contract_::erc20::{IMusicShareTokenDispatcher, IMusicShareTokenDispatcherTrait};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::utils::serde::SerializedAppend;
use snforge_std::{CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare};
use starknet::{ContractAddress, contract_address_const};


fn owner() -> ContractAddress {
    contract_address_const::<'owner'>()
}

fn zero() -> ContractAddress {
    contract_address_const::<0>()
}

fn kim() -> ContractAddress {
    contract_address_const::<'kim'>()
}

fn bob() -> ContractAddress {
    contract_address_const::<'thurston'>()
}

fn lee() -> ContractAddress {
    contract_address_const::<'lee'>()
}


fn deploy_music_share_token() -> ContractAddress {
    let owner = owner();
    let contractclass = declare("MusicStrk").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append_serde(owner);
    let (contractaddress, _) = contractclass.deploy(@calldata).unwrap();
    contractaddress
}
fn deploy_revenue_contract(
    owner: ContractAddress, token_address: ContractAddress,
) -> ContractAddress {
    let contract = declare("RevenueDistribution").unwrap().contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    owner.serialize(ref constructor_calldata);
    token_address.serialize(ref constructor_calldata);
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

#[test]
fn test_revenue_distribution() {
    let contract_address = deploy_music_share_token();
    // Deploy the RevenueDistribution contract
    let revenue_address = deploy_revenue_contract(owner(), contract_address);

    let revenue_distribution = IRevenueDistributionDispatcher { contract_address: revenue_address };
    let token = IERC20Dispatcher { contract_address };

    // Initialize the token
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    IMusicShareTokenDispatcher { contract_address }
        .initialize(bob(), "ipfs://test", "RecordToken", "REC", 6 // decimals
        );

    // Verify initial balances
    assert(token.balance_of(bob()) == 100_u256, 'Initial from balance wrong');
    // Transfer 30 tokens from kim to thurston
    cheat_caller_address(contract_address, bob(), CheatSpan::TargetCalls(2));
    revenue_distribution.transfer_token_share(kim(), 30_u256);
    revenue_distribution.transfer_token_share(lee(), 70_u256);

    // Add revenue
    revenue_distribution.add_revenue(Category::TICKET, 1000);

    // Distribute revenue
    cheat_caller_address(revenue_address, owner(), CheatSpan::TargetCalls(1));
    revenue_distribution.distribute_revenue();

    // Check revenue distribution
    let kim_revenue = revenue_distribution.get_holder_revenue(kim());
    let lee_revenue = revenue_distribution.get_holder_revenue(lee());

    assert_eq!(kim_revenue, 300, "Kim's revenue incorrect");
    assert_eq!(lee_revenue, 700, "Lee's revenue incorrect");
}

#[test]
fn test_add_revenue() {
    let contract_address = deploy_music_share_token();
    // Deploy the RevenueDistribution contract
    let revenue_address = deploy_revenue_contract(owner(), contract_address);
    let revenue_distribution = IRevenueDistributionDispatcher { contract_address: revenue_address };

    // Add revenue to a category
    revenue_distribution.add_revenue(Category::STREAMING, 1000);

    // Check the revenue by category
    let (revenue, cat) = revenue_distribution.get_revenue_by_category(Category::STREAMING);
    assert_eq!(revenue, 1000);
    assert_eq!(cat, 3_u8);
}

#[test]
fn test_Calculate_revenue_share() {
    let contract_address = deploy_music_share_token();
    // Deploy the RevenueDistribution contract
    let revenue_address = deploy_revenue_contract(owner(), contract_address);

    let revenue_distribution = IRevenueDistributionDispatcher { contract_address: revenue_address };
    let token = IERC20Dispatcher { contract_address };

    // Initialize the token
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    IMusicShareTokenDispatcher { contract_address }
        .initialize(bob(), "ipfs://test", "RecordToken", "REC", 6 // decimals
        );

    // Verify initial balances
    assert(token.balance_of(bob()) == 100_u256, 'Initial from balance wrong');
    // Transfer 30 tokens from kim to thurston
    cheat_caller_address(contract_address, bob(), CheatSpan::TargetCalls(2));
    revenue_distribution.transfer_token_share(kim(), 30_u256);
    revenue_distribution.transfer_token_share(lee(), 70_u256);

    let kim_share = revenue_distribution.calculate_revenue_share(kim());
    let lee_share = revenue_distribution.calculate_revenue_share(lee());
    let bob_share = revenue_distribution.calculate_revenue_share(bob());

    assert(kim_share == 30000000_u256, 'kim_should_have_30000000');
    assert(lee_share == 70000000_u256, 'lee_should_have_70000000');
    assert(bob_share == 0_u256, 'bob_should_have_0');
}

#[test]
fn test_transfer_token_share() {
    // Setup
    let from_address = kim();
    let to_address = bob();
    let contract_address = deploy_music_share_token();
    let revenue_address = deploy_revenue_contract(owner(), contract_address);
    let revenue_distribution = IRevenueDistributionDispatcher { contract_address: revenue_address };
    let token = IERC20Dispatcher { contract_address };

    // Initialize the token
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    IMusicShareTokenDispatcher { contract_address }
        .initialize(from_address, "ipfs://test", "RecordToken", "REC", 6);

    // Verify initial balances
    assert(token.balance_of(from_address) == 100_u256, 'Initial from balance wrong');
    assert(token.balance_of(to_address) == 0_u256, 'Initial to balance wrong');

    // Transfer 30 tokens from kim to thurston
    cheat_caller_address(contract_address, from_address, CheatSpan::TargetCalls(1));
    revenue_distribution.transfer_token_share(to_address, 30_u256);

    // Check balances after transfer
    assert(token.balance_of(from_address) == 70_u256, 'Final from balance wrong');
    assert(token.balance_of(to_address) == 30_u256, 'Final to balance wrong');
}

#[test]
fn test_get_holders_of_token() {
    let contract_address = deploy_music_share_token();
    // Deploy the RevenueDistribution contract
    let revenue_address = deploy_revenue_contract(owner(), contract_address);

    let revenue_distribution = IRevenueDistributionDispatcher { contract_address: revenue_address };
    let token = IERC20Dispatcher { contract_address };

    // Initialize the token
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    IMusicShareTokenDispatcher { contract_address }
        .initialize(bob(), "ipfs://test", "RecordToken", "REC", 6 // decimals
        );

    // Verify initial balances
    assert(token.balance_of(bob()) == 100_u256, 'Initial from balance wrong');
    // Transfer 30 tokens from kim to thurston
    cheat_caller_address(contract_address, bob(), CheatSpan::TargetCalls(2));
    revenue_distribution.transfer_token_share(kim(), 30_u256);
    revenue_distribution.transfer_token_share(lee(), 70_u256);

    let holders = revenue_distribution.get_holders_by_token(contract_address);

    assert(*holders[0] == kim(), 'kim');
    assert(*holders[1] == lee(), 'lee');
}

#[test]
fn test_revenue_distribution_history() {
    let contract_address = deploy_music_share_token();
    // Deploy the RevenueDistribution contract
    let revenue_address = deploy_revenue_contract(owner(), contract_address);

    let revenue_distribution = IRevenueDistributionDispatcher { contract_address: revenue_address };
    let token = IERC20Dispatcher { contract_address };

    // Initialize the token
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    IMusicShareTokenDispatcher { contract_address }
        .initialize(bob(), "ipfs://test", "RecordToken", "REC", 6 // decimals
        );

    // Verify initial balances
    assert(token.balance_of(bob()) == 100_u256, 'Initial from balance wrong');
    // Transfer 30 tokens from kim to thurston
    cheat_caller_address(contract_address, bob(), CheatSpan::TargetCalls(2));
    revenue_distribution.transfer_token_share(kim(), 30_u256);
    revenue_distribution.transfer_token_share(lee(), 70_u256);

    // Add revenue
    revenue_distribution.add_revenue(Category::TICKET, 1000);

    // Distribute revenue
    cheat_caller_address(revenue_address, owner(), CheatSpan::TargetCalls(1));
    revenue_distribution.distribute_revenue();

    // Check revenue distribution
    let kim_revenue = revenue_distribution.get_holder_revenue(kim());
    let lee_revenue = revenue_distribution.get_holder_revenue(lee());

    assert_eq!(kim_revenue, 300, "Kim's revenue incorrect");
    assert_eq!(lee_revenue, 700, "Lee's revenue incorrect");

    let history = revenue_distribution.get_distribution_history();

    println!("history should be :[(7039341, 300, 0), (7103845, 700, 0)] == {:?}", history)
}
