/// This is an auto-generated file. Do not modify it directly.
module thala_hippo_adapter::stable_swap_adapter {
    use aptos_framework::coin::Coin;
    use aptos_framework::aptos_coin::AptosCoin as APT;
    
    use thalaswap::stable_pool;
    use thalaswap::base_pool::Null;

    use thala_hippo_adapter::encoder_decoder;

    use ThalaProtocol::mod_coin::MOD as MOD; // Move Dollar
    use THLCoin::thl_coin::THL as THL; // Thala Token
    use PancakeOFT::oft::CakeOFT as CAKE; // PancakeSwap Token
    use TortugaGovernance::staked_aptos_coin::StakedAptosCoin as TAPT; // Tortuga Staked Aptos
    use WrappedCoin1::coin::T as WUSDC; // USD Coin (Wormhole)
    use WrappedCoin2::coin::T as WWETH; // Wrapped Ether (Wormhole)
    use bridge::asset::USDC as ZUSDC; // USD Coin (LayerZero)
    use bridge::asset::USDT as ZUSDT; // USD Tether (LayerZero)
    use bridge::asset::WETH as ZWETH; // Wrapped Ether (LayerZero)

    // Error codes
    const ERR_INVALID_ENCODING: u64 = 0;

    public fun swap_exact_in<X, Y>(coin_in: Coin<X>, pool_type: u64): Coin<Y> {
        let encoded_coin = encoder_decoder::get_a(pool_type);
        if (encoded_coin > 10) abort ERR_INVALID_ENCODING;
if (encoded_coin <= 5) { 
if (encoded_coin <= 3) { 
if (encoded_coin <= 2) { 
  if (encoded_coin == 1) swap_exact_in_1<APT, X, Y>(coin_in, pool_type)
  else swap_exact_in_1<MOD, X, Y>(coin_in, pool_type)
} 
else { 
  swap_exact_in_1<THL
, X, Y>(coin_in, pool_type)}
} 
else { 
  if (encoded_coin == 4) swap_exact_in_1<CAKE, X, Y>(coin_in, pool_type)
  else swap_exact_in_1<TAPT, X, Y>(coin_in, pool_type)
}
} 
else { 
if (encoded_coin <= 8) { 
if (encoded_coin <= 7) { 
  if (encoded_coin == 6) swap_exact_in_1<WUSDC, X, Y>(coin_in, pool_type)
  else swap_exact_in_1<WWETH, X, Y>(coin_in, pool_type)
} 
else { 
  swap_exact_in_1<ZUSDC
, X, Y>(coin_in, pool_type)}
} 
else { 
  if (encoded_coin == 9) swap_exact_in_1<ZUSDT, X, Y>(coin_in, pool_type)
  else swap_exact_in_1<ZWETH, X, Y>(coin_in, pool_type)
}
}

    }

    // number of known coins = 1
    fun swap_exact_in_1<A, X, Y>(coin_in: Coin<X>, pool_type: u64): Coin<Y> {
        let encoded_coin = encoder_decoder::get_b(pool_type);
        if (encoded_coin > 10) abort ERR_INVALID_ENCODING;
if (encoded_coin <= 5) { 
if (encoded_coin <= 3) { 
if (encoded_coin <= 2) { 
  if (encoded_coin == 1) swap_exact_in_2<A, APT, X, Y>(coin_in, pool_type)
  else swap_exact_in_2<A, MOD, X, Y>(coin_in, pool_type)
} 
else { 
  swap_exact_in_2<A, THL
, X, Y>(coin_in, pool_type)}
} 
else { 
  if (encoded_coin == 4) swap_exact_in_2<A, CAKE, X, Y>(coin_in, pool_type)
  else swap_exact_in_2<A, TAPT, X, Y>(coin_in, pool_type)
}
} 
else { 
if (encoded_coin <= 8) { 
if (encoded_coin <= 7) { 
  if (encoded_coin == 6) swap_exact_in_2<A, WUSDC, X, Y>(coin_in, pool_type)
  else swap_exact_in_2<A, WWETH, X, Y>(coin_in, pool_type)
} 
else { 
  swap_exact_in_2<A, ZUSDC
, X, Y>(coin_in, pool_type)}
} 
else { 
  if (encoded_coin == 9) swap_exact_in_2<A, ZUSDT, X, Y>(coin_in, pool_type)
  else swap_exact_in_2<A, ZWETH, X, Y>(coin_in, pool_type)
}
}

    }

    // number of known coins = 2
    fun swap_exact_in_2<A, B, X, Y>(coin_in: Coin<X>, pool_type: u64): Coin<Y> {
        let encoded_coin = encoder_decoder::get_c(pool_type);
        if (encoded_coin > 10) abort ERR_INVALID_ENCODING;
        if (encoded_coin == 0) {
            stable_pool::swap_exact_in<A, B, Null, Null, X, Y>(coin_in)
        }
        else if (encoded_coin <= 5) { 
if (encoded_coin <= 3) { 
if (encoded_coin <= 2) { 
  if (encoded_coin == 1) swap_exact_in_3<A, B, APT, X, Y>(coin_in, pool_type)
  else swap_exact_in_3<A, B, MOD, X, Y>(coin_in, pool_type)
} 
else { 
  swap_exact_in_3<A, B, THL
, X, Y>(coin_in, pool_type)}
} 
else { 
  if (encoded_coin == 4) swap_exact_in_3<A, B, CAKE, X, Y>(coin_in, pool_type)
  else swap_exact_in_3<A, B, TAPT, X, Y>(coin_in, pool_type)
}
} 
else { 
if (encoded_coin <= 8) { 
if (encoded_coin <= 7) { 
  if (encoded_coin == 6) swap_exact_in_3<A, B, WUSDC, X, Y>(coin_in, pool_type)
  else swap_exact_in_3<A, B, WWETH, X, Y>(coin_in, pool_type)
} 
else { 
  swap_exact_in_3<A, B, ZUSDC
, X, Y>(coin_in, pool_type)}
} 
else { 
  if (encoded_coin == 9) swap_exact_in_3<A, B, ZUSDT, X, Y>(coin_in, pool_type)
  else swap_exact_in_3<A, B, ZWETH, X, Y>(coin_in, pool_type)
}
}

    }

    // number of known coins = 3
    fun swap_exact_in_3<A, B, C, X, Y>(coin_in: Coin<X>, pool_type: u64): Coin<Y> {
        let encoded_coin = encoder_decoder::get_d(pool_type);
        if (encoded_coin > 10) abort ERR_INVALID_ENCODING;
        if (encoded_coin == 0) {
            stable_pool::swap_exact_in<A, B, C, Null, X, Y>(coin_in)
        }
        else if (encoded_coin <= 5) { 
if (encoded_coin <= 3) { 
if (encoded_coin <= 2) { 
  if (encoded_coin == 1) stable_pool::swap_exact_in<A, B, C, APT, X, Y>(coin_in)
  else stable_pool::swap_exact_in<A, B, C, MOD, X, Y>(coin_in)
} 
else { 
  stable_pool::swap_exact_in<A, B, C, THL
, X, Y>(coin_in)}
} 
else { 
  if (encoded_coin == 4) stable_pool::swap_exact_in<A, B, C, CAKE, X, Y>(coin_in)
  else stable_pool::swap_exact_in<A, B, C, TAPT, X, Y>(coin_in)
}
} 
else { 
if (encoded_coin <= 8) { 
if (encoded_coin <= 7) { 
  if (encoded_coin == 6) stable_pool::swap_exact_in<A, B, C, WUSDC, X, Y>(coin_in)
  else stable_pool::swap_exact_in<A, B, C, WWETH, X, Y>(coin_in)
} 
else { 
  stable_pool::swap_exact_in<A, B, C, ZUSDC
, X, Y>(coin_in)}
} 
else { 
  if (encoded_coin == 9) stable_pool::swap_exact_in<A, B, C, ZUSDT, X, Y>(coin_in)
  else stable_pool::swap_exact_in<A, B, C, ZWETH, X, Y>(coin_in)
}
}

    }
}