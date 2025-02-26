use contract_::erc20::{
    IBurnableDispatcher, IBurnableDispatcherTrait, IMintableDispatcher, IMintableDispatcherTrait,
    MusicStrk,
};
use openzeppelin::token::erc20::erc20::ERC20Component;
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::utils::serde::SerializedAppend;
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait,
    cheat_caller_address, declare, spy_events,
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

fn mint(contract_address: ContractAddress, recipient: ContractAddress, amount: u256) {
    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));
    IMintableDispatcher { contract_address }.mint(recipient, amount);
}

fn deploy_erc20() -> ContractAddress {
    let owner = owner();
    let contract_class = declare("MusicStrk").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append_serde(owner);
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    contract_address
}

#[test]
fn test_owner_can_mint() {
    let owner = owner();
    let kim = kim();
    let amount = 1000;
    let contract_address = deploy_erc20();
    let erc20 = IERC20Dispatcher { contract_address };
    let previous_balance = erc20.balance_of(owner);
    cheat_caller_address(contract_address, owner, CheatSpan::TargetCalls(1));
    IMintableDispatcher { contract_address }.mint(owner, amount);
    let balance = erc20.balance_of(owner);
    assert(balance - previous_balance == amount, 'Wrong amount after mint');

    let previous_balance = erc20.balance_of(kim);
    cheat_caller_address(contract_address, owner, CheatSpan::TargetCalls(1));
    IMintableDispatcher { contract_address }.mint(kim, amount);
    let balance = erc20.balance_of(kim);
    assert(balance - previous_balance == amount, 'Wrong amount after mint');
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_only_owner_can_mint() {
    let kim = kim();
    let contract_address = deploy_erc20();

    cheat_caller_address(contract_address, kim, CheatSpan::TargetCalls(1));
    IMintableDispatcher { contract_address }.mint(kim, 1000);
}

#[test]
fn test_supply_is_updated_after_mint() {
    let kim = kim();
    let amount = 1000;
    let contract_address = deploy_erc20();
    let erc20 = IERC20Dispatcher { contract_address };
    let previous_supply = erc20.total_supply();
    mint(contract_address, kim, amount);
    let supply = erc20.total_supply();
    assert(supply - previous_supply == amount, 'Wrong supply after mint');
}

#[test]
fn test_mint_emit_event() {
    let owner = owner();
    let kim = kim();
    let amount = 1000;
    let contract_address = deploy_erc20();
    let mut spy = spy_events();

    cheat_caller_address(contract_address, owner, CheatSpan::TargetCalls(1));
    IMintableDispatcher { contract_address }.mint(kim, amount);
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    MusicStrk::Event::MintEvent(MusicStrk::MintEvent { recipient: kim, amount }),
                ),
            ],
        );
}

#[test]
#[should_panic(expected: 'ERC20: mint to 0')]
fn test_mint_recipient_is_zero() {
    let owner = owner();
    let zero = zero();
    let amount = 1000;
    let contract_address = deploy_erc20();

    cheat_caller_address(contract_address, owner, CheatSpan::TargetCalls(1));
    IMintableDispatcher { contract_address }.mint(zero, amount);
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_only_owner_can_burn() {
    let kim = kim();
    let amount = 1000;
    let contract_address = deploy_erc20();
    mint(contract_address, kim, amount);
    cheat_caller_address(contract_address, kim, CheatSpan::TargetCalls(1));
    IBurnableDispatcher { contract_address }.burn(amount);
}


#[test]
fn test_supply_is_updated_after_burn() {
    let owner = owner();
    let amount = 1000;
    let contract_address = deploy_erc20();
    let erc20 = IERC20Dispatcher { contract_address };
    mint(contract_address, owner, amount);

    let previous_supply = erc20.total_supply();
    cheat_caller_address(contract_address, owner, CheatSpan::TargetCalls(1));
    IBurnableDispatcher { contract_address }.burn(amount);
    let supply = erc20.total_supply();
    assert(previous_supply - supply == amount, 'Wrong supply after burn');
}

#[test]
fn test_burn_emit_event() {
    let owner = owner();
    let amount = 1000;
    let contract_address = deploy_erc20();
    mint(contract_address, owner, amount);
    let mut spy = spy_events();
    cheat_caller_address(contract_address, owner, CheatSpan::TargetCalls(1));
    IBurnableDispatcher { contract_address }.burn(amount);
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    MusicStrk::Event::BurnEvent(MusicStrk::BurnEvent { from: owner, amount }),
                ),
            ],
        );
}

#[test]
#[should_panic(expected: 'ERC20: insufficient balance')]
fn test_cant_burn_more_than_balance() {
    let owner = owner();
    let contract_address = deploy_erc20();
    mint(contract_address, owner, 1000);
    let erc20 = IERC20Dispatcher { contract_address };
    let balance = erc20.balance_of(owner);
    cheat_caller_address(contract_address, owner, CheatSpan::TargetCalls(1));
    IBurnableDispatcher { contract_address }.burn(balance + 1);
}

#[test]
fn test_transfer() {
    let kim = kim();
    let thurston = thurston();
    let amount = 1000;
    let contract_address = deploy_erc20();
    mint(contract_address, kim, amount);
    let erc20 = IERC20Dispatcher { contract_address };
    let previous_balance_kim = erc20.balance_of(kim);
    let previous_balance_thurston = erc20.balance_of(thurston);
    cheat_caller_address(contract_address, kim, CheatSpan::TargetCalls(1));
    erc20.transfer(thurston, amount);
    let balance_kim = erc20.balance_of(kim);
    let balance_thurston = erc20.balance_of(thurston);
    assert(previous_balance_kim - balance_kim == amount, 'Wrong amount after transfer');
    assert(balance_thurston - previous_balance_thurston == amount, 'Wrong amount after transfer');
}


#[test]
fn test_transfer_emit_event() {
    let kim = kim();
    let thurston = thurston();
    let amount = 1000;
    let contract_address = deploy_erc20();
    mint(contract_address, thurston, amount);

    let erc20 = IERC20Dispatcher { contract_address };
    let mut spy = spy_events();
    cheat_caller_address(contract_address, thurston, CheatSpan::TargetCalls(1));
    erc20.transfer(kim, amount);
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    ERC20Component::Event::Transfer(
                        ERC20Component::Transfer { from: thurston, to: kim, value: amount },
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic(expected: 'ERC20: insufficient balance')]
fn test_transfer_not_enough_balance() {
    let kim = kim();
    let thurston = thurston();
    let amount = 1000;
    let contract_address = deploy_erc20();
    mint(contract_address, thurston, amount);

    let erc20 = IERC20Dispatcher { contract_address };
    let balance = erc20.balance_of(thurston);
    cheat_caller_address(contract_address, thurston, CheatSpan::TargetCalls(1));
    erc20.transfer(kim, balance + 1);
}

#[test]
#[should_panic(expected: 'ERC20: transfer to 0')]
fn test_transfer_to_zero_address() {
    let zero = zero();
    let thurston = thurston();
    let amount = 1000;
    let contract_address = deploy_erc20();
    mint(contract_address, thurston, amount);

    let erc20 = IERC20Dispatcher { contract_address };
    let balance = erc20.balance_of(thurston);
    cheat_caller_address(contract_address, thurston, CheatSpan::TargetCalls(1));
    erc20.transfer(zero, balance);
}

#[test]
fn test_transfer_from() {
    let kim = kim();
    let thurston = thurston();
    let lee = lee();
    let amount = 1000;
    let contract_address = deploy_erc20();
    mint(contract_address, kim, 2 * amount);

    let erc20 = IERC20Dispatcher { contract_address };
    let previous_balance_kim = erc20.balance_of(kim);
    let previous_balance_thurston = erc20.balance_of(thurston);

    cheat_caller_address(contract_address, kim, CheatSpan::TargetCalls(1));
    erc20.approve(lee, amount);

    cheat_caller_address(contract_address, lee, CheatSpan::TargetCalls(1));
    erc20.transfer_from(kim, thurston, amount);

    let balance_kim = erc20.balance_of(kim);
    let balance_thurston = erc20.balance_of(thurston);
    assert(previous_balance_kim - balance_kim == amount, 'Wrong amount after transfer');
    assert(balance_thurston - previous_balance_thurston == amount, 'Wrong amount after transfer');
}

#[test]
fn test_transfer_from_emit_event() {
    let kim = kim();
    let thurston = thurston();
    let lee = lee();
    let amount = 1000;
    let contract_address = deploy_erc20();
    mint(contract_address, kim, 2 * amount);

    let erc20 = IERC20Dispatcher { contract_address };
    cheat_caller_address(contract_address, kim, CheatSpan::TargetCalls(1));
    erc20.approve(lee, amount);

    let mut spy = spy_events();
    cheat_caller_address(contract_address, lee, CheatSpan::TargetCalls(1));
    erc20.transfer_from(kim, thurston, amount);
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    ERC20Component::Event::Transfer(
                        ERC20Component::Transfer { from: kim, to: thurston, value: amount },
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic(expected: 'ERC20: insufficient allowance')]
fn test_transfer_from_not_enough_allowance() {
    let kim = kim();
    let thurston = thurston();
    let lee = lee();
    let amount = 1000;
    let allowed_amount = amount - 1;
    let contract_address = deploy_erc20();
    mint(contract_address, kim, amount);

    let erc20 = IERC20Dispatcher { contract_address };
    cheat_caller_address(contract_address, kim, CheatSpan::TargetCalls(1));
    erc20.approve(lee, allowed_amount);

    cheat_caller_address(contract_address, lee, CheatSpan::TargetCalls(1));
    erc20.transfer_from(kim, thurston, amount);
}

#[test]
#[should_panic(expected: 'ERC20: insufficient balance')]
fn test_transfer_from_not_enough_balance() {
    let kim = kim();
    let thurston = thurston();
    let lee = lee();
    let amount = 1000;
    let transfer_amount = amount + 1;
    let contract_address = deploy_erc20();
    mint(contract_address, kim, amount);

    let erc20 = IERC20Dispatcher { contract_address };
    cheat_caller_address(contract_address, kim, CheatSpan::TargetCalls(1));
    erc20.approve(lee, transfer_amount);

    cheat_caller_address(contract_address, lee, CheatSpan::TargetCalls(1));
    erc20.transfer_from(kim, thurston, transfer_amount);
}

#[test]
#[should_panic(expected: 'ERC20: transfer to 0')]
fn test_transfrom_from_to_zero_address() {
    let kim = kim();
    let zero = zero();
    let lee = lee();
    let amount = 1000;
    let contract_address = deploy_erc20();
    mint(contract_address, kim, 2 * amount);

    let erc20 = IERC20Dispatcher { contract_address };

    cheat_caller_address(contract_address, kim, CheatSpan::TargetCalls(1));
    erc20.approve(lee, amount);

    cheat_caller_address(contract_address, lee, CheatSpan::TargetCalls(1));
    erc20.transfer_from(kim, zero, amount);
}

#[test]
fn test_allowance() {
    let kim = kim();
    let lee = lee();
    let amount = 1000;
    let contract_address = deploy_erc20();
    let erc20 = IERC20Dispatcher { contract_address };
    let allowance = erc20.allowance(kim, lee);
    assert(allowance == 0, 'Wrong allowance');
    cheat_caller_address(contract_address, kim, CheatSpan::TargetCalls(1));
    erc20.approve(lee, amount);
    let allowance = erc20.allowance(kim, lee);
    assert(allowance == amount, 'Wrong allowance');
}

#[test]
fn test_allowance_is_updated_after_transfer_from() {
    let kim = kim();
    let thurston = thurston();
    let lee = lee();
    let amount = 1000;
    let contract_address = deploy_erc20();
    mint(contract_address, kim, 2 * amount);

    let erc20 = IERC20Dispatcher { contract_address };

    cheat_caller_address(contract_address, kim, CheatSpan::TargetCalls(1));
    erc20.approve(lee, amount);
    let previous_allowance = erc20.allowance(kim, lee);

    cheat_caller_address(contract_address, lee, CheatSpan::TargetCalls(1));
    erc20.transfer_from(kim, thurston, amount);

    let allowance = erc20.allowance(kim, lee);

    assert(previous_allowance - allowance == amount, 'Wrong allowance after transfer');
}

#[test]
fn test_approve_emit_event() {
    let kim = kim();
    let lee = lee();
    let amount = 1000;
    let contract_address = deploy_erc20();
    let erc20 = IERC20Dispatcher { contract_address };
    let mut spy = spy_events();
    cheat_caller_address(contract_address, kim, CheatSpan::TargetCalls(1));
    erc20.approve(lee, amount);
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    ERC20Component::Event::Approval(
                        ERC20Component::Approval { owner: kim, spender: lee, value: amount },
                    ),
                ),
            ],
        );
}
