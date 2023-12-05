module thalaswap::coin_helper {
    use aptos_std::comparator::{Self, Result};
    use aptos_std::type_info;
    
    ///
    /// Functions
    ///

    /// Checks if X, Y are sorted and unique. X < Y && X != Y
    public fun is_unique_and_sorted<X, Y>(): bool {
        let order = compare<X, Y>();

        // `is_smaller_than` returns false if equal
        comparator::is_smaller_than(&order)
    }

    // Internal helpers

    fun compare<X, Y>(): Result {
        let x_info = type_info::type_of<X>();
        let y_info = type_info::type_of<Y>();

        // 1. compare struct_name
        let x_struct_name = type_info::struct_name(&x_info);
        let y_struct_name = type_info::struct_name(&y_info);
        let struct_cmp = comparator::compare(&x_struct_name, &y_struct_name);
        if (!comparator::is_equal(&struct_cmp)) return struct_cmp;

        // 2. if struct names are equal, compare module name
        let x_module_name = type_info::module_name(&x_info);
        let y_module_name = type_info::module_name(&y_info);
        let module_cmp = comparator::compare(&x_module_name, &y_module_name);
        if (!comparator::is_equal(&module_cmp)) return module_cmp;

        // 3. if modules are equal, compare addresses
        let x_address = type_info::account_address(&x_info);
        let y_address = type_info::account_address(&y_info);
        return comparator::compare(&x_address, &y_address)
    }

    #[test_only]
    struct BTC {}

    #[test_only]
    struct ETH {}


    #[test]
    fun compare_ok() {
        assert!(comparator::is_equal(&compare<BTC, BTC>()), 0);
        assert!(comparator::is_smaller_than(&compare<BTC, ETH>()), 0);
        assert!(comparator::is_greater_than(&compare<ETH, BTC>()), 0);
    }

    #[test]
    fun is_unique_and_sorted_ok() {
        assert!(!is_unique_and_sorted<BTC, BTC>(), 0);
        assert!(!is_unique_and_sorted<ETH, BTC>(), 0);

        assert!(is_unique_and_sorted<BTC, ETH>(), 0);
    }
}
