import std.functional;
import core.memory, core.stdc.stdlib, core.stdc.string, std.algorithm,
    std.conv, std.exception, std.functional, std.range, std.traits,
    std.typecons, std.typetuple;
import std.stdio;
import std.datetime;
import core.memory;

//debug = RB_ROTATION;
//debug = RB_ADD;

/*
void swap(T)(ref T a, ref T b) {
	auto t = a;
	a = b;
	b = t;
}
*/


/*
 * Implementation for a Red Black node for use in a Red Black Tree (see below)
 *
 * this implementation assumes we have a marker Node that is the parent of the
 * root Node.  This marker Node is not a valid Node, but marks the end of the
 * collection.  The root is the left child of the marker Node, so it is always
 * last in the collection.  The marker Node is passed in to the setColor
 * function, and the Node which has this Node as its parent is assumed to be
 * the root Node.
 *
 * A Red Black tree should have O(lg(n)) insertion, removal, and search time.
 */
struct RBNode(V, bool hasStats)
{
    /*
     * Convenience alias
     */
    alias RBNode!(V, hasStats)* Node;

    public Node _left;
    public Node _right;
    public Node _parent;
	
	static if (hasStats) {
		int childCountLeft;
		int childCountRight;
	}
	
	Node root() {
		auto it = &this;
		while (it._parent) it = it._parent;
		return it._left;
	}
	
	static if (hasStats) {
		void updateCurrentAndAncestors(int countIncrement) {
			auto prev = &this;
			auto it = this.parent;
			while (it) {
				if (it.left is prev) it.childCountLeft += countIncrement;
				else if (it.right is prev) it.childCountRight += countIncrement;
				prev = it;
				it = it.parent;
			}
		}
	}
	
	string toString() {
		static if (hasStats) {
			return std.string.format(
				"RBNode(value=%s, childCountLeft=%d, childCountRight=%d, color=%s, left=%s, right=%s)",
				value,
				childCountLeft,
				childCountRight,
				to!string(color),
				_left,
				_right
			);
		} else {
			return std.string.format(
				"RBNode(value=%s, color=%s, left=%s, right=%s)",
				value,
				to!string(color),
				_left,
				_right
			);
		}
	}

	void printTree(Node _this = null, int level = 0, string label = "L") {
		for (int n = 0; n < level; n++) writef("  ");
		string info;
		if (_this == &this) info = " (this)";
		/*
		if (_this.parent == &this) info = " (parent)";
		if (_this._left == &this) info = " (left)";
		if (_this._right == &this) info = " (right)";
		*/
		writefln("- %s:%s%s", label, this, info);
		if (_left || _right) {
			if (_left) {
				_left.printTree(_this, level + 1, "L");
			}
			if (_right) {
				_right.printTree(_this, level + 1, "R");
			}
		}
	}

    /**
     * The value held by this node
     */
    V value;

    /**
     * Enumeration determining what color the node is.  Null nodes are assumed
     * to be black.
     */
    enum Color : byte
    {
        Red,
        Black
    }

    /**
     * The color of the node.
     */
    Color color;

    /**
     * Get the left child
     */
    @property Node left()
    {
        return _left;
    }

    /**
     * Get the right child
     */
    @property Node right()
    {
        return _right;
    }

    /**
     * Get the parent
     */
    @property Node parent()
    {
        return _parent;
    }

    /**
     * Set the left child.  Also updates the new child's parent node.  This
     * does not update the previous child.
     *
     * Returns newNode
     */
    @property Node left(Node newNode)
    {
        _left = newNode;
        if(newNode !is null)
            newNode._parent = &this;
        return newNode;
    }

    /**
     * Set the right child.  Also updates the new child's parent node.  This
     * does not update the previous child.
     *
     * Returns newNode
     */
    @property Node right(Node newNode)
    {
        _right = newNode;
        if(newNode !is null)
            newNode._parent = &this;
        return newNode;
    }

    // assume _left is not null
    //
    // performs rotate-right operation, where this is T, _right is R, _left is
    // L, _parent is P:
    //
    //      P         P
    //      |   ->    |
    //      T         L
    //     / \       / \
    //    L   R     a   T
    //   / \           / \
    //  a   b         b   R
    //
    /**
     * Rotate right.  This performs the following operations:
     *  - The left child becomes the parent of this node.
     *  - This node becomes the new parent's right child.
     *  - The old right child of the new parent becomes the left child of this
     *    node.
     */
    Node rotateR()
    in
    {
        assert(_left !is null);
    }
    body
    {
    	debug (RB_ROTATION) {
			//writefln("rotateR (this=%s)", this);
			//writefln("rotateR (left=%s)", *_left);
			//writefln("rotateR (parent=%s)", *parent);
			writefln("- BEFORE ---------------------------------------------------");
			root.printTree(&this);
		}
	
        // sets _left._parent also
        if (this.isLeftNode) {
            parent.left = this._left;
			//if (_left !is null) _left.childCount = childCount;
        } else {
            parent.right = this._left;
			//if (_right !is null) _right.childCount = childCount;
		}
        
        //this.childCountRight = this._left.childCountLeft;
        //_left.childCountLeft = this.childCountLeft + this.childCountRight + 1;
        static if (hasStats) {
	        this.childCountLeft = this._left.childCountRight;
	        _left.childCountRight = this.childCountLeft + this.childCountRight + 1;
		} 
        
        Node tmp = _left._right;

        // sets _parent also
        _left.right = &this;
		//_left.right.childCount -= this.childCount;

        // sets tmp._parent also
        left = tmp;

		debug (RB_ROTATION) {
			writefln("- AFTER ----------------------------------------------------");
			root.printTree(&this);
			writefln("- ////// ---------------------------------------------------");
		}

        return &this;
    }

    // assumes _right is non null
    //
    // performs rotate-left operation, where this is T, _right is R, _left is
    // L, _parent is P:
    //
    //      P           P
    //      |    ->     |
    //      T           R
    //     / \         / \
    //    L   R       T   b
    //       / \     / \
    //      a   b   L   a
    //
    /**
     * Rotate left.  This performs the following operations:
     *  - The right child becomes the parent of this node.
     *  - This node becomes the new parent's left child.
     *  - The old left child of the new parent becomes the right child of this
     *    node.
     */
    Node rotateL()
    in
    {
        assert(_right !is null);
    }
    body
    {
    	debug (RB_ROTATION) {
			writefln("rotateL");
			writefln("- BEFORE ---------------------------------------------------");
			root.printTree();
		}
	
        // sets _right._parent also
        if(isLeftNode)
            parent.left = _right;
        else
            parent.right = _right;
        Node tmp = _right._left;

		static if (hasStats) {        
	        this.childCountRight = this._right.childCountLeft;
	        _right.childCountLeft = this.childCountLeft + this.childCountRight + 1;
		} 

        // sets _parent also
        _right.left = &this;

        // sets tmp._parent also
        right = tmp;
		
		debug (RB_ROTATION) {
			writefln("- AFTER ----------------------------------------------------");
			root.printTree();
			writefln("- ////// ---------------------------------------------------");
		}

        return &this;
    }


    /**
     * Returns true if this node is a left child.
     *
     * Note that this should always return a value because the root has a
     * parent which is the marker node.
     */
    @property bool isLeftNode() const
    in
    {
        assert(_parent !is null);
    }
    body
    {
        return _parent._left is &this;
    }

    /**
     * Set the color of the node after it is inserted.  This performs an
     * update to the whole tree, possibly rotating nodes to keep the Red-Black
     * properties correct.  This is an O(lg(n)) operation, where n is the
     * number of nodes in the tree.
     *
     * end is the marker node, which is the parent of the topmost valid node.
     */
    void setColor(Node end)
    {
		//writefln("Updating tree...");
        // test against the marker node
        if(_parent !is end)
        {
            if(_parent.color == Color.Red)
            {
                Node cur = &this;
                while(true)
                {
                    // because root is always black, _parent._parent always exists
                    if(cur._parent.isLeftNode)
                    {
                        // parent is left node, y is 'uncle', could be null
                        Node y = cur._parent._parent._right;
                        if(y !is null && y.color == Color.Red)
                        {
                            cur._parent.color = Color.Black;
                            y.color = Color.Black;
                            cur = cur._parent._parent;
                            if(cur._parent is end)
                            {
                                // root node
                                cur.color = Color.Black;
                                break;
                            }
                            else
                            {
                                // not root node
                                cur.color = Color.Red;
                                if(cur._parent.color == Color.Black)
                                    // satisfied, exit the loop
                                    break;
                            }
                        }
                        else
                        {
                            if(!cur.isLeftNode)
                                cur = cur._parent.rotateL();
                            cur._parent.color = Color.Black;
                            cur = cur._parent._parent.rotateR();
                            cur.color = Color.Red;
                            // tree should be satisfied now
                            break;
                        }
                    }
                    else
                    {
                        // parent is right node, y is 'uncle'
                        Node y = cur._parent._parent._left;
                        if(y !is null && y.color == Color.Red)
                        {
                            cur._parent.color = Color.Black;
                            y.color = Color.Black;
                            cur = cur._parent._parent;
                            if(cur._parent is end)
                            {
                                // root node
                                cur.color = Color.Black;
                                break;
                            }
                            else
                            {
                                // not root node
                                cur.color = Color.Red;
                                if(cur._parent.color == Color.Black)
                                    // satisfied, exit the loop
                                    break;
                            }
                        }
                        else
                        {
                            if(cur.isLeftNode)
                                cur = cur._parent.rotateR();
                            cur._parent.color = Color.Black;
                            cur = cur._parent._parent.rotateL();
                            cur.color = Color.Red;
                            // tree should be satisfied now
                            break;
                        }
                    }
                }

            }
        }
        else
        {
            //
            // this is the root node, color it black
            //
            color = Color.Black;
        }
    }

    /**
     * Remove this node from the tree.  The 'end' node is used as the marker
     * which is root's parent.  Note that this cannot be null!
     *
     * Returns the next highest valued node in the tree after this one, or end
     * if this was the highest-valued node.
     */
    Node remove(Node end)
    {
    	static if (hasStats) {
			updateCurrentAndAncestors(-1);
		}

        //
        // remove this node from the tree, fixing the color if necessary.
        //
        Node x;
        Node ret;
        if(_left is null || _right is null)
        {
            ret = next;
        }
        else
        {
            //
            // normally, we can just swap this node's and y's value, but
            // because an iterator could be pointing to y and we don't want to
            // disturb it, we swap this node and y's structure instead.  This
            // can also be a benefit if the value of the tree is a large
            // struct, which takes a long time to copy.
            //
            Node yp, yl, yr;
            Node y = next;
            yp = y._parent;
            yl = y._left;
            yr = y._right;
            auto yc = y.color;
            auto isyleft = y.isLeftNode;

            //
            // replace y's structure with structure of this node.
            //
            if(isLeftNode)
                _parent.left = y;
            else
                _parent.right = y;
            //
            // need special case so y doesn't point back to itself
            //
            y.left = _left;
            if(_right is y)
                y.right = &this;
            else
                y.right = _right;
            y.color = color;

            //
            // replace this node's structure with structure of y.
            //
            left = yl;
            right = yr;
            if(_parent !is y)
            {
                if(isyleft)
                    yp.left = &this;
                else
                    yp.right = &this;
            }
            color = yc;

            //
            // set return value
            //
            ret = y;
        }

        // if this has less than 2 children, remove it
        if(_left !is null)
            x = _left;
        else
            x = _right;

        // remove this from the tree at the end of the procedure
        bool removeThis = false;
        if(x is null)
        {
            // pretend this is a null node, remove this on finishing
            x = &this;
            removeThis = true;
        }
        else if(isLeftNode)
            _parent.left = x;
        else
            _parent.right = x;

        // if the color of this is black, then it needs to be fixed
        if(color == color.Black)
        {
            // need to recolor the tree.
            while(x._parent !is end && x.color == Node.Color.Black)
            {
                if(x.isLeftNode)
                {
                    // left node
                    Node w = x._parent._right;
                    if(w.color == Node.Color.Red)
                    {
                        w.color = Node.Color.Black;
                        x._parent.color = Node.Color.Red;
                        x._parent.rotateL();
                        w = x._parent._right;
                    }
                    Node wl = w.left;
                    Node wr = w.right;
                    if((wl is null || wl.color == Node.Color.Black) &&
                            (wr is null || wr.color == Node.Color.Black))
                    {
                        w.color = Node.Color.Red;
                        x = x._parent;
                    }
                    else
                    {
                        if(wr is null || wr.color == Node.Color.Black)
                        {
                            // wl cannot be null here
                            wl.color = Node.Color.Black;
                            w.color = Node.Color.Red;
                            w.rotateR();
                            w = x._parent._right;
                        }

                        w.color = x._parent.color;
                        x._parent.color = Node.Color.Black;
                        w._right.color = Node.Color.Black;
                        x._parent.rotateL();
                        x = end.left; // x = root
                    }
                }
                else
                {
                    // right node
                    Node w = x._parent._left;
                    if(w.color == Node.Color.Red)
                    {
                        w.color = Node.Color.Black;
                        x._parent.color = Node.Color.Red;
                        x._parent.rotateR();
                        w = x._parent._left;
                    }
                    Node wl = w.left;
                    Node wr = w.right;
                    if((wl is null || wl.color == Node.Color.Black) &&
                            (wr is null || wr.color == Node.Color.Black))
                    {
                        w.color = Node.Color.Red;
                        x = x._parent;
                    }
                    else
                    {
                        if(wl is null || wl.color == Node.Color.Black)
                        {
                            // wr cannot be null here
                            wr.color = Node.Color.Black;
                            w.color = Node.Color.Red;
                            w.rotateL();
                            w = x._parent._left;
                        }

                        w.color = x._parent.color;
                        x._parent.color = Node.Color.Black;
                        w._left.color = Node.Color.Black;
                        x._parent.rotateR();
                        x = end.left; // x = root
                    }
                }
            }
            x.color = Node.Color.Black;
        }

        if(removeThis)
        {
            //
            // clear this node out of the tree
            //
            if(isLeftNode)
                _parent.left = null;
            else
                _parent.right = null;
        }

        return ret;
    }

    /**
     * Return the leftmost descendant of this node.
     */
    @property Node leftmost()
    {
        Node result = &this;
        while(result._left !is null)
            result = result._left;
        return result;
    }

    /**
     * Return the rightmost descendant of this node
     */
    @property Node rightmost()
    {
        Node result = &this;
        while(result._right !is null)
            result = result._right;
        return result;
    }

    /**
     * Returns the next valued node in the tree.
     *
     * You should never call this on the marker node, as it is assumed that
     * there is a valid next node.
     */
    @property Node next()
    {
        Node n = &this;
        if(n.right is null)
        {
            while(!n.isLeftNode)
                n = n._parent;
            return n._parent;
        }
        else
            return n.right.leftmost;
    }

    /**
     * Returns the previous valued node in the tree.
     *
     * You should never call this on the leftmost node of the tree as it is
     * assumed that there is a valid previous node.
     */
    @property Node prev()
    {
        Node n = &this;
        if(n.left is null)
        {
            while(n.isLeftNode)
                n = n._parent;
            return n._parent;
        }
        else
            return n.left.rightmost;
    }

    Node dup(scope Node delegate(V v) alloc)
    {
        //
        // duplicate this and all child nodes
        //
        // The recursion should be lg(n), so we shouldn't have to worry about
        // stack size.
        //
        Node copy = alloc(value);
        copy.color = color;
        if(_left !is null)
            copy.left = _left.dup(alloc);
        if(_right !is null)
            copy.right = _right.dup(alloc);
        return copy;
    }

    Node dup()
    {
        Node copy = new RBNode!(V, hasStats);
        copy.value = value;
        copy.color = color;
        static if (hasStats) {
        	copy.childCountLeft  = childCountLeft; 
        	copy.childCountRight = childCountRight;
        }
        if(_left !is null)
            copy.left = _left.dup();
        if(_right !is null)
            copy.right = _right.dup();
        return copy;
    }
}

/**
 * Implementation of a $(LUCKY red-black tree) container.
 *
 * All inserts, removes, searches, and any function in general has complexity
 * of $(BIGOH lg(n)).
 *
 * To use a different comparison than $(D "a < b"), pass a different operator string
 * that can be used by $(XREF functional, binaryFun), or pass in a
 * function, delegate, functor, or any type where $(D less(a, b)) results in a $(D bool)
 * value.
 *
 * Note that less should produce a strict ordering.  That is, for two unequal
 * elements $(D a) and $(D b), $(D less(a, b) == !less(b, a)). $(D less(a, a)) should
 * always equal $(D false).
 *
 * If $(D allowDuplicates) is set to $(D true), then inserting the same element more than
 * once continues to add more elements.  If it is $(D false), duplicate elements are
 * ignored on insertion.  If duplicates are allowed, then new elements are
 * inserted after all existing duplicate elements.
 */
class RedBlackTree(T, alias less = "a < b", bool allowDuplicates = false, bool hasStats = false)
    if(is(typeof(binaryFun!less(T.init, T.init))))
{
    alias binaryFun!less _less;
    
    static assert (!(allowDuplicates && hasStats));

    // BUG: this must come first in the struct due to issue 2810

    // add an element to the tree, returns the node added, or the existing node
    // if it has already been added and allowDuplicates is false

    private auto _add(Elem n)
    {
        Node result;
		
		void preInsert() {
			debug (RB_ADD) {
				writefln("_add(%s)", n);
			}
			//writefln("- BEFORE ---------------------------------------------------");
			//result.root.printTree();
			static if (hasStats) {
				result.updateCurrentAndAncestors(+1);
			}
			//writefln("- AFTER ----------------------------------------------------");
			//result.root.printTree();
			//writefln("- /////// --------------------------------------------------");
		}

        static if(!allowDuplicates)
        {
            bool added = true;
            scope(success)
            {
                if(added) {
					++_length;
				}
            }
        }
        else
        {
            scope(success) {
				++_length;
			}
        }
		
        if(!_end.left)
        {
            _end.left = result = allocate(n);
        }
        else
        {
            Node newParent = _end.left;
            Node nxt = void;
            while(true)
            {
                if(_less(n, newParent.value))
                {
                    nxt = newParent.left;
                    if(nxt is null)
                    {
                        //
                        // add to right of new parent
                        //
                        newParent.left = result = allocate(n);
                        break;
                    }
                }
                else
                {
                    static if(!allowDuplicates)
                    {
                        if(!_less(newParent.value, n))
                        {
                            result = newParent;
                            added = false;
                            break;
                        }
                    }
                    nxt = newParent.right;
                    if(nxt is null)
                    {
                        //
                        // add to right of new parent
                        //
                        newParent.right = result = allocate(n);
                        break;
                    }
                }
                newParent = nxt;
            }
        }
		
        static if(allowDuplicates)
        {
			preInsert();
            result.setColor(_end);
            version(RBDoChecks)
                check();
            return result;
        }
        else
        {
            if(added) {
				preInsert();
                result.setColor(_end);
			}
            version(RBDoChecks)
                check();
            return Tuple!(bool, "added", Node, "n")(added, result);
        }
    }

	private enum doUnittest = false;

    /**
      * Element type for the tree
      */
    alias T Elem;

    // used for convenience
    //private alias RBNode!Elem.Node Node;
    private alias RBNode!(Elem, hasStats)* Node;

    public Node   _end;
    private size_t _length;

    private void _setup()
    {
        assert(!_end); //Make sure that _setup isn't run more than once.
        _end = allocate();
    }

    static private Node allocate()
    {
        return new RBNode!(Elem, hasStats);
    }

    static private Node allocate(Elem v)
    {
        auto result = allocate();
        result.value = v;
        return result;
    }

    /**
     * The range type for $(D RedBlackTree)
     */
    class Range
    {
        private Node _rbegin;
        private Node _rend;

        private this(Node b, Node e)
        {
            _rbegin = b;
            _rend = e;
        }
        
        public Range limit(int limitCount) {
        	static if (hasStats) {
        		return new Range(_rbegin, locateNodeAtPosition(getNodePosition(_rbegin) + limitCount));
        	} else {
	    		Node current = _rbegin;
	    		int count = 0;
	    		while (true) {
	    			if (count == limitCount) {
	    				return new Range(_rbegin, current);
	    			}
	    			count++;
	    			if (current is _rend) break;
	    			current = current.next;
	    		}
	    		return new Range(_rbegin, _rend); 
        	}
        }
        
        public Range skip(int skipCount) {
        	static if (hasStats) {
        		return new Range(locateNodeAtPosition(getNodePosition(_rbegin) + skipCount), _rend);
        	} else {
	    		Node current = _rbegin;
	    		int count = 0;
	    		while (true) {
	    			if (count == skipCount) {
	    				return new Range(current, _rend);
	    			}
	    			count++;
	    			if (current is _rend) break;
	    			current = current.next;
	    		}
	    		return new Range(_rend, _rend); 
        	}
        }
        
        /**
         * Returns $(D true) if the range is _empty
         */
        @property bool empty() const
        {
            return _rbegin is _rend;
        }

        /**
         * Returns the first element in the range
         */
        @property Elem front()
        {
            return _rbegin.value;
        }

        /**
         * Returns the last element in the range
         */
        @property Elem back()
        {
            return _rend.prev.value;
        }

        /**
         * pop the front element from the range
         *
         * complexity: amortized $(BIGOH 1)
         */
        void popFront()
        {
            _rbegin = _rbegin.next;
        }
        
        @property int length() {
        	//writefln("Begin: %d:%s", countLesser(_begin), *_begin);
        	//writefln("End: %d:%s", countLesser(_end), *_end);
        	//return _begin
        	static if (hasStats) {
        		return countLesser(_rend) - countLesser(_rbegin);
        	} else {
        		// For all() use the global stats.
        		if ((_rend == _end) && (_rbegin == _end.leftmost)) return _length;
        		
        		Node current = _rbegin;
        		int count = 0;
        		while (current !is _rend) {
        			count++;
        			current = current.next;
        		}
        		return count; 
        	}
        }

        Range opSlice() {
        	return new Range(_rbegin, _rend);
        }
        
        Range opSlice(int start, int end) {
        	static if (hasStats) {
	        	int startPosition = getNodePosition(_rbegin);
	        	return new Range(
	        		locateNodeAtPosition(startPosition + start),
	        		locateNodeAtPosition(startPosition + end)
	        	);
	        } else {
	        	return skip(start).limit(end - start);
	        }
        }

        Node opIndex(int index) {
        	static if (hasStats) {
        		return locateNodeAtPosition(getNodePosition(_rbegin) + index);
        	} else {
        		return skip(index)._rbegin;
        	}
        }
        
        /**
         * pop the back element from the range
         *
         * complexity: amortized $(BIGOH 1)
         */
        void popBack()
        {
            _rend = _rend.prev;
        }

        /**
         * Trivial _save implementation, needed for $(D isForwardRange).
         */
        @property Range save()
        {
            return this;
        }
    }

    // find a node based on an element value
    public Node _find(Elem e)
    {
        static if(allowDuplicates)
        {
            Node cur = _end.left;
            Node result = null;
            while(cur)
            {
                if(_less(cur.value, e))
                    cur = cur.right;
                else if(_less(e, cur.value))
                    cur = cur.left;
                else
                {
                    // want to find the left-most element
                    result = cur;
                    cur = cur.left;
                }
            }
            return result;
        }
        else
        {
            Node cur = _end.left;
            while(cur)
            {
                if(_less(cur.value, e))
                    cur = cur.right;
                else if(_less(e, cur.value))
                    cur = cur.left;
                else
                    return cur;
            }
            return null;
        }
    }

    /**
     * Check if any elements exist in the container.  Returns $(D true) if at least
     * one element exists.
     */
    @property bool empty()
    {
        return _end.left is null;
    }

    /++
        Returns the number of elements in the container.

        Complexity: $(BIGOH 1).
    +/
    @property size_t length()
    {
        return _length;
    }

    /**
     * Duplicate this container.  The resulting container contains a shallow
     * copy of the elements.
     *
     * Complexity: $(BIGOH n)
     */
    @property RedBlackTree dup()
    {
        return new RedBlackTree(_end.dup(), _length);
    }

    /**
     * Fetch a range that spans all the elements in the container.
     *
     * Complexity: $(BIGOH log(n))
     */
    Range opSlice()
    {
        return new Range(_end.leftmost, _end);
    }

    /**
     * The front element in the container
     *
     * Complexity: $(BIGOH log(n))
     */
    Elem front()
    {
        return _end.leftmost.value;
    }

    /**
     * The last element in the container
     *
     * Complexity: $(BIGOH log(n))
     */
    Elem back()
    {
        return _end.prev.value;
    }

    /++
        $(D in) operator. Check to see if the given element exists in the
        container.

       Complexity: $(BIGOH log(n))
     +/
    bool opBinaryRight(string op)(Elem e) if (op == "in")
    {
        return _find(e) !is null;
    }

    /**
     * Removes all elements from the container.
     *
     * Complexity: $(BIGOH 1)
     */
    void clear()
    {
        _end.left = null;
        _length = 0;
    }

    /**
     * Insert a single element in the container.  Note that this does not
     * invalidate any ranges currently iterating the container.
     *
     * Complexity: $(BIGOH log(n))
     */
    size_t stableInsert(Stuff)(Stuff stuff) if (isImplicitlyConvertible!(Stuff, Elem))
    {
        static if(allowDuplicates)
        {
            _add(stuff);
            return 1;
        }
        else
        {
            return(_add(stuff).added ? 1 : 0);
        }
    }

    /**
     * Insert a range of elements in the container.  Note that this does not
     * invalidate any ranges currently iterating the container.
     *
     * Complexity: $(BIGOH m * log(n))
     */
    size_t stableInsert(Stuff)(Stuff stuff) if(isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, Elem))
    {
        size_t result = 0;
        static if(allowDuplicates)
        {
            foreach(e; stuff)
            {
                ++result;
                _add(e);
            }
        }
        else
        {
            foreach(e; stuff)
            {
                if(_add(e).added)
                    ++result;
            }
        }
        return result;
    }

    /// ditto
    alias stableInsert insert;

    /**
     * Remove an element from the container and return its value.
     *
     * Complexity: $(BIGOH log(n))
     */
    Elem removeAny()
    {
        scope(success) {
            --_length;
		}
        auto n = _end.leftmost;
        auto result = n.value;
        n.remove(_end);
        version(RBDoChecks)
            check();
        return result;
    }

    /**
     * Remove the front element from the container.
     *
     * Complexity: $(BIGOH log(n))
     */
    void removeFront()
    {
        scope(success) {
            --_length;
		}
        _end.leftmost.remove(_end);
        version(RBDoChecks)
            check();
    }

    /**
     * Remove the back element from the container.
     *
     * Complexity: $(BIGOH log(n))
     */
    void removeBack()
    {
        scope(success)
            --_length;
        _end.prev.remove(_end);
        version(RBDoChecks)
            check();
    }

    /++
        Removes the given range from the container.

        Returns: A range containing all of the elements that were after the
                 given range.

        Complexity: $(BIGOH m * log(n)) (where m is the number of elements in
                    the range)
     +/
    Range remove(Range r)
    {
        auto b = r._rbegin;
        auto e = r._rend;
        while(b !is e)
        {
            b = b.remove(_end);
            --_length;
        }
        version(RBDoChecks)
            check();
        return new Range(e, _end);
    }

    /++
        Removes the given $(D Take!Range) from the container

        Returns: A range containing all of the elements that were after the
                 given range.

        Complexity: $(BIGOH m * log(n)) (where m is the number of elements in
                    the range)
     +/
    Range remove(Range r)
    {
        auto b = r._rbegin;

        while(!r.empty)
            r.popFront(); // move take range to its last element

        auto e = r._rbegin;

        while(b != e)
        {
            b = b.remove(_end);
            --_length;
        }

        return new Range(e, _end);
    }

    /++
       Removes elements from the container that are equal to the given values
       according to the less comparator. One element is removed for each value
       given which is in the container. If $(D allowDuplicates) is true,
       duplicates are removed only if duplicate values are given.

       Returns: The number of elements removed.

       Complexity: $(BIGOH m log(n)) (where m is the number of elements to remove)

        Examples:
--------------------
auto rbt = redBlackTree!true(0, 1, 1, 1, 4, 5, 7);
rbt.removeKey(1, 4, 7);
assert(std.algorithm.equal(rbt[], [0, 1, 1, 5]));
rbt.removeKey(1, 1, 0);
assert(std.algorithm.equal(rbt[], [5]));
--------------------
      +/
    size_t removeKey(U)(U[] elems...)
        if(isImplicitlyConvertible!(U, Elem))
    {
        immutable lenBefore = length;

        foreach(e; elems)
        {
            auto beg = _firstGreaterEqual(e);
            if(beg is _end || _less(e, beg.value))
                // no values are equal
                continue;
			beg.remove(_end);
            --_length;
        }

        return lenBefore - length;
    }

    /++ Ditto +/
    size_t removeKey(Stuff)(Stuff stuff)
        if(isInputRange!Stuff &&
           isImplicitlyConvertible!(ElementType!Stuff, Elem) &&
           !is(Stuff == Elem[]))
    {
        //We use array in case stuff is a Range from this RedBlackTree - either
        //directly or indirectly.
        return removeKey(array(stuff));
    }

    // find the first node where the value is > e
    private Node _firstGreater(Elem e)
    {
        // can't use _find, because we cannot return null
        auto cur = _end.left;
        auto result = _end;
        while(cur)
        {
            if(_less(e, cur.value))
            {
                result = cur;
                cur = cur.left;
            }
            else
                cur = cur.right;
        }
        return result;
    }

    // find the first node where the value is >= e
    private Node _firstGreaterEqual(Elem e)
    {
        // can't use _find, because we cannot return null.
        auto cur = _end.left;
        auto result = _end;
        while(cur)
        {
            if(_less(cur.value, e))
                cur = cur.right;
            else
            {
                result = cur;
                cur = cur.left;
            }

        }
        return result;
    }

    /**
     * Get a range from the container with all elements that are > e according
     * to the less comparator
     *
     * Complexity: $(BIGOH log(n))
     */
    Range upperBound(Elem e)
    {
        return new Range(_firstGreater(e), _end);
    }

    /**
     * Get a range from the container with all elements that are < e according
     * to the less comparator
     *
     * Complexity: $(BIGOH log(n))
     */
    Range lowerBound(Elem e)
    {
        return new Range(_end.leftmost, _firstGreaterEqual(e));
    }

    /**
     * Get a range from the container with all elements that are == e according
     * to the less comparator
     *
     * Complexity: $(BIGOH log(n))
     */
    Range equalRange(Elem e)
    {
        auto beg = _firstGreaterEqual(e);
        if(beg is _end || _less(e, beg.value))
            // no values are equal
            return new Range(beg, beg);
        static if(allowDuplicates)
        {
            return new Range(beg, _firstGreater(e));
        }
        else
        {
            // no sense in doing a full search, no duplicates are allowed,
            // so we just get the next node.
            return new Range(beg, beg.next);
        }
    }

    version(RBDoChecks)
    {
        /*
         * Print the tree.  This prints a sideways view of the tree in ASCII form,
         * with the number of indentations representing the level of the nodes.
         * It does not print values, only the tree structure and color of nodes.
         */
        void printTree(Node n, int indent = 0)
        {
            if(n !is null)
            {
                printTree(n.right, indent + 2);
                for(int i = 0; i < indent; i++)
                    write(".");
                writeln(n.color == n.color.Black ? "B" : "R");
                printTree(n.left, indent + 2);
            }
            else
            {
                for(int i = 0; i < indent; i++)
                    write(".");
                writeln("N");
            }
            if(indent is 0)
                writeln();
        }

        /*
         * Check the tree for validity.  This is called after every add or remove.
         * This should only be enabled to debug the implementation of the RB Tree.
         */
        void check()
        {
            //
            // check implementation of the tree
            //
            int recurse(Node n, string path)
            {
                if(n is null)
                    return 1;
                if(n.parent.left !is n && n.parent.right !is n)
                    throw new Exception("Node at path " ~ path ~ " has inconsistent pointers");
                Node next = n.next;
                static if(allowDuplicates)
                {
                    if(next !is _end && _less(next.value, n.value))
                        throw new Exception("ordering invalid at path " ~ path);
                }
                else
                {
                    if(next !is _end && !_less(n.value, next.value))
                        throw new Exception("ordering invalid at path " ~ path);
                }
                if(n.color == n.color.Red)
                {
                    if((n.left !is null && n.left.color == n.color.Red) ||
                            (n.right !is null && n.right.color == n.color.Red))
                        throw new Exception("Node at path " ~ path ~ " is red with a red child");
                }

                int l = recurse(n.left, path ~ "L");
                int r = recurse(n.right, path ~ "R");
                if(l != r)
                {
                    writeln("bad tree at:");
                    printTree(n);
                    throw new Exception("Node at path " ~ path ~ " has different number of black nodes on left and right paths");
                }
                return l + (n.color == n.color.Black ? 1 : 0);
            }

            try
            {
                recurse(_end.left, "");
            }
            catch(Exception e)
            {
                printTree(_end.left, 0);
                throw e;
            }
        }
    }

    /+
        For the moment, using templatized contstructors doesn't seem to work
        very well (likely due to bug# 436 and/or bug# 1528). The redBlackTree
        helper function seems to do the job well enough though.

    /**
     * Constructor.  Pass in an array of elements, or individual elements to
     * initialize the tree with.
     */
    this(U)(U[] elems...) if (isImplicitlyConvertible!(U, Elem))
    {
        _setup();
        stableInsert(elems);
    }

    /**
     * Constructor.  Pass in a range of elements to initialize the tree with.
     */
    this(Stuff)(Stuff stuff) if (isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, Elem) && !is(Stuff == Elem[]))
    {
        _setup();
        stableInsert(stuff);
    }
    +/

    /++ +/
    this()
    {
        _setup();
    }

    /++
       Constructor.  Pass in an array of elements, or individual elements to
       initialize the tree with.
     +/
    this(Elem[] elems...)
    {
        _setup();
        stableInsert(elems);
    }

    private this(Node end, size_t length)
    {
        _end = end;
        _length = length;
    }
    
    //auto _equals(Node a, Node b) { return !_less(a, b) && !_less(b, a); }
    //auto _lessOrEquals(Node a, Node b) { return _less(a, b) || _equals(a, b); }
    
	int countLesser(Node node) {
	    static if (hasStats) {
			if (node is null) return 0;
			if (node.parent is null) return node.childCountLeft;

			//auto prev = node;
			auto it = node;
			int count;
			while (true) {
				if (it.parent is null) break;
				//writefln("+%d+1", it.childCountLeft);
				//if (it.value <= node.value) {
				if (!_less(node.value, it.value)) {
					count += it.childCountLeft + 1;
				}
				it = it.parent;
				if (it is null) {
					//writefln("it is null");
					break;
				} else {
					//writefln("less(%s, %s) : %d", it.value, node.value, it.value < node.value);
					
					//if (_less(it, node)) break;
					//if (it.value >= node.value) break;
				}
				//_less
				//if (it._right != prev) break;
				//prev = it;
			}
			return count - 1;
		} else {
			return (new Range(_end.leftmost, node)).length;
			//static assert (false, "Not Implemented");
		}
	}
	
	alias countLesser getNodePosition;
	
	Node locateNodeAtPosition(int positionToFind) {
		static if (hasStats) {
			// log(n) ^^ 2
			/*static if (false) {
				Node current = _end;
				while (true) {
					int currentPosition = getNodePosition(current);
					//writefln("currentPosition: %d/%d", currentPosition, positionToFind);
					
					if (currentPosition == positionToFind) {
						break;
						//return current;
					}
					
					if (positionToFind < currentPosition) {
						//writefln("Left(%s/%s)", current.childCountLeft, current.childCountRight);
						current = current.left;
					} else {
						//writefln("Right(%s/%s)", current.childCountLeft, current.childCountRight);
						current = current.right;
					}
				}
			}
			// log(n)
			else*/{
				//writefln("Root(%s/%s)", _end.childCountLeft, _end.childCountRight);
				Node current = _end;
				int currentPosition = _end.childCountLeft;
				while (true) {
					//int currentPositionExpected = getNodePosition(current);
					if (currentPosition == positionToFind) return current;
					
					if (positionToFind < currentPosition) {
						//currentPosition += current.childCountLeft;
						current = current.left;
						//writefln("Left(%s/%s) ::: %d-%d", current.childCountLeft, current.childCountRight, currentPosition, current.childCountRight);
						currentPosition -= current.childCountRight + 1;
					} else {
						current = current.right;
						//writefln("Right(%s/%s) ::: %d+%d", current.childCountLeft, current.childCountRight, currentPosition, current.childCountLeft);
						currentPosition += current.childCountLeft + 1;
					}
					//writefln("currentPosition: %d/%d/%d", currentPosition, currentPositionExpected, positionToFind);
				}
			}
			return null;
			//throw(new Exception("Can't find position"));
		} else {
			Node current = _end.leftmost;
			while (current != _end) {
				if (positionToFind == 0) return current;
				current = current.next;
				positionToFind--;
			}
			return null;
		}
	}
    
    @property Range all() {
    	return new Range(_end.leftmost, _end);
    }
}

class User {
	uint userId;
	uint score;
	uint timestamp;
	
	this(uint userId, uint score, uint timestamp) {
		this.userId    = userId;
		this.score     = score;
		this.timestamp = timestamp;
	}
	
	static bool compareByScore(User a, User b) {
		if (a.score == b.score) {
			if (a.timestamp == b.timestamp) {
				return a.userId < b.userId;
			} else {
				return a.timestamp < b.timestamp;
			}
		} else { 
			return a.score < b.score;
		}
	}
	
	public string toString() {
		return std.string.format("User(userId:%d, timestamp:%d, score:%d)", userId, timestamp, score);
	}
}

const bool useStats = true;

void measure(string desc, void delegate() dg) {
	auto start = Clock.currTime;
	dg();
	auto end = Clock.currTime;
	writefln("Time('%s'): %s", desc, end - start);
	writefln("");
}

void measurePerformance(bool useStats)() {
	writefln("---------------------------------------");
	writefln("measurePerformance(useStats=%s)", useStats);
	writefln("---------------------------------------");
	
	//RedBlackTree(T, alias less = "a < b", bool allowDuplicates = false, bool hasStats = false)
	
	auto start = Clock.currTime;
	measure("Total", {
		int itemSize = 1_000_000;
		
		auto items = new RedBlackTree!(User, User.compareByScore, false, useStats)();
		User generate(uint id) {
			return new User(id, id * 100, id);
		}
	
		writefln("NodeSize: %d", (*items._end).sizeof);
		
		//for (int n = itemSize; n >= 11; n--) {
		measure(std.string.format("Insert(%d) items", itemSize), {
			for (int n = 0; n < itemSize; n++) {
				items.insert(generate(n));
			}
		});
		
		items.removeKey(generate(100_000));
		items.removeKey(generate(700_000));

		measure(std.string.format("locateNodeAtPosition"), {
			for (int n = 0; n < 40; n++) {
				int result = items.locateNodeAtPosition(800_000).value.userId;
				if (n == 40 - 1) {
					writefln("%s", result);
				}
			}
		});
		
		measure("IterateUpperBound", {
			foreach (item; items.upperBound(generate(1_000_000 - 100_000))) {
				//writefln("Item: %s", item);
			}
		});
	
		measure("LengthAll", {
			writefln("%d", items.all.length);
		});
		measure("Length(skipx40:800_000)", {
			for (int n = 0; n < 40; n++) {
				int result = items.all.skip(800_000).length;
				//int result = items.all[800_000..items.all.length].length;
				if (n == 40 - 1) {
					writefln("%d", items.all.skip(800_000).front.userId);
					writefln("%d", items.all.skip(800_000).back.userId);
					writefln("%d", result);
				}
			}
		});
		
		measure("Length(skip+limitx40:100_000,600_000)", {
			for (int n = 0; n < 40; n++) {
				//int result = items.all.skip(100_000).limit(600_000).length;
				int result = items.all[100_000 .. 700_000].length;
				if (n == 40 - 1) {
					writefln("%d", items.all.skip(100_000).limit(600_000).front.userId);
					writefln("%d", items.all.skip(100_000).limit(600_000).back.userId);
					writefln("%d", result);
				}
			}
		});
		measure("Length(lesserx40)", {
			for (int n = 0; n < 40; n++) {
				int result = items.countLesser(items._find(generate(1_000_000 - 10)));
				if (n == 40 - 1) writefln("%d", result);
			}
		});
		measure("LengthBigRangex40", {
			for (int n = 0; n < 40; n++) {
				int result = items.upperBound(generate(1_000_000 - 900_000)).length;
				if (n == 40 - 1) writefln("%d", result);
			}
		});
		
		//items._end._left.printTree();
		//writefln("%s", *items._find(5));
		//foreach (item; items) writefln("%d", item);
		static if (useStats) {
			measure("Count all items position one by one (only with stats) O(N*log(N))", {
				for (int n = 0; n < itemSize; n++) {
					if (n == 100_000 || n == 700_000) continue;
		
					scope user = new User(n, n * 100, n);
					
					//writefln("%d", count);
					//writefln("-----------------------------------------------------");
					//writefln("######## Count(%d): %d", n, count);
					/*
					if (n > 500) {
						assert(count == n - 1);
					} else {
						assert(count == n);
					}
					*/
					static if (useStats) {
						int count = items.countLesser(items._find(user));
						
						int v = n;
						if (n > 100_000) v--;
						if (n > 700_000) v--;
						assert(count == v);
					}
				}
			});
		}
	});
}

int main(string[] args) {
	GC.disable();
	{
		measurePerformance!(true);
		measurePerformance!(false);
	}
	GC.enable();
	GC.collect();
	
	return 0;
}