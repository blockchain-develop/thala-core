module thalaswap_math::stable_math {
    use std::vector;

    use fixed_point64::fixed_point64::{Self, FixedPoint64};

    ///
    /// Error Codes
    ///

    const ERR_STABLE_MATH_OVERFLOW: u64 = 1;
    const ERR_STABLE_MATH_INVALID_INDICES: u64 = 2;

    const ERR_STABLE_MATH_D_NOT_CONVERGE: u64 = 3;
    const ERR_STABLE_MATH_Y_NOT_CONVERGE: u64 = 4;
    const ERR_STABLE_MATH_Y_NOT_INCREASING: u64 = 5;
    const ERR_STABLE_MATH_Y_NOT_DECREASING: u64 = 6;

    const ERR_STABLE_MATH_INVARIANT_DECREASE: u64 = 7;
    const ERR_STABLE_MATH_INVALID_NUM_COINS: u64 = 8;

    const ERR_DIVIDE_BY_ZERO: u64 = 9;

    ///
    /// Constants
    ///

    const MAX_LOOP_LIMIT: u64 = 100;
    const MAX_U64: u64 = 18446744073709551615;
    
    // `compute_invariant` and `get_Y` converges when the difference between two consecutive results is close enough
    // this number is empirically determined
    const CONVERGE_THRESHOLD: u256 = 3;

    // Normally, invariant should not decrease in a swap. However, due to numerical errors, it may decrease by a small amount
    // We allow the invariant to decrease by a tiny amount, and revert if it decreases by a larger amount
    const INVARIANT_DECREASE_TOLERANCE: u256 = 1;

    ///
    /// Functions
    ///

    /// Calculate the amount out given an input amount
    ///
    /// a: Amplification Factor
    /// i: Index of token swapped in
    /// j: Index of token swapped out
    /// aI: Normalized amount of tokens swapped in
    /// xp: Normalized balances of tokens in the pool
    ///
    /// CONTRACT: i != j, amounts & balances are normalized to the same decimal precision
    ///
    /// Returns: ***Normalized*** amount to swap for the added input
    public fun calc_out_given_in(a: u64, i: u64, j: u64, aI: u64, xp: &vector<u64>): u64 {
        let n = vector::length(xp);
        assert!(i < n && j < n && i != j, ERR_STABLE_MATH_INVALID_INDICES);

        let balance_in = *vector::borrow(xp, i);
        assert!(aI <= MAX_U64 - balance_in, ERR_STABLE_MATH_OVERFLOW);

        let new_balance_in = aI + balance_in;

        // compute the new ouput balance and ensure that it has decreased in this exchange
        let prev_balance_out = *vector::borrow(xp, j);
        let (new_balance_out, prev_invariant) = get_Y_with_prev_invariant(xp, new_balance_in, a, i, j);
        assert!(new_balance_out < prev_balance_out, ERR_STABLE_MATH_Y_NOT_DECREASING);

        // compute new invariant and ensure that it does not decrease in this exchange
        let new_xp = vector::empty<u64>();
        let k = 0;
        while (k < n) {
            let new_val = if (k == i) new_balance_in else if (k == j) new_balance_out else *vector::borrow(xp, k);
            vector::push_back(&mut new_xp, new_val);
            k = k + 1;
        };

        let new_invariant = compute_invariant(&new_xp, a);
        assert!(new_invariant + INVARIANT_DECREASE_TOLERANCE >= prev_invariant, ERR_STABLE_MATH_INVARIANT_DECREASE);

        prev_balance_out - new_balance_out
    }
    
    /// Calculate the amount in given an output amount
    ///
    /// a: Amplification Factor
    /// i: Index of token swapped in
    /// j: Index of token swapped out
    /// aO: Normalized amount of tokens to be swapped out
    /// xp: Normalized balances of tokens in the pool
    ///
    /// CONTRACT: i != j, xp[j] >= aO, amounts & balances are normalized to the same decimal precision
    ///
    /// Returns: ***Normalized*** amount to swap for the added input
    public fun calc_in_given_out(a: u64, i: u64, j: u64, aO: u64, xp: &vector<u64>): u64 {
        let n = vector::length(xp);
        assert!(i < n && j < n && i != j, ERR_STABLE_MATH_INVALID_INDICES);

        let balance_out = *vector::borrow(xp, j);

        let new_balance_out = balance_out - aO;

        // compute the new input balance and ensure that it has increased in this exchange
        let prev_balance_in = *vector::borrow(xp, i);
        let (new_balance_in, prev_invariant) = get_Y_with_prev_invariant(xp, new_balance_out, a, j, i);
        assert!(new_balance_in > prev_balance_in, ERR_STABLE_MATH_Y_NOT_INCREASING);

        // compute new invariant and ensure that it does not decrease in this exchange
        let new_xp = vector::empty<u64>();
        let k = 0;
        while (k < n) {
            let new_val = if (k == i) new_balance_in else if (k == j) new_balance_out else *vector::borrow(xp, k);
            vector::push_back(&mut new_xp, new_val);
            k = k + 1;
        };

        let new_invariant = compute_invariant(&new_xp, a);
        assert!(new_invariant + INVARIANT_DECREASE_TOLERANCE >= prev_invariant, ERR_STABLE_MATH_INVARIANT_DECREASE);

        new_balance_in - prev_balance_in
    }

    /// Compute the invariant, D, given the token balances and amplification factor
    ///
    /// Based off of the Balancer V2 Stable Pool Invariant:
    /// ********************************************************************************************//
    /// D = invariant                                                                               //
    /// A = amplification coefficient                                         D^(n+1)               //
    /// S = sum of balances                A * n^n * S + D = A * D * n^n + -------------            //
    /// P = product of balances                                                n^n P                //
    /// n = number of tokens                                                                        //
    /// ********************************************************************************************//
    ///
    /// The invariant is solved for using the Newton Raphson Method. See
    /// https://atulagarwal.dev/posts/curveamm/stableswap for an analysis of the approximation
    ///
    /// *********************************************************************************************//
    ///                                                                      |                       //
    /// D  = next estimated invariant                D' (S*An^n + n*Dp)      |          D'^(n+1)     //
    /// D' = previously estimated invariant    D = ------------------------  |   Dp = ------------   //
    ///                                             D'*(An^n - 1) + (n+1)Dp  |           P n^n       //
    ///                                                                      |                       //
    /// *********************************************************************************************//
    ///
    /// NOTE: In practice, we encode the An^n constant as An for simplicity. Many implementations of
    /// this invariant do the same.
    ///
    /// a: amplification factor
    /// xp: normalized balances of tokens in the pool
    public fun compute_invariant(xp: &vector<u64>, a: u64): u256 {
        let num_coins = vector::length(xp);

        let s: u256 = 0; // use u256 to avoid overflow 
        let i = 0;
        while (i < num_coins) {
            let x = (*vector::borrow(xp, i) as u256);

            // no risk of overflow here because sum of 4 u64 integers will not exceed u256
            s = s + x;
            i = i + 1;
        };

        if (s == 0) {
            return 0
        };

        let d = s;
        let ann = ((a * num_coins) as u256);

        let n = (num_coins as u256);

        // sort balances in ascending order
        // when calculating d^(n+1) / (p * n^n), we divide by smaller balances first to improve precision
        let (x1, x2, x3, x4) = if (num_coins == 2) {
            let (x1, x2) = sort_2((*vector::borrow(xp, 0) as u256), (*vector::borrow(xp, 1) as u256));
            (x1, x2, 0, 0)
        } else if (num_coins == 3) {
            let (x1, x2, x3) = sort_3((*vector::borrow(xp, 0) as u256), (*vector::borrow(xp, 1) as u256), (*vector::borrow(xp, 2) as u256));
            (x1, x2, x3, 0)
        } else {
            let (x1, x2, x3, x4) = sort_4((*vector::borrow(xp, 0) as u256), (*vector::borrow(xp, 1) as u256), (*vector::borrow(xp, 2) as u256), (*vector::borrow(xp, 3) as u256));
            (x1, x2, x3, x4)
        };

        // product of balances. only used in n=2 case
        let p = x1 * x2;

        let i = 0;
        while (i < MAX_LOOP_LIMIT) {
            let prev_d = d;
            let d_squared = d * d;
            let dp = if (num_coins == 2) {
                // no risks of overflow for d^3
                // d^3 / n^2 / p
                // in which n^2 = 4
                d * d_squared / p / 4
            }
            else if (num_coins == 3) {
                // d^4 / n^3 / p
                // in which n^3 = 27
                d * d_squared / x1 / x2 * d / x3 / 27
            }
            else if (num_coins == 4) {
                // d^5 / n^4 / p
                // in which n^4 = 256
                d * d_squared / x1 / x2 * d_squared / x3 / x4 / 256
            }
            else {
                abort ERR_STABLE_MATH_INVALID_NUM_COINS
            };

            d = (ann * s + n * dp) * d / ((ann - 1) * d + dp * (n + 1));

            if (abs_diff(prev_d, d) <= CONVERGE_THRESHOLD) {
                return d
            };

            i = i + 1;
        };

        abort ERR_STABLE_MATH_D_NOT_CONVERGE
    }

    // Compute the expected updated balance of a token given a balance change of another token.
    // Token of known balance is indexed with `i` and balance `x`
    // Token to calculate updated balance is indexed with `j`, and new balance will be `y`
    //
    // The new balance is solved for using the Newton Raphson Method. See `compute_invarant` for the equation
    // & https://atulagarwal.dev/posts/curveamm/stableswap for an analysis of the approximation
    //
    // **************************************************************************************************************//
    // y  = next estimated balance                                    |                       |                      //
    // y' = previously estimated balance                  y'^2 + c    |         D^(n+1)       |             D        //
    // D = invariant                              y =  -------------- |  c = ---------------- | b = S + ----------   //
    // A = amplification coefficient                     2y' + b - D  |       n^n * P * An^n  |            An^n      //
    // S = sum of balances (excluding index `j`)                      |                       |                      //
    // P = product of balances (excluding index `j`)                  |                       |                      //
    // n = number of tokens                                           |                       |                      //
    // **************************************************************************************************************//
    //
    // NOTE: In practice, we encode the An^n constant as An for simplicity. Many implementations of
    // this invariant do the same.
    //
    // xp: current pool balances (** Normalized **)
    // x: balance of asset `i` after swap
    // a: amplification factor
    // i: index of asset which the updated balance is known
    // j: index to compute updated balance
    fun get_Y(xp: &vector<u64>, x: u64, a: u64, i: u64, j: u64): u64 {
        let (y, _invariant) = get_Y_with_prev_invariant(xp, x, a, i, j);
        y
    }

    // Returns the new balance (in u64) and the invariant prior to the update (in u256, equals to `compute_invariant(xp, a)` as a by-product of the computation).
    fun get_Y_with_prev_invariant(xp: &vector<u64>, x: u64, a: u64, i: u64, j: u64): (u64, u256) {
        let d = compute_invariant(xp, a);

        let num_coins = vector::length(xp);
        let n = (num_coins as u256);
        let ann = (a as u256) * n;

        let c: u256 = d;
        let s: u256 = 0;
        let k = 0;
        while (k < num_coins) {
            if (k == j) {
                k = k + 1;
                continue
            };

            let x_k = ((if (k == i) x else *vector::borrow(xp, k)) as u256);
            s = s + x_k;

            c = c * d / (x_k * n);
            k = k + 1;
        };

        c = c * d / n / ann;
        let b = d / ann + s;
        let y = d;
        let k = 0;
        while (k < MAX_LOOP_LIMIT) {
            let prev_y = y;
            y = (y * y + c) / (2 * y + b - d);
            if (abs_diff(y, prev_y) <= CONVERGE_THRESHOLD) {
                // return (y + 10) instead of y because numerical errors may cause y to be slightly less than what it should be
                // and that would cause the invariant to decrease slightly, and fail the assertion in `get_D`
                // pool precision is 8 digits, so this is equivalent to charging a fee of 0.0000001, which is negligible
                let y_out = y + 10;
                assert!(y_out < (MAX_U64 as u256), ERR_STABLE_MATH_OVERFLOW);
                return ((y_out as u64), d)
            };

            k = k + 1;
        };

        abort ERR_STABLE_MATH_Y_NOT_CONVERGE
    }

    // Internal Helpers

    fun abs_diff_fp(x: FixedPoint64, y: FixedPoint64): FixedPoint64 {
        if (fixed_point64::gt(&x, &y)) fixed_point64::sub_fp(x, y) else fixed_point64::sub_fp(y, x)
    }
    
    fun abs_diff(x: u256, y: u256): u256 {
        if (x >= y) x - y else y - x
    }

    /// Calculates x * y / z by casting intermediate values to u256 to avoid overflow
    fun mul_div(x: u64, y: u64, z: u64): u64 {
        assert!(z != 0, ERR_DIVIDE_BY_ZERO);
        let r = (x as u256) * (y as u256) / (z as u256);
        (r as u64)
    }

    // sort 2 u256 numbers in ascending order
    fun sort_2(a: u256, b: u256): (u256, u256) {
        if (a > b) (b, a) else (a, b)
    }

    // sort 3 u256 numbers in ascending order using bubble sort
    fun sort_3(a: u256, b: u256, c: u256): (u256, u256, u256) {
        let (a, b) = sort_2(a, b);
        let (b, c) = sort_2(b, c);
        let (a, b) = sort_2(a, b);
        (a, b, c)
    }

    // sort 4 u256 numbers in ascending order using bubble sort
    fun sort_4(a: u256, b: u256, c: u256, d: u256): (u256, u256, u256, u256) {
        let (a, b) = sort_2(a, b);
        let (b, c) = sort_2(b, c);
        let (c, d) = sort_2(c, d);
        let (a, b) = sort_2(a, b);
        let (b, c) = sort_2(b, c);
        let (a, b) = sort_2(a, b);
        (a, b, c, d)
    }

    #[test]
    fun compute_invariant_ok() {
        // emperically calculated values that satisfy the invariant
        let amp = 1;
        let d = 10;
        let xp = vector<u64>[5, 5];
        assert!(compute_invariant(&xp, amp) == d, 0);
    }

    #[test]
    fun compute_invariant_large_numbers_ok() {
        let xp = vector<u64>[MAX_U64/4, MAX_U64/4, MAX_U64/4, MAX_U64/4];
        compute_invariant(&xp, 1);
    }

    #[test]
    fun sort_2_ok() {
        let (a, b) = sort_2(1, 2);
        assert!(a == 1, 0);
        assert!(b == 2, 0);
    }

    #[test]
    fun sort_3_ok() {
        let (a, b, c) = sort_3(1, 2, 3);
        assert!(a == 1, 0);
        assert!(b == 2, 0);
        assert!(c == 3, 0);

        let (a, b, c) = sort_3(2, 1, 3);
        assert!(a == 1, 0);
        assert!(b == 2, 0);
        assert!(c == 3, 0);
        
        let (a, b, c) = sort_3(3, 2, 1);
        assert!(a == 1, 0);
        assert!(b == 2, 0);
        assert!(c == 3, 0);
    }

    #[test]
    fun sort_4_ok() {
        let (a, b, c, d) = sort_4(1, 2, 3, 4);
        assert!(a == 1, 0);
        assert!(b == 2, 0);
        assert!(c == 3, 0);
        assert!(d == 4, 0);

        let (a, b, c, d) = sort_4(1, 4, 3, 2);
        assert!(a == 1, 0);
        assert!(b == 2, 0);
        assert!(c == 3, 0);
        assert!(d == 4, 0);

        let (a, b, c, d) = sort_4(2, 3, 1, 4);
        assert!(a == 1, 0);
        assert!(b == 2, 0);
        assert!(c == 3, 0);
        assert!(d == 4, 0);

        let (a, b, c, d) = sort_4(2, 4, 3, 1);
        assert!(a == 1, 0);
        assert!(b == 2, 0);
        assert!(c == 3, 0);
        assert!(d == 4, 0);

        let (a, b, c, d) = sort_4(3, 2, 4, 1);
        assert!(a == 1, 0);
        assert!(b == 2, 0);
        assert!(c == 3, 0);
        assert!(d == 4, 0);

        let (a, b, c, d) = sort_4(3, 1, 4, 2);
        assert!(a == 1, 0);
        assert!(b == 2, 0);
        assert!(c == 3, 0);
        assert!(d == 4, 0);

        let (a, b, c, d) = sort_4(4, 2, 3, 1);
        assert!(a == 1, 0);
        assert!(b == 2, 0);
        assert!(c == 3, 0);
        assert!(d == 4, 0);

        let (a, b, c, d) = sort_4(4, 1, 3, 2);
        assert!(a == 1, 0);
        assert!(b == 2, 0);
        assert!(c == 3, 0);
        assert!(d == 4, 0);
    }
}
