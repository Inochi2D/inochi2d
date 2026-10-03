/**
    Macro Node Graph

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.ctrl.node;
import inochi2d.ctrl.iface;
import nulib.quark;
import nulib;
import numem;

/**
    A connection between one node and another.
*/
struct NodeConnection {
@nogc nothrow:

    /**
        The port that is connected to the target.
    */
    quark outport;

    /**
        Target of the connection.
    */
    MacroNode target;

    /**
        The input port connected.
    */
    quark inport;
}

/**
    A node in the macro tree.
*/
abstract
class MacroNode : NuRefCounted {
private:
@nogc:
    static
    struct MacroRef {
        MacroNode target;
        ptrdiff_t refs;
    }

    nstring name_;
    vector!NodeConnection connections_;
    vector!MacroRef targets_;
    vector!MacroRef sources_;

    // Helper that finds a target macro node in the targets
    // list.
    ptrdiff_t findTarget(MacroNode target) {
        foreach(i, t; targets_)
            if (t.target is target)
                return i;
        return -1;
    }

    // Helper that finds a target macro node in the sources
    // list.
    ptrdiff_t findSource(MacroNode source) {
        foreach(i, t; sources_)
            if (t.target is target)
                return i;
        return -1;
    }

    // Helper that adds an internal reference to the
    // given target.
    void retainTargetRef(MacroNode target) {
        ptrdiff_t idx = findTarget(target);
        if (idx >= 0) {
            targets_[idx].refs++;

            ptrdiff_t sidx = target.findSource(this);
            assert(sidx >= 0, "Source and target lists desynced!");
            target.sources_[sidx].refs++;
            return;
        }

        targets_ ~= MacroRef(target.retained, 1);
        target.sources_ ~= MacroRef(this, 1);
    }

    void releaseTargetRef(MacroNode target) {
        ptrdiff_t idx = findTarget(target);
        if (idx >= 0) {
            targets_[idx].refs--;

            ptrdiff_t sidx = target.findSource(this);
            assert(sidx >= 0, "Source and target lists desynced!");
            target.sources_[sidx].refs--;
            if (target.sources_[sidx].refs <= 0)
                target.sources_.removeAt(sidx);

            if (targets_[idx].refs <= 0) {
                targets_.removeAt(idx);
                target.release();
            }
        }
    }

protected:

    /**
        Callback executed when the node is to run a update cycle.
    
        Params:
            delta = Time since last frame.
    */
    void onUpdate(float delta) {
    }

public:

    /**
        Connections between this node and others.
    */
    @property NodeConnection[] connections() nothrow pure => connections_[];

    /**
        Name of the node.
    */
    @property string name() => name_[];

    /**
        Gets whether the given node has an output port with a given
        port name.

        Params:
            port = The port to query.

        Returns:
            $(D true) if the node has a given output port,
            $(D false) otherwise.
    */
    bool hasOutput(quark port) { return false; }

    /**
        Gets whether the given node has an input port with a given
        port name.

        Params:
            port = The port to query.

        Returns:
            $(D true) if the node has a given input port,
            $(D false) otherwise.
    */
    bool hasInput(quark port) { return false; }

    /**
        Gets whether this node is connected to the
        given node.

        Params:
            node = The node to query connection with.

        Returns:
            $(D true) if this node is in any way connected 
            to $(D node), $(D false) otherwise.
    */
    bool isConnectedTo(MacroNode node) {
        return 
            this.findSource(node) != -1 || 
            this.findTarget(node) != -1;
    }

    /**
        Try to connect this node to another node's port.

        Params:
            srcport =   The source port to connect.
            target =    The node to connect to.
            port =      The port to connect to.

        Returns:
            $(D true) if the operation succeeded,
            $(D false) otherwise.
    */
    bool tryConnect(quark srcport, MacroNode target, quark port) {
        
        // Invalid output.
        if (!this.hasOutput(srcport))
            return false;
        
        // Invalid input.
        if (!target.hasInput(port))
            return false;

        // Circular connections are not allowed!
        if (target.isCircularConnection(this))
            return false;

        // Ensure we don't connect to the same port multiple times.
        // in this case the connection succeeded, but because it
        // already was connected.
        NodeConnection toCreate = NodeConnection(srcport, target, port);
        if (connections_.find(toCreate) != -1)
            return true;

        // We also keep a list of targets to update after ourselves,
        // so if we don't already have said target, add it.
        this.retainTargetRef(target);
        this.connections_ ~= toCreate;
        return true;
    }

    /**
        Try to disconnect this node from another node's
        input port.

        Params:
            target =    The node to disconnect from.
            port =      The port to disconnect from.
    */
    bool tryDisconnect(MacroNode target, quark port) {
        foreach(i, NodeConnection conn; connections_) {
            if (conn.target is target && conn.inport == port) {
                connections_.removeAt(i);
                this.releaseTargetRef(target);
                return true;
            }
        }
        return false;
    }

    /**
        Updates the node and all of the targets it controls.
    
        Params:
            delta = Time since last frame.
    */
    void update(float delta) {
        this.onUpdate(delta);
        foreach(target; targets_)
            target.target.update(delta);
    }
}

/**
    Gets whether a connection from the given 2 nodes would be circular.

    Params:
        from =  The source node
        to =    The destination node.
*/
bool isCircularConnection(MacroNode from, MacroNode to) @nogc nothrow pure {
    foreach(conn; to.connections) {
        if (conn.target is from)
            return true;

        // If the given node has any output connections, check those
        // recursively.
        if (conn.target.connections.length > 0)
            return isCircularConnection(from, conn.target);
    }
    return false;
}

/**
    A generator which produces an output value that can be passed
    onto other nodes in the graph.
*/
abstract
class GeneratorNode : MacroNode, IMacroSource {
public:

    /**
        Names of the output ports to the macro.
    */
    abstract @property quark[] outputs() nothrow pure;

    /**
        Gets the value of the given output port.

        Params:
            name = The name of the port to get the value from.

        Returns:
            The floating point value in the port on success,
            $(D NaN) on failure.
    */
    abstract float getValue(quark name) nothrow;
}

/**
    A node which presents a control to the end user.
    These cannot be controlled by other graph nodes.
*/
abstract
class ControlNode : MacroNode, IMacroSource {
public:

    /**
        Names of the output ports to the macro.
    */
    abstract @property quark[] outputs() nothrow pure;

    /**
        Gets the value of the given output port.

        Params:
            name = The name of the port to get the value from.

        Returns:
            The floating point value in the port on success,
            $(D NaN) on failure.
    */
    abstract float getValue(quark name) nothrow;
}