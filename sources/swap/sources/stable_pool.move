module thalaswap::stable_pool {
    use std::signer;
    use std::string::{Self, String};
    use std::vector;

    use aptos_framework::account;
    use aptos_framework::coin::{Self, Coin, MintCapability, BurnCapability};

    use aptos_std::type_info;
    use aptos_std::table::{Self, Table};
    use aptos_std::event::{Self, EventHandle};
    use aptos_std::math64;

    use thalaswap::base_pool;
    use thalaswap::fees;
    use thalaswap::package;

    use thalaswap_math::stable_math;

    use thala_manager::manager;

    use fixed_point64::fixed_point64::{Self, FixedPoint64};

    friend thalaswap::init;

    ///
    /// Error codes
    ///

    const ERR_UNAUTHORIZED: u64 = 0;

    // Initialization
    const ERR_INITIALIZED: u64 = 1;
    const ERR_UNINITIALIZED: u64 = 2;

    // Pool Conditions
    const ERR_STABLE_POOL_EXISTS: u64 = 3;
    const ERR_STABLE_POOL_NOT_EXISTS: u64 = 4;
    const ERR_STABLE_POOL_INVALID_POOL_ASSETS: u64 = 5;
    const ERR_STABLE_POOL_INVARIANT_NOT_INCREASING: u64 = 6;
    const ERR_STABLE_POOL_INSUFFICIENT_INPUT: u64 = 7;
    const ERR_STABLE_POOL_INSUFFICIENT_LIQUIDITY: u64 = 8;

    // Swap Conditions
    const ERR_STABLE_POOL_INVALID_SWAP: u64 = 9;

    // Management
    const ERR_STABLE_POOL_INVALID_SWAP_FEE: u64 = 9;

    // Input check
    const ERR_STABLE_POOL_AMP_FACTOR_OUT_OF_BOUND: u64 = 10;

    // Math
    const ERR_DIVIDE_BY_ZERO: u64 = 11;

    ///
    /// Defaults
    ///

    const DEFAULT_SWAP_FEE_BPS: u64 = 10;

    ///
    /// Constants
    ///

    const POOL_TOKEN_DECIMALS: u8 = 8;
    const MINIMUM_LIQUIDITY: u64 = 100;

    /// A sane upper bound of amp factor so that it cannot go arbitrarily high
    const MAX_AMP_FACTOR: u64 = 10000;

    const BPS_BASE: u64 = 10000;

    ///
    /// Resources
    ///

    /// Token issued to LPs represnting fractional ownership of the pool
    struct StablePoolToken<phantom Asset0, phantom Asset1, phantom Asset2, phantom Asset3> {}

    struct StablePool<phantom Asset0, phantom Asset1, phantom Asset2, phantom Asset3> has key {
        asset_0: Coin<Asset0>,
        asset_1: Coin<Asset1>,
        asset_2: Coin<Asset2>,
        asset_3: Coin<Asset3>,

        amp_factor: u64,

        // multipliers for each pooled asset's precision to get to base_pool::max_supported_decimals()
        // for example, MOD has 8 decimals, so the multiplier should be 1 (=10^0).
        // let's say USDC has 6, then the multiplier should be 100 (=10^(8-6))
        precision_multipliers: vector<u64>,

        swap_fee_ratio: FixedPoint64,
        inverse_negated_swap_fee_ratio: FixedPoint64,

        pool_token_mint_cap: MintCapability<StablePoolToken<Asset0, Asset1, Asset2, Asset3>>,
        pool_token_burn_cap: BurnCapability<StablePoolToken<Asset0, Asset1, Asset2, Asset3>>,

        reserved_lp_coin: Coin<StablePoolToken<Asset0, Asset1, Asset2, Asset3>>,

        events: StablePoolEvents<Asset0, Asset1, Asset2, Asset3>,
    }

    struct StablePoolLookup has key {
        // key: LP token type_name, value: StablePoolInfo
        // this is used to help LP oracle to query the status of a pool using LP token name
        name_to_pool: Table<String, StablePoolInfo>,
        
        // key: unique pool ID, value: LP token type_name
        // this is to help DEX aggregator (e.g. Hippo) to iterate all pools
        id_to_name: Table<u64, String>,

        // Pool ID increments for each new pool
        next_id: u64,
    }

    /// Stores the status of a pool without "CoinType" generic type
    /// Can be used to query the status of a pool by LP token name - mainly used by Thalaswap LP Oracle (in ThalaOracle package)
    struct StablePoolInfo has copy, store, drop {
        balances: vector<u64>,
        precision_multipliers: vector<u64>,
        amp_factor: u64,
        lp_coin_supply: u64
    }

    struct StablePoolParams has key {
        default_swap_fee_ratio: FixedPoint64,
        param_change_events: EventHandle<StablePoolParamChangeEvent>
    }

    ///
    /// Events
    ///

    /// Event emitted when a pool is created
    struct StablePoolCreationEvent<phantom Asset0, phantom Asset1, phantom Asset2, phantom Asset3> has drop, store {
        creator: address,
        amount_0: u64,
        amount_1: u64,
        amount_2: u64,
        amount_3: u64,
        minted_lp_coin_amount: u64,
        swap_fee_bps: u64,
    }

    /// Event emitted when a liquidity is added to a pool
    struct AddLiquidityEvent<phantom Asset0, phantom Asset1, phantom Asset2, phantom Asset3> has drop, store {
        amount_0: u64,
        amount_1: u64,
        amount_2: u64,
        amount_3: u64,
        minted_lp_coin_amount: u64,
    }

    /// Event emitted when a liquidity is removed from a pool
    struct RemoveLiquidityEvent<phantom Asset0, phantom Asset1, phantom Asset2, phantom Asset3> has drop, store {
        amount_0: u64,
        amount_1: u64,
        amount_2: u64,
        amount_3: u64,
        burned_lp_coin_amount: u64,
    }

    /// Event emitted when a swap is executed
    struct SwapEvent<phantom Asset0, phantom Asset1, phantom Asset2, phantom Asset3> has drop, store {
        idx_in: u64,
        idx_out: u64,
        amount_in: u64,
        amount_out: u64,
        fee_amount: u64,
        pool_balance_0: u64,
        pool_balance_1: u64,
        pool_balance_2: u64,
        pool_balance_3: u64,
        amp_factor: u64,
    }

    /// Event emitted when a protocol parameter is changed
    struct StablePoolParamChangeEvent has drop, store {
        name: String,

        prev_value: u64,
        new_value: u64
    }

    struct StablePoolEvents<phantom Asset0, phantom Asset1, phantom Asset2, phantom Asset3> has store {
        pool_creation_events: EventHandle<StablePoolCreationEvent<Asset0, Asset1, Asset2, Asset3>>,
        add_liquidity_events: EventHandle<AddLiquidityEvent<Asset0, Asset1, Asset2, Asset3>>,
        remove_liquidity_events: EventHandle<RemoveLiquidityEvent<Asset0, Asset1, Asset2, Asset3>>,
        swap_events: EventHandle<SwapEvent<Asset0, Asset1, Asset2, Asset3>>,

        param_change_events: EventHandle<StablePoolParamChangeEvent>
    }

    ///
    /// Initialization
    ///

    /// Creates new resource account for this stable pool module.
    public(friend) fun initialize() {
        assert!(!initialized(), ERR_INITIALIZED);

        // Required Dependencies
        assert!(base_pool::initialized(), ERR_UNINITIALIZED);

        let resource_account_signer = package::resource_account_signer();
        move_to(&resource_account_signer, StablePoolLookup { 
            name_to_pool: table::new(),
            id_to_name: table::new(),
            next_id: 0
        });
        move_to(&resource_account_signer, StablePoolParams {
            default_swap_fee_ratio: fixed_point64::fraction(DEFAULT_SWAP_FEE_BPS, BPS_BASE),
            param_change_events: account::new_event_handle<StablePoolParamChangeEvent>(&resource_account_signer),
        });
    }

    ///
    /// Config & Param Management
    ///

    public entry fun set_default_pool_swap_fee_bps(manager: &signer, bps: u64) acquires StablePoolParams {
        assert!(manager::is_authorized(manager), ERR_UNAUTHORIZED);
        assert!(initialized(), ERR_INITIALIZED);
        assert!(base_pool::validate_swap_fee(bps), ERR_STABLE_POOL_INVALID_SWAP_FEE);

        let params = borrow_global_mut<StablePoolParams>(package::resource_account_address());
        let prev_bps = fixed_point64::decode(fixed_point64::mul(params.default_swap_fee_ratio, BPS_BASE));
        params.default_swap_fee_ratio = fixed_point64::fraction(bps, BPS_BASE);
        event::emit_event<StablePoolParamChangeEvent>(
            &mut params.param_change_events,
            StablePoolParamChangeEvent { name: string::utf8(b"default_swap_fee_bps"), prev_value: prev_bps, new_value: bps }
        );
    }

    ///
    /// Functions
    ///

    public fun create_stable_pool<Asset0, Asset1, Asset2, Asset3>(
        account: &signer,
        asset_0: Coin<Asset0>,
        asset_1: Coin<Asset1>,
        asset_2: Coin<Asset2>,
        asset_3: Coin<Asset3>,
        amp_factor: u64,
    ): Coin<StablePoolToken<Asset0, Asset1, Asset2, Asset3>> acquires StablePoolParams, StablePoolLookup {
        assert!(initialized(), ERR_UNINITIALIZED);
        assert!(base_pool::validate_pool_assets<Asset0, Asset1, Asset2, Asset3>(), ERR_STABLE_POOL_INVALID_POOL_ASSETS);
        assert!(!stable_pool_exists<Asset0, Asset1, Asset2, Asset3>(), ERR_STABLE_POOL_EXISTS);
        assert!(amp_factor > 0 && amp_factor <= MAX_AMP_FACTOR, ERR_STABLE_POOL_AMP_FACTOR_OUT_OF_BOUND);

        let amount_0 = coin::value(&asset_0);
        let amount_1 = coin::value(&asset_1);
        let amount_2 = coin::value(&asset_2);
        let amount_3 = coin::value(&asset_3);

        // If an Asset is non-null, it must have a non-zero amount. First two assets are mandatory
        assert!(amount_0 > 0 && amount_1 > 0, ERR_STABLE_POOL_INVALID_POOL_ASSETS);
        if (base_pool::is_null<Asset2>()) {
            // Only 2 Assets
            assert!(amount_2 == 0 && amount_3 == 0, ERR_STABLE_POOL_INVALID_POOL_ASSETS);
        } else if (base_pool::is_null<Asset3>()) {
            // Only 3 Assets
            assert!(amount_2 > 0 && amount_3 == 0, ERR_STABLE_POOL_INVALID_POOL_ASSETS);
        } else {
            // All 4 Assets
            assert!(amount_2 > 0 && amount_3 > 0, ERR_STABLE_POOL_INVALID_POOL_ASSETS);
        };

        let resource_account_address = package::resource_account_address();
        let resource_account_signer = package::resource_account_signer();
        let params = borrow_global<StablePoolParams>(resource_account_address);

        let (pool_token_burn_cap, pool_token_mint_cap) = {
            let (burn_cap, freeze_cap, mint_cap) = coin::initialize<StablePoolToken<Asset0, Asset1, Asset2, Asset3>>(
                &resource_account_signer,
                lp_short_name<Asset0, Asset1, Asset2, Asset3>(),
                string::utf8(b"THALA-LP"),
                POOL_TOKEN_DECIMALS,
                true
            );

            coin::destroy_freeze_cap(freeze_cap);
            (burn_cap, mint_cap)
        };

        let swap_fee_ratio = params.default_swap_fee_ratio;
        let one_fp = fixed_point64::one();
        let inverse_negated_swap_fee_ratio = fixed_point64::div_fp(one_fp, fixed_point64::sub_fp(one_fp, swap_fee_ratio));

        let precision_multipliers = get_precision_multipliers<Asset0, Asset1, Asset2, Asset3>();
        let reserved_lp_coin = coin::mint(MINIMUM_LIQUIDITY, &pool_token_mint_cap);
        let pool = StablePool<Asset0, Asset1, Asset2, Asset3> {
            asset_0, asset_1, asset_2, asset_3,
            amp_factor,
            precision_multipliers,
            pool_token_mint_cap,
            pool_token_burn_cap,
            reserved_lp_coin,
            swap_fee_ratio,
            inverse_negated_swap_fee_ratio,
            events: StablePoolEvents<Asset0, Asset1, Asset2, Asset3> {
                pool_creation_events: account::new_event_handle<StablePoolCreationEvent<Asset0, Asset1, Asset2, Asset3>>(&resource_account_signer),
                add_liquidity_events: account::new_event_handle<AddLiquidityEvent<Asset0, Asset1, Asset2, Asset3>>(&resource_account_signer),
                remove_liquidity_events: account::new_event_handle<RemoveLiquidityEvent<Asset0, Asset1, Asset2, Asset3>>(&resource_account_signer),
                swap_events: account::new_event_handle<SwapEvent<Asset0, Asset1, Asset2, Asset3>>(&resource_account_signer),
                param_change_events: account::new_event_handle<StablePoolParamChangeEvent>(&resource_account_signer),
            }
        };

        // Create liquidity
        let initial_lp_coin_amount = (stable_math::compute_invariant(&get_xp(&pool), amp_factor) as u64);
        assert!(initial_lp_coin_amount > MINIMUM_LIQUIDITY, ERR_STABLE_POOL_INSUFFICIENT_LIQUIDITY);

        event::emit_event<StablePoolCreationEvent<Asset0, Asset1, Asset2, Asset3>>(
            &mut pool.events.pool_creation_events, StablePoolCreationEvent {
                amount_0, amount_1, amount_2, amount_3,
                creator: signer::address_of(account),
                minted_lp_coin_amount: initial_lp_coin_amount,
                swap_fee_bps: fixed_point64::decode(fixed_point64::mul(params.default_swap_fee_ratio, BPS_BASE))
            }
        );

        let lp_coin = coin::mint(initial_lp_coin_amount - MINIMUM_LIQUIDITY, &pool.pool_token_mint_cap);
        update_pool_lookup(&pool, true);
        move_to(&resource_account_signer, pool);

        lp_coin
    }

    public entry fun set_pool_swap_fee_bps<Asset0, Asset1, Asset2, Asset3>(manager: &signer, swap_fee_bps: u64) acquires StablePool {
        assert!(manager::is_authorized(manager), ERR_UNAUTHORIZED);
        assert!(initialized(), ERR_UNINITIALIZED);
        assert!(base_pool::validate_swap_fee(swap_fee_bps), ERR_STABLE_POOL_INVALID_SWAP_FEE);

        let pool = borrow_global_mut<StablePool<Asset0, Asset1, Asset2, Asset3>>(package::resource_account_address());
        let prev_swap_fee_bps = fixed_point64::decode(fixed_point64::mul(pool.swap_fee_ratio, BPS_BASE));
        pool.swap_fee_ratio = fixed_point64::fraction(swap_fee_bps, BPS_BASE);

        let one_fp = fixed_point64::one();
        pool.inverse_negated_swap_fee_ratio = fixed_point64::div_fp(one_fp, fixed_point64::sub_fp(one_fp, pool.swap_fee_ratio));

        event::emit_event<StablePoolParamChangeEvent>(
            &mut pool.events.param_change_events,
            StablePoolParamChangeEvent { name: string::utf8(b"swap_fee_bps"), prev_value: prev_swap_fee_bps, new_value: swap_fee_bps }
        );
    }

    public entry fun set_amp_factor<Asset0, Asset1, Asset2, Asset3>(manager: &signer, amp_factor: u64) acquires StablePool, StablePoolLookup {
        assert!(manager::is_authorized(manager), ERR_UNAUTHORIZED);
        assert!(initialized(), ERR_UNINITIALIZED);
        assert!(amp_factor > 0 && amp_factor <= MAX_AMP_FACTOR, ERR_STABLE_POOL_AMP_FACTOR_OUT_OF_BOUND);

        let pool = borrow_global_mut<StablePool<Asset0, Asset1, Asset2, Asset3>>(package::resource_account_address());
        let prev_amp_factor = pool.amp_factor;
        pool.amp_factor = amp_factor;
        event::emit_event<StablePoolParamChangeEvent>(
            &mut pool.events.param_change_events,
            StablePoolParamChangeEvent { name: string::utf8(b"amp_factor"), prev_value: prev_amp_factor, new_value: amp_factor }
        );

        update_pool_lookup(pool, false);
    }

    public fun add_liquidity<Asset0, Asset1, Asset2, Asset3>(
        asset_0: Coin<Asset0>,
        asset_1: Coin<Asset1>,
        asset_2: Coin<Asset2>,
        asset_3: Coin<Asset3>
    ): Coin<StablePoolToken<Asset0, Asset1, Asset2, Asset3>> acquires StablePool, StablePoolLookup {
        assert!(initialized(), ERR_UNINITIALIZED);

        let resource_account_address = package::resource_account_address();
        let pool = borrow_global_mut<StablePool<Asset0, Asset1, Asset2, Asset3>>(resource_account_address);
        let amp = pool.amp_factor;

        let amount_0 = coin::value(&asset_0);
        let amount_1 = coin::value(&asset_1);
        let amount_2 = coin::value(&asset_2);
        let amount_3 = coin::value(&asset_3);

        let prev_inv = stable_math::compute_invariant(&get_xp(pool), amp);

        coin::merge(&mut pool.asset_0, asset_0);
        coin::merge(&mut pool.asset_1, asset_1);
        coin::merge(&mut pool.asset_2, asset_2);
        coin::merge(&mut pool.asset_3, asset_3);

        // Invariant should always increase when liquidity is added
        let inv = stable_math::compute_invariant(&get_xp(pool), amp);
        assert!(inv > prev_inv, ERR_STABLE_POOL_INVARIANT_NOT_INCREASING);

        let total_supply = base_pool::pool_token_supply<StablePoolToken<Asset0, Asset1, Asset2, Asset3>>();
        let liquidity = (((total_supply as u256) * (inv - prev_inv) / prev_inv) as u64);
        event::emit_event<AddLiquidityEvent<Asset0, Asset1, Asset2, Asset3>>(
            &mut pool.events.add_liquidity_events,
            AddLiquidityEvent { amount_0, amount_1, amount_2, amount_3, minted_lp_coin_amount: liquidity }
        );

        let lp_coin = coin::mint(liquidity, &pool.pool_token_mint_cap);

        update_pool_lookup(pool, false);

        lp_coin
    }

    public fun remove_liquidity<Asset0, Asset1, Asset2, Asset3>(
        lp_coin: Coin<StablePoolToken<Asset0, Asset1, Asset2, Asset3>>
    ): (Coin<Asset0>, Coin<Asset1>, Coin<Asset2>, Coin<Asset3>) acquires StablePool, StablePoolLookup {
        assert!(initialized(), ERR_UNINITIALIZED);

        let resource_account_address = package::resource_account_address();
        let pool = borrow_global_mut<StablePool<Asset0, Asset1, Asset2, Asset3>>(resource_account_address);

        let lp_coin_amount = coin::value(&lp_coin);
        let total_supply = base_pool::pool_token_supply<StablePoolToken<Asset0, Asset1, Asset2, Asset3>>();

        let lp_ratio = fixed_point64::fraction(lp_coin_amount, total_supply);

        let amount_0 = fixed_point64::decode_round_down(fixed_point64::mul(lp_ratio, coin::value(&pool.asset_0)));
        let amount_1 = fixed_point64::decode_round_down(fixed_point64::mul(lp_ratio, coin::value(&pool.asset_1)));
        let amount_2 = fixed_point64::decode_round_down(fixed_point64::mul(lp_ratio, coin::value(&pool.asset_2)));
        let amount_3 = fixed_point64::decode_round_down(fixed_point64::mul(lp_ratio, coin::value(&pool.asset_3)));

        let out_0 = coin::extract(&mut pool.asset_0, amount_0);
        let out_1 = coin::extract(&mut pool.asset_1, amount_1);
        let out_2 = coin::extract(&mut pool.asset_2, amount_2);
        let out_3 = coin::extract(&mut pool.asset_3, amount_3);

        coin::burn(lp_coin, &pool.pool_token_burn_cap);
        event::emit_event<RemoveLiquidityEvent<Asset0, Asset1, Asset2, Asset3>>(
            &mut pool.events.remove_liquidity_events,
            RemoveLiquidityEvent { amount_0, amount_1, amount_2, amount_3, burned_lp_coin_amount: lp_coin_amount }
        );
        
        update_pool_lookup(pool, false);

        (out_0, out_1, out_2, out_3)
    }

    public fun swap_exact_in<Asset0, Asset1, Asset2, Asset3, X, Y>(coin_in: Coin<X>): Coin<Y> acquires StablePool, StablePoolLookup {
        assert!(initialized(), ERR_UNINITIALIZED);

        // Ensure Input
        let amount_in = coin::value(&coin_in);
        assert!(amount_in > 0, ERR_STABLE_POOL_INSUFFICIENT_INPUT);

        let resource_account_address = package::resource_account_address();
        let pool = borrow_global_mut<StablePool<Asset0, Asset1, Asset2, Asset3>>(resource_account_address);

        let typeof_x = type_info::type_of<X>();
        let typeof_y = type_info::type_of<Y>();
        assert!(typeof_x != typeof_y && !base_pool::is_null<X>() && !base_pool::is_null<Y>(), ERR_STABLE_POOL_INVALID_SWAP);

        let (is_in_0, is_in_1, is_in_2, is_in_3) = (typeof_x == type_info::type_of<Asset0>(), typeof_x == type_info::type_of<Asset1>(), typeof_x == type_info::type_of<Asset2>(), typeof_x == type_info::type_of<Asset3>());
        assert!(is_in_0 || is_in_1 || is_in_2 || is_in_3, ERR_STABLE_POOL_INVALID_SWAP);

        let (is_out_0, is_out_1, is_out_2, is_out_3) = (typeof_y == type_info::type_of<Asset0>(), typeof_y == type_info::type_of<Asset1>(), typeof_y == type_info::type_of<Asset2>(), typeof_y == type_info::type_of<Asset3>());
        assert!(is_out_0 || is_out_1 || is_out_2 || is_out_3, ERR_STABLE_POOL_INVALID_SWAP);

        // Compute fee allocation & adjust the input that is swapped as a result
        let total_fee_amount = fixed_point64::decode(fixed_point64::mul(pool.swap_fee_ratio, amount_in));
        let protocol_fee_amount = fixed_point64::decode(fixed_point64::mul(base_pool::swap_fee_protocol_allocation_ratio(), total_fee_amount));
        let amount_in_post_fee = amount_in - total_fee_amount;

        // Absorb Protocol Fees
        fees::absorb_fee(coin::extract(&mut coin_in, protocol_fee_amount));

        // Compute Swap Output
        let idx_in = if (is_in_0) 0 else if (is_in_1) 1 else if (is_in_2) 2 else 3;
        let idx_out = if (is_out_0) 0 else if (is_out_1) 1 else if (is_out_2) 2 else 3;
        let xp = &get_xp(pool);
        let calc_in = amount_in_post_fee * *vector::borrow(&pool.precision_multipliers, idx_in);
        let calc_out = stable_math::calc_out_given_in(pool.amp_factor, idx_in, idx_out, calc_in, xp);
        let amount_out = calc_out / *vector::borrow(&pool.precision_multipliers, idx_out);

        // Absorb Swapped In Asset. Yield is provided to LPs by their implicit increased in value with the lp fees included in `coin_in`
        deposit_to_pool<Asset0, Asset1, Asset2, Asset3, X>(resource_account_address, idx_in, coin_in);

        // Extract Swapped out Asset
        let coin_out = extract_from_pool<Asset0, Asset1, Asset2, Asset3, Y>(resource_account_address, idx_out, amount_out);

        let pool = borrow_global_mut<StablePool<Asset0, Asset1, Asset2, Asset3>>(resource_account_address);
        event::emit_event<SwapEvent<Asset0, Asset1, Asset2, Asset3>>(
            &mut pool.events.swap_events, SwapEvent { 
                idx_in, idx_out,
                amount_in, amount_out,
                fee_amount: total_fee_amount,
                pool_balance_0: coin::value(&pool.asset_0),
                pool_balance_1: coin::value(&pool.asset_1),
                pool_balance_2: coin::value(&pool.asset_2),
                pool_balance_3: coin::value(&pool.asset_3),
                amp_factor: pool.amp_factor,
            }
        );
        
        update_pool_lookup(pool, false);

        coin_out
    }

    // Swap with exact amount out
    // X is input coin, Y is output coin
    // Returns extra amount of coin X refunded, and output coin Y
    public fun swap_exact_out<Asset0, Asset1, Asset2, Asset3, X, Y>(coin_in: Coin<X>, amount_out: u64): (Coin<X>, Coin<Y>) acquires StablePool, StablePoolLookup {
        assert!(initialized(), ERR_UNINITIALIZED);
        let provided_amount_in = coin::value(&coin_in);

        assert!(amount_out > 0, ERR_STABLE_POOL_INVALID_SWAP);
        assert!(provided_amount_in > 0, ERR_STABLE_POOL_INVALID_SWAP);

        let resource_account_address = package::resource_account_address();
        let pool = borrow_global_mut<StablePool<Asset0, Asset1, Asset2, Asset3>>(resource_account_address);
        
        let typeof_x = type_info::type_of<X>();
        let typeof_y = type_info::type_of<Y>();
        assert!(typeof_x != typeof_y && !base_pool::is_null<X>() && !base_pool::is_null<Y>(), ERR_STABLE_POOL_INVALID_SWAP);

        let (is_in_0, is_in_1, is_in_2, is_in_3) = (typeof_x == type_info::type_of<Asset0>(), typeof_x == type_info::type_of<Asset1>(), typeof_x == type_info::type_of<Asset2>(), typeof_x == type_info::type_of<Asset3>());
        assert!(is_in_0 || is_in_1 || is_in_2 || is_in_3, ERR_STABLE_POOL_INVALID_SWAP);

        let (is_out_0, is_out_1, is_out_2, is_out_3) = (typeof_y == type_info::type_of<Asset0>(), typeof_y == type_info::type_of<Asset1>(), typeof_y == type_info::type_of<Asset2>(), typeof_y == type_info::type_of<Asset3>());
        assert!(is_out_0 || is_out_1 || is_out_2 || is_out_3, ERR_STABLE_POOL_INVALID_SWAP);
        
        let idx_in = if (is_in_0) 0 else if (is_in_1) 1 else if (is_in_2) 2 else 3;
        let (idx_out, pool_balance_out) = if (is_out_0) {
            (0, coin::value(&pool.asset_0))
        } else if (is_out_1) {
            (1, coin::value(&pool.asset_1))
        } else if (is_out_2) { 
            (2, coin::value(&pool.asset_2))
        } else {
            (3, coin::value(&pool.asset_3))
        };

        // Ensure Liquidity & Input. Asset in the pool must have enough balance for the swap
        assert!(amount_out < pool_balance_out, ERR_STABLE_POOL_INSUFFICIENT_LIQUIDITY);

        // Compute Swap Input
        //  - `amount_in_post_fee` calculated needs to be increased to also include the swap fee. `amount_in_post_fee / (1 - swap_fee_ratio)` represents the
        //  the input necessary to generate `amount_out` with an input that also accounts for the necesarry fee.
        let xp = &get_xp(pool);
        let calc_out = amount_out * *vector::borrow(&pool.precision_multipliers, idx_out);
        let calc_in = stable_math::calc_in_given_out(pool.amp_factor, idx_in, idx_out, calc_out, xp);
        let amount_in_post_fee = calc_in / *vector::borrow(&pool.precision_multipliers, idx_in);
        let amount_in = fixed_point64::decode(fixed_point64::mul(pool.inverse_negated_swap_fee_ratio, amount_in_post_fee));
        assert!(amount_in <= provided_amount_in, ERR_STABLE_POOL_INSUFFICIENT_INPUT);

        let total_fee_amount = amount_in - amount_in_post_fee;
        let protocol_fee_amount = fixed_point64::decode(fixed_point64::mul(base_pool::swap_fee_protocol_allocation_ratio(), total_fee_amount));
        let amount_in_post_protocol_fee = amount_in - protocol_fee_amount;
        
        // Absorb Protocol Fees
        fees::absorb_fee(coin::extract(&mut coin_in, protocol_fee_amount));

        // Absorb Swapped In Asset. Yield is provided to LPs by their implicit increased in value with the lp fees included in `coin_in`
        deposit_to_pool<Asset0, Asset1, Asset2, Asset3, X>(resource_account_address, idx_in, coin::extract(&mut coin_in, amount_in_post_protocol_fee));
        
        // Extract Swapped out Asset
        let coin_out = extract_from_pool<Asset0, Asset1, Asset2, Asset3, Y>(resource_account_address, idx_out, amount_out);
        
        let pool = borrow_global_mut<StablePool<Asset0, Asset1, Asset2, Asset3>>(resource_account_address);
        event::emit_event<SwapEvent<Asset0, Asset1, Asset2, Asset3>>(
            &mut pool.events.swap_events, SwapEvent { 
                idx_in, idx_out,
                amount_in, amount_out,
                fee_amount: total_fee_amount,
                pool_balance_0: coin::value(&pool.asset_0),
                pool_balance_1: coin::value(&pool.asset_1),
                pool_balance_2: coin::value(&pool.asset_2),
                pool_balance_3: coin::value(&pool.asset_3),
                amp_factor: pool.amp_factor,
            }
        );
        
        update_pool_lookup(pool, false);

        (coin_in, coin_out)
    }

    // Public Getters

    public fun initialized(): bool {
        exists<StablePoolParams>(package::resource_account_address())
    }

    #[view]
    public fun stable_pool_exists<Asset0, Asset1, Asset2, Asset3>(): bool {
        exists<StablePool<Asset0, Asset1, Asset2, Asset3>>(package::resource_account_address())
    }

    #[view]
    /// Returns pool balances, amp factor, and lp coin supply
    /// **Note** Balances are normalized to the same precision -- `base_pool::max_supported_decimals()`
    public fun pool_info(lp_coin_name: String): (vector<u64>, u64, u64) acquires StablePoolLookup {
        let lookup = borrow_global<StablePoolLookup>(package::resource_account_address());
        assert!(table::contains(&lookup.name_to_pool, lp_coin_name), ERR_STABLE_POOL_NOT_EXISTS);
        let info = table::borrow(&lookup.name_to_pool, lp_coin_name);
        
        // TODO: in the future we can use higher-order inline functions in AIP-8 https://github.com/aptos-foundation/AIPs/blob/main/aips/higher-order-functions.md
        let balances = vector::empty<u64>();
        let num_assets = vector::length(&info.balances);
        let i = 0;
        while (i < num_assets) {
            vector::push_back(&mut balances, *vector::borrow(&info.balances, i) * *vector::borrow(&info.precision_multipliers, i));
            i = i + 1;
        };

        (balances, info.amp_factor, info.lp_coin_supply)
    }

    #[view]
    /// Get a list of balances. **Note** Balances are normalized to the same precision -- `base_pool::max_supported_decimals()`
    public fun pool_balances<Asset0, Asset1, Asset2, Asset3>(): vector<u64>
    acquires StablePool {
        let resource_account_address = package::resource_account_address();
        let pool = borrow_global<StablePool<Asset0, Asset1, Asset2, Asset3>>(resource_account_address);
        get_xp(pool)
    }

    #[view]
    /// Extract the AMP factor of a stable pool
    public fun pool_amp_factor<Asset0, Asset1, Asset2, Asset3>(): u64 acquires StablePool {
        let resource_account_address = package::resource_account_address();
        let pool = borrow_global<StablePool<Asset0, Asset1, Asset2, Asset3>>(resource_account_address);
        pool.amp_factor
    }

    #[view]
    public fun next_pool_id(): u64 acquires StablePoolLookup {
        let lookup = borrow_global<StablePoolLookup>(package::resource_account_address());
        lookup.next_id
    }

    #[view]
    public fun lp_name_by_id(id: u64): String acquires StablePoolLookup {
        let lookup = borrow_global<StablePoolLookup>(package::resource_account_address());
        assert!(table::contains(&lookup.id_to_name, id), ERR_STABLE_POOL_NOT_EXISTS);
        *table::borrow(&lookup.id_to_name, id)
    }
    
    #[view]
    public fun get_precision_multipliers<Asset0, Asset1, Asset2, Asset3>(): vector<u64> {
        let precision_multipliers = vector::empty<u64>();
        let pool_precision_decimals = base_pool::max_supported_decimals();

        vector::push_back(&mut precision_multipliers, math64::pow(10, (pool_precision_decimals - coin::decimals<Asset0>() as u64)));
        vector::push_back(&mut precision_multipliers, math64::pow(10, (pool_precision_decimals - coin::decimals<Asset1>() as u64)));

        if (!base_pool::is_null<Asset2>()) {
            vector::push_back(&mut precision_multipliers, math64::pow(10, (pool_precision_decimals - coin::decimals<Asset2>() as u64)));
        };

        if (!base_pool::is_null<Asset3>()) {
            vector::push_back(&mut precision_multipliers, math64::pow(10, (pool_precision_decimals - coin::decimals<Asset3>() as u64)));
        };

        precision_multipliers
    }

    // Internal Helpers

    // Ensures that the balance for the asset extracted never reaches zero
    // CONTRACT: `CoinOut` is one of the listed asset types
    fun extract_from_pool<Asset0, Asset1, Asset2, Asset3, CoinOut>(resource_account_address: address, idx: u64, amount_out: u64): Coin<CoinOut> acquires StablePool {
        if (idx == 0) {
            let pool = borrow_global_mut<StablePool<CoinOut, Asset1, Asset2, Asset3>>(resource_account_address);
            assert!(amount_out < coin::value(&pool.asset_0), ERR_STABLE_POOL_INSUFFICIENT_LIQUIDITY);

            coin::extract(&mut pool.asset_0, amount_out)
        } else if (idx == 1) {
            let pool = borrow_global_mut<StablePool<Asset0, CoinOut, Asset2, Asset3>>(resource_account_address);
            assert!(amount_out < coin::value(&pool.asset_1), ERR_STABLE_POOL_INSUFFICIENT_LIQUIDITY);

            coin::extract(&mut pool.asset_1, amount_out)
        } else if (idx == 2) {
            let pool = borrow_global_mut<StablePool<Asset0, Asset1, CoinOut, Asset3>>(resource_account_address);
            assert!(amount_out < coin::value(&pool.asset_2), ERR_STABLE_POOL_INSUFFICIENT_LIQUIDITY);

            coin::extract(&mut pool.asset_2, amount_out)
        } else {
            let pool = borrow_global_mut<StablePool<Asset0, Asset1, Asset2, CoinOut>>(resource_account_address);
            assert!(amount_out < coin::value(&pool.asset_3), ERR_STABLE_POOL_INSUFFICIENT_LIQUIDITY);

            coin::extract(&mut pool.asset_3, amount_out)
        }
    }

    // CONTRACT: `CoinIn` is one of the listed Asset Types
    fun deposit_to_pool<Asset0, Asset1, Asset2, Asset3, CoinIn>(resource_account_address: address, idx: u64, coin: Coin<CoinIn>) acquires StablePool {
        if (idx == 0) {
            let pool = borrow_global_mut<StablePool<CoinIn, Asset1, Asset2, Asset3>>(resource_account_address);
            coin::merge(&mut pool.asset_0, coin)
        } else if (idx == 1) {
            let pool = borrow_global_mut<StablePool<Asset0, CoinIn, Asset2, Asset3>>(resource_account_address);
            coin::merge(&mut pool.asset_1, coin)
        } else if (idx == 2) {
            let pool = borrow_global_mut<StablePool<Asset0, Asset1, CoinIn, Asset3>>(resource_account_address);
            coin::merge(&mut pool.asset_2, coin)
        } else {
            let pool = borrow_global_mut<StablePool<Asset0, Asset1, Asset2, CoinIn>>(resource_account_address);
            coin::merge(&mut pool.asset_3, coin)
        }
    }

    // Use current status of "pool" variable to update the info in the lookup table
    fun update_pool_lookup<Asset0, Asset1, Asset2, Asset3>(pool: &StablePool<Asset0, Asset1, Asset2, Asset3>, new_pool: bool) acquires StablePoolLookup {
        let balances = vector::empty<u64>();
        vector::push_back(&mut balances, coin::value(&pool.asset_0));
        vector::push_back(&mut balances, coin::value(&pool.asset_1));
        if (!base_pool::is_null<Asset2>()) {
            vector::push_back(&mut balances, coin::value(&pool.asset_2));
        };
        if (!base_pool::is_null<Asset3>()) {
            vector::push_back(&mut balances, coin::value(&pool.asset_3));
        };
        
        let lookup = borrow_global_mut<StablePoolLookup>(package::resource_account_address());
        let name = type_info::type_name<StablePoolToken<Asset0, Asset1, Asset2, Asset3>>();
        table::upsert(&mut lookup.name_to_pool, name, StablePoolInfo {
            balances,
            precision_multipliers: pool.precision_multipliers,
            amp_factor: pool.amp_factor,
            lp_coin_supply: base_pool::pool_token_supply<StablePoolToken<Asset0, Asset1, Asset2, Asset3>>()
        });
        
        // If it's a new pool, add it to the ID -> name lookup table and increment the next ID
        if (new_pool) {
            table::add(&mut lookup.id_to_name, lookup.next_id, name);
            lookup.next_id = lookup.next_id + 1;
        }
    }

    fun lp_short_name<Asset0, Asset1, Asset2, Asset3>(): String {
        let name = string::utf8(b"SP:");
        string::append(&mut name, coin::symbol<Asset0>());
        string::append(&mut name, string::utf8(b"-"));
        string::append(&mut name, coin::symbol<Asset1>());

        if (!base_pool::is_null<Asset2>()) {
            string::append(&mut name, string::utf8(b"-"));
            string::append(&mut name, coin::symbol<Asset2>());

            // Asset3 can only be non-null if Asset 2 was non-null
            if (!base_pool::is_null<Asset3>()) {
                string::append(&mut name, string::utf8(b"-"));
                string::append(&mut name, coin::symbol<Asset3>());
            };
        };

        // `coin.move` specifies a limit of 32 characters for a name. If we exceed this limit
        // we truncate and replace the last 3 characters with "..." to indicate that the name is too long
        if (string::length(&name) > 32) {
            name = string::sub_string(&name, 0, 29);
            string::append(&mut name, string::utf8(b"..."));
        };

        name
    }

    fun get_xp<Asset0, Asset1, Asset2, Asset3>(pool: &StablePool<Asset0, Asset1, Asset2, Asset3>): vector<u64> {
        let xp = vector::empty<u64>();
        vector::push_back(&mut xp, coin::value(&pool.asset_0) * *vector::borrow(&pool.precision_multipliers, 0));
        vector::push_back(&mut xp, coin::value(&pool.asset_1) * *vector::borrow(&pool.precision_multipliers, 1));

        if (!base_pool::is_null<Asset2>()) {
            vector::push_back(&mut xp, coin::value(&pool.asset_2) * *vector::borrow(&pool.precision_multipliers, 2));
        };

        if (!base_pool::is_null<Asset3>()) {
            vector::push_back(&mut xp, coin::value(&pool.asset_3) * *vector::borrow(&pool.precision_multipliers, 3));
        };

        xp
    }

    #[test_only]
    use thalaswap::base_pool::Null;

    #[test_only]
    struct FakeCoin_A {}

    #[test_only]
    struct FakeCoin_B {}

    #[test_only]
    struct CapabilitiesHolder<phantom CoinType> has key {
        mint: MintCapability<CoinType>,
        burn: BurnCapability<CoinType>,
        freeze: coin::FreezeCapability<CoinType>
    }

    #[test(manager = @thalaswap)]
    fun test_lp_short_name_ok(manager: &signer) {
        // prepare
        let (burn, freeze, mint) = coin::initialize<FakeCoin_A>(manager, string::utf8(b"FakeCoin_A"), string::utf8(b"FCA"), 0, false);
        move_to(manager, CapabilitiesHolder { mint, burn, freeze });

        let (burn, freeze, mint) = coin::initialize<FakeCoin_B>(manager, string::utf8(b"FakeCoin_B"), string::utf8(b"FCB"), 0, false);
        move_to(manager, CapabilitiesHolder { mint, burn, freeze });

        // test
        assert!(lp_short_name<FakeCoin_A, FakeCoin_B, Null, Null>() == string::utf8(b"SP:FCA-FCB"), 0);
        assert!(lp_short_name<FakeCoin_A, FakeCoin_B, FakeCoin_A, Null>() == string::utf8(b"SP:FCA-FCB-FCA"), 0);
        assert!(lp_short_name<FakeCoin_A, FakeCoin_B, FakeCoin_A, FakeCoin_B>() == string::utf8(b"SP:FCA-FCB-FCA-FCB"), 0);
    }

    #[test(manager = @thalaswap)]
    fun test_lp_short_name_truncate_ok(manager: &signer) {
        // prepare
        let (burn, freeze, mint) = coin::initialize<FakeCoin_A>(manager, string::utf8(b"F"), string::utf8(b"FFFFFFFFFF"), 0, false);
        move_to(manager, CapabilitiesHolder { mint, burn, freeze });

        // test. 30 characters of symbols + "SP:" > 32 limit
        let name = lp_short_name<FakeCoin_A, FakeCoin_A, FakeCoin_A, Null>();
        assert!(name == string::utf8(b"SP:FFFFFFFFFF-FFFFFFFFFF-FFFF..."), 0);
    }
}
