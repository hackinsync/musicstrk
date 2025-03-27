# MusicStrk Test Documentation

This document provides an overview of the test cases implemented for the MusicStrk token and factory contracts.

## Token Contract Tests

### Basic Token Functionality Tests

| Test Case | Description | Expected Result |
|-----------|-------------|-----------------|
| `test_deployment` | Verify token contract deploys successfully | Contract deploys with non-zero address |
| `test_initialize` | Initialize token with basic parameters | Token should have correct name, symbol, decimals, and initial supply |
| `test_burn` | Test token burning functionality | Token balance and total supply should decrease accordingly |
| `test_transfer` | Test token transfer between addresses | Sender balance decreases, recipient balance increases, total supply unchanged |
| `test_approve_and_transfer_from` | Test approvals and delegated transfers | Approval set correctly, transfer_from works, balances updated correctly |
| `test_metadata_uri` | Test setting and retrieving metadata URI | Metadata URI should be retrievable and match what was set |
| `test_ownership_transfer` | Test transferring contract ownership | New owner should have ownership rights |

### Token Edge Case Tests

| Test Case | Description | Expected Result |
|-----------|-------------|-----------------|
| `test_edge_cases` | Test zero approval and zero transfers | Zero approvals should be allowed, zero transfers shouldn't change balances |
| `test_decimal_configuration` | Test tokens with different decimal places | Tokens should work correctly with 0, 2, and 18 decimals |
| `test_double_initialization` | Try to initialize token twice | Second initialization should fail |
| `test_6_decimal_precision` | Test token with 6 decimals (like USDC) | Token should handle all operations with 6 decimal precision |
| `test_authorization_failure` | Test initialization by non-owner | Should fail with authorization error |

## Factory Contract Tests

### Basic Factory Functionality Tests

| Test Case | Description | Expected Result |
|-----------|-------------|-----------------|
| `test_successful_music_share_token_deployment` | Deploy token through factory | Token deploys successfully with correct parameters |
| `test_deploy_music_share_token_event` | Verify deployment events | Correct event should be emitted with proper parameters |
| `test_multiple_tokens_per_artist` | Artist deploys multiple tokens | Artist can deploy multiple tokens, all are tracked correctly |
| `test_multiple_artists` | Different artists deploy tokens | Each artist's tokens are tracked separately |
| `test_token_functionality` | Test tokens deployed through factory | Tokens should have full ERC20 functionality |

### Access Control Tests

| Test Case | Description | Expected Result |
|-----------|-------------|-----------------|
| `test_unauthorized_user_deploy_failure` | Unauthorized user tries to deploy | Should fail with authorization error |
| `test_artist_role_management` | Test granting/revoking artist role | Artist can deploy when granted role, can't when revoked |
| `test_grant_artist_role_unauthorized` | Unauthorized user tries to grant role | Should fail with authorization error |

### Factory Edge Case Tests

| Test Case | Description | Expected Result |
|-----------|-------------|-----------------|
| `test_no_deploy_invalid_token_index` | Access token at non-existent index | Should fail with index out of bounds error |
| `test_update_token_class_hash` | Update token implementation class hash | Class hash should update successfully |
| `test_update_token_class_hash_unauthorized` | Unauthorized update of class hash | Should fail with authorization error |
| `test_deploy_factory_with_zero_owner` | Deploy factory with zero address owner | Should fail with owner zero address error |
| `test_deploy_token_with_zero_decimals` | Deploy token with 0 decimal places | Token should function correctly with 0 decimals |
| `test_deploy_token_with_empty_strings` | Deploy token with empty name, symbol and metadata | Token should deploy successfully with empty string values |

## Performance Tests

| Test Case | Description | Expected Result |
|-----------|-------------|-----------------|
| `test_compare_deployment_gas_costs` | Compare direct vs factory deployment | Analyze gas costs, verify both deployment methods work |
| `test_batch_deployment_efficiency` | Deploy multiple tokens through factory | Measure gas usage per token in batch deployment |

## Gas Cost Analysis

Gas costs are measured using transaction spying in the test environment. The results provide insights into:

1. **Direct Deployment**: Deploying a token contract directly
2. **Factory Deployment**: Deploying a token through the factory
3. **Batch Deployment**: Efficiency of deploying multiple tokens through the factory

These measurements help optimize deployment strategies for different scenarios:

- For a single token, direct deployment might be simpler
- For multiple tokens with the same implementation, factory deployment reduces gas costs
- For ecosystem standardization, factory deployment ensures consistency
