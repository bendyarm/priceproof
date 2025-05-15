import credits.aleo;
program price_proof_test_11.aleo;

mapping market_state:
    key as address.public;
    value as u8.public;

mapping bet_price_threshold:
    key as boolean.public;
    value as u64.public;

mapping bull_bets:
    key as address.public;
    value as u64.public;

mapping bear_bets:
    key as address.public;
    value as u64.public;

mapping id_to_bull_bettor:
    key as u16.public;
    value as address.public;

mapping next_bull_bettors_index:
    key as boolean.public;
    value as u16.public;

mapping id_to_bear_bettor:
    key as u16.public;
    value as address.public;

mapping next_bear_bettors_index:
    key as boolean.public;
    value as u16.public;

function initialize_market:
    input r0 as u64.private;
    assert.eq self.signer aleo1utnfugwpu6ac8z0dp90mlulvrgf768984huy7gwfcr0676hfmv9qwxkl9n;
    call credits.aleo/transfer_public_as_signer price_proof_test_11.aleo 1000000u64 into r1;
    async initialize_market r0 r1 into r2;
    output r2 as price_proof_test_11.aleo/initialize_market.future;

finalize initialize_market:
    input r0 as u64.public;
    input r1 as credits.aleo/transfer_public_as_signer.future;
    get.or_use market_state[aleo1utnfugwpu6ac8z0dp90mlulvrgf768984huy7gwfcr0676hfmv9qwxkl9n] 0u8 into r2;
    assert.eq r2 0u8;
    set 1u8 into market_state[aleo1utnfugwpu6ac8z0dp90mlulvrgf768984huy7gwfcr0676hfmv9qwxkl9n];
    set r0 into bet_price_threshold[true];
    set 0u16 into next_bull_bettors_index[true];
    set 0u16 into next_bear_bettors_index[true];
    await r1;

function place_bet:
    input r0 as u64.private;
    input r1 as boolean.private;
    call credits.aleo/transfer_public_as_signer price_proof_test_11.aleo r0 into r2;
    async place_bet self.signer r1 r0 r2 into r3;
    output r3 as price_proof_test_11.aleo/place_bet.future;

finalize place_bet:
    input r0 as address.public;
    input r1 as boolean.public;
    input r2 as u64.public;
    input r3 as credits.aleo/transfer_public_as_signer.future;
    get.or_use market_state[aleo1utnfugwpu6ac8z0dp90mlulvrgf768984huy7gwfcr0676hfmv9qwxkl9n] 0u8 into r4;
    assert.eq r4 1u8;
    branch.eq r1 false to end_then_0_0;
    contains bull_bets[r0] into r5;
    get next_bull_bettors_index[true] into r6;
    lt r6 100u16 into r7;
    or r5 r7 into r8;
    assert.eq r8 true;
    get.or_use bull_bets[r0] 0u64 into r9;
    add r9 r2 into r10;
    set r10 into bull_bets[r0];
    not r5 into r11;
    branch.eq r11 false to end_then_1_2;
    get next_bull_bettors_index[true] into r12;
    contains id_to_bull_bettor[r12] into r13;
    not r13 into r14;
    assert.eq r14 true;
    set r0 into id_to_bull_bettor[r12];
    add r12 1u16 into r15;
    set r15 into next_bull_bettors_index[true];
    branch.eq true true to end_otherwise_1_3;
    position end_then_1_2;
    position end_otherwise_1_3;
    branch.eq true true to end_otherwise_0_1;
    position end_then_0_0;
    contains bear_bets[r0] into r16;
    get next_bear_bettors_index[true] into r17;
    lt r17 100u16 into r18;
    or r16 r18 into r19;
    assert.eq r19 true;
    get.or_use bear_bets[r0] 0u64 into r20;
    add r20 r2 into r21;
    set r21 into bear_bets[r0];
    not r16 into r22;
    branch.eq r22 false to end_then_1_4;
    get next_bear_bettors_index[true] into r23;
    contains id_to_bear_bettor[r23] into r24;
    not r24 into r25;
    assert.eq r25 true;
    set r0 into id_to_bear_bettor[r23];
    add r23 1u16 into r26;
    set r26 into next_bear_bettors_index[true];
    branch.eq true true to end_otherwise_1_5;
    position end_then_1_4;
    position end_otherwise_1_5;
    position end_otherwise_0_1;
    await r3;
