extends Node

func createPCGNode(type: String)->GraphNode:
	var node: GraphNode
	match type:
		"WAVE_FUNC_COLLAPSE":
			node = createWaveFuncNode()
	return node	
func createWaveFuncNode():
	return Node
