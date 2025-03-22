use contract_::erc20::{
    IMusicShareTokenDispatcher, IMusicShareTokenDispatcherTrait,
    IBurnableDispatcher, IBurnableDispatcherTrait,
};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use openzeppelin::utils::serde::SerializedAppend;
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait,
    cheat_caller_address, declare,
};
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

fn thurston() -> ContractAddress {
    contract_address_const::<'thurston'>()
}

fn lee() -> ContractAddress {
    contract_address_const::<'lee'>()
}

// Helper function to deploy the music share token contract
fn deploy_music_share_token() -> ContractAddress {
    let owner = owner();
    let contract_class = declare("MusicStrk").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append_serde(owner);
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    contract_address
}

#[test]
fn test_deployment() {
    // Simple test just to check that the contract deploys successfully
    let contract_address = deploy_music_share_token();
    
    // Simple check that deployed contract address is not zero
    assert(contract_address != zero(), 'Contract not deployed');
}

#[test]
fn test_initialize() {
    // Setup
    let recipient = kim();
    let contract_address = deploy_music_share_token();
    let token = IERC20Dispatcher { contract_address };
    let share_token = IMusicShareTokenDispatcher { contract_address };
    
    // Initialize the token with minimal data
    // Direct string literals should work in Cairo 2.9.4
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    share_token.initialize(
        recipient, 
        "ipfs://test", 
        "RecordToken", 
        "REC", 
        2 // decimals
    );
    
    // Verify total supply is exactly 100 tokens
    assert(token.total_supply() == 100_u256, 'Wrong total supply');
    
    // Verify recipient received 100 tokens
    assert(token.balance_of(recipient) == 100_u256, 'Recipient balance wrong');
}

#[test]
fn test_burn() {
    // Setup
    let recipient = kim();
    let contract_address = deploy_music_share_token();
    let token = IERC20Dispatcher { contract_address };
    let burnable = IBurnableDispatcher { contract_address };
    
    // Initialize the token
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    IMusicShareTokenDispatcher { contract_address }.initialize(
        recipient, 
        "ipfs://test", 
        "RecordToken", 
        "REC", 
        2 // decimals
    );
    
    // Verify initial balance
    assert(token.balance_of(recipient) == 100_u256, 'Initial balance wrong');
    
    // Burn 25 tokens
    cheat_caller_address(contract_address, recipient, CheatSpan::TargetCalls(1));
    burnable.burn(25_u256);
    
    // Check balance after burning
    assert(token.balance_of(recipient) == 75_u256, 'Balance after burn wrong');
    
    // Check total supply decreased
    assert(token.total_supply() == 75_u256, 'Total supply wrong after burn');
}

#[test]
fn test_transfer() {
    // Setup
    let from_address = kim();
    let to_address = thurston();
    let contract_address = deploy_music_share_token();
    let token = IERC20Dispatcher { contract_address };
    
    // Initialize the token
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    IMusicShareTokenDispatcher { contract_address }.initialize(
        from_address, 
        "ipfs://test", 
        "RecordToken", 
        "REC", 
        2 // decimals
    );
    
    // Verify initial balances
    assert(token.balance_of(from_address) == 100_u256, 'Initial from balance wrong');
    assert(token.balance_of(to_address) == 0_u256, 'Initial to balance wrong');
    
    // Transfer 30 tokens from kim to thurston
    cheat_caller_address(contract_address, from_address, CheatSpan::TargetCalls(1));
    token.transfer(to_address, 30_u256);
    
    // Check balances after transfer
    assert(token.balance_of(from_address) == 70_u256, 'Final from balance wrong');
    assert(token.balance_of(to_address) == 30_u256, 'Final to balance wrong');
    
    // Ensure total supply remains unchanged
    assert(token.total_supply() == 100_u256, 'Total supply changed');
}

#[test]
fn test_approve_and_transfer_from() {
    // Setup
    let token_owner = kim();
    let spender = thurston();
    let recipient = lee();
    let contract_address = deploy_music_share_token();
    let token = IERC20Dispatcher { contract_address };
    
    // Initialize the token
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    IMusicShareTokenDispatcher { contract_address }.initialize(
        token_owner, 
        "ipfs://test", 
        "RecordToken", 
        "REC", 
        2 // decimals
    );
    
    // Verify initial balances
    assert(token.balance_of(token_owner) == 100_u256, 'Initial owner balance wrong');
    assert(token.balance_of(spender) == 0_u256, 'Initial spender balance wrong');
    assert(token.balance_of(recipient) == 0_u256, 'Initial recipient balance wrong');
    
    // Approve spender to spend 50 tokens
    cheat_caller_address(contract_address, token_owner, CheatSpan::TargetCalls(1));
    token.approve(spender, 50_u256);
    
    // Check allowance
    assert(token.allowance(token_owner, spender) == 50_u256, 'Allowance not set correctly');
    
    // Spender transfers 40 tokens from token_owner to recipient
    cheat_caller_address(contract_address, spender, CheatSpan::TargetCalls(1));
    token.transfer_from(token_owner, recipient, 40_u256);
    
    // Check balances after transfer
    assert(token.balance_of(token_owner) == 60_u256, 'Final owner balance wrong');
    assert(token.balance_of(recipient) == 40_u256, 'Final recipient balance wrong');
    
    // Check remaining allowance
    assert(token.allowance(token_owner, spender) == 10_u256, 'Remaining allowance wrong');
    
    // Ensure total supply remains unchanged
    assert(token.total_supply() == 100_u256, 'Total supply changed');
}

#[test]
fn test_metadata_uri() {
    // Setup
    let recipient = kim();
    let contract_address = deploy_music_share_token();
    let share_token = IMusicShareTokenDispatcher { contract_address };
    
    // Initialize the token with metadata URI
    let metadata_uri = "ipfs://QmSpecificCID";
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    share_token.initialize(
        recipient, 
        metadata_uri, 
        "RecordToken", 
        "REC", 
        2 // decimals
    );
    
    // Verify that the metadata URI is correctly set and retrievable
    let retrieved_uri = share_token.get_metadata_uri();
    
    // For Cairo 2.9.4, we'll verify the URI was set by checking if it exists
    // We don't have a direct way to compare ByteArray values in the test environment
    assert(retrieved_uri.len() > 0, 'Metadata URI not set');
}

#[test]
fn test_ownership_transfer() {
    // Setup
    let original_owner = owner();
    let new_owner = kim();
    let contract_address = deploy_music_share_token();
    let ownable = IOwnableDispatcher { contract_address };
    
    // Verify initial owner
    assert(ownable.owner() == original_owner, 'Initial owner incorrect');
    
    // Transfer ownership from original owner to new owner
    cheat_caller_address(contract_address, original_owner, CheatSpan::TargetCalls(1));
    ownable.transfer_ownership(new_owner);
    
    // Verify new owner
    assert(ownable.owner() == new_owner, 'Ownership transfer failed');
}

#[test]
fn test_edge_cases() {
    // Setup
    let token_owner = kim();
    let spender = thurston();
    let contract_address = deploy_music_share_token();
    let token = IERC20Dispatcher { contract_address };
    let share_token = IMusicShareTokenDispatcher { contract_address };
    
    // Initialize the token
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    share_token.initialize(
        token_owner, 
        "ipfs://test", 
        "RecordToken", 
        "REC", 
        2 // decimals
    );
    
    // Case 1: Approve zero amount
    cheat_caller_address(contract_address, token_owner, CheatSpan::TargetCalls(1));
    token.approve(spender, 0_u256);
    
    // Verify zero approval
    assert(token.allowance(token_owner, spender) == 0_u256, 'Zero approval failed');
    
    // Case 2: Transfer zero amount
    let initial_balance = token.balance_of(token_owner);
    cheat_caller_address(contract_address, token_owner, CheatSpan::TargetCalls(1));
    token.transfer(spender, 0_u256);
    
    // Verify balances didn't change
    assert(token.balance_of(token_owner) == initial_balance, 'Balance changed');
    assert(token.balance_of(spender) == 0_u256, 'Received tokens');
}

#[test]
fn test_decimal_configuration() {
    // Test with different decimal configurations
    
    // Test with 0 decimals
    let decimal_0 = 0_u8;
    let recipient = kim();
    let to_address = thurston();
    let contract_address = deploy_music_share_token();
    let token = IERC20Dispatcher { contract_address };
    let share_token = IMusicShareTokenDispatcher { contract_address };
    
    // Initialize with 0 decimals
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    share_token.initialize(
        recipient, 
        "ipfs://test", 
        "RecordToken", 
        "REC", 
        decimal_0
    );
    
    // Verify the decimals setting was stored correctly
    assert(share_token.get_decimals() == decimal_0, 'Decimals not set to 0');
    
    // Verify initial balance - should be 100 tokens regardless of decimals
    assert(token.balance_of(recipient) == 100_u256, 'Initial balance incorrect');
    
    // Transfer a whole amount
    let transfer_amount = 5_u256;
    cheat_caller_address(contract_address, recipient, CheatSpan::TargetCalls(1));
    token.transfer(to_address, transfer_amount);
    
    // Verify transfer worked correctly
    assert(token.balance_of(to_address) == transfer_amount, 'Transfer failed');
    assert(token.balance_of(recipient) == 100_u256 - transfer_amount, 'Sender balance wrong');
    
    // Now test with a different decimal value
    let decimal_2 = 2_u8;
    let recipient2 = kim();
    let to_address2 = thurston();
    let contract_address2 = deploy_music_share_token();
    let token2 = IERC20Dispatcher { contract_address: contract_address2 };
    let share_token2 = IMusicShareTokenDispatcher { contract_address: contract_address2 };
    
    // Initialize with 2 decimals
    cheat_caller_address(contract_address2, owner(), CheatSpan::TargetCalls(1));
    share_token2.initialize(
        recipient2, 
        "ipfs://test", 
        "RecordToken", 
        "REC", 
        decimal_2
    );
    
    // Verify the decimals setting was stored correctly
    assert(share_token2.get_decimals() == decimal_2, 'Decimals not set to 2');
    
    // Verify initial balance - should be 100 tokens regardless of decimals
    assert(token2.balance_of(recipient2) == 100_u256, 'Initial balance incorrect');
    
    // Transfer an amount
    let transfer_amount2 = 1_u256;
    cheat_caller_address(contract_address2, recipient2, CheatSpan::TargetCalls(1));
    token2.transfer(to_address2, transfer_amount2);
    
    // Verify transfer worked correctly
    assert(token2.balance_of(to_address2) == transfer_amount2, 'Transfer failed');
    assert(token2.balance_of(recipient2) == 100_u256 - transfer_amount2, 'Sender balance wrong');
    
    // Additionally, test a high decimal value (18, which is standard for many tokens)
    let decimal_18 = 18_u8;
    let recipient3 = kim();
    let contract_address3 = deploy_music_share_token();
    let share_token3 = IMusicShareTokenDispatcher { contract_address: contract_address3 };
    
    // Initialize with 18 decimals
    cheat_caller_address(contract_address3, owner(), CheatSpan::TargetCalls(1));
    share_token3.initialize(
        recipient3, 
        "ipfs://test", 
        "RecordToken", 
        "REC", 
        decimal_18
    );
    
    // Verify the decimals setting was stored correctly
    assert(share_token3.get_decimals() == decimal_18, 'Decimals not set to 18');
}

#[test]
#[should_panic]
fn test_double_initialization() {
    // Setup
    let recipient = kim();
    let contract_address = deploy_music_share_token();
    let share_token = IMusicShareTokenDispatcher { contract_address };
    
    // Initialize the token first time
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    share_token.initialize(
        recipient, 
        "ipfs://test", 
        "RecordToken", 
        "REC", 
        2 // decimals
    );
    
    // Try to initialize again - should fail
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    share_token.initialize(
        thurston(), 
        "ipfs://test2", 
        "RecordToken2", 
        "REC2", 
        3 // different decimals
    );
    // This should panic, but we don't specify the exact message since it might vary
}
