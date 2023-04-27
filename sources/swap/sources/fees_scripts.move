module thalaswap::fees_scripts {
    use aptos_framework::coin;

    use thalaswap::fees;
    use std::signer;

    public entry fun transfer_fee<CoinType>(manager: &signer, to: address, amount: u64) {
        let manager_addr = signer::address_of(manager);
        if (manager_addr == to && !coin::is_account_registered<CoinType>(manager_addr)) {
            coin::register<CoinType>(manager);
        };
        coin::deposit(to, fees::withdraw_fee<CoinType>(manager, amount))
    }
}
