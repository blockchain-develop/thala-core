module thala_hippo_adapter::adapter {
    use aptos_framework::coin::Coin;

    use thala_hippo_adapter::stable_swap_adapter;
    use thala_hippo_adapter::weighted_swap_adapter;
    use thala_hippo_adapter::encoder_decoder;

    public fun swap_exact_in<X, Y>(coin_in: Coin<X>, pool_type: u64): Coin<Y> {
        if (encoder_decoder::is_weighted_pool(pool_type)) weighted_swap_adapter::swap_exact_in(coin_in, pool_type)
        else stable_swap_adapter::swap_exact_in(coin_in, pool_type)
    }
}