# Truco Card Game - Godot Project

## Project Overview

This is a Godot 4.5 project implementing the traditional Argentine Truco card game. Truco is a popular 2-player vs 2-player partnership card game played with a Spanish deck of 40 cards (excluding 8s and 9s). The project is written in GDScript and includes game logic, player management, card hierarchy, and scoring systems for the Truco game.

The main features implemented include:
- 4-player game (2 vs 2 teams)
- Complete Spanish deck implementation with proper Truco card hierarchy
- Envido scoring system
- Truco/Retruco/Vale Cuatro mechanics
- Basic UI for game visualization
- Player management (human and AI players)

## Project Structure

```
├── project.godot              # Godot project configuration
├── TrucoMain.gd              # Main game scene script
├── truco_room.tscn           # 3D game room scene
├── scenes/
│   └── main.tscn             # Main UI scene
├── scripts/
│   ├── TrucoGame.gd          # Core game logic
│   ├── Player.gd             # Player management
│   ├── Card.gd               # Card implementation with hierarchy
│   └── Deck.gd               # Deck management
└── textures/                 # Card textures and other assets
```

## Core Components

### TrucoGame.gd
The main game controller that manages:
- Player setup and teams
- Deck management and dealing
- Game state transitions (playing hand, envido, truco, game over)
- Scoring system
- Truco call mechanics

### Card.gd
Implements the Spanish deck cards with proper Truco hierarchy:
- 4 suits: ORO, COPA, ESPADA, BASTO
- 12 values: 1, 2, 3, 4, 5, 6, 7, 10, 11, 12 (8s and 9s are removed)
- Special Truco hierarchy: 1 Espada (strongest), 1 Basto, 7 Espada, 7 Oro, etc.
- Envido calculation logic

### Player.gd
Represents individual players with:
- Hand management
- Team assignment (0 or 1)
- Partnership tracking
- Envido calculation from hand

### Deck.gd
Manages a 40-card Spanish deck with:
- Card creation
- Shuffling
- Drawing mechanics

## Game Mechanics

### Card Hierarchy
In Argentine Truco, cards have a specific hierarchy:
1. 1 of Spades (1 de Espada) (12 points)
2. 1 of Clubs/Basto (1 de Basto) (11 points) 
3. 7 of Spades (7 de Espada) (10 points)
4. 7 of Golds (7 de Oros) (9 points)
5. All 3s (3 de Espada, 3 de Basto, 3 de Oros, 3 de Copas) (8 points)
6. All 2s (2 de Espada, 2 de Basto, 2 de Oros, 2 de Copas) (7 points)
7. 1 of Cups (1 de Copas) (6 points)
8. 1 of Golds (1 de Oros) (5 points)
9. All 12s (12 de Espada, 12 de Basto, 12 de Oros, 12 de Copas) (4 points)
10. All 11s (11 de Espada, 11 de Basto, 11 de Oros, 11 de Copas) (3 points)
11. All 10s (10 de Espada, 10 de Basto, 10 de Oros, 10 de Copas) (2 points)
12. 7 of Cups (7 de Copas) (1 point)
13. 7 of Clubs/Basto (7 de Basto) (0 points)
14. All 6s (6 de Espada, 6 de Basto, 6 de Oros, 6 de Copas) (0 points) - highest of low cards
15. All 5s (5 de Espada, 5 de Basto, 5 de Oros, 5 de Copas) (-1 points) - middle of low cards
16. All 4s (4 de Espada, 4 de Basto, 4 de Oros, 4 de Copas) (-2 points) - lowest of low cards

### Envido Scoring
The game calculates envido scores based on:
- Same suit cards (20 + highest 2 envido values)
- Mixed suits with envido cards (20 + highest envido value)
- Two or more non-envido cards (20 points)

### Truco Mechanics
The game implements:
- Truco calling and state management
- Retruco and Vale Cuatro
- Accept/reject logic for truco challenges

## Building and Running

To run this project:
1. Open the project in Godot 4.5 editor
2. The main scene is set to `res://scenes/main.tscn` in project.godot
3. Press F5 or click "Play" to run the game

The project uses Godot's native build system. For deployment, Godot's export system can be used to create executables for different platforms.

## Development Conventions

- GDScript is used for all game logic
- The project follows Godot's object-oriented structure with Resource-based classes
- Spanish language is used for UI labels and game logic (with English comments)
- The game state is managed with enums for better readability
- Proper encapsulation with private methods (prefixed with `_`) and public methods

## Current State

The project includes a functional implementation of Truco with:
- Basic UI showing deck count, players and hands, and game state
- Test controls for starting new hands and showing player cards
- Complete card hierarchy implementation
- Team scoring system
- Basic truco mechanics

The 3D scene (`truco_room.tscn`) appears to be a visual representation of a card table, though the UI is primarily handled in the 2D canvas layers.