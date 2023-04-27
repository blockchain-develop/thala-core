/// This is an auto-generated file. Do not modify it directly.
module thala_hippo_adapter::weighted_swap_adapter {
    use aptos_framework::coin::Coin;
    use aptos_framework::aptos_coin::AptosCoin as APT;

    use thalaswap::weighted_pool::{Self, Weight_5, Weight_10, Weight_15, Weight_20, Weight_25, Weight_30, Weight_35, Weight_40, Weight_45, Weight_50, Weight_55, Weight_60, Weight_65, Weight_70, Weight_75, Weight_80, Weight_85, Weight_90, Weight_95};
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
            swap_exact_in_weight_0<A, B, Null, Null, X, Y>(coin_in, pool_type)
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
            swap_exact_in_weight_0<A, B, C, Null, X, Y>(coin_in, pool_type)
        }
        else if (encoded_coin <= 5) { 
if (encoded_coin <= 3) { 
if (encoded_coin <= 2) { 
  if (encoded_coin == 1) swap_exact_in_weight_0<A, B, C, APT, X, Y>(coin_in, pool_type)
  else swap_exact_in_weight_0<A, B, C, MOD, X, Y>(coin_in, pool_type)
} 
else { 
  swap_exact_in_weight_0<A, B, C, THL
, X, Y>(coin_in, pool_type)}
} 
else { 
  if (encoded_coin == 4) swap_exact_in_weight_0<A, B, C, CAKE, X, Y>(coin_in, pool_type)
  else swap_exact_in_weight_0<A, B, C, TAPT, X, Y>(coin_in, pool_type)
}
} 
else { 
if (encoded_coin <= 8) { 
if (encoded_coin <= 7) { 
  if (encoded_coin == 6) swap_exact_in_weight_0<A, B, C, WUSDC, X, Y>(coin_in, pool_type)
  else swap_exact_in_weight_0<A, B, C, WWETH, X, Y>(coin_in, pool_type)
} 
else { 
  swap_exact_in_weight_0<A, B, C, ZUSDC
, X, Y>(coin_in, pool_type)}
} 
else { 
  if (encoded_coin == 9) swap_exact_in_weight_0<A, B, C, ZUSDT, X, Y>(coin_in, pool_type)
  else swap_exact_in_weight_0<A, B, C, ZWETH, X, Y>(coin_in, pool_type)
}
}

    }

    // number of known weights = 0
     fun swap_exact_in_weight_0<A, B, C, D, X, Y>(coin_in: Coin<X>, pool_type: u64): Coin<Y> {
        let encoded_weight = encoder_decoder::get_w1(pool_type);
        if (encoded_weight == 0 || encoded_weight > 19) abort ERR_INVALID_ENCODING;

if (encoded_weight <= 10) {
    if (encoded_weight <= 5) {
        if (encoded_weight <= 3) {
            if (encoded_weight <= 2) {
                if (encoded_weight == 1) swap_exact_in_weight_1<A, B, C, D, Weight_5, X, Y>(coin_in, pool_type)
                else swap_exact_in_weight_1<A, B, C, D, Weight_10, X, Y>(coin_in, pool_type)
            }
            else swap_exact_in_weight_1<A, B, C, D, Weight_15, X, Y>(coin_in, pool_type)
        }
        else {
            if (encoded_weight == 4) swap_exact_in_weight_1<A, B, C, D, Weight_20, X, Y>(coin_in, pool_type)
            else swap_exact_in_weight_1<A, B, C, D, Weight_25, X, Y>(coin_in, pool_type)
        }
    }
    else {
        if (encoded_weight <= 8) {
            if (encoded_weight <= 7) {
                if (encoded_weight == 6) swap_exact_in_weight_1<A, B, C, D, Weight_30, X, Y>(coin_in, pool_type)
                else swap_exact_in_weight_1<A, B, C, D, Weight_35, X, Y>(coin_in, pool_type)
            }
            else swap_exact_in_weight_1<A, B, C, D, Weight_40, X, Y>(coin_in, pool_type)
        }
        else {
            if (encoded_weight == 9) swap_exact_in_weight_1<A, B, C, D, Weight_45, X, Y>(coin_in, pool_type)
            else swap_exact_in_weight_1<A, B, C, D, Weight_50, X, Y>(coin_in, pool_type)
        }
    }
}
else {
    if (encoded_weight <= 15) {
        if (encoded_weight <= 13) {
            if (encoded_weight <= 12) {
                if (encoded_weight == 11) swap_exact_in_weight_1<A, B, C, D, Weight_55, X, Y>(coin_in, pool_type)
                else swap_exact_in_weight_1<A, B, C, D, Weight_60, X, Y>(coin_in, pool_type)
            }
            else swap_exact_in_weight_1<A, B, C, D, Weight_65, X, Y>(coin_in, pool_type)
        }
        else {
            if (encoded_weight == 14) swap_exact_in_weight_1<A, B, C, D, Weight_70, X, Y>(coin_in, pool_type)
            else swap_exact_in_weight_1<A, B, C, D, Weight_75, X, Y>(coin_in, pool_type)
        }
    }
    else {
        if (encoded_weight <= 18) {
            if (encoded_weight <= 17) {
                if (encoded_weight == 16) swap_exact_in_weight_1<A, B, C, D, Weight_80, X, Y>(coin_in, pool_type)
                else swap_exact_in_weight_1<A, B, C, D, Weight_85, X, Y>(coin_in, pool_type)
            }
            else swap_exact_in_weight_1<A, B, C, D, Weight_90, X, Y>(coin_in, pool_type)
        }
        else swap_exact_in_weight_1<A, B, C, D, Weight_95, X, Y>(coin_in, pool_type)
    }
}

    }

    // number of known weights = 1
     fun swap_exact_in_weight_1<A, B, C, D, W1, X, Y>(coin_in: Coin<X>, pool_type: u64): Coin<Y> {
        let encoded_weight = encoder_decoder::get_w2(pool_type);
        if (encoded_weight == 0 || encoded_weight > 19) abort ERR_INVALID_ENCODING;

if (encoded_weight <= 10) {
    if (encoded_weight <= 5) {
        if (encoded_weight <= 3) {
            if (encoded_weight <= 2) {
                if (encoded_weight == 1) swap_exact_in_weight_2<A, B, C, D, W1, Weight_5, X, Y>(coin_in, pool_type)
                else swap_exact_in_weight_2<A, B, C, D, W1, Weight_10, X, Y>(coin_in, pool_type)
            }
            else swap_exact_in_weight_2<A, B, C, D, W1, Weight_15, X, Y>(coin_in, pool_type)
        }
        else {
            if (encoded_weight == 4) swap_exact_in_weight_2<A, B, C, D, W1, Weight_20, X, Y>(coin_in, pool_type)
            else swap_exact_in_weight_2<A, B, C, D, W1, Weight_25, X, Y>(coin_in, pool_type)
        }
    }
    else {
        if (encoded_weight <= 8) {
            if (encoded_weight <= 7) {
                if (encoded_weight == 6) swap_exact_in_weight_2<A, B, C, D, W1, Weight_30, X, Y>(coin_in, pool_type)
                else swap_exact_in_weight_2<A, B, C, D, W1, Weight_35, X, Y>(coin_in, pool_type)
            }
            else swap_exact_in_weight_2<A, B, C, D, W1, Weight_40, X, Y>(coin_in, pool_type)
        }
        else {
            if (encoded_weight == 9) swap_exact_in_weight_2<A, B, C, D, W1, Weight_45, X, Y>(coin_in, pool_type)
            else swap_exact_in_weight_2<A, B, C, D, W1, Weight_50, X, Y>(coin_in, pool_type)
        }
    }
}
else {
    if (encoded_weight <= 15) {
        if (encoded_weight <= 13) {
            if (encoded_weight <= 12) {
                if (encoded_weight == 11) swap_exact_in_weight_2<A, B, C, D, W1, Weight_55, X, Y>(coin_in, pool_type)
                else swap_exact_in_weight_2<A, B, C, D, W1, Weight_60, X, Y>(coin_in, pool_type)
            }
            else swap_exact_in_weight_2<A, B, C, D, W1, Weight_65, X, Y>(coin_in, pool_type)
        }
        else {
            if (encoded_weight == 14) swap_exact_in_weight_2<A, B, C, D, W1, Weight_70, X, Y>(coin_in, pool_type)
            else swap_exact_in_weight_2<A, B, C, D, W1, Weight_75, X, Y>(coin_in, pool_type)
        }
    }
    else {
        if (encoded_weight <= 18) {
            if (encoded_weight <= 17) {
                if (encoded_weight == 16) swap_exact_in_weight_2<A, B, C, D, W1, Weight_80, X, Y>(coin_in, pool_type)
                else swap_exact_in_weight_2<A, B, C, D, W1, Weight_85, X, Y>(coin_in, pool_type)
            }
            else swap_exact_in_weight_2<A, B, C, D, W1, Weight_90, X, Y>(coin_in, pool_type)
        }
        else swap_exact_in_weight_2<A, B, C, D, W1, Weight_95, X, Y>(coin_in, pool_type)
    }
}

    }

    // number of known weights = 2
     fun swap_exact_in_weight_2<A, B, C, D, W1, W2, X, Y>(coin_in: Coin<X>, pool_type: u64): Coin<Y> {
        let encoded_weight = encoder_decoder::get_w3(pool_type);
        if (encoded_weight > 19) abort ERR_INVALID_ENCODING;
        if (encoded_weight == 0) weighted_pool::swap_exact_in<A, B, C, D, W1, W2, Null, Null, X, Y>(coin_in)
        else 
if (encoded_weight <= 10) {
    if (encoded_weight <= 5) {
        if (encoded_weight <= 3) {
            if (encoded_weight <= 2) {
                if (encoded_weight == 1) swap_exact_in_weight_3<A, B, C, D, W1, W2, Weight_5, X, Y>(coin_in, pool_type)
                else swap_exact_in_weight_3<A, B, C, D, W1, W2, Weight_10, X, Y>(coin_in, pool_type)
            }
            else swap_exact_in_weight_3<A, B, C, D, W1, W2, Weight_15, X, Y>(coin_in, pool_type)
        }
        else {
            if (encoded_weight == 4) swap_exact_in_weight_3<A, B, C, D, W1, W2, Weight_20, X, Y>(coin_in, pool_type)
            else swap_exact_in_weight_3<A, B, C, D, W1, W2, Weight_25, X, Y>(coin_in, pool_type)
        }
    }
    else {
        if (encoded_weight <= 8) {
            if (encoded_weight <= 7) {
                if (encoded_weight == 6) swap_exact_in_weight_3<A, B, C, D, W1, W2, Weight_30, X, Y>(coin_in, pool_type)
                else swap_exact_in_weight_3<A, B, C, D, W1, W2, Weight_35, X, Y>(coin_in, pool_type)
            }
            else swap_exact_in_weight_3<A, B, C, D, W1, W2, Weight_40, X, Y>(coin_in, pool_type)
        }
        else {
            if (encoded_weight == 9) swap_exact_in_weight_3<A, B, C, D, W1, W2, Weight_45, X, Y>(coin_in, pool_type)
            else swap_exact_in_weight_3<A, B, C, D, W1, W2, Weight_50, X, Y>(coin_in, pool_type)
        }
    }
}
else {
    if (encoded_weight <= 15) {
        if (encoded_weight <= 13) {
            if (encoded_weight <= 12) {
                if (encoded_weight == 11) swap_exact_in_weight_3<A, B, C, D, W1, W2, Weight_55, X, Y>(coin_in, pool_type)
                else swap_exact_in_weight_3<A, B, C, D, W1, W2, Weight_60, X, Y>(coin_in, pool_type)
            }
            else swap_exact_in_weight_3<A, B, C, D, W1, W2, Weight_65, X, Y>(coin_in, pool_type)
        }
        else {
            if (encoded_weight == 14) swap_exact_in_weight_3<A, B, C, D, W1, W2, Weight_70, X, Y>(coin_in, pool_type)
            else swap_exact_in_weight_3<A, B, C, D, W1, W2, Weight_75, X, Y>(coin_in, pool_type)
        }
    }
    else {
        if (encoded_weight <= 18) {
            if (encoded_weight <= 17) {
                if (encoded_weight == 16) swap_exact_in_weight_3<A, B, C, D, W1, W2, Weight_80, X, Y>(coin_in, pool_type)
                else swap_exact_in_weight_3<A, B, C, D, W1, W2, Weight_85, X, Y>(coin_in, pool_type)
            }
            else swap_exact_in_weight_3<A, B, C, D, W1, W2, Weight_90, X, Y>(coin_in, pool_type)
        }
        else swap_exact_in_weight_3<A, B, C, D, W1, W2, Weight_95, X, Y>(coin_in, pool_type)
    }
}

    }

    // number of known weights = 3
     fun swap_exact_in_weight_3<A, B, C, D, W1, W2, W3, X, Y>(coin_in: Coin<X>, pool_type: u64): Coin<Y> {
        let encoded_weight = encoder_decoder::get_w3(pool_type);
        if (encoded_weight > 19) abort ERR_INVALID_ENCODING;
        if (encoded_weight == 0) weighted_pool::swap_exact_in<A, B, C, D, W1, W2, W3, Null, X, Y>(coin_in)
        else 
if (encoded_weight <= 10) {
    if (encoded_weight <= 5) {
        if (encoded_weight <= 3) {
            if (encoded_weight <= 2) {
                if (encoded_weight == 1) weighted_pool::swap_exact_in<A, B, C, D, W1, W2, W3, Weight_5, X, Y>(coin_in)
                else weighted_pool::swap_exact_in<A, B, C, D, W1, W2, W3, Weight_10, X, Y>(coin_in)
            }
            else weighted_pool::swap_exact_in<A, B, C, D, W1, W2, W3, Weight_15, X, Y>(coin_in)
        }
        else {
            if (encoded_weight == 4) weighted_pool::swap_exact_in<A, B, C, D, W1, W2, W3, Weight_20, X, Y>(coin_in)
            else weighted_pool::swap_exact_in<A, B, C, D, W1, W2, W3, Weight_25, X, Y>(coin_in)
        }
    }
    else {
        if (encoded_weight <= 8) {
            if (encoded_weight <= 7) {
                if (encoded_weight == 6) weighted_pool::swap_exact_in<A, B, C, D, W1, W2, W3, Weight_30, X, Y>(coin_in)
                else weighted_pool::swap_exact_in<A, B, C, D, W1, W2, W3, Weight_35, X, Y>(coin_in)
            }
            else weighted_pool::swap_exact_in<A, B, C, D, W1, W2, W3, Weight_40, X, Y>(coin_in)
        }
        else {
            if (encoded_weight == 9) weighted_pool::swap_exact_in<A, B, C, D, W1, W2, W3, Weight_45, X, Y>(coin_in)
            else weighted_pool::swap_exact_in<A, B, C, D, W1, W2, W3, Weight_50, X, Y>(coin_in)
        }
    }
}
else {
    if (encoded_weight <= 15) {
        if (encoded_weight <= 13) {
            if (encoded_weight <= 12) {
                if (encoded_weight == 11) weighted_pool::swap_exact_in<A, B, C, D, W1, W2, W3, Weight_55, X, Y>(coin_in)
                else weighted_pool::swap_exact_in<A, B, C, D, W1, W2, W3, Weight_60, X, Y>(coin_in)
            }
            else weighted_pool::swap_exact_in<A, B, C, D, W1, W2, W3, Weight_65, X, Y>(coin_in)
        }
        else {
            if (encoded_weight == 14) weighted_pool::swap_exact_in<A, B, C, D, W1, W2, W3, Weight_70, X, Y>(coin_in)
            else weighted_pool::swap_exact_in<A, B, C, D, W1, W2, W3, Weight_75, X, Y>(coin_in)
        }
    }
    else {
        if (encoded_weight <= 18) {
            if (encoded_weight <= 17) {
                if (encoded_weight == 16) weighted_pool::swap_exact_in<A, B, C, D, W1, W2, W3, Weight_80, X, Y>(coin_in)
                else weighted_pool::swap_exact_in<A, B, C, D, W1, W2, W3, Weight_85, X, Y>(coin_in)
            }
            else weighted_pool::swap_exact_in<A, B, C, D, W1, W2, W3, Weight_90, X, Y>(coin_in)
        }
        else weighted_pool::swap_exact_in<A, B, C, D, W1, W2, W3, Weight_95, X, Y>(coin_in)
    }
}

    }
}
