# Pit-A-Pat Rules Specification v1.0

## Overview

Pit-A-Pat is a traditional Caribbean-inspired shedding card game based on Pitty Pat, expanded with optional chain-building mechanics.

The objective is to be the first player to empty their hand and successfully call TAP before going out.

Pit-A-Pat is designed around:

* Fast turns
* Strategic card sequencing
* Hand management
* Player interaction
* Table talk and social play
* Optional advanced chain building

---

# Setup

## Players

* 2-4 players
* Human players or AI bots

## Deck

* Standard 52-card deck
* No Jokers

## Starting Hand

* Deal 5 cards to each player

## Starting Card

* Deal one card face-up to the centre of the table
* This becomes the Active Card

## Turn Order

* Play proceeds clockwise

---

# Core Objective

A player wins the hand by:

1. Emptying their hand
2. Correctly calling TAP before playing their final card(s)

Failure to TAP results in a penalty.

---

# Active Card

The Active Card is always the top visible card on the play pile.

The Active Card determines what may be played next.

Example:

Active Card:

J♥

Valid Matches:

* Any Jack
* Any Heart

Examples:

Valid:

J♣
J♦
J♠
2♥
8♥
K♥

Invalid:

4♣
9♠
K♦

---

# Standard Turn

A player's turn consists of:

1. Matching the Active Card
2. Optionally building a chain
3. Ending their turn

---

# Match Rule

The first card played must match the Active Card by:

* Rank
  OR
* Suit

Example:

Active Card:

J♥

Valid opening cards:

J♣
A♥
10♥
J♠

---

# Traditional Pitty Pat Flow

After making a valid match, a player may discard another card from their hand.

This second card becomes the new Active Card.

Example:

Active Card:

J♥

Player:

J♣
4♠

Play:

J♣
4♠

New Active Card:

4♠

---

# Pit-A-Pat Chain Rule

Instead of stopping after a single match and discard, a player may continue building a legal chain.

Each additional card must match the card immediately before it by:

* Rank
  OR
* Suit

Example:

Active Card:

J♥

Player plays:

J♣
J♦
J♠
4♠

Validation:

J♣ matches J♥ by rank ✓

J♦ matches J♣ by rank ✓

J♠ matches J♦ by rank ✓

4♠ matches J♠ by suit ✓

Chain valid.

New Active Card:

4♠

---

# Optional Chain Continuation

Players are not required to play the longest possible chain.

Example:

Hand:

J♣
J♦
J♠
4♠

Player may choose:

J♣
J♦
J♠

and stop.

New Active Card:

J♠

Strategic stopping points are encouraged.

---

# New Active Card

The final card played always becomes the new Active Card.

Examples:

Play:

J♣
J♦
J♠

New Active Card:

J♠

Play:

J♣
J♦
J♠
4♠

New Active Card:

4♠

---

# Passing

If a player cannot make a legal opening match, they must PASS.

---

# Draw Rule

If all players pass in sequence without a successful play:

Each player draws one card from the deck.
Play continues.
Consecutive pass counter resets.
Empty Deck

If the deck becomes empty:

The Active Card remains on the table.
All other cards in the play pile are collected.
The collected cards are shuffled to form a new deck.
Play then continues normally.

This process may occur multiple times during a hand.

The game should only enter stalemate resolution if:

No player can make a legal play, AND
No cards remain available to draw after reshuffling.

---

# TAP Rule

TAP is required before playing the final card or chain that would empty a player's hand.

Example:

Hand:

J♣
J♦
J♠
4♠

Player intends to play all four cards.

Before playing:

TAP

must be declared.

Then the chain is played.

Player wins.

---

# Failure To TAP

If a player empties their hand without first calling TAP:

* Player does not win
* One penalty card is drawn
* Play continues

Example:

Player forgets to TAP.

Hand becomes empty.

Draw one penalty card.

Remain in game.

---

# Winning

A player wins the hand when:

* Their hand becomes empty
* TAP was declared correctly

---

# Optional House Rules (Future)

These rules are disabled by default.

## 2s - Draw Two

Playing a 2 causes the next player to draw two cards.

Optional stacking:

2 + 2 = Draw Four

---

## 8s - Skip

Playing an 8 skips the next player's turn.

---

## Reverse Direction

Optional variant.

Playing specific cards reverses turn order.

Disabled by default.

---

# Digital Interaction Rules

## Selecting Cards

* Click card to select
* Selected cards lift slightly
* Selected cards glow

## Building Chains

* Players may select multiple cards
* Order matters

## Playing Cards

* Drag selected stack
* Drop onto Active Card pile

## Validation

* First card must match Active Card by rank OR suit
* Each subsequent card must match previous card by rank OR suit

## Result

* Valid stack plays
* Invalid stack snaps back

## New Active Card

* Final card in the played stack becomes Active Card

---

# Design Philosophy

Pit-A-Pat should feel:

* Fast
* Social
* Strategic
* Easy to learn
* Difficult to master

Traditional Pitty Pat remains the foundation.

Chain building provides additional strategic depth without replacing the original game.

## TAP Philosophy

TAP is intentionally retained because it creates player signalling.

Calling TAP publicly announces that a player intends to leave the game.

This creates a social and strategic layer where opponents may attempt to:

- force draws
- skip turns
- alter the active card
- disrupt planned chains

The resulting table interaction is a core part of the Pit-A-Pat experience.

The tension between announcing victory and successfully achieving it is a feature, not a flaw.