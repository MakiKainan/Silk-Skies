class_name DuelResult
extends RefCounted
## How one duel ended.

var won: bool = false
var enemy: EnemyData
var seconds: float = 0.0
## Shield + hull points the player took off the enemy / the enemy took off the player.
var damage_dealt: float = 0.0
var damage_taken: float = 0.0
