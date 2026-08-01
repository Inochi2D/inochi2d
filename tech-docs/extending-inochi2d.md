# Extending Inochi2D

Inochi2D is built to allow extensions to the file format, extensions can either be written as
seperate libraries loaded in, or by using Inochi2D as a static library, then rexporting Inochi2D
symbols.

## Adding new types.

To add new types to Inochi2D you must create a subclass in D, then register the type with Inochi2D
in the appropriate type registry. The type registries are strongly typed and you must follow the 
protocol of the base type of each registry.

The following code will create a new node type and register it with Inochi2D
when the library is loaded and C runtime initialisers are executed:

```d
module myextension;
import inochi2d;
import numem;

// NOTE: IDs 0x00000000 to 0x0000FFFF are reserved by Inochi2D.
//		 new nodes should be registered in the range
//       0x00010000-0xFFFF0000
@TypeId("MyNode", 0x000100000)
class MyNode : Node {
protected:
@nogc:

    /**
        Deserializes this node from a DataNode.

        Params:
            object =    The DataNode to deserialize from.
            state =     The state of the deserializer.
    */
    override
    void onDeserialize(ref DataNode object, ref ModelState state) {
        super.onDeserialize(object, state);

        state.info("MyNode loaded!");
    }

public:
	
	/// Destructor
     ~this() { }

    /**
        Constructs a new MeshGroup node
    */
    this(Node parent = null) {
        super(parent);
    }

}
mixin Register!(MyNode, in_node_registry);
```