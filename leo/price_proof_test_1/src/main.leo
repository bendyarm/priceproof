import credits.aleo;

// A simple bet program.
program price_proof_test_1.aleo {

  // --------------------------------
  // Global constants

  const BET_MASTER: address = aleo13mt57u8txw8skhnhup59nscrrzm759lmy0wft3gwucqrfacvvqyqvj8zw4;

  // For now we limit the number of unique bettors (addresses) to 100.
  // Use u16 in case we want it to be larger than 255.
  const BET_POOL_SIZE: u16 = 100u16;

  // --------------------------------
  // On-chain mappings

  // market_state(addr) is undefined or equals 0 means not yet initialized (and not taking bets)
  // 1 means initialized and is taking bets
  // 2 means market is closed and not taking bets, but has not yet disbursed funds
  // 3 means market is deactivated, not taking bets, and funds have been disbursed
  mapping market_state: address => u8;

  // bet_price_threshold is set at the USD value
  // (in units of hundredths of cents, or 10^-4 USD;
  //  e.g. $0.23 will be 2300u64.)
  // of 1 ALEO at the bet end time.
  // Bullish bettors bet that the USD value will be greater or equal to this amount.
  // Bearish bettors bet that the USD value will be less than this amount.
  // This mapping is set when the market is initialized.
  // (Note that $0.25 is 
  mapping bet_price_threshold: bool => u64;
  // bool is always true; the mapping is used as a variable.

  // Bull and bear bet amounts are stored as separate mappings.
  // Within each mapping, bets by the same bettor can accumulate.
  mapping bull_bets: address => u64;
  mapping bear_bets: address => u64;
  
  // We also need to maintain the keys to do payouts if we are doing automatic payouts.
  // (or payouts could be "claimed" by their bettors, in which case a good
  //  extension would be to have a time limit;
  //  maybe 10,000,000 blocks, which at the current rate is about 1 year)
  //  for claiming, after which the BET_MASTER would get the bet.)

  // Also keep track of the bettors, to do automatic payouts.
  mapping id_to_bull_bettor: u16 => address;
  mapping next_bull_bettors_index: bool => u16;
  mapping id_to_bear_bettor: u16 => address;
  mapping next_bear_bettors_index: bool => u16;
  // For the previous mapping, bool is always true; the mapping is used as a variable.

  // --------------------------------
  // Transitions

  // Initialize market
  // The parameter bet_above_or_equal
  async transition initialize_market (bet_threshold: u64) -> Future {

    // Only the deployer can call this transition
    assert_eq(self.signer, BET_MASTER);

    // Transfer 1 Credit to the program to get it started.
    let transfer_initial_pot: Future =
      credits.aleo/transfer_public_as_signer(price_proof_test_1.aleo, 1_000_000u64);

    return(finalize_initialize_market(bet_threshold, transfer_initial_pot));
  }

  async function finalize_initialize_market (bet_threshold: u64, transfer: Future) {

    // Prevent this transition from being called a second time.
    assert_eq(Mapping::get_or_use(market_state, BET_MASTER, 0u8), 0u8);
    Mapping::set(market_state, BET_MASTER, 1u8);

    // Set the bet theshold (users can bet that the USD price will either be
    // (1) below or (2) equal or above this value.
    Mapping::set(bet_price_threshold, true, bet_threshold);

    // The values here should always correspond to the number of unique bettors in each mapping.
    Mapping::set(next_bull_bettors_index, true, 0u16);
    Mapping::set(next_bear_bettors_index, true, 0u16);

    transfer.await();
  }

  // ----------------

  // place bet amount in microcredits.
  async transition place_bet (amount: u64, is_bull: bool) -> Future {

    // Note: the bet amounts, if large enough to be worth it,
    // could be staked, e.g with credits.aleo/bond_public

    let transfer_bet_funds: Future =
      credits.aleo/transfer_public_as_signer(price_proof_test_1.aleo, amount);

    return(finalize_place_bet(self.signer, is_bull, amount, transfer_bet_funds));

  }

  async function finalize_place_bet (bettor: address,
                                     is_bull: bool,
                                     amount: u64,
                                     transfer: Future) {

    // make sure the contract is taking bets
    assert_eq(Mapping::get_or_use(market_state, BET_MASTER, 0u8), 1u8);


    if is_bull {
      // See if this bettor is in the map, in which case they will also
      // be in the array of keys.
      let previously_seen_bettor: bool = Mapping::contains(bull_bets, bettor);

      // Make sure the betting is not fully-booked.
      // (If we already saw the bettor, the bet will just be updated.)
      assert( previously_seen_bettor || Mapping::get(next_bull_bettors_index, true) < BET_POOL_SIZE );

      let old_bet: u64 = Mapping::get_or_use(bull_bets, bettor, 0u64);

      // update the bet amount
      Mapping::set(bull_bets, bettor, old_bet + amount);

      // Maintain the map from ids to bettors, so we can iterate
      // over them later.
      if !previously_seen_bettor {
        let next_index: u16 = Mapping::get(next_bull_bettors_index, true);
        assert( !Mapping::contains(id_to_bull_bettor, next_index));
        Mapping::set(id_to_bull_bettor, next_index, bettor);
        Mapping::set(next_bull_bettors_index, true, next_index + 1u16);
      }

    } else { // is bear bet
      let previously_seen_bettor: bool = Mapping::contains(bear_bets, bettor);
      assert( previously_seen_bettor || Mapping::get(next_bear_bettors_index, true) < BET_POOL_SIZE );
      let old_bet: u64 = Mapping::get_or_use(bear_bets, bettor, 0u64);
      Mapping::set(bear_bets, bettor, old_bet + amount);
      if !previously_seen_bettor {
        let next_index: u16 = Mapping::get(next_bear_bettors_index, true);
        assert( !Mapping::contains(id_to_bear_bettor, next_index));
        Mapping::set(id_to_bear_bettor, next_index, bettor);
        Mapping::set(next_bear_bettors_index, true, next_index + 1u16);
      }
    }

    transfer.await();
  }

  // ----------------

  // receive oracle price data and do payouts
  // async transition settle_ (amount: u64, is_bull: bool) -> Future {

  // 

}
