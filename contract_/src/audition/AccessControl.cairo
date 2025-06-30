use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
pub enum Role {
    OWNER,
    ADMIN,
    SESSION_CREATOR,
    JUDGE,
    REVIEWER,
    ORACLE,
    NONE, // Used for revoking roles
    #[default]
    USER,
}

#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
pub struct RoleData {
    pub role: Role,
    pub granted_at: u64,
    pub expires_at: u64, // 0 means permanent
    pub granted_by: ContractAddress,
}

#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
pub struct RoleOperation {
    pub role: Role,
    pub account: ContractAddress,
}

#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
pub struct SessionDelegation {
    pub session_id: u256,
    pub role: Role,
    pub delegated_to: ContractAddress,
    pub delegated_by: ContractAddress,
    pub granted_at: u64,
    pub expires_at: u64 // 0 means permanent
}

#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
pub struct AuditLog {
    pub account: ContractAddress,
    pub role: Role,
    pub action: u64, // 0: granted, 1: revoked, 2: delegated, 3: expire
    pub timestamp: u64,
    pub actor: ContractAddress,
}

#[starknet::interface]
pub trait IAccessControl<TContractState> {
    fn has_role(self: @TContractState, role: Role, account: ContractAddress) -> bool;

    fn grant_role(ref self: TContractState, role: Role, account: ContractAddress);

    fn revoke_role(ref self: TContractState, account: ContractAddress);

    fn batch_grant_roles(
        ref self: TContractState, roles: Array<Role>, accounts: Array<ContractAddress>,
    );

    fn batch_revoke_roles(ref self: TContractState, accounts: Array<ContractAddress>);

    fn grant_temporary_role(
        ref self: TContractState, role: Role, account: ContractAddress, expires_at: u64,
    );

    fn delegate_session_role(
        ref self: TContractState, session_id: u256, role: Role, account: ContractAddress,
    );

    fn revoke_session_delegation(
        ref self: TContractState, session_id: u256, role: Role, account: ContractAddress,
    );

    fn has_session_role(
        self: @TContractState, session_id: u256, role: Role, account: ContractAddress,
    ) -> bool;

    fn get_user_roles(self: @TContractState, account: ContractAddress) -> Array<Role>;

    fn is_role_expired(self: @TContractState, role: Role, account: ContractAddress) -> bool;

    fn emergency_override_role(
        ref self: TContractState, target: ContractAddress, role: Role, granted: bool,
    );
}

#[starknet::contract]
pub mod AccessControl {
    use contract_::errors::errors;
    use super::{Role, RoleData, SessionDelegation, AuditLog, IAccessControl};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };


    #[storage]
    struct Storage {
        roles: Map<ContractAddress, Role>,
        role_data: Map<ContractAddress, RoleData>,
        session_roles: Map<u256, SessionDelegation>,
        audit_log_count: Map<ContractAddress, u32>,
        audit_entries: Map<(ContractAddress, u32), AuditLog>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        RoleGranted: RoleGranted,
        RoleRevoked: RoleRevoked,
        SessionRoleDelegated: SessionRoleDelegated,
        EmergencyOverride: EmergencyOverride,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RoleGranted {
        #[key]
        role: Role,
        #[key]
        account: ContractAddress,
        #[key]
        sender: ContractAddress,
        expires_at: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RoleRevoked {
        #[key]
        role: Role,
        #[key]
        account: ContractAddress,
        #[key]
        sender: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SessionRoleDelegated {
        #[key]
        session_id: u256,
        #[key]
        role: Role,
        #[key]
        account: ContractAddress,
        delegated_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct EmergencyOverride {
        #[key]
        target: ContractAddress,
        #[key]
        role: Role,
        granted: bool,
        #[key]
        admin: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        // Grant owner role to deployer
        let owner_role_data = RoleData {
            role: Role::ADMIN,
            granted_at: get_block_timestamp(),
            expires_at: 0, // permanent
            granted_by: owner,
        };
        self.roles.entry(owner).write(Role::ADMIN);
        self.role_data.entry(owner).write(owner_role_data);
        self.audit_log_count.entry(owner).write(0);
        self
            .audit_entries
            .entry((owner, 0))
            .write(
                AuditLog {
                    account: owner,
                    role: Role::OWNER,
                    action: 0, // granted
                    timestamp: get_block_timestamp(),
                    actor: owner,
                },
            );

        self.emit(RoleGranted { role: Role::ADMIN, account: owner, sender: owner, expires_at: 0 });
    }

    #[abi(embed_v0)]
    impl AccessControlImpl of IAccessControl<ContractState> {
        fn has_role(self: @ContractState, role: Role, account: ContractAddress) -> bool {
            let role_data: RoleData = self.role_data.entry(account).read();
            return role_data.role == role
                && (role_data.expires_at == 0 || role_data.expires_at > get_block_timestamp());
        }

        fn grant_role(ref self: ContractState, role: Role, account: ContractAddress) {
            let caller = get_caller_address();

            assert(self.has_role(Role::ADMIN, caller), errors::CALLER_UNAUTHORIZED);

            let current_time = get_block_timestamp();
            let role_data = RoleData {
                role: role,
                granted_at: current_time,
                expires_at: 0, // permanent
                granted_by: caller,
            };
            self.roles.entry(account).write(role);
            self.role_data.entry(account).write(role_data);
            self
                .audit_log_count
                .entry(account)
                .write(self.audit_log_count.entry(account).read() + 1);
            self
                .audit_entries
                .entry((account, self.audit_log_count.entry(account).read()))
                .write(
                    AuditLog {
                        account, role, action: 0, // granted
                        timestamp: current_time, actor: caller,
                    },
                );

            self.emit(RoleGranted { role, account, sender: caller, expires_at: 0 });
        }

        fn revoke_role(ref self: ContractState, account: ContractAddress) {
            let caller = get_caller_address();
            assert(self.has_role(Role::ADMIN, caller), errors::CALLER_UNAUTHORIZED);
            let role = self.roles.entry(account).read();
            assert(role != Role::NONE, 'Role not granted');

            let role_data = RoleData {
                role: Role::NONE, granted_at: 0, expires_at: 0, granted_by: caller,
            };
            self.roles.entry(account).write(Role::NONE);
            self.role_data.entry(account).write(role_data);
            self
                .audit_log_count
                .entry(account)
                .write(self.audit_log_count.entry(account).read() + 1);
            self
                .audit_entries
                .entry((account, self.audit_log_count.entry(account).read()))
                .write(
                    AuditLog {
                        account,
                        role,
                        action: 1, // revoked
                        timestamp: get_block_timestamp(),
                        actor: caller,
                    },
                );

            self.emit(RoleRevoked { role, account, sender: caller });
        }

        fn batch_grant_roles(
            ref self: ContractState, roles: Array<Role>, accounts: Array<ContractAddress>,
        ) {
            assert(roles.len() == accounts.len(), errors::ARRAY_LENGTH_MISMATCH);

            let caller = get_caller_address();
            assert(self.has_role(Role::ADMIN, caller), errors::CALLER_UNAUTHORIZED);

            let mut i = 0;
            let len = roles.len();
            while i < len {
                let role = *roles[i];
                let account = *accounts[i];
                self.grant_role(role, account);
                i = i + 1;
            }
        }

        fn batch_revoke_roles(ref self: ContractState, accounts: Array<ContractAddress>) {
            let caller = get_caller_address();
            assert(self.has_role(Role::ADMIN, caller), errors::CALLER_UNAUTHORIZED);

            let mut i = 0;
            let len = accounts.len();
            while i < len {
                let account = *accounts[i];
                self.revoke_role(account);
                i = i + 1;
            }
        }

        fn grant_temporary_role(
            ref self: ContractState, role: Role, account: ContractAddress, expires_at: u64,
        ) {
            let caller = get_caller_address();
            assert(self.has_role(Role::ADMIN, caller), errors::CALLER_UNAUTHORIZED);
            assert(expires_at > get_block_timestamp(), 'Expiration must be later');

            let role_data = RoleData {
                role, granted_at: get_block_timestamp(), expires_at, granted_by: caller,
            };
            self.roles.entry(account).write(role);
            self.role_data.entry(account).write(role_data);

            self.emit(RoleGranted { role, account, sender: caller, expires_at });
        }

        fn delegate_session_role(
            ref self: ContractState, session_id: u256, role: Role, account: ContractAddress,
        ) {
            let caller = get_caller_address();
            assert(self.has_role(Role::SESSION_CREATOR, caller), errors::CALLER_UNAUTHORIZED);

            let current_time = get_block_timestamp();
            let delegation = SessionDelegation {
                session_id,
                role,
                delegated_to: account,
                delegated_by: caller,
                granted_at: current_time,
                expires_at: 0 // permanent
            };
            self.session_roles.entry(session_id).write(delegation);
            self
                .audit_log_count
                .entry(account)
                .write(self.audit_log_count.entry(account).read() + 1);
            self
                .audit_entries
                .entry((account, self.audit_log_count.entry(account).read()))
                .write(
                    AuditLog {
                        account,
                        role,
                        action: 2, // delegated
                        timestamp: current_time,
                        actor: caller,
                    },
                );

            self.emit(SessionRoleDelegated { session_id, role, account, delegated_by: caller });
        }

        fn revoke_session_delegation(
            ref self: ContractState, session_id: u256, role: Role, account: ContractAddress,
        ) {
            let caller = get_caller_address();
            assert(self.has_role(Role::SESSION_CREATOR, caller), errors::CALLER_UNAUTHORIZED);

            let delegation = self.session_roles.entry(session_id).read();
            assert(
                delegation.role == role && delegation.delegated_to == account, 'No such delegation',
            );

            self
                .session_roles
                .entry(session_id)
                .write(
                    SessionDelegation {
                        session_id,
                        role,
                        delegated_to: account,
                        delegated_by: caller,
                        granted_at: 0, // revoked
                        expires_at: 0 // revoked
                    },
                );

            self
                .audit_log_count
                .entry(account)
                .write(self.audit_log_count.entry(account).read() + 1);
            self
                .audit_entries
                .entry((account, self.audit_log_count.entry(account).read()))
                .write(
                    AuditLog {
                        account,
                        role,
                        action: 1, // revoked
                        timestamp: get_block_timestamp(),
                        actor: caller,
                    },
                );
        }

        fn has_session_role(
            self: @ContractState, session_id: u256, role: Role, account: ContractAddress,
        ) -> bool {
            let delegation = self.session_roles.entry(session_id).read();
            return delegation.role == role
                && delegation.delegated_to == account
                && (delegation.granted_at != 0 || delegation.expires_at > get_block_timestamp());
        }

        fn get_user_roles(self: @ContractState, account: ContractAddress) -> Array<Role> {
            let mut roles = array![];
            let role_data = self.role_data.entry(account).read();
            if role_data.role != Role::USER {
                roles.append(role_data.role);
            }
            return roles;
        }

        fn is_role_expired(self: @ContractState, role: Role, account: ContractAddress) -> bool {
            let role_data = self.role_data.entry(account).read();
            return role_data.role == role
                && (role_data.expires_at != 0 && role_data.expires_at <= get_block_timestamp());
        }

        fn emergency_override_role(
            ref self: ContractState, target: ContractAddress, role: Role, granted: bool,
        ) {
            let caller = get_caller_address();
            assert(self.has_role(Role::ADMIN, caller), errors::CALLER_UNAUTHORIZED);

            if granted {
                self.grant_role(role, target);
            } else {
                self.revoke_role(target);
            }

            self.emit(EmergencyOverride { target, role: role, granted, admin: caller });
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _assert_valid_role(self: @ContractState, role: Role) {
            assert(
                role == Role::OWNER
                    || role == Role::ADMIN
                    || role == Role::SESSION_CREATOR
                    || role == Role::JUDGE
                    || role == Role::REVIEWER
                    || role == Role::ORACLE
                    || role == Role::USER,
                'Invalid role',
            );
        }

        fn _has_active_role(self: @ContractState, role: Role, account: ContractAddress) -> bool {
            let role_data = self.role_data.entry(account).read();
            return role_data.role == role
                && (role_data.expires_at == 0 || role_data.expires_at > get_block_timestamp());
        }

        fn _assert_can_manage_role(self: @ContractState, role: Role, account: ContractAddress) {
            let caller = get_caller_address();

            assert(self._has_active_role(Role::ADMIN, caller), errors::CALLER_UNAUTHORIZED);
            assert(self._has_active_role(role, account), errors::ACCOUNT_NOT_AUTHORIZED);
        }

        fn _add_audit_log(
            ref self: ContractState, account: ContractAddress, role: Role, action: u64,
        ) {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            let log_count = self.audit_log_count.entry(account).read() + 1;
            self.audit_log_count.entry(account).write(log_count);
            self
                .audit_entries
                .entry((account, log_count))
                .write(AuditLog { account, role, action, timestamp: current_time, actor: caller });
        }
    }
}

#[starknet::interface]
trait IRBACModifiers<TContractState> {
    fn only_owner(self: @TContractState);
    fn only_admin(self: @TContractState);
    fn only_session_creator(self: @TContractState);
    fn only_judge(self: @TContractState);
    fn only_reviewer(self: @TContractState);
    fn only_oracle(self: @TContractState);
    fn only_user(self: @TContractState);
    fn only_role(self: @TContractState, role: Role);
    fn only_session_role(
        self: @TContractState, session_id: u256, role: Role, account: ContractAddress,
    );
}

#[starknet::component]
pub mod RBACComponent {
    use super::{IRBACModifiers, IAccessControlDispatcher, IAccessControlDispatcherTrait, Role};
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};


    #[storage]
    struct Storage {
        access_control_address: ContractAddress,
    }

    #[embeddable_as(RBACModifiersImpl)]
    pub impl RBACModifiers<
        TContractState, +HasComponent<TContractState>,
    > of IRBACModifiers<ComponentState<TContractState>> {
        fn only_owner(self: @ComponentState<TContractState>) {
            self._require_role(Role::OWNER);
        }

        fn only_admin(self: @ComponentState<TContractState>) {
            self._require_role(Role::ADMIN);
        }

        fn only_session_creator(self: @ComponentState<TContractState>) {
            self._require_role(Role::SESSION_CREATOR);
        }

        fn only_judge(self: @ComponentState<TContractState>) {
            self._require_role(Role::JUDGE);
        }

        fn only_reviewer(self: @ComponentState<TContractState>) {
            self._require_role(Role::REVIEWER);
        }

        fn only_oracle(self: @ComponentState<TContractState>) {
            self._require_role(Role::ORACLE);
        }

        fn only_user(self: @ComponentState<TContractState>) {
            self._require_role(Role::USER);
        }

        fn only_role(self: @ComponentState<TContractState>, role: Role) {
            self._require_role(role);
        }

        fn only_session_role(
            self: @ComponentState<TContractState>,
            session_id: u256,
            role: Role,
            account: ContractAddress,
        ) {
            self._require_session_role(session_id, role, account);
        }
    }

    #[generate_trait]
    impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        fn _require_role(self: @ComponentState<TContractState>, role: Role) {
            let access_control = IAccessControlDispatcher {
                contract_address: self.access_control_address.read(),
            };
            assert(access_control.has_role(role, get_caller_address()), 'Access denied: ');
        }

        fn _require_session_role(
            self: @ComponentState<TContractState>,
            session_id: u256,
            role: Role,
            account: ContractAddress,
        ) {
            let access_control = IAccessControlDispatcher {
                contract_address: self.access_control_address.read(),
            };
            assert(
                access_control.has_session_role(session_id, role, account), 'Session Access Denied',
            );
        }

        fn _set_access_control_address(
            ref self: ComponentState<TContractState>, address: ContractAddress,
        ) {
            self.access_control_address.write(address);
        }
    }
}
