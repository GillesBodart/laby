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

# UI
signal notify(text: String)
## E on a crafting station: opens its recipe book ("" = close the book).
signal station_used(station: String)
## E on an empty farm plot: the seed picker opens for it.
signal farm_plot_used(plot: Node)
