/// Deprecated: use MultihopSwapRouter package instead
module thalaswap::multi_hop_scripts {
    const ERR_DEPRECATED: u64 = 0;
    const ERR_MULTIHOP_POOL_NOT_EXIST: u64 = 1;
    const ERR_MULTIHOP_INSUFFICIENT_OUTPUT: u64 = 2;

    public entry fun swap_exact_in_2<A0, A1, A2, A3, W0, W1, W2, W3, B0, B1, B2, B3, X0, X1, X2, X3, I, M, O>(_account: &signer, _amount_in: u64, _min_amount_out: u64) {
        abort ERR_DEPRECATED
    }
    
    public entry fun swap_exact_in_3<A0, A1, A2, A3, W0, W1, W2, W3, B0, B1, B2, B3, X0, X1, X2, X3, C0, C1, C2, C3, Y0, Y1, Y2, Y3, I, M1, M2, O>(_account: &signer, _amount_in: u64, _min_amount_out: u64) {
        abort ERR_DEPRECATED
    }
}
