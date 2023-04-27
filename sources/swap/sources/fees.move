module thalaswap::fees {
    use aptos_framework::coin::{Self, Coin};

    use thalaswap::package;

    use thala_manager::manager;

    friend thalaswap::weighted_pool;
    friend thalaswap::stable_pool;

    ///
    /// Error Codes
    ///

    // Authorization
    const ERR_UNAUTHORIZED: u64 = 0;

    ///
    /// Functions
    ///


    public(friend) fun absorb_fee<CoinType>(fee: Coin<CoinType>) {
        try_register<CoinType>();
        coin::deposit(package::resource_account_address(), fee);
    }

    public fun withdraw_fee<CoinType>(manager: &signer, amount: u64): Coin<CoinType> {
        assert!(manager::is_authorized(manager), ERR_UNAUTHORIZED);

        try_register<CoinType>();
        coin::withdraw<CoinType>(&package::resource_account_signer(), amount)
    }

    #[view]
    public fun balance<CoinType>(): u64 {
        coin::balance<CoinType>(package::resource_account_address())
    }

    // Internal Helpers

    fun try_register<CoinType>() {
        if (!coin::is_account_registered<CoinType>(package::resource_account_address())) {
            coin::register<CoinType>(&package::resource_account_signer());
        };
    }

    #[test_only]
    use thalaswap::coin_test;

    #[test_only]
    struct FakeCoin {}

    #[test_only]
    fun initialize_for_test<CoinType>(manager: &signer) {
        // setup the manager & package resource
        manager::initialize_for_test(std::signer::address_of(manager));
        package::init_for_test();

        coin_test::initialize_fake_coin<CoinType>(manager);
    }

    #[test_only]
    fun absorb_fee_ok<CoinType>(manager: &signer) {
        initialize_for_test<FakeCoin>(manager);
        absorb_fee(thalaswap::coin_test::mint_coin<FakeCoin>(manager, 1));

        assert!(balance<FakeCoin>() == 1, 0);
    }

    #[test(manager = @thalaswap)]
    #[expected_failure(abort_code = ERR_UNAUTHORIZED)]
    fun withdraw_fee_unauthorized_err(manager: &signer) {
        initialize_for_test<FakeCoin>(manager);

        let non_manager = aptos_framework::account::create_account_for_test(@0xA);
        coin::destroy_zero(withdraw_fee<FakeCoin>(&non_manager, 10));
    }

    #[test(manager = @thalaswap)]
    fun withdraw_fee_ok(manager: &signer) {
        initialize_for_test<FakeCoin>(manager);

        absorb_fee(coin_test::mint_coin<FakeCoin>(manager, 2));
        assert!(balance<FakeCoin>() == 2, 0);

        let fee = withdraw_fee<FakeCoin>(manager, 1);
        assert!(coin::value(&fee) == 1, 0);
        assert!(balance<FakeCoin>() == 1, 0);

        coin_test::burn_coin(manager, fee);
    }
}
