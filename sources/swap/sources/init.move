module thalaswap::init {
    use std::signer;

    use thalaswap::package;
    use thalaswap::base_pool;
    use thalaswap::stable_pool;
    use thalaswap::weighted_pool;

    use thala_manager::manager;

    // Authorization
    const ERR_UNAUTHORIZED: u64 = 0;

    // Core Dependencies
    const ERR_PACKAGE_UNINITIALIZED: u64 = 1;
    const ERR_MANAGER_UNINITIALIZED: u64 = 2;

    public entry fun initialize(deployer: &signer) {
        assert!(signer::address_of(deployer) == @thalaswap_deployer, ERR_UNAUTHORIZED);

        // Key dependencies
        assert!(package::initialized(), ERR_PACKAGE_UNINITIALIZED);
        assert!(manager::initialized(), ERR_MANAGER_UNINITIALIZED);

        // in order of each module's dependencies
        base_pool::initialize();
        stable_pool::initialize();
        weighted_pool::initialize();
    }
}
