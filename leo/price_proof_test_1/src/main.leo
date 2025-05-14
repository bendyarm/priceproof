import credits.aleo;

// A simple bet program.
program price_proof_test_1.aleo {

  // --------------------------------
  // Global constants

  const BET_MASTER: address = aleo13mt57u8txw8skhnhup59nscrrzm759lmy0wft3gwucqrfacvvqyqvj8zw4;

  // --------------------------------
  // On-chain mappings

  // market_state(addr) is undefined or equals 0 means not yet initialized (and not taking bets)
  // 1 means initialized and is taking bets
  // 2 means market is closed and not taking bets, but has not yet disbursed funds
  // 3 means market is deactivated, not taking bets, and funds have been disbursed
  mapping market_state: address => u8;

  // for each bettor address, stores their cumulative bet
  mapping bets: address => u64;
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
    assert_eq(Mapping::get_or_use(market_state, BET_MASTER, 0u8), 0u8);
    Mapping::set(market_state, BET_MASTER, 1u8);

    transfer.await();
  }

  // ----------------

  // place bet amount in microcredits
  async transition place_bet (amount: u64) -> Future {

    // Note: the bet amounts, if large enough to be worth it,
    // could be staked, e.g with credits.aleo/bond_public

    let transfer_bet_funds: Future =
      credits.aleo/transfer_public_as_signer(price_proof_test_1.aleo, amount);

    return(finalize_place_bet(self.signer, amount, transfer_bet_funds));

  }

  async function finalize_place_bet (bettor: address, amount: u64, transfer: Future) {

    // make sure the contract is taking bets
    assert_eq(Mapping::get_or_use(market_state, BET_MASTER, 0u8), 1u8);

    // get the current bet amount for the signer
    let old_bet: u64 = Mapping::get_or_use(bets, bettor, 0u64);
    // update the bet amount
    Mapping::set(bets, bettor, old_bet + amount);

    transfer.await();
  }

}
