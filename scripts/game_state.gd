extends Node
## Progress tracker for one playthrough. Registered as the autoload "GameState",
## so any script can call it directly, e.g. GameState.give_ability(GameState.HOOK).
## Lives across room changes. Call new_game() to reset (title screen / restart).
##
## Progression:
##   Area 1 as the Regular Guy: find the hook -> crossbow -> tether.
##   Beat the Chupacabra boss -> Chupacabra form.  Beat the Wendigo boss -> Wendigo form.
##   Final boss -> choose: Kill (Bad ending) / Spare (True ending),
##   plus "Break the curse" (Good ending) only if you found every collectible.
##
## Debug keys (editor runs only, never in exported builds):
##   F1  unlock every form and ability     F2  print the current state

signal form_unlocked(index: int)
signal ability_gained(ability: String)
signal boss_defeated(boss: String)
signal collectible_found(id: String, found: int, total: int)
signal checkpoint_set(room: String, position: Vector2)
signal ending_chosen(ending: Ending)

# Forms (same order as the player's forms list)
const REGULAR := 0
const WENDIGO := 1
const CHUPACABRA := 2

# Regular Guy abilities, found in area 1
const HOOK := "hook"           # swing from grapple points
const CROSSBOW := "crossbow"   # shoot (tap / charged bolts)
const TETHER := "tether"       # pull yourself to an enemy

# Bosses, and the form each one gives you
const BOSS_CHUPACABRA := "chupacabra"
const BOSS_WENDIGO := "wendigo"
const BOSS_FINAL := "final"
const BOSS_REWARDS := {BOSS_CHUPACABRA: CHUPACABRA, BOSS_WENDIGO: WENDIGO}

enum Ending { NONE, BAD, TRUE, GOOD }
enum Choice { KILL, SPARE, BREAK_CURSE }

## How many collectibles exist in the whole game. Update when the map is built.
const TOTAL_COLLECTIBLES := 5

var unlocked: Array[bool] = []
var abilities := {}                 # ability name -> true
var bosses := {}                    # boss name -> true once defeated
var collected := {}                 # collectible id -> true
var ending := Ending.NONE
var checkpoint_room := ""           # scene path of the room with the last checkpoint
var checkpoint_position := Vector2.ZERO


func _ready() -> void:
	new_game()


func new_game() -> void:
	unlocked = [true, false, false]   # you wake up as the Regular Guy, with nothing
	abilities.clear()
	bosses.clear()
	collected.clear()
	ending = Ending.NONE
	checkpoint_room = ""
	checkpoint_position = Vector2.ZERO


# ---------------------------------------------------------------- forms

func is_unlocked(index: int) -> bool:
	return index >= 0 and index < unlocked.size() and unlocked[index]


func unlock_form(index: int) -> void:
	if is_unlocked(index):
		return
	while unlocked.size() <= index:
		unlocked.append(false)
	unlocked[index] = true
	form_unlocked.emit(index)


# ---------------------------------------------------------------- abilities

func has_ability(ability: String) -> bool:
	return abilities.has(ability)


func give_ability(ability: String) -> void:
	if has_ability(ability):
		return
	abilities[ability] = true
	ability_gained.emit(ability)


# ---------------------------------------------------------------- bosses

## Call when a boss dies. Chupacabra and Wendigo bosses unlock their form.
func defeat_boss(boss: String) -> void:
	if bosses.has(boss):
		return
	bosses[boss] = true
	boss_defeated.emit(boss)
	if BOSS_REWARDS.has(boss):
		unlock_form(BOSS_REWARDS[boss])


func is_boss_defeated(boss: String) -> bool:
	return bosses.has(boss)


# ---------------------------------------------------------------- collectibles

## Returns false if it was already collected.
func collect(id: String) -> bool:
	if collected.has(id):
		return false
	collected[id] = true
	collectible_found.emit(id, found_count(), TOTAL_COLLECTIBLES)
	return true


func is_collected(id: String) -> bool:
	return collected.has(id)


func found_count() -> int:
	return collected.size()


func has_all_collectibles() -> bool:
	return found_count() >= TOTAL_COLLECTIBLES


# ---------------------------------------------------------------- checkpoints

func set_checkpoint(room: String, pos: Vector2) -> void:
	checkpoint_room = room
	checkpoint_position = pos
	checkpoint_set.emit(room, pos)


func has_checkpoint() -> bool:
	return checkpoint_room != ""


# ---------------------------------------------------------------- final choice + endings

## What the final-boss menu offers. "Break the curse" only appears with every collectible.
func available_choices() -> Array[Choice]:
	var choices: Array[Choice] = [Choice.KILL, Choice.SPARE]
	if has_all_collectibles():
		choices.append(Choice.BREAK_CURSE)
	return choices


## Kill -> Bad (the amalgamation takes him over). Spare -> True (stays a shapeshifter, becomes a legend).
## Break the curse -> Good (becomes human).
func choose(choice: Choice) -> Ending:
	match choice:
		Choice.KILL:
			ending = Ending.BAD
		Choice.SPARE:
			ending = Ending.TRUE
		Choice.BREAK_CURSE:
			ending = Ending.GOOD if has_all_collectibles() else Ending.TRUE
	defeat_boss(BOSS_FINAL)
	ending_chosen.emit(ending)
	return ending


# ---------------------------------------------------------------- debug

func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F1:
			for i in 3:
				unlock_form(i)
			for a in [HOOK, CROSSBOW, TETHER]:
				give_ability(a)
			print("[GameState] all forms and abilities unlocked")
		KEY_F2:
			print("[GameState] forms=%s abilities=%s bosses=%s collected=%d/%d %s checkpoint=%s @ %s choices=%s ending=%s" % [
				unlocked, abilities.keys(), bosses.keys(), found_count(), TOTAL_COLLECTIBLES, collected.keys(),
				checkpoint_room, checkpoint_position,
				available_choices().map(func(c: Choice) -> String: return Choice.keys()[c]),
				Ending.keys()[ending]])
