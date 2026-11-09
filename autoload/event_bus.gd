extends Node
## Global signal hub. Systems communicate through these signals instead of
## referencing each other directly.

# Time
signal minute_changed(day: int, minute_of_day: int)
signal phase_changed(phase: int)
signal day_started(day: int)
signal night_started(night_index: int)

# World
signal gates_changed(open: bool)

# Players
signal player_spawned(player: Node)
signal player_despawned(peer_id: int)
## A companion fell (its GameState.companions record, now downed).
signal companion_downed(record: Dictionary)
## A player slept through the night in a bed (the screen fades in from black).
signal slept

# UI
signal notify(text: String)
## Compact bottom-right item feed ("drop" = items thrown away).
signal item_feed(verb: String, id: String, count: int)
## E on a crafting station: opens its recipe book ("" = close the book).
signal station_used(station: String)
## E on an empty farm plot: the seed picker opens for it.
signal farm_plot_used(plot: Node)
signal chest_used
## E on a waystone: the travel picker opens.
signal waystone_used(stone: Node)
## A Skill Altar was used: the skill graph opens with the respec offer.
signal altar_used(altar: Node)
## Survivors joined, left or changed roles.
signal settlement_changed
## E on a survivor (opens the settlement panel).
signal survivor_talked(survivor: Node)
