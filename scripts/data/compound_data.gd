class_name CompoundData
extends Resource
## Compound recipe (B8): two materials with minimum Ranks -> one Rank 1 result.

@export var id: StringName = &""
@export var material_a: StringName = &""
@export var material_a_min_rank: int = 1
@export var material_b: StringName = &""
@export var material_b_min_rank: int = 1
@export var result: StringName = &""


func validate() -> Array[String]:
	var errors: Array[String] = []
	if material_a == material_b or result in [material_a, material_b]:
		errors.append("compound %s: cyclic or duplicate recipe" % id)
	if material_a_min_rank < 1 or material_b_min_rank < 1:
		errors.append("compound %s: min ranks must be >= 1" % id)
	return errors
