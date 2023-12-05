module thalaswap::base_pool {
    use std::option;
    use std::string::{Self, String};

    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_std::event::{Self, EventHandle};
    use aptos_std::type_info;

    use thalaswap::coin_helper;
    use thalaswap::package;

    use thala_manager::manager;

    use fixed_point64::fixed_point64::{Self, FixedPoint64};

    friend thalaswap::init;

    friend thalaswap::stable_pool;
    friend thalaswap::weighted_pool;

    ///
    /// Error Codes
    ///

    const ERR_UNAUTHORIZED: u64 = 0;

    // Initialization
    const ERR_INITIALIZED: u64 = 1;
    const ERR_UNINITIALIZED: u64 = 2;

    // BPS
    const ERR_BPS_GT_10000: u64 = 3;

    ///
    /// Defaults
    ///

    const DEFAULT_SWAP_FEE_PROTOCOL_ALLOCATION_BPS: u64 = 2000;

    ///
    /// Constants
    ///

    const MAX_SUPPORTED_DECIMALS: u8 = 8;
    const MAX_SWAP_FEE: u64 = 1000;

    const BPS_BASE: u64 = 10000;

    ///
    /// Resources
    ///

    /// Used as a placeholder for void Weight & Asset pool type parameters
    struct Null {}

    /// Stores parameters that apply to all pools
    struct BasePoolParams has key {
        swap_fee_protocol_allocation_ratio: FixedPoint64,
        param_change_events: EventHandle<BasePoolParamChangeEvent>
    }

    ///
    /// Events
    ///

    /// Event emitted when a protocol parameter is changed
    struct BasePoolParamChangeEvent has drop, store {
        name: String,

        prev_value: u64,
        new_value: u64
    }

    ///
    /// Initialization
    ///

    public(friend) fun initialize() {
        assert!(!initialized(), ERR_INITIALIZED);

        let resource_account_signer = package::resource_account_signer();
        move_to(&resource_account_signer, BasePoolParams {
            swap_fee_protocol_allocation_ratio: fixed_point64::fraction(DEFAULT_SWAP_FEE_PROTOCOL_ALLOCATION_BPS, BPS_BASE),
            param_change_events: account::new_event_handle<BasePoolParamChangeEvent>(&resource_account_signer),
        });
    }

    ///
    /// Config & Param Management
    ///

    public entry fun set_swap_fee_protocol_allocation_bps(manager: &signer, allocation_bps: u64) acquires BasePoolParams {
        assert!(manager::is_authorized(manager), ERR_UNAUTHORIZED);
        assert!(initialized(), ERR_INITIALIZED);
        assert!(allocation_bps <= BPS_BASE, ERR_BPS_GT_10000);

        let params = borrow_global_mut<BasePoolParams>(package::resource_account_address());
        let prev_bps = fixed_point64::decode(fixed_point64::mul(params.swap_fee_protocol_allocation_ratio, BPS_BASE));
        params.swap_fee_protocol_allocation_ratio = fixed_point64::fraction(allocation_bps, BPS_BASE);
        event::emit_event<BasePoolParamChangeEvent>(
            &mut params.param_change_events,
            BasePoolParamChangeEvent { name: string::utf8(b"swap_fee_protocol_allocation_bps"), prev_value: prev_bps, new_value: allocation_bps }
        );
    }

    //
    // Functions
    //

    #[view]
    /// Return the token supply of an LP token. LP token supply is always denominated in units of u64
    public fun pool_token_supply<LPCoinType>(): u64 {
        (option::extract(&mut coin::supply<LPCoinType>()) as u64)
    }

    /// Checks ordering, unique coins, & coin decimals
    /// Returns (success, number of assets in a pool)
    public(friend) fun validate_pool_assets<X, Y, Z, W>(): bool {
        // check if X & Y are the only specified assets
        if (is_null<X>() || is_null<Y>()) return false;
        if (coin::decimals<X>() > MAX_SUPPORTED_DECIMALS || coin::decimals<Y>() > MAX_SUPPORTED_DECIMALS) return false;
        if (!coin_helper::is_unique_and_sorted<X, Y>()) return false;
        if (is_null<Z>()) {
            if (is_null<W>()) return true
            else return false // W must also be Null if Z is Null
        };

        // check if X, Y & Z are the only specified assets
        if (coin::decimals<Z>() > MAX_SUPPORTED_DECIMALS) return false;
        if (!coin_helper::is_unique_and_sorted<Y, Z>()) return false;
        if (is_null<W>()) return true;

        // check if X, Y, Z, & W (all) are specified assets
        if (coin::decimals<W>() > MAX_SUPPORTED_DECIMALS) return false;
        coin_helper::is_unique_and_sorted<Z, W>()
    }

    /// Validates that the swap fee is between bounds
    public(friend) fun validate_swap_fee(swap_fee_bps: u64): bool {
        swap_fee_bps <= MAX_SWAP_FEE
    }

    public fun is_null<CoinType>(): bool {
        type_info::type_name<Null>() == type_info::type_name<CoinType>()
    }

    // Public Getters

    public(friend) fun initialized(): bool {
        exists<BasePoolParams>(package::resource_account_address())
    }

    #[view]
    public fun swap_fee_protocol_allocation_ratio(): FixedPoint64 acquires BasePoolParams {
        let params = borrow_global_mut<BasePoolParams>(package::resource_account_address());
        params.swap_fee_protocol_allocation_ratio
    }

    #[view]
    public fun max_supported_decimals(): u8 {
        MAX_SUPPORTED_DECIMALS
    }


    #[test_only]
    struct FakeCoin_A {}

    #[test_only]
    struct FakeCoin_B {}

    #[test_only]
    struct FakeCoin_C {}

    #[test_only]
    struct FakeCoin_D {}
    
    #[test_only]
    use test_utils::coin_test;

    #[test(manager = @thalaswap)]
    fun validate_pool_assets_ok(manager: &signer) {
        coin_test::initialize_fake_coin<FakeCoin_A>(manager);
        coin_test::initialize_fake_coin<FakeCoin_B>(manager);
        coin_test::initialize_fake_coin<FakeCoin_C>(manager);
        coin_test::initialize_fake_coin<FakeCoin_D>(manager);

        // test
        assert!(validate_pool_assets<FakeCoin_A, FakeCoin_B, Null, Null>(), 0);
        assert!(validate_pool_assets<FakeCoin_A, FakeCoin_B, FakeCoin_C, Null>(), 0);
        assert!(validate_pool_assets<FakeCoin_A, FakeCoin_B, FakeCoin_C, FakeCoin_D>(), 0);
    }

    #[test(manager = @thalaswap)]
    fun validate_pool_assets_nok(manager: &signer) {
        coin_test::initialize_fake_coin<FakeCoin_A>(manager);
        coin_test::initialize_fake_coin<FakeCoin_B>(manager);
        coin_test::initialize_fake_coin<FakeCoin_C>(manager);
        coin_test::initialize_fake_coin_with_decimals<FakeCoin_D>(manager, 10); // over MAX_SUPPORTED_DECIMALS

        // test

        // insufficient asset count
        assert!(!validate_pool_assets<FakeCoin_A, Null, Null, Null>(), 0);

        // invalid 3-pool format
        assert!(!validate_pool_assets<FakeCoin_A, FakeCoin_B, Null, FakeCoin_C>(), 0);

        // over MAX_SUPPORTED_DECIMALS
        assert!(!validate_pool_assets<FakeCoin_A, FakeCoin_B, FakeCoin_D, Null>(), 0);

        // invalid ordering
        assert!(!validate_pool_assets<FakeCoin_B, FakeCoin_A, Null, Null>(), 0);

        // duplicate
        assert!(!validate_pool_assets<FakeCoin_A, FakeCoin_A, FakeCoin_B, Null>(), 0);

        // invalid ordering & duplicate
        assert!(!validate_pool_assets<FakeCoin_A, FakeCoin_B, FakeCoin_C, FakeCoin_A>(), 0);
    }
}
