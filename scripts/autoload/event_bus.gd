extends Node
## Autoload. Combat events, so UI and juice can react without gameplay knowing they exist.

## A ship took a hit. [param result] says what each layer absorbed.
signal ship_hit(ship: Node, result: DamageResult)
signal ship_destroyed(ship: Node, source: Node)
signal weapon_fired(ship: Node, weapon: WeaponData)
## A boss ship has just entered its next phase.
signal phase_started(ship: Node, phase: PhaseData)
## A fighter bay launched its fighters.
signal fighters_launched(ship: Node, bay: FighterBayData)
signal active_used(ship: Node, item: ItemData)
## A ship's shield just went from up to 0. Its hull is exposed for a moment (HealthComponent).
signal shield_broken(ship: Node)
