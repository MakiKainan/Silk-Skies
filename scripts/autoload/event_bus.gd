extends Node
## Autoload. Combat events, so UI and juice can react without gameplay knowing they exist.

## A ship took a hit. [param result] says what each layer absorbed.
signal ship_hit(ship: Node, result: DamageResult)
signal ship_destroyed(ship: Node, source: Node)
signal weapon_fired(ship: Node, weapon: WeaponData)
## A boss ship has just entered its next phase.
signal phase_started(ship: Node, phase: PhaseData)
