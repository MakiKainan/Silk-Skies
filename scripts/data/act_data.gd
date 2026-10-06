class_name ActData
extends Resource
## An ordered run of encounters. The slice's act is brawler, sniper, mini-boss.

@export var id: StringName
@export var display_name: String = ""
@export var encounters: Array[EnemyData] = []
