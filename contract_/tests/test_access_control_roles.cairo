use starknet::ContractAddress;
use contract_::audition::AccessControl::{
    IAccessControlDispatcher, IAccessControlDispatcherTrait, Role,
};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_block_timestamp,
    start_cheat_caller_address, stop_cheat_block_timestamp, stop_cheat_caller_address,
};

fn deploy_access_control(owner: ContractAddress) -> IAccessControlDispatcher {
    let contract = declare("AccessControl").unwrap().contract_class();
    let constructor_calldata = array![owner.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    IAccessControlDispatcher { contract_address }
}

fn setup() -> (IAccessControlDispatcher, ContractAddress, ContractAddress, ContractAddress) {
    let owner: ContractAddress = 0x123.try_into().unwrap();
    let user1: ContractAddress = 0x456.try_into().unwrap();
    let user2: ContractAddress = 0x789.try_into().unwrap();

    let access_control = deploy_access_control(owner);

    (access_control, owner, user1, user2)
}

#[test]
fn test_constructor_grants_admin_role_to_owner() {
    let (access_control, owner, _, _) = setup();

    assert!(access_control.has_role(Role::ADMIN, owner));
}

#[test]
fn test_grant_role_success() {
    let (access_control, owner, user1, _) = setup();

    start_cheat_caller_address(access_control.contract_address, owner);
    access_control.grant_role(Role::JUDGE, user1);
    stop_cheat_caller_address(access_control.contract_address);

    assert!(access_control.has_role(Role::JUDGE, user1));
}

#[test]
#[should_panic(expected: ('Caller is not authorized',))]
fn test_grant_role_unauthorized() {
    let (access_control, _, user1, user2) = setup();

    start_cheat_caller_address(access_control.contract_address, user1);
    access_control.grant_role(Role::JUDGE, user2);
    stop_cheat_caller_address(access_control.contract_address);
}

#[test]
fn test_revoke_role_success() {
    let (access_control, owner, user1, _) = setup();

    start_cheat_caller_address(access_control.contract_address, owner);
    access_control.grant_role(Role::JUDGE, user1);
    assert!(access_control.has_role(Role::JUDGE, user1));
    access_control.revoke_role(user1);
    assert!(!access_control.has_role(Role::JUDGE, user1));
    stop_cheat_caller_address(access_control.contract_address);
}

#[test]
#[should_panic(expected: ('Caller is not authorized',))]
fn test_revoke_role_unauthorized() {
    let (access_control, owner, user1, user2) = setup();

    start_cheat_caller_address(access_control.contract_address, owner);
    access_control.grant_role(Role::JUDGE, user1);
    stop_cheat_caller_address(access_control.contract_address);
    start_cheat_caller_address(access_control.contract_address, user2);
    access_control.revoke_role(user1);
    stop_cheat_caller_address(access_control.contract_address);
}

#[test]
fn test_batch_grant_roles() {
    let (access_control, owner, user1, user2) = setup();

    start_cheat_caller_address(access_control.contract_address, owner);

    let roles = array![Role::JUDGE, Role::REVIEWER];
    let accounts = array![user1, user2];

    access_control.batch_grant_roles(roles, accounts);
    stop_cheat_caller_address(access_control.contract_address);

    assert!(access_control.has_role(Role::JUDGE, user1));
    assert!(access_control.has_role(Role::REVIEWER, user2));
}

#[test]
#[should_panic(expected: ('Array length mismatch',))]
fn test_batch_grant_roles_length_mismatch() {
    let (access_control, owner, user1, user2) = setup();

    start_cheat_caller_address(access_control.contract_address, owner);

    let roles = array![Role::JUDGE];
    let accounts = array![user1, user2];

    access_control.batch_grant_roles(roles, accounts);

    stop_cheat_caller_address(access_control.contract_address);
}

#[test]
fn test_batch_revoke_roles() {
    let (access_control, owner, user1, user2) = setup();

    start_cheat_caller_address(access_control.contract_address, owner);

    access_control.grant_role(Role::JUDGE, user1);
    access_control.grant_role(Role::REVIEWER, user2);
    let roles = array![Role::JUDGE, Role::REVIEWER];
    let accounts = array![user1, user2];
    access_control.batch_revoke_roles(accounts);
    stop_cheat_caller_address(access_control.contract_address);
    assert!(!access_control.has_role(Role::JUDGE, user1));
    assert!(!access_control.has_role(Role::REVIEWER, user2));
}

#[test]
fn test_grant_temporary_role() {
    let (access_control, owner, user1, _) = setup();

    start_cheat_caller_address(access_control.contract_address, owner);
    start_cheat_block_timestamp(access_control.contract_address, 1000);

    let expires_at = 2000;
    access_control.grant_temporary_role(Role::ORACLE, user1, expires_at);
    stop_cheat_block_timestamp(access_control.contract_address);
    start_cheat_block_timestamp(access_control.contract_address, 1500);
    assert!(access_control.has_role(Role::ORACLE, user1));
    stop_cheat_block_timestamp(access_control.contract_address);
    start_cheat_block_timestamp(access_control.contract_address, 2500);
    assert!(!access_control.has_role(Role::ORACLE, user1));
    stop_cheat_block_timestamp(access_control.contract_address);
    stop_cheat_caller_address(access_control.contract_address);
}

#[test]
#[should_panic(expected: ('Expiration must be later',))]
fn test_grant_temporary_role_invalid_expiration() {
    let (access_control, owner, user1, _) = setup();

    start_cheat_caller_address(access_control.contract_address, owner);
    start_cheat_block_timestamp(access_control.contract_address, 2000);

    let expires_at = 1000;
    access_control.grant_temporary_role(Role::ORACLE, user1, expires_at);

    stop_cheat_block_timestamp(access_control.contract_address);
    stop_cheat_caller_address(access_control.contract_address);
}

#[test]
fn test_delegate_session_role() {
    let (access_control, owner, user1, user2) = setup();

    start_cheat_caller_address(access_control.contract_address, owner);
    access_control.grant_role(Role::SESSION_CREATOR, user1);
    stop_cheat_caller_address(access_control.contract_address);
    start_cheat_caller_address(access_control.contract_address, user1);
    start_cheat_block_timestamp(access_control.contract_address, 1000);
    let session_id: u256 = 12345;
    access_control.delegate_session_role(session_id, Role::JUDGE, user2);
    stop_cheat_block_timestamp(access_control.contract_address);
    start_cheat_block_timestamp(access_control.contract_address, 1500);
    assert!(access_control.has_session_role(session_id, Role::JUDGE, user2));
    stop_cheat_block_timestamp(access_control.contract_address);
    stop_cheat_caller_address(access_control.contract_address);
}

#[test]
#[should_panic(expected: ('Caller is not authorized',))]
fn test_delegate_session_role_unauthorized() {
    let (access_control, _, user1, user2) = setup();
    start_cheat_caller_address(access_control.contract_address, user1);
    let session_id: u256 = 12345;
    access_control.delegate_session_role(session_id, Role::JUDGE, user2);
    stop_cheat_caller_address(access_control.contract_address);
}

#[test]
fn test_revoke_session_delegation() {
    let (access_control, owner, user1, user2) = setup();
    start_cheat_caller_address(access_control.contract_address, owner);
    access_control.grant_role(Role::SESSION_CREATOR, user1);
    stop_cheat_caller_address(access_control.contract_address);
    start_cheat_caller_address(access_control.contract_address, user1);
    start_cheat_block_timestamp(access_control.contract_address, 1000);
    let session_id: u256 = 12345;
    access_control.delegate_session_role(session_id, Role::JUDGE, user2);
    stop_cheat_block_timestamp(access_control.contract_address);
    start_cheat_block_timestamp(access_control.contract_address, 1500);
    assert!(access_control.has_session_role(session_id, Role::JUDGE, user2));
    stop_cheat_block_timestamp(access_control.contract_address);
    access_control.revoke_session_delegation(session_id, Role::JUDGE, user2);
    assert!(!access_control.has_session_role(session_id, Role::JUDGE, user2));
    stop_cheat_caller_address(access_control.contract_address);
}

#[test]
#[should_panic(expected: ('No such delegation',))]
fn test_revoke_nonexistent_session_delegation() {
    let (access_control, owner, user1, user2) = setup();
    start_cheat_caller_address(access_control.contract_address, owner);
    access_control.grant_role(Role::SESSION_CREATOR, user1);
    start_cheat_caller_address(access_control.contract_address, user1);
    let session_id: u256 = 12345;
    access_control.revoke_session_delegation(session_id, Role::JUDGE, user2);
}

#[test]
fn test_get_user_roles() {
    let (access_control, owner, user1, _) = setup();
    start_cheat_caller_address(access_control.contract_address, owner);
    access_control.grant_role(Role::JUDGE, user1);
    let user_roles = access_control.get_user_roles(user1);
    assert!(user_roles.len() == 1);
    assert!(*user_roles[0] == Role::JUDGE);
    stop_cheat_caller_address(access_control.contract_address);
}

#[test]
fn test_get_user_roles_default_user() {
    let (access_control, _, user1, _) = setup();
    let user_roles = access_control.get_user_roles(user1);
    assert!(user_roles.len() == 0);
}

#[test]
fn test_is_role_expired() {
    let (access_control, owner, user1, _) = setup();
    start_cheat_caller_address(access_control.contract_address, owner);
    start_cheat_block_timestamp(access_control.contract_address, 1000);
    let expires_at = 2000;
    access_control.grant_temporary_role(Role::ORACLE, user1, expires_at);
    start_cheat_block_timestamp(access_control.contract_address, 1500);
    assert!(!access_control.is_role_expired(Role::ORACLE, user1));
    start_cheat_block_timestamp(access_control.contract_address, 2500);
    assert!(access_control.is_role_expired(Role::ORACLE, user1));
    stop_cheat_block_timestamp(access_control.contract_address);
    stop_cheat_caller_address(access_control.contract_address);
}

#[test]
fn test_emergency_override_role_grant() {
    let (access_control, owner, user1, _) = setup();
    start_cheat_caller_address(access_control.contract_address, owner);
    access_control.emergency_override_role(user1, Role::REVIEWER, true);
    assert!(access_control.has_role(Role::REVIEWER, user1));
    stop_cheat_caller_address(access_control.contract_address);
}

#[test]
fn test_emergency_override_role_revoke() {
    let (access_control, owner, user1, _) = setup();
    start_cheat_caller_address(access_control.contract_address, owner);
    access_control.grant_role(Role::REVIEWER, user1);
    assert!(access_control.has_role(Role::REVIEWER, user1));
    access_control.emergency_override_role(user1, Role::REVIEWER, false);
    assert!(!access_control.has_role(Role::REVIEWER, user1));
    stop_cheat_caller_address(access_control.contract_address);
}

#[test]
#[should_panic(expected: ('Caller is not authorized',))]
fn test_emergency_override_role_unauthorized() {
    let (access_control, _, user1, user2) = setup();
    start_cheat_caller_address(access_control.contract_address, user1);
    access_control.emergency_override_role(user2, Role::REVIEWER, true);
    stop_cheat_caller_address(access_control.contract_address);
}

#[test]
fn test_has_role_permanent() {
    let (access_control, owner, user1, _) = setup();
    start_cheat_caller_address(access_control.contract_address, owner);
    access_control.grant_role(Role::JUDGE, user1);
    start_cheat_block_timestamp(access_control.contract_address, 999999);
    assert!(access_control.has_role(Role::JUDGE, user1));
    stop_cheat_block_timestamp(access_control.contract_address);
    stop_cheat_caller_address(access_control.contract_address);
}

#[test]
fn test_session_role_functionality() {
    let (access_control, owner, user1, user2) = setup();
    start_cheat_caller_address(access_control.contract_address, owner);
    access_control.grant_role(Role::SESSION_CREATOR, user1);
    start_cheat_caller_address(access_control.contract_address, user1);
    start_cheat_block_timestamp(access_control.contract_address, 1000);
    let session_id: u256 = 54321;
    access_control.delegate_session_role(session_id, Role::ORACLE, user2);
    stop_cheat_block_timestamp(access_control.contract_address);
    start_cheat_block_timestamp(access_control.contract_address, 1500);
    assert!(access_control.has_session_role(session_id, Role::ORACLE, user2));
    assert!(!access_control.has_session_role(session_id, Role::JUDGE, user2));
    assert!(!access_control.has_session_role(999, Role::ORACLE, user2));
    stop_cheat_caller_address(access_control.contract_address);
}

#[test]
fn test_complete_role_lifecycle() {
    let (access_control, owner, user1, user2) = setup();
    start_cheat_caller_address(access_control.contract_address, owner);
    start_cheat_block_timestamp(access_control.contract_address, 1000);
    access_control.grant_role(Role::JUDGE, user1);
    assert!(access_control.has_role(Role::JUDGE, user1));
    access_control.grant_temporary_role(Role::ORACLE, user2, 2000);
    assert!(access_control.has_role(Role::ORACLE, user2));
    start_cheat_block_timestamp(access_control.contract_address, 2500);
    assert!(access_control.has_role(Role::JUDGE, user1));
    assert!(!access_control.has_role(Role::ORACLE, user2));
    assert!(access_control.is_role_expired(Role::ORACLE, user2));
    access_control.revoke_role(user1);
    assert!(!access_control.has_role(Role::JUDGE, user1));
    access_control.emergency_override_role(user1, Role::ADMIN, true);
    assert!(access_control.has_role(Role::ADMIN, user1));
}

#[test]
#[should_panic(expected: ('Caller is not authorized',))]
fn test_role_permissions() {
    let (access_control, owner, user1, user2) = setup();
    start_cheat_caller_address(access_control.contract_address, owner);
    access_control.grant_role(Role::JUDGE, user1);
    start_cheat_caller_address(access_control.contract_address, user1);
    let result = access_control.grant_role(Role::REVIEWER, user2);
    stop_cheat_caller_address(access_control.contract_address);
}

#[test]
fn test_multiple_roles_same_user() {
    let (access_control, owner, user1, _) = setup();
    start_cheat_caller_address(access_control.contract_address, owner);
    access_control.grant_role(Role::JUDGE, user1);
    access_control.grant_role(Role::REVIEWER, user1);
    assert!(!access_control.has_role(Role::JUDGE, user1));
    assert!(access_control.has_role(Role::REVIEWER, user1));
    start_cheat_caller_address(access_control.contract_address, owner);
}
