/// This is an auto-generated file. Do not modify it directly.
module thala_hippo_adapter::coin_encoder {
    use aptos_std::type_info;
    use aptos_framework::aptos_coin::AptosCoin as APT;
    use thalaswap::base_pool::Null;
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
    const ERR_UNSUPPORTED_COIN: u64 = 0;

    public fun encode_coin_type<CoinType>(): u16 {
        let type_name = type_info::type_name<CoinType>();
        if (type_name == type_info::type_name<Null>()) 0
        else if (type_name == type_info::type_name<APT>()) 1
        else if (type_name == type_info::type_name<MOD>()) 2
        else if (type_name == type_info::type_name<THL>()) 3
        else if (type_name == type_info::type_name<CAKE>()) 4
        else if (type_name == type_info::type_name<TAPT>()) 5
        else if (type_name == type_info::type_name<WUSDC>()) 6
        else if (type_name == type_info::type_name<WWETH>()) 7
        else if (type_name == type_info::type_name<ZUSDC>()) 8
        else if (type_name == type_info::type_name<ZUSDT>()) 9
        else if (type_name == type_info::type_name<ZWETH>()) 10

        else abort ERR_UNSUPPORTED_COIN
    }
}
