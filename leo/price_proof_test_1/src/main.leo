import credits.aleo;

// A simple bet program.
program price_proof_test_1.aleo {

  // --------------------------------
  // Global constants

  const BET_MASTER: address = aleo13mt57u8txw8skhnhup59nscrrzm759lmy0wft3gwucqrfacvvqyqvj8zw4;

  // For now we limit the number of unique bettors (addresses) in either the bull or bear
  // mapping to 100.
  // Use u16 in case we want it to be larger than 255.
  const BET_POOL_SIZE: u16 = 100u16;

  // --------------------------------
  // On-chain mappings

  // market_state(addr) is undefined or equals 0 means not yet initialized (and not taking bets)
  // 1 means initialized and is taking bets
  // 2 means market is closed and not taking bets, but has not yet received the oracle price
  // 3 means market has received oracle price and bettors may claim their bets
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

  // oracle_price is the closing price of ALEO in units of 10^-4 USD at the expiration time.
  mapping oracle_price: bool => u64;
  // bool is always true; the mapping is used as a variable.
  
  // Bull and bear bet amounts are stored as separate mappings.
  // Within each mapping, bets by the same bettor can accumulate.
  mapping bull_bets: address => u64;
  mapping bear_bets: address => u64;

  // We also need to maintain the keys to do payouts if we are doing automatic payouts.
  // However, automatic payouts are expensive (and require more complex code due to
  // each payout being an external call), so we decided to let bettors claim their payouts.
  // A potenpayouts could be "claimed" by their bettors, in which case a good
  //  extension would be to have a time limit;
  //  maybe 10,000,000 blocks, which at the current rate is about 1 year)
  //  for claiming, after which the BET_MASTER would get the bet.)

  // Also keep track of the bettors.
  // (Might not be necessary given we are not doing automatic payouts.)
  mapping id_to_bull_bettor: u16 => address;
  mapping next_bull_bettors_index: bool => u16;
  mapping id_to_bear_bettor: u16 => address;
  mapping next_bear_bettors_index: bool => u16;
  // For the previous mapping, bool is always true; the mapping is used as a variable.

  // Keep track of each address that has claimed their winnings,
  // so we can reject duplicate claims.
  mapping already_claimed: address => bool;

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

    // Set the bet theshold --- users can bet that the USD price will either be
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
    // If the staking rewards went to the bet master,
    // that could result in an incentive for the bet master to
    // delay the closing price, if they could get more staking rewards based
    // on everyone's bets.
    // Better would be for the staking rewards to go to the pot before the closing
    // price is posted, but to go to the bet master afterwards.

    // Note, the bet master chould be openly taking a very small percentage of the bets,
    // but escrowed until they have posted the closing price at expiration,
    // so that they are incentivized to complete the process.

    // We restrict bets to 10^12 microcredits, since it simplifies payout logic.
    assert(amount < 1_000_000_000_000u64);

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

  // Close betting.  Call this sometime within the 1-hour window before the
  // time resolving the bet (the time Coinbase reports ALEO-USD at the end of the day
  // of the day we are betting about).

  async transition close_betting () -> Future {

    // Only the deployer can call this transition
    assert_eq(self.signer, BET_MASTER);

    return(finalize_close_betting());
  }

  async function finalize_close_betting () {

    // Make sure the state is taking bets (market_state = 1) and not something else.
    assert_eq(Mapping::get_or_use(market_state, BET_MASTER, 0u8), 1u8);

    // Set state to 2: market is closed.
    Mapping::set(market_state, BET_MASTER, 2u8);
  }

  // ----------------

  // Receive oracle ALEO-USD price from Coinbase.

  // Note: see the notes under `transition place_bet` for some enhancements
  // that could be done here.

  // amount is in hundredths of a cent (10^-4 USD)
  async transition receive_oracle_price (amount: u64) -> Future {

    // Only the deployer can call this transition
    assert_eq(self.signer, BET_MASTER);

    return(finalize_receive_oracle_price(amount));
  }

  async function finalize_receive_oracle_price(amount: u64) {

    // Make sure the state is 2 (market closed) and not something else.
    assert_eq(Mapping::get_or_use(market_state, BET_MASTER, 0u8), 2u8);

    Mapping::set(oracle_price, true, amount);

    // set state to 3: oracle price received; bettors may claim their bets
    Mapping::set(market_state, BET_MASTER, 3u8);
  }

  // ----------------

  // Note, it is hard to do automatic payouts, since we can only call external transitions
  // from a transition, and credits.aleo/transfer_public is an external transition.
  // Therefore we will give the bettor the responsibility of claiming their winnings.

  // ========
  // WARNING: We don't have a way to get a value from a mapping and then to pass
  // it to credits.aleo/transfer_public.  If it is a single value, it is fairly
  // easy for the bettor to look it up and submit it as a claim.
  // But if there are a bunch of mapping values from which the claim amount is
  // computed, then the amount of work placed on the bettor is unreasonable.
  // Possible solutions:
  // 1. The user interface gets the necessary mapping values and does the exact same
  //    computation as the computations we do in the async function; then submits
  //    that result as a claim, and the async function does the computations and
  //    if the result is different, throws an error.
  // 2. Do a multi-step process.
  //    (a) The bettor (or user interface) submits a
  //        calculate_claim transaction which is put in a new mapping.
  //    (b) The user interface must look up their address in this new mapping
  //        (or they can do it manually).
  //    (c) the bettor or user interface submits a claim_bet transaction,
  //        inputting the value computed in (a).
  //        The transition calls transfer_public to the bettor and then calls the
  //        async function that repeats the computation in (a).  If the computed
  //        result didn't match what the bettor claimed, the transaction is rejected.
  //
  // Which of these is better?  #1 seems more brittle but #2 is more cumbersome.
  // However, #1's potential brittleness of the user interface is ameliorated by
  // the the check of correctness in the async function,
  // so the worst would be that a bug in the user interface prevents
  // the bettor from claiming the bet until the user interface is fixed.
  // We will go with #1 for now.
  // ========

  // claim_bet is called by a bettor to claim their winning bet.
  // If winning_bet_was_bull is true but the closing price was below the strike price,
  // the transition gets an error.
  // If winning_bet_amount is different than the actual winning bet from this bettor,
  // the transition gets an error.
  // If these both match, then the bet is transferred publicly to the bettor
  // and this program records that the bet has been claimed.
  //
  async transition claim_bet (claimed_winning_amount: u64) -> Future {

    // Transfer the claimed credits to the winning bettor (checks are later)
    let transfer_winning_bet: Future =
      credits.aleo/transfer_public(self.signer, claimed_winning_amount);

    return(finalize_claim_bet(self.signer, claimed_winning_amount, transfer_winning_bet));
  }

  async function finalize_claim_bet(claimant: address,
                                    claimed_amount: u64,
                                    transfer: Future) {

    // Make sure the state is 3 (bets are claimable) and not something else.
    assert_eq(Mapping::get_or_use(market_state, BET_MASTER, 0u8), 3u8);

    // Make sure the signer has not already claimed their bet
    assert( !Mapping::contains(already_claimed, claimant));

    // Determine how much claimant is supposed to get.

    // Should the bull bets win?
    let bull_bets_win: bool
          = (Mapping::get(oracle_price, true) >= Mapping::get(bet_price_threshold, true));

    // Calculate aggregate winning bets.  This has to be done once for each side of the bet
    // because of the compiler limitation
    // "Cannot re-assign to xxx from a conditional scope to an outer scope in an async function"
    let total_winning_bull_bets: u64 = 0u64;
    for i: u16 in 0u16..100u16 {
       let bull_bettor: address = Mapping::get(id_to_bull_bettor, i);
       let bull_bettor_amount: u64 = Mapping::get(bull_bets, bull_bettor);
       total_winning_bull_bets += (next_bull_bettors_index.get(true) < i) ? bull_bettor_amount : 0u64;
     }
    let total_winning_bear_bets: u64 = 0u64;
    for i: u16 in 0u16..100u16 {
       let bear_bettor: address = Mapping::get(id_to_bear_bettor, i);
       let bear_bettor_amount: u64 = Mapping::get(bear_bets, bear_bettor);
       total_winning_bear_bets += (next_bear_bettors_index.get(true) < i) ? bear_bettor_amount : 0u64;
     }
    let total_winning_bets: u64 = bull_bets_win ? total_winning_bull_bets : total_winning_bear_bets;

// This didn't work.  Compiler limitation.  There is a plan to fix it.
//    let total_winning_bets: u64 = 0u64;
//    for i: u16 in 0u16..100u16 {
//       if bull_bets_win && next_bull_bettors_index.get(true) < i  {
//         let bull_bettor: address = Mapping::get(id_to_bull_bettor, i);
//         let bull_bettor_amount: u64 = Mapping::get(bull_bets, bull_bettor);
//         total_winning_bets += bull_bettor_amount;
//       }
//       if !bull_bets_win && next_bear_bettors_index.get(true) < i  {
//         let bear_bettor: address = Mapping::get(id_to_bear_bettor, i);
//         let bear_bettor_amount: u64 = Mapping::get(bear_bets, bear_bettor);
//         total_winning_bets += bear_bettor_amount;
//       }
//    }

    // Look up how much claimant bet on the winning side.
    // Compiler limitation makes this pattern weird.

    let claimant_winning_bet: u64 =
       bull_bets_win ? Mapping::get_or_use(bull_bets, claimant, 0u64)
                     : Mapping::get_or_use(bear_bets, claimant, 0u64);

//    let claimant_winning_bet: u64 = 0u64;
//    if bull_bets_win {
//      claimant_winning_bet = Mapping::get_or_use(bull_bets, claimant, 0u64);
//    } else {
//      claimant_winning_bet = Mapping::get_or_use(bear_bets, claimant, 0u64);
//    }

    assert(claimant_winning_bet > 0u64);

    // MAYBE PROBLEM: credits.aleo doesn't have a function to get the public balance for a program.
    // Can we just refer to the mapping?
    let total_pool: u64 = Mapping::get(credits.aleo/account, self.address);

    // To make sure we get the most accurate payout, let's do the calculation
    // (<user's winning bet> * <pot of all bets>) / <sum of winning bets>
    // Since the total ALEO microcredits issued is around 10^51, if we want to keep the calculation
    // within u64 then the max bet can be about 10^13 microcredits, 10^12 to be safe.
    // That is 10^6 ALEO Credits, which is a lot but not impossible.
    // We could handle large bids here by casting to u128 for the intermediate values of the
    // computation but for now we restrict bids to be 10^12 microcredits.  (See above note.)
    let calculated_payout: u64 = (total_pool * claimant_winning_bet) / total_winning_bets;

    // Halt if the claimed amount was not correct.
    assert_eq(claimed_amount, calculated_payout);

    // If those checks pass, allow the transfer for the claim.
    transfer.await();

    // Record that this claimant has claimed their winnings.
    Mapping::set(already_claimed, claimant, true);
  }

} // program
