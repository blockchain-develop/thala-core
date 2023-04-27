module thalaswap::multi_hop_scripts {

    use std::signer;

    use aptos_framework::coin::{Self, Coin};

    use thalaswap::base_pool;
    use thalaswap::weighted_pool;
    use thalaswap::stable_pool;

    const ERR_MULTIHOP_POOL_NOT_EXIST: u64 = 1;
    const ERR_MULTIHOP_INSUFFICIENT_OUTPUT: u64 = 2;

    /// A0, A1, A2, A3, W0, W1, W2, W3 identifies the first pool
    /// B0, B1, B2, B3, X0, X1, X2, X3 identifies the second pool
    /// Stable pool does not have weight types, so if all 4 weight types W0, W1, W2, W3 are zero, then it is a stable pool
    /// I is the input token type
    /// O is the output token type
    /// M is the intermediate token type
    public entry fun swap_exact_in_2<A0, A1, A2, A3, W0, W1, W2, W3, B0, B1, B2, B3, X0, X1, X2, X3, I, M, O>(account: &signer, amount_in: u64, min_amount_out: u64) {
        let account_addr = signer::address_of(account);

        let coin_in = coin::withdraw<I>(account, amount_in);
        let coin_mid = check_and_swap<A0, A1, A2, A3, W0, W1, W2, W3, I, M>(coin_in);
        let coin_out = check_and_swap<B0, B1, B2, B3, X0, X1, X2, X3, M, O>(coin_mid);
        assert!(coin::value(&coin_out) >= min_amount_out, ERR_MULTIHOP_INSUFFICIENT_OUTPUT);

        if (!coin::is_account_registered<O>(account_addr)) coin::register<O>(account);
        coin::deposit<O>(account_addr, coin_out);
    }
    
    /// A0, A1, A2, A3, W0, W1, W2, W3 identifies the first pool
    /// B0, B1, B2, B3, X0, X1, X2, X3 identifies the second pool
    /// C0, C1, C2, C3, Y0, Y1, Y2, Y3 identifies the third pool
    /// I is the input token type
    /// O is the output token type
    /// M1 is the 1st intermediate token type
    /// M2 is the 2nd intermediate token type
    public entry fun swap_exact_in_3<A0, A1, A2, A3, W0, W1, W2, W3, B0, B1, B2, B3, X0, X1, X2, X3, C0, C1, C2, C3, Y0, Y1, Y2, Y3, I, M1, M2, O>(account: &signer, amount_in: u64, min_amount_out: u64) {
        let account_addr = signer::address_of(account);

        let coin_in = coin::withdraw<I>(account, amount_in);
        let coin_mid_1 = check_and_swap<A0, A1, A2, A3, W0, W1, W2, W3, I, M1>(coin_in);
        let coin_mid_2 = check_and_swap<B0, B1, B2, B3, X0, X1, X2, X3, M1, M2>(coin_mid_1);
        let coin_out = check_and_swap<C0, C1, C2, C3, Y0, Y1, Y2, Y3, M2, O>(coin_mid_2);
        assert!(coin::value(&coin_out) >= min_amount_out, ERR_MULTIHOP_INSUFFICIENT_OUTPUT);

        if (!coin::is_account_registered<O>(account_addr)) coin::register<O>(account);
        coin::deposit<O>(account_addr, coin_out);
    }

    /// we only need to check the first type arg to decide if we use weighted pool swap path
    fun is_weighted_pool<W0, W1, W2, W3>(): bool {
        !base_pool::is_null<W0>()
    }

    /// check_and_swap checks the pool type and performs one hop swap
    /// A0, A1, A2, A3, W0, W1, W2, W3 identifies pool
    /// I is the input token type
    /// O is the output token type
    fun check_and_swap<A0, A1, A2, A3, W0, W1, W2, W3, I, O>(coin_in: Coin<I>): Coin<O> {
        if (is_weighted_pool<W0, W1, W2, W3>()) {
            assert!(weighted_pool::weighted_pool_exists<A0, A1, A2, A3, W0, W1, W2, W3>(), ERR_MULTIHOP_POOL_NOT_EXIST);
            weighted_pool::swap_exact_in<A0, A1, A2, A3, W0, W1, W2, W3, I, O>(coin_in)
        } else {
            assert!(stable_pool::stable_pool_exists<A0, A1, A2, A3>(), ERR_MULTIHOP_POOL_NOT_EXIST);
            stable_pool::swap_exact_in<A0, A1, A2, A3, I, O>(coin_in)
        }
    }
}
