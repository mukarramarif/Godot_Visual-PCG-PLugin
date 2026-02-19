
## For Future use, this file will contain all the different node types for the visual scripting system.
## For now, it will only contain the wave function collapse node.
extends Node

func createPCGNode(type: String)->GraphNode:
	var node: GraphNode
	match type:
		"WAVE_FUNC_COLLAPSE":
			node = createWaveFuncNode()
	return node
func createWaveFuncNode():
	return Node
