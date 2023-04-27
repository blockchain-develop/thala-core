module thala_hippo_adapter::encoder_decoder {
    use thalaswap::weighted_pool;
    use thalaswap::base_pool;
    use thala_hippo_adapter::coin_encoder::encode_coin_type;

    const LOWEST_11_BITS: u64 = 0x7FF;
    const LOWEST_5_BITS: u64 = 0x1F;

    #[view]
    public fun get_pool_type<A, B, C, D, W1, W2, W3, W4>(): u64 {
        pack(encode_coin_type<A>(), encode_coin_type<B>(), encode_coin_type<C>(), encode_coin_type<D>(), encode_weight_type<W1>(), encode_weight_type<W2>(), encode_weight_type<W3>(), encode_weight_type<W4>())
    }

    // Weight can be 5 ~ 95 in increments of 5
    // We encode it as 1 ~ 19
    // Encode Null as 0
    public fun encode_weight_type<WeightType>(): u8 {
        if (base_pool::is_null<WeightType>()) 0
        else (weighted_pool::get_weight<WeightType>() / 5 as u8)
    }

    public fun is_weighted_pool(pool_type: u64): bool {
        get_w1(pool_type) != 0
    }

    // Get highest 11 bits of pool_type represents coin A
    public fun get_a(pool_type: u64): u16 {
        ((pool_type >> 53) as u16)
    }

    // Get 12~22nd bits of pool_type represents coin B
    public fun get_b(pool_type: u64): u16 {
        (((pool_type >> 42) & LOWEST_11_BITS) as u16)
    }

    // Get 23~33rd bits of pool_type represents coin C
    public fun get_c(pool_type: u64): u16 {
        (((pool_type >> 31) & LOWEST_11_BITS) as u16)
    }

    // Get 34~44th bits of pool_type represents coin D
    public fun get_d(pool_type: u64): u16 {
        (((pool_type >> 20) & LOWEST_11_BITS) as u16)
    }

    // Get 45~49th bits of pool_type represents weight 1
    public fun get_w1(pool_type: u64): u8 {
        (((pool_type >> 15) & LOWEST_5_BITS) as u8)
    }

    // Get 50~54th bits of pool_type represents weight 2
    public fun get_w2(pool_type: u64): u8 {
        (((pool_type >> 10) & LOWEST_5_BITS) as u8)
    }

    // Get 55~59th bits of pool_type represents weight 3
    public fun get_w3(pool_type: u64): u8 {
        (((pool_type >> 5) & LOWEST_5_BITS) as u8)
    }

    // Get lowest 5 bits of pool_type represents weight 4
    public fun get_w4(pool_type: u64): u8 {
        ((pool_type & LOWEST_5_BITS) as u8)
    }
    
    fun pack(a: u16, b: u16, c: u16, d: u16, w1: u8, w2: u8, w3: u8, w4: u8): u64 {
        ((a as u64) << 53) | ((b as u64) << 42) | ((c as u64) << 31) | ((d as u64) << 20) | ((w1 as u64) << 15) | ((w2 as u64) << 10) | ((w3 as u64) << 5) | (w4 as u64)
    }
}