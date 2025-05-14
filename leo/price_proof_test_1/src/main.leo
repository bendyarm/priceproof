import credits.aleo;

// A simple bet program.
program price_proof_test_1.aleo {

  // --------------------------------
  // Global constants

  const BET_MASTER: address = aleo13mt57u8txw8skhnhup59nscrrzm759lmy0wft3gwucqrfacvvqyqvj8zw4;

  // --------------------------------
  // On-chain mappings

  mapping market_initialized: address => bool;

  mapping bettors: address => u64;
  // later: hide addresses

  // --------------------------------
  // Transitions

  // Initialize market
  async transition initialize_market () -> Future {

    // Only the deployer can call this transition
    assert_eq(self.signer, BET_MASTER);

    // Transfer 1 Credit to the program to get it started.
    let transfer_initial_pot: Future =
      credits.aleo/transfer_public_as_signer(price_proof_test_1.aleo, 1_000_000u64);

    return(finalize_initialize_market(transfer_initial_pot));
  }

  async function finalize_initialize_market (transfer: Future) {

    // Prevent this transition from being called a second time.
    assert(Mapping::get_or_use(market_initialized, BET_MASTER, false));
    Mapping::set(market_initialized, BET_MASTER, true);

    transfer.await();
  }
}