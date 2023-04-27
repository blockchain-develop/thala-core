module thalaswap::weighted_pool_scripts {
    use std::signer;

    use aptos_framework::coin;

    use thalaswap::base_pool;
    use thalaswap::weighted_pool::{Self, WeightedPoolToken};
    
    const ERR_LP_SLIPPAGE: u64 = 0;
    const ERR_INSUFFICIENT_OUTPUT: u64 = 1;

    public entry fun create_weighted_pool<Asset0, Asset1, Asset2, Asset3, Weight0, Weight1, Weight2, Weight3>(account: &signer, in_0: u64, in_1: u64, in_2: u64, in_3: u64) {
        let account_addr = signer::address_of(account);

        let coin_0 = coin::withdraw<Asset0>(account, in_0);
        let coin_1 = coin::withdraw<Asset1>(account, in_1);
        let coin_2 = if (!base_pool::is_null<Asset2>()) coin::withdraw<Asset2>(account, in_2) else coin::zero<Asset2>();
        let coin_3 = if (!base_pool::is_null<Asset3>()) coin::withdraw<Asset3>(account, in_3) else coin::zero<Asset3>();

        let lp_token = weighted_pool::create_weighted_pool<Asset0, Asset1, Asset2, Asset3, Weight0, Weight1, Weight2, Weight3>(account, coin_0, coin_1, coin_2, coin_3);
        if (!coin::is_account_registered<WeightedPoolToken<Asset0, Asset1, Asset2, Asset3, Weight0, Weight1, Weight2, Weight3>>(account_addr)) {
            coin::register<WeightedPoolToken<Asset0, Asset1, Asset2, Asset3, Weight0, Weight1, Weight2, Weight3>>(account);
        };
        
        coin::deposit<WeightedPoolToken<Asset0, Asset1, Asset2, Asset3, Weight0, Weight1, Weight2, Weight3>>(account_addr, lp_token);
    }

    public entry fun swap_exact_in<Asset0, Asset1, Asset2, Asset3, Weight0, Weight1, Weight2, Weight3, X, Y>(account: &signer, amount_in: u64, min_amount_out: u64) {
        let account_addr = signer::address_of(account);

        let coin_in = coin::withdraw<X>(account, amount_in);
        let coin_out = weighted_pool::swap_exact_in<Asset0, Asset1, Asset2, Asset3, Weight0, Weight1, Weight2, Weight3, X, Y>(coin_in);

        assert!(coin::value(&coin_out) >= min_amount_out, ERR_INSUFFICIENT_OUTPUT);
        if (!coin::is_account_registered<Y>(account_addr)) coin::register<Y>(account);
        coin::deposit<Y>(account_addr, coin_out);
    }

    public entry fun swap_exact_out<Asset0, Asset1, Asset2, Asset3, Weight0, Weight1, Weight2, Weight3, X, Y>(account: &signer, amount_in: u64, amount_out: u64) {
        let account_addr = signer::address_of(account);

        let coin_in = coin::withdraw<X>(account, amount_in);
        let (refunded_coin_in, coin_out) = weighted_pool::swap_exact_out<Asset0, Asset1, Asset2, Asset3, Weight0, Weight1, Weight2, Weight3, X, Y>(coin_in, amount_out);

        coin::deposit<X>(account_addr, refunded_coin_in);

        if (!coin::is_account_registered<Y>(account_addr)) coin::register<Y>(account);
        coin::deposit<Y>(account_addr, coin_out);
    }

    public entry fun add_liquidity<Asset0, Asset1, Asset2, Asset3, Weight0, Weight1, Weight2, Weight3>(account: &signer, in_0: u64, in_1: u64, in_2: u64, in_3: u64, min_amount_in_0: u64, min_amount_in_1: u64, min_amount_in_2: u64, min_amount_in_3: u64) {
        let account_addr = signer::address_of(account);

        let coin_0 = coin::withdraw<Asset0>(account, in_0);
        let coin_1 = coin::withdraw<Asset1>(account, in_1);
        let coin_2 = if (!base_pool::is_null<Asset2>()) coin::withdraw<Asset2>(account, in_2) else coin::zero<Asset2>();
        let coin_3 = if (!base_pool::is_null<Asset3>()) coin::withdraw<Asset3>(account, in_3) else coin::zero<Asset3>();

        let (lp_token, refunded_coin_0, refunded_coin_1, refunded_coin_2, refunded_coin_3) = 
            weighted_pool::add_liquidity<Asset0, Asset1, Asset2, Asset3, Weight0, Weight1, Weight2, Weight3>(coin_0, coin_1, coin_2, coin_3);

        // assert the amount that is deposited to pool is greater than or equal to the minimum amount
        assert!(in_0 - coin::value(&refunded_coin_0) >= min_amount_in_0, ERR_LP_SLIPPAGE);
        assert!(in_1 - coin::value(&refunded_coin_1) >= min_amount_in_1, ERR_LP_SLIPPAGE);

        coin::deposit<Asset0>(account_addr, refunded_coin_0);
        coin::deposit<Asset1>(account_addr, refunded_coin_1);
        if (!base_pool::is_null<Asset2>()) {
            assert!(in_2 - coin::value(&refunded_coin_2) >= min_amount_in_2, ERR_LP_SLIPPAGE);
            coin::deposit(account_addr, refunded_coin_2) 
        } else coin::destroy_zero(refunded_coin_2);
        if (!base_pool::is_null<Asset3>()) { 
            assert!(in_3 - coin::value(&refunded_coin_3) >= min_amount_in_3, ERR_LP_SLIPPAGE);
            coin::deposit(account_addr, refunded_coin_3)
        } else coin::destroy_zero(refunded_coin_3);

        if (!coin::is_account_registered<WeightedPoolToken<Asset0, Asset1, Asset2, Asset3, Weight0, Weight1, Weight2, Weight3>>(account_addr)) {
            coin::register<WeightedPoolToken<Asset0, Asset1, Asset2, Asset3, Weight0, Weight1, Weight2, Weight3>>(account);
        };
        coin::deposit<WeightedPoolToken<Asset0, Asset1, Asset2, Asset3, Weight0, Weight1, Weight2, Weight3>>(account_addr, lp_token);
    }

    public entry fun remove_liquidity<Asset0, Asset1, Asset2, Asset3, Weight0, Weight1, Weight2, Weight3>(account: &signer, lp_token_in: u64, min_amount_out_0: u64, min_amount_out_1: u64, min_amount_out_2: u64, min_amount_out_3: u64) {
        let account_addr = signer::address_of(account);
        
        let lp_coin = coin::withdraw<WeightedPoolToken<Asset0, Asset1, Asset2, Asset3, Weight0, Weight1, Weight2, Weight3>>(account, lp_token_in);

        let (output_coin_0, output_coin_1, output_coin_2, output_coin_3) = 
            weighted_pool::remove_liquidity<Asset0, Asset1, Asset2, Asset3, Weight0, Weight1, Weight2, Weight3>(lp_coin);

        assert!(coin::value(&output_coin_0) >= min_amount_out_0, ERR_INSUFFICIENT_OUTPUT);
        assert!(coin::value(&output_coin_1) >= min_amount_out_1, ERR_INSUFFICIENT_OUTPUT);

        coin::deposit<Asset0>(account_addr, output_coin_0);
        coin::deposit<Asset1>(account_addr, output_coin_1);
        if (!base_pool::is_null<Asset2>()) { 
            assert!(coin::value(&output_coin_2) >= min_amount_out_2, ERR_INSUFFICIENT_OUTPUT);
            coin::deposit(account_addr, output_coin_2) 
        } else coin::destroy_zero(output_coin_2);
        if (!base_pool::is_null<Asset3>()) { 
            assert!(coin::value(&output_coin_3) >= min_amount_out_3, ERR_INSUFFICIENT_OUTPUT);
            coin::deposit(account_addr, output_coin_3) 
        } else coin::destroy_zero(output_coin_3);
    }
}
