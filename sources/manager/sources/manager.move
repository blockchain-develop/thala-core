module thala_manager::manager {
    use std::signer;

    use aptos_framework::account;
    use aptos_std::event::{Self, EventHandle};

    use thala_manager::package;

    ///
    /// Errors
    ///

    // Authorization
    const ERR_UNAUTHORIZED: u64 = 0;

    // Initialization
    const ERR_MANAGER_UNINITIALIZED: u64 = 1;
    const ERR_MANAGER_INITIALIZED: u64 = 2;

    const ERR_MANAGER_INVALID_MANAGER_ADDRESS: u64 = 3;
    const ERR_MANAGER_NO_MANAGER_CHANGE_PROPOSAL: u64 = 4;

    struct Manager has key {
        manager_address: address,
        events: ManagerEvents
    }

    struct ManagerChangeProposal has key, drop {
        new_manager_address: address
    }

    ///
    /// Events
    ///

    struct ManagerEvents has store {
        change_proposal_created: EventHandle<ManagerChangeProposalCreated>,
        change_proposal_dropped: EventHandle<ManagerChangeProposalDropped>,
        change_proposal_accepted: EventHandle<ManagerChangeProposalAccepted>,
    }

    struct ManagerChangeProposalCreated has store, drop {
        current_manager: address,
        new_manager: address
    }

    struct ManagerChangeProposalDropped has store, drop {
        current_manager: address,
        dropped_manager: address
    }

    struct ManagerChangeProposalAccepted has store, drop {
        new_manager: address
    }

    ///
    /// Initialization
    ///

    /// Initialize the Thala Manager. We do not utilize an `init` module given the simplicity of this
    /// package. **MUST** be called from the original deployer account of this package.
    ///
    /// All manager operations of Thala products are gated by `manager::is_authorized(&signer)`.
    /// The authorized signer is the one controlling the supplied `manager_address`.
    ///
    /// This model allows for the deployment of 
    ///   (a) A centralized manager via an externally owned `manager_address`
    ///   (b) Governance controlled manager. In which `manager_address` is not externally owned.
    public entry fun initialize(deployer: &signer, manager_address: address) {
        assert!(!initialized(), ERR_MANAGER_INITIALIZED);
        assert!(signer::address_of(deployer) == @thala_manager_deployer, ERR_UNAUTHORIZED);
        assert!(account::exists_at(manager_address), ERR_MANAGER_INVALID_MANAGER_ADDRESS);

        // Dependencies
        assert!(package::initialized(), ERR_MANAGER_UNINITIALIZED);

        let resource_account_signer = package::resource_account_signer();
        move_to(&resource_account_signer, Manager {
            manager_address,
            events: ManagerEvents {
                change_proposal_created: account::new_event_handle<ManagerChangeProposalCreated>(&resource_account_signer),
                change_proposal_dropped: account::new_event_handle<ManagerChangeProposalDropped>(&resource_account_signer),
                change_proposal_accepted: account::new_event_handle<ManagerChangeProposalAccepted>(&resource_account_signer),
            }
        });
    }
    
    ///
    /// Config & Param Management
    ///

    /// Change the manager address of the manager
    public entry fun change_manager_address(account: &signer, new_manager_address: address) acquires Manager, ManagerChangeProposal {
        assert!(is_authorized(account), ERR_UNAUTHORIZED);

        let resource_account_address = package::resource_account_address();
        let manager = borrow_global_mut<Manager>(resource_account_address);
        let manager_addr = manager.manager_address;
        assert!(new_manager_address != manager_addr && account::exists_at(new_manager_address), ERR_MANAGER_INVALID_MANAGER_ADDRESS);

        // drop any existing proposals
        if (exists<ManagerChangeProposal>(resource_account_address)) {
            let old_proposal = move_from<ManagerChangeProposal>(resource_account_address);
            event::emit_event(&mut manager.events.change_proposal_dropped, ManagerChangeProposalDropped {
                current_manager: manager_addr,
                dropped_manager: old_proposal.new_manager_address
            });

            // old_proposal is dropped from here on out
        };

        // store this latest proposal
        event::emit_event(&mut manager.events.change_proposal_created, ManagerChangeProposalCreated {
            current_manager: manager_addr,
            new_manager: new_manager_address
        });

        move_to(&package::resource_account_signer(), ManagerChangeProposal { new_manager_address });
    }

    /// Accept the manager change, officially making the switch
    public entry fun accept_manager_proposal(account: &signer) acquires Manager, ManagerChangeProposal {
        let account_addr = signer::address_of(account);

        let resource_account_address = package::resource_account_address();
        let manager = borrow_global_mut<Manager>(resource_account_address);
        assert!(exists<ManagerChangeProposal>(resource_account_address), ERR_MANAGER_NO_MANAGER_CHANGE_PROPOSAL);

        let change_proposal = borrow_global<ManagerChangeProposal>(resource_account_address);
        assert!(account_addr == change_proposal.new_manager_address, ERR_UNAUTHORIZED);

        // Drop the proposal from storage & update the manager address
        let _ = move_from<ManagerChangeProposal>(resource_account_address);
        manager.manager_address = account_addr;

        event::emit_event(&mut manager.events.change_proposal_accepted, ManagerChangeProposalAccepted {
            new_manager: account_addr
        });
    }

    ///
    /// Functions
    ///

    /// Check if an account is the current manager.
    public fun is_authorized(account: &signer): bool acquires Manager {
        is_authorized_address(signer::address_of(account))
    }

    /// Query if an address it associated with the current manager
    public fun is_authorized_address(account_addr: address): bool acquires Manager {
        assert!(initialized(), ERR_MANAGER_UNINITIALIZED);

        let manager = borrow_global<Manager>(package::resource_account_address());
        account_addr  == manager.manager_address
    }

    /// Upgrade or publish modules under the manager's resource account
    public entry fun upgrade_manager(account: &signer, metadata_serialized: vector<u8>, code: vector<vector<u8>>) acquires Manager {
        assert!(is_authorized(account), ERR_UNAUTHORIZED);

        package::publish_package(metadata_serialized, code);
    }

    // Public Getters

    public fun initialized(): bool {
        exists<Manager>(package::resource_account_address())
    }

    #[view]
    public fun manager_address(): address acquires Manager {
        borrow_global<Manager>(package::resource_account_address()).manager_address
    }

    #[test_only]
    public fun initialize_for_test(manager_address: address) {
        // In order for other modules to depend on ThalaManager and mock the manager in tests, we internally
        // create this module's deployer account to initialize from. This is important as various modules
        // may differ in the deployer address used. We do not call `create_account_for_test` as modules may
        // also share the deployer
        let deployer = account::create_signer_for_test(package::resource_account_deployer_address());
        if (!account::exists_at(manager_address)) _ = account::create_account_for_test(manager_address);

        package::init_for_test();
        initialize(&deployer, manager_address);
    }

    #[test]
    #[expected_failure(abort_code = ERR_UNAUTHORIZED)]
    public fun initialize_unauthorized_err() {
        let incorrect_deployer = account::create_account_for_test(@0xA);
        initialize(&incorrect_deployer, @0xA);
    }

    #[test]
    #[expected_failure(abort_code = ERR_MANAGER_INITIALIZED)]
    fun initialize_twice_err() {
        // prepare
        let deployer = account::create_account_for_test(@thala_manager_deployer);
        initialize_for_test(@0xA);

        // test
        initialize(&deployer, @0xA)
    }

    #[test]
    #[expected_failure(abort_code = ERR_UNAUTHORIZED)]
    fun upgrade_manager_unauthorized_err() acquires Manager {
        let manager = account::create_account_for_test(@0xA);
        initialize_for_test(@0xA);

        // test
        assert!(is_authorized(&manager), 0);

        let non_manager = account::create_account_for_test(@0xB);
        upgrade_manager(&non_manager, std::vector::empty(), std::vector::empty());
    }

    #[test]
    fun change_manager_address_ok() acquires Manager, ManagerChangeProposal {
        // prepare
        let accountA = account::create_account_for_test(@0xA);
        let accountB = account::create_account_for_test(@0xB);
        initialize_for_test(@0xA);

        // test
        assert!(is_authorized(&accountA), 0);
        assert!(!is_authorized(&accountB), 0);

        change_manager_address(&accountA, @0xB);
        accept_manager_proposal(&accountB);
        assert!(!is_authorized(&accountA), 0);
        assert!(is_authorized(&accountB), 0);

        change_manager_address(&accountB, @0xA);
        accept_manager_proposal(&accountA);
        assert!(is_authorized(&accountA), 0);
        assert!(!is_authorized(&accountB), 0);
    }

    #[test]
    fun change_manager_2phase_ok() acquires Manager, ManagerChangeProposal {
        // prepare
        let accountA = account::create_account_for_test(@0xA);
        let accountB = account::create_account_for_test(@0xB);
        initialize_for_test(@0xA);

        // test
        assert!(is_authorized(&accountA), 0);
        assert!(!is_authorized(&accountB), 0);

        change_manager_address(&accountA, @0xB);

        // accountA is stil the manager
        assert!(is_authorized(&accountA), 0);
        assert!(!is_authorized(&accountB), 0);

        // manager change only on accept
        accept_manager_proposal(&accountB);
        assert!(!is_authorized(&accountA), 0);
        assert!(is_authorized(&accountB), 0);
    }

    #[test]
    #[expected_failure(abort_code = ERR_UNAUTHORIZED)]
    fun change_manager_overwriten_proposal_unauthorize_err() acquires Manager, ManagerChangeProposal {
        // prepare
        let accountA = account::create_account_for_test(@0xA);
        let accountB = account::create_account_for_test(@0xB);
        initialize_for_test(@0xA);

        // test
        assert!(is_authorized(&accountA), 0);
        assert!(!is_authorized(&accountB), 0);

        change_manager_address(&accountA, @0xB);

        account::create_account_for_test(@0xC);
        change_manager_address(&accountA, @0xC); // overwrite to a different manager

        accept_manager_proposal(&accountB);
    }

    #[test]
    fun change_manager_accept_overwriten_proposal_ok() acquires Manager, ManagerChangeProposal {
        // prepare
        let accountA = account::create_account_for_test(@0xA);
        let accountB = account::create_account_for_test(@0xB);
        initialize_for_test(@0xA);

        // test
        assert!(is_authorized(&accountA), 0);
        assert!(!is_authorized(&accountB), 0);

        account::create_account_for_test(@0xC);
        change_manager_address(&accountA, @0xC);
        change_manager_address(&accountA, @0xB); // overwrite to a different manager

        accept_manager_proposal(&accountB);
        assert!(!is_authorized(&accountA), 0);
        assert!(is_authorized(&accountB), 0);
    }

    #[test]
    #[expected_failure(abort_code = ERR_UNAUTHORIZED)]
    fun change_manager_address_unauthorized_err() acquires Manager, ManagerChangeProposal {
        // prepare
        let accountA = account::create_account_for_test(@0xA);
        let accountB = account::create_account_for_test(@0xB);
        initialize_for_test(@0xA);

        // test
        change_manager_address(&accountA, @0xB);
        accept_manager_proposal(&accountB);

        change_manager_address(&accountA, @0xB);
    }
}
