class_name TechmodData
extends ItemData
## A passive ship module; some also grant an active ability.


func slot_type() -> HardpointData.Type:
	return HardpointData.Type.TECHMOD


func category_name() -> String:
	return "Techmod"
