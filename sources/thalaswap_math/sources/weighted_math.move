module thalaswap_math::weighted_math {
    use std::vector;
    use aptos_std::math64;

    use fixed_point64::fixed_point64::{Self, FixedPoint64};
    use fixed_point64::log_exp_math;

    ///
    /// Error Codes
    ///

    const ERR_WEIGHTED_MATH_VALUES_TOO_LARGE: u64 = 1;
    const ERR_WEIGHTED_MATH_NO_TOKEN_SUPPLY: u64 = 2;
    const ERR_WEIGHTED_MATH_INVALID_INPUTS: u64 = 3;
    const ERR_WEIGHTED_MATH_ZERO_WEIGHT_RATIO: u64 = 4;

    const ERR_WEIGHTED_SWAP_INVARIANT_DECREASE: u64 = 5;

    ///
    /// Constants
    ///

    const ONE_HUNDRED: u64 = 100;
    const MAX_U64: u64 = 18446744073709551615;

    // Weighted pool invariant calculation has some numerical errors due to log_exp_math::pow function
    // We set a tolerance value by which the FixedPoint64 invariant is allowed to decrease by
    // This is a raw u128 value of FixedPoint64, equivalent to 10^-10
    const INVARIANT_DECREASE_TOLERANCE_U128: u128 = 1844674407;

    /// Calculate the swap output amount. Weights can be provided in `FixedPoint64` for percise granularity
    /// 
    /// idx_in: Index of token swapped in
    /// idx_out: Index of token swapped out
    /// aI: Amount of tokens swapped in
    /// balances: Balances of tokens in the pool
    /// weights: Weights of tokens in the pool (FP64 values) 
    ///
    /// CONTRACT: idx_in != idx_out, weights sum to 100
    ///
    /// Returns: expected output amount
    public fun calc_out_given_in(idx_in: u64, idx_out: u64, aI: u64, balances: &vector<u64>, weights: &vector<FixedPoint64>): u64 {
        let prev_invariant = compute_invariant(balances, weights);
        let wI = *vector::borrow(weights, idx_in);
        let wO = *vector::borrow(weights, idx_out);
        let bI = *vector::borrow(balances, idx_in);
        let bO = *vector::borrow(balances, idx_out);
        let weight_ratio = fixed_point64::div_fp(wI, wO);

        let aO = calc_out_given_in_internal(bI, bO, aI, weight_ratio);

        let i = 0;
        let n = vector::length(balances);
        let new_balances = vector::empty<u64>();
        while (i < n) {
            let b_prev = *vector::borrow(balances, i);
            let b_new = if (i == idx_in) b_prev + aI else if (i == idx_out) b_prev - aO else b_prev;
            vector::push_back(&mut new_balances, b_new);
            i = i + 1;
        };
        
        let new_invariant = compute_invariant(&new_balances, weights);
        assert!(fixed_point64::gte(&fixed_point64::add_fp(new_invariant, fixed_point64::from_u128(INVARIANT_DECREASE_TOLERANCE_U128)), &prev_invariant), ERR_WEIGHTED_SWAP_INVARIANT_DECREASE);

        aO
    }

    /// Calculate the swap output amount. Discrete weights can be supplied in u64 (i.e % or any scaled value)
    /// 
    /// idx_in: Index of token swapped in
    /// idx_out: Index of token swapped out
    /// aI: Amount of tokens swapped in
    /// balances: Balances of tokens in the pool
    /// weights: Weights of tokens in the pool (u64 values) 
    ///
    /// CONTRACT: idx_in != idx_out, weights sum to 100, balances[idx_out] >= aO
    ///
    /// Returns: expected output amount
    public fun calc_out_given_in_weights_u64(idx_in: u64, idx_out: u64, aI: u64, balances: &vector<u64>, weights: &vector<u64>): u64 {
        let prev_invariant = compute_invariant_weights_u64(balances, weights);
        let wI = *vector::borrow(weights, idx_in);
        let wO = *vector::borrow(weights, idx_out);
        let bI = *vector::borrow(balances, idx_in);
        let bO = *vector::borrow(balances, idx_out);
        let weight_ratio = fixed_point64::fraction(wI, wO);

        let aO = calc_out_given_in_internal(bI, bO, aI, weight_ratio);

        let i = 0;
        let n = vector::length(balances);
        let new_balances = vector::empty<u64>();
        while (i < n) {
            let b_prev = *vector::borrow(balances, i);
            let b_new = if (i == idx_in) b_prev + aI else if (i == idx_out) b_prev - aO else b_prev;
            vector::push_back(&mut new_balances, b_new);
            i = i + 1;
        };
        
        let new_invariant = compute_invariant_weights_u64(&new_balances, weights);
        assert!(fixed_point64::gte(&fixed_point64::add_fp(new_invariant, fixed_point64::from_u128(INVARIANT_DECREASE_TOLERANCE_U128)), &prev_invariant), ERR_WEIGHTED_SWAP_INVARIANT_DECREASE);

        aO
    }

    // Reference "Out-Given-In" section in Balancer whitepaper https://balancer.fi/whitepaper.pdf
    // aI, bI must have same decimals
    // output aO will have the same decimals as bO
    // ********************************************************************************************
    // calcOutGivenIn                                                                            //
    // aO = tokenAmountOut                                                                       //
    // bO = tokenBalanceOut                                                                      //
    // bI = tokenBalanceIn              /      /            bI             \    (wI / wO) \      //
    // aI = tokenAmountIn    aO = bO * |  1 - | --------------------------  | ^            |     //
    // wI = tokenWeightIn               \      \          bI + aI          /              /      //
    // wO = tokenWeightOut                                                                       //
    // ********************************************************************************************
    // CONTRACT: bI + aI <= MAX_U64
    fun calc_out_given_in_internal(bI: u64, bO: u64, aI: u64, weight_ratio: FixedPoint64): u64 {
        assert!(aI <= MAX_U64 - bI, ERR_WEIGHTED_MATH_VALUES_TOO_LARGE);
        assert!(fixed_point64::to_u128(weight_ratio) > 0, ERR_WEIGHTED_MATH_ZERO_WEIGHT_RATIO);

        let fraction = fixed_point64::fraction(bI, bI + aI);

        // result is smaller than or equal to the actual value
        let result = fixed_point64::mul(fixed_point64::sub_fp(fixed_point64::one(), log_exp_math::pow_up(fraction, weight_ratio)), bO);
        fixed_point64::decode_round_down(result)
    }

    /// Calculate the swap input amount given desired output. Weights can be provided in `FixedPoint64` for percise granularity
    /// 
    /// idx_in: Index of token swapped in
    /// idx_out: Index of token swapped out
    /// aO: Expected amount of tokens swapped out
    /// balances: Balances of tokens in the pool
    /// weights: Weights of tokens in the pool (FP values) 
    ///
    /// CONTRACT: idx_in != idx_out, weights sum to 1
    ///
    /// Returns: expected input amount
    public fun calc_in_given_out(idx_in: u64, idx_out: u64, aO: u64, balances: &vector<u64>, weights: &vector<FixedPoint64>): u64 {
        let prev_invariant = compute_invariant(balances, weights);
        let wI = *vector::borrow(weights, idx_in);
        let wO = *vector::borrow(weights, idx_out);
        let bI = *vector::borrow(balances, idx_in);
        let bO = *vector::borrow(balances, idx_out);

        let weight_ratio = fixed_point64::div_fp(wO, wI);

        let aI = calc_in_given_out_internal(bI, bO, aO, weight_ratio);
        
        let i = 0;
        let n = vector::length(balances);
        let new_balances = vector::empty<u64>();
        while (i < n) {
            let b_prev = *vector::borrow(balances, i);
            let b_new = if (i == idx_in) b_prev + aI else if (i == idx_out) b_prev - aO else b_prev;
            vector::push_back(&mut new_balances, b_new);
            i = i + 1;
        };
        
        let new_invariant = compute_invariant(&new_balances, weights);
        assert!(fixed_point64::gte(&fixed_point64::add_fp(new_invariant, fixed_point64::from_u128(INVARIANT_DECREASE_TOLERANCE_U128)), &prev_invariant), ERR_WEIGHTED_SWAP_INVARIANT_DECREASE);

        aI
    }

    /// Calculate swap input amount given the desired output. Discrete weights can be supplied in u64 (i.e % or any scaled value)
    /// 
    /// idx_in: Index of token swapped in
    /// idx_out: Index of token swapped out
    /// aO: Expected amount of tokens swapped out
    /// balances: Balances of tokens in the pool
    /// weights: Weights of tokens in the pool (u64 values) 
    ///
    /// CONTRACT: idx_in != idx_out, weights sum to 100
    ///
    /// Returns: expected input amount
    public fun calc_in_given_out_weights_u64(idx_in: u64, idx_out: u64, aO: u64, balances: &vector<u64>, weights: &vector<u64>): u64 {
        let prev_invariant = compute_invariant_weights_u64(balances, weights);
        let wI = *vector::borrow(weights, idx_in);
        let wO = *vector::borrow(weights, idx_out);
        let bI = *vector::borrow(balances, idx_in);
        let bO = *vector::borrow(balances, idx_out);

        let weight_ratio = fixed_point64::fraction(wO, wI);
        let aI = calc_in_given_out_internal(bI, bO, aO, weight_ratio);

        let i = 0;
        let n = vector::length(balances);
        let new_balances = vector::empty<u64>();
        while (i < n) {
            let b_prev = *vector::borrow(balances, i);
            let b_new = if (i == idx_in) b_prev + aI else if (i == idx_out) b_prev - aO else b_prev;
            vector::push_back(&mut new_balances, b_new);
            i = i + 1;
        };
        
        let new_invariant = compute_invariant_weights_u64(&new_balances, weights);
        assert!(fixed_point64::gte(&fixed_point64::add_fp(new_invariant, fixed_point64::from_u128(INVARIANT_DECREASE_TOLERANCE_U128)), &prev_invariant), ERR_WEIGHTED_SWAP_INVARIANT_DECREASE);

        aI
    }

    // Reference "In-Given-Out" section in Balancer whitepaper https://balancer.fi/whitepaper.pdf
    // aO, bO must have same decimals
    // output aI will have the same decimals as bI
    // ********************************************************************************************
    // calcInGivenOut                                                                            //
    // aI = tokenAmountIn                                                                        //
    // bO = tokenBalanceOut               /  /     bO      \    (wO / wI)      \                 //
    // bI = tokenBalanceIn    aI =  bI * |  | ------------  | ^            - 1  |                //
    // aO = tokenAmountOut                \  \ ( bO - aO ) /                   /                 //
    // wI = tokenWeightIn                                                                        //
    // wO = tokenWeightOut                                                                       //
    // ********************************************************************************************
    // CONTRACT: bO > aO
    fun calc_in_given_out_internal(bI: u64, bO: u64, aO: u64, weight_ratio: FixedPoint64): u64 {
        assert!(bO > aO, ERR_WEIGHTED_MATH_VALUES_TOO_LARGE);
        assert!(fixed_point64::to_u128(weight_ratio) > 0, ERR_WEIGHTED_MATH_ZERO_WEIGHT_RATIO);

        let fraction = fixed_point64::fraction(bO, bO - aO);

        // result is greater than or equal to the actual value
        let result = fixed_point64::mul(fixed_point64::sub(log_exp_math::pow_up(fraction, weight_ratio), 1), bI);
        fixed_point64::decode_round_up(result)
    }

    /// ***************************************************************************************//
    ///                                _____                                                   //
    /// wi = weight index i             | |       wi                                           //
    /// bi = balance index i       k =  | |  bi ^                                              //
    /// k = invariant                                                                          //
    /// ***************************************************************************************//
    /// This function will be used by LBP in which weights are fixed point numbers
    /// CONTRACT: balances > 0, sum(weights) == 1.0
    public fun compute_invariant(balances: &vector<u64>, weights: &vector<FixedPoint64>): FixedPoint64 {
        let weights_length = vector::length(weights);
        let balances_length = vector::length(balances);
        assert!(weights_length == balances_length && weights_length >= 2, ERR_WEIGHTED_MATH_INVALID_INPUTS);

        let k = fixed_point64::one();

        let i = 0;
        while (i < balances_length) {
            let balance = fixed_point64::encode(*vector::borrow(balances, i));
            let weight = *vector::borrow(weights, i);
            k = fixed_point64::mul_fp(k, log_exp_math::pow(balance, weight));

            i = i + 1;
        };

        k
    }

    /// CONTRACT: balances > 0, sum(weights) == 100
    public fun compute_invariant_weights_u64(balances: &vector<u64>, weights: &vector<u64>): FixedPoint64 {
        let weights_length = vector::length(weights);
        let balances_length = vector::length(balances);
        assert!(weights_length == balances_length && weights_length >= 2, ERR_WEIGHTED_MATH_INVALID_INPUTS);

        let k = fixed_point64::one();

        let i = 0;
        while (i < balances_length) {
            let balance = fixed_point64::encode(*vector::borrow(balances, i));
            let weight = fixed_point64::fraction(*vector::borrow(weights, i), ONE_HUNDRED);
            k = fixed_point64::mul_fp(k, log_exp_math::pow(balance, weight));

            i = i + 1;
        };

        k
    }


    /// Computes lp tokens issued resultant of depositing liquidity
    /// Reference "All-Asset Deposit/Withdrawal" section in Balancer whitepaper https://docs.balancer.fi/v/v1/core-concepts/protocol/index
    /// ********************************************************************************************
    /// computePoolTokensIssued                                                                    //
    /// Pissued = poolTokenIssued                                                                  //
    /// Psupply = poolTokenSupply                                                                  //
    /// Dk = tokenKDeposited                                                                       //
    /// Bk = balanceTokenK           /     Psupply + Pissued           \                           //
    ///                    Dk =     |  ------------------------   - 1   |  * Bk                    //
    ///                              \          Psupply                /                           //
    ///                                                                                            //
    /// Solving for Pissued: Pissued = Psupply * Dk / Bk                                           //
    ///                                                                                            //
    /// This method takes in a max_amount of each asset, D0 & D1, computes Pissued for both assets //
    /// and returns the minimum Pissued as per the above equation. The method also computes the    //
    /// excess amount of D0 or D1 provisioned in the call, and returns that excess value to caller //
    /// ********************************************************************************************
    ///
    /// CONTRACT: p_supply > 0, deposit_i > 0, balance_i > 0
    ///
    /// Returns (u64, vector<u64>) -> (p_issued, deposit refunds).
    public fun compute_pool_tokens_issued(deposits: &vector<u64>, balances: &vector<u64>, p_supply: u64): (u64, vector<u64>) {
        assert!(p_supply > 0, ERR_WEIGHTED_MATH_NO_TOKEN_SUPPLY);

        let deposits_length = vector::length(deposits);
        let balances_length = vector::length(balances);
        assert!(deposits_length == balances_length && deposits_length >= 2, ERR_WEIGHTED_MATH_INVALID_INPUTS);

        // Find the token with minimum Pissued
        // Let r = Dk / Bk
        let k = 0;
        let r = fixed_point64::fraction(*vector::borrow(deposits, 0), *vector::borrow(balances, 0));

        let i = 1; // first deposit is assumed to have the minimum Pissued
        while (i < deposits_length) {
            let new_r = fixed_point64::fraction(*vector::borrow(deposits, i), *vector::borrow(balances, i));
            if (fixed_point64::lt(&new_r, &r)) {
                k = i;
                r = new_r;
            };

            i = i + 1;
        };

        // Given r, Pissued = Psupply * r
        let p_issued = fixed_point64::decode_round_down(fixed_point64::mul(r, p_supply));
        assert!(p_issued <= MAX_U64 - p_supply, ERR_WEIGHTED_MATH_VALUES_TOO_LARGE);

        // If assets are not provided in balance, we will refund any excess liquidity.
        // Expected deposit amount for asset k: expected_deposit_k = r * balance_k
        // Refunded amount for asset k:         refund_k = deposit_k - expected_deposit_k
        let refunds = vector::empty<u64>();

        let i = 0;
        while (i < deposits_length) {
            if (k == i) vector::push_back(&mut refunds, 0)
            else {
                let deposit = *vector::borrow(deposits, i);
                let expected_deposit = fixed_point64::decode_round_up(fixed_point64::mul(r, *vector::borrow(balances, i)));
                vector::push_back(&mut refunds, deposit - expected_deposit);
            };

            i = i + 1;
        };

        (p_issued, refunds)
    }

    /// Computes asset amount to issue resultant of returning liquidity `token_provided`
    /// Reference "All-Asset Deposit/Withdrawal" section in Balancer whitepaper https://docs.balancer.fi/v/v1/core-concepts/protocol/index
    /// ********************************************************************************************
    /// computeAssetAmountToReturn                                                                    //
    /// Ak = tokenKReturned                                                                           //
    /// Pissued = poolTokenIssued                                                                     //
    /// Predeemed = poolTokenRedeemed                                                                 //
    /// Bk = balanceTokenK            /       Psupply - Predeemed      \                              //
    ///                       Ak =   |  1 - ------------------------    |  * Bk                       //
    ///                               \           Psupply              /                              //
    ///                                                                                               //
    /// Simplified, Ak: Ak = Predeemed * Bk / Psupply                                                 //
    ///                                                                                               //
    /// This method takes in an amount of pool token, and returns the amount of asset k to return     //
    /// ********************************************************************************************
    ///
    /// CONTRACT: balance > 0, p_supply > 0
    ///
    /// Returns `u64` (return amount).
    public fun compute_asset_amount_to_return(balance: u64, p_redeemed: u64, p_supply: u64): u64 {
        math64::mul_div(p_redeemed, balance, p_supply)
    }

    #[test]
    fun compute_issued_pool_tokens_zero_return_ok() {
        let deposits = vector<u64>[100, 100];
        let balances = vector<u64>[100, 100];
        let p_supply = 100;

        let (lp_amount, refunds) = compute_pool_tokens_issued(&deposits, &balances, p_supply);
        assert!(lp_amount == 100, 0);
        assert!(*vector::borrow(&refunds, 0) == 0, 0);
        assert!(*vector::borrow(&refunds, 1) == 0, 0);
    }

    #[test]
    fun compute_issued_pool_tokens_nonzero_return_ok() {
        let deposits = vector<u64>[200, 100];
        let balances = vector<u64>[100, 100];
        let p_supply = 100;

        let (lp_amount, refunds) = compute_pool_tokens_issued(&deposits, &balances, p_supply);
        assert!(lp_amount == 100, 0);
        assert!(*vector::borrow(&refunds, 0) == 100, 0);
        assert!(*vector::borrow(&refunds, 1) == 0, 0);
    }

    #[test]
    fun compute_issued_pool_tokens_rounded_nearest_return_ok() {
        // expected lp_amount = 63.9 -> should always be rounded down to 63
        //
        // Original: b0 = 100, b1 = 100
        // After: b0 = 171, b1 = 171
        let deposits = vector<u64>[100, 71];
        let balances = vector<u64>[100, 100];
        let p_supply = 90;

        let (lp_amount, refunds) = compute_pool_tokens_issued(&deposits, &balances, p_supply);
        assert!(lp_amount == 63, 0);
        assert!(*vector::borrow(&refunds, 0) == 29, 0);
        assert!(*vector::borrow(&refunds, 1) == 0, 0);
    }

    #[test]
    public fun compute_asset_amount_to_return_ok() {
        assert!(compute_asset_amount_to_return(100, 0, 200) == 0, 0);
    }

    #[test]
    fun compute_asset_amount_to_return_nonzero_ok() {
        assert!(compute_asset_amount_to_return(100, 100, 200) == 50, 0);
    }

    #[test]
    fun compute_asset_amount_to_return_rounded_down_ok() {
        // expected return_amount = 63.9 -> should always be rounded down to 63
        assert!(compute_asset_amount_to_return(90, 71, 100) == 63, 0);
    }

    #[test]
    fun compute_invariant_ok() {
        let balances = vector<u64>[100, 200];
        let weights = vector<u64>[25, 75];
        let k = compute_invariant_weights_u64(&balances, &weights); // 168.17928
        assert!(fixed_point64::decode_round_down(k) == 168, 0);
        
        let balances = vector<u64>[100, 200, 50, 50];
        let weights = vector<u64>[10, 20, 30, 40];
        let k = compute_invariant_weights_u64(&balances, &weights); // 70.71068
        assert!(fixed_point64::decode_round_down(k) == 70, 0); // nearest integer (floor)
    }

    #[test]
    fun compute_invariant_large_values_ok() {
        let balances = vector<u64>[MAX_U64/4, MAX_U64/4, MAX_U64/4, MAX_U64/4];
        let weights = vector<u64>[25, 25, 25, 25];
        compute_invariant_weights_u64(&balances, &weights); // Roughly MAX_U64. Loss due to log_exp estimation
    }
    
    #[test]
    fun swap_math_ok() {
        let aI = 18;
        let bI = 18;
        let wI = 80;
        let wO = 20;
        let bO = 100;
        let result = calc_out_given_in(0, 1, aI, &vector<u64>[bI, bO], &vector<FixedPoint64>[fixed_point64::fraction(wI, 100), fixed_point64::fraction(wO, 100)]);
        let result_u64 = calc_out_given_in_weights_u64(0, 1, aI, &vector<u64>[bI, bO], &vector<u64>[wI, wO]); // expected 93.75, round down
        assert!(result == 93, 0);
        assert!(result == result_u64, 0);
        
        let aO = 10;
        bO = 20;
        bI = 100;
        wO = 80;
        wI = 20;
        result = calc_in_given_out(0, 1, aO, &vector<u64>[bI, bO], &vector<FixedPoint64>[fixed_point64::fraction(wI, 100), fixed_point64::fraction(wO, 100)]);
        result_u64 = calc_in_given_out_weights_u64(0, 1, aO, &vector<u64>[bI, bO], &vector<u64>[wI, wO]); // expected 1500
        assert!(result == 1501, 0); // 1500 + 1 due to pow_up in calc_in_given_out function
        assert!(result_u64 == 1500, 0); // exactly 1500 because pow result isn't scaled up when wO/wI == 4
    }
}
