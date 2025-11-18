# AI Technical Context

This document provides deep technical context for the Truco project. It is intended to be read by AI agents to understand the architecture, state management, and specific game logic implementations.

## Architecture Overview

The project follows a standard Godot 4 architecture with a mix of 2D UI and 3D visualization.

- **Main Scene**: `scenes/main.tscn` (UI-focused) or `TrucoMain.gd`.
- **Game Logic**: Encapsulated in `scripts/TrucoGame.gd`.
- **Data Models**:
  - `Card` (`scripts/Card.gd`): Resource-based. Handles value, suit, and Truco/Envido calculations.
  - `Player` (`scripts/Player.gd`): Manages hand, team, and state.
  - `Deck` (`scripts/Deck.gd`): Manages the collection of Cards.

## State Management

The game likely uses a state machine or enum-based state in `TrucoGame.gd`.
*Note: Verify exact state implementation in `TrucoGame.gd`.*

Common states in Truco:
- `DEALING`: Distributing cards.
- `ENVIDO_BIDDING`: Players bidding on Envido points.
- `PLAYING_HAND`: Standard trick-taking phase.
- `TRUCO_BIDDING`: Negotiating Truco stakes.
- `SCORING`: End of round calculation.

## Game Logic Details

### Card Hierarchy & Values
Defined in `scripts/Card.gd`.
- **Truco Value**: Used for comparing cards in a trick. Higher is better.
  - 1 Espada > 1 Basto > 7 Espada > 7 Oro > 3s > 2s > 1s > 12s > 11s > 10s > 7s (others) > 6s > 5s > 4s.
- **Envido Value**: Used for scoring points.
  - Logic: If same suit, 20 + sum of values (face cards 10/11/12 count as 0).
  - If different suit, highest single value.

### Teams
- 2 vs 2 (or 1 vs 1).
- Teams are usually Team 0 and Team 1.
- Points are tracked globally per team.

## Asset Structure
- `textures/`: Contains card sprites. Naming convention likely follows `suit_value.png` or similar.
- `scenes/`: Reusable components (e.g., `Card.tscn`, `PlayerArea.tscn`).

## Common Tasks for AI
1. **Adding a new rule**: Check `TrucoGame.gd` state logic.
2. **Modifying card logic**: Check `Card.gd`.
3. **UI Updates**: Check `scenes/main.tscn` and connected signals.
