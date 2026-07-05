module inochi2d.core.memory.arena;
import numem.core.lifetime;
import numem.core.memory;
import numem.object;
import numem.heap;
import numem;

/**
    Assumed page size to allocate.
*/
enum PAGE_SIZE = 4096;

/**
    An Arena Pool, contains and manages multiple arenas with a given
    alignment.
*/
class ArenaPoolHeap : NuHeap {
private:
@nogc:
    size_t alignment_;
    size_t itemsPerHeap_;
    ArenaHeap[] arenas;

    ArenaHeap addArena() {
        this.arenas = arenas.nu_resize(arenas.length + 1);
        arenas[$ - 1] = nogc_new!ArenaHeap(alignment_, alignment_ * itemsPerHeap_);
        return arenas[$ - 1];
    }

public:

    /**
        The alignment of data within the pool
    */
    final @property size_t alignment() => alignment_;

    /// Destructor
    ~this() {
        nu_freea(arenas);
    }

    /**
        Constructs a new arena pool.

        Params:
            alignment =     The alignment between objects in the pool.
            itemsPerHeap =  How many elements to make space for in each heap.
    */
    this(size_t alignment, size_t itemsPerHeap) {
        this.alignment_ = nu_max((void*).sizeof, alignment);
        this.itemsPerHeap_ = nu_max(50, itemsPerHeap);
    }

    /** 
        Allocates memory on the heap.
        
        Params:
            bytes = The amount of bytes to allocate from the heap.

        Returns: 
            A pointer to the memory allocated on the heap.
            $(D null) if operation failed.
    */
    override void* alloc(size_t bytes) {
        if (bytes >= alignment_ * itemsPerHeap_)
            return null;

        foreach (arena; arenas) {
            if (void* ptr = arena.alloc(bytes))
                return ptr;
        }

        // No arenas? allocate a new one.
        return this.addArena().alloc(bytes);
    }

    /** 
        Attempts to reallocate an existing memory allocation on the heap.

        Params:
            allocation = The original allocation
            bytes = The new size of the allocation, in bytes.
        
        Returns:
            A pointer to the memory allocated on the heap.
            $(D null) if the operation failed. 
    */
    override void* realloc(void* allocation, size_t bytes) {
        foreach (arena; arenas) {
            if (arena.has(allocation)) {
                if (void* newAddress = arena.realloc(allocation, bytes))
                    return newAddress;

                // Need to be re-located to another pool.
                void* newAddress = this.alloc(bytes);
                nu_memcpy(newAddress, arena.getAllocationBase(allocation), arena.getAllocationSize(allocation));
                arena.free(allocation);
                return newAddress;
            }
        }
        return null;
    }

    /** 
        Frees memory from the heap.
        Note: Only memory owned by the heap may be freed by it.

        Params:
            allocation = The allocation to free.
    */
    override void free(void* allocation) {
        foreach (arena; arenas) {
            if (arena.has(allocation))
                arena.free(allocation);
        }
    }
}

/**
    A memory arena.
*/
class ArenaHeap : NuHeap {
private:
@nogc:
    // Core data
    size_t size_;
    size_t alignment_;
    size_t usable_;
    void* start_;
    size_t usage_;
    BlockInfo[] blocks;

    // Helper that gets whether the given address is inbounds.
    pragma(inline, true)
    bool isInbounds(void* address) {
        return address >= start_ && address < start_ + size_;
    }

    // Finds contiguous free blocks.
    ptrdiff_t findFree(size_t count = 1) {
        size_t i = 0;
        size_t base = 0;
        size_t found = 0;
        while (count > 0 && i < blocks.length) {
            if (!(blocks[i].flags & BLOCK_FLAG_USED)) {
                if (count == 1)
                    return i;

                // Check for continuus free blocks
                base = i;
                if (count > 1) {
                    while (i < blocks.length) {

                        if (!(blocks[i].flags & BLOCK_FLAG_USED)) {
                            found++;
                            i++;

                            if (found >= count)
                                return base;

                            continue;
                        }
                        break;
                    }
                }
            }

            i++;
        }
        return -1;
    }

    // Find the given allocation at the given address.
    ptrdiff_t find(void* address) {
        if (!isInbounds(address))
            return -1;

        // Skip back to the start of the allocation, if neccesary.
        ptrdiff_t offset = nu_aligndown(cast(size_t)(address - start_), alignment_) / size_;
        while (offset >= 0 && (blocks[offset].flags & BLOCK_FLAG_PARTIAL)) {
            offset--;
        }
        return offset;
    }

    // Converts a given byte offset into an allocation info offset.
    size_t bytesToBlocks(size_t byteLength) {
        return nu_aligndown(byteLength, alignment_) / usable_;
    }

    // Gets address from block index.
    void* blockToAddress(size_t block) {
        return start_ + (block * alignment_);
    }

    // Gets block index from address.
    ptrdiff_t addressToBlock(void* address) {
        if (!isInbounds(address))
            return -1;

        return this.bytesToBlocks(address - start_);
    }

    // Claims the given blocks.
    void claim(size_t block, size_t length) {
        size_t blocksToClaim = this.bytesToBlocks(length);
        blocks[block].flags = BLOCK_FLAG_USED;
        blocks[block].length = alignment_;

        ptrdiff_t remaining = length;
        foreach (i; 0 .. blocksToClaim) {
            blocks[block + 1 + i].flags = BLOCK_FLAG_PARTIAL | BLOCK_FLAG_USED;
            blocks[block + 1 + i].length = remaining % alignment_;
            remaining -= alignment_;
        }

        usage_ += length;
    }

    // Unclaims a block and all subsequent partial blocks.
    void unclaim(size_t block) {
        size_t i = block + 1;
        while (i < blocks.length) {
            if (blocks[i].flags & BLOCK_FLAG_PARTIAL) {
                usage_ -= blocks[i].length;

                blocks[i] = BlockInfo.init;
                i++;
                continue;
            }

            break;
        }

        usage_ -= blocks[block].length;
        blocks[block] = BlockInfo.init;
    }

    // Gets whether a given range can be claimed.
    bool canClaim(size_t start, size_t count) {
        if (start + count >= blocks.length)
            return false;

        foreach (i; start .. start + count) {
            if (blocks[i].flags == 0)
                continue;

            return false;
        }
        return true;
    }

    size_t blockUsage(size_t block) {
        if (block >= blocks.length)
            return 0;

        size_t p_used = blocks[block].length;
        size_t i = block;
        while (i < blocks.length) {
            i++;

            if (blocks[i].flags & BLOCK_FLAG_PARTIAL) {
                p_used += blocks[i].length;
                continue;
            }
            break;
        }

        return p_used;
    }

    size_t totalBlockUsage(size_t block) {
        if (block >= blocks.length)
            return 0;

        size_t p_used = alignment_;
        size_t i = block;
        while (i < blocks.length) {
            i++;

            if (blocks[i].flags & BLOCK_FLAG_PARTIAL) {
                p_used += alignment_;
                continue;
            }
            break;
        }

        return p_used;
    }

public:

    /**
        The amount of bytes used.
    */
    final @property size_t bytesUsed() => usage_;

    /**
        The amount of bytes free.
    */
    final @property size_t bytesFree() => size_ - usage_;

    /**
        The usable size of the arena.
    */
    final @property size_t size() => usable_;

    /**
        The total size of the arena, including any added padding.
    */
    final @property size_t totalSize() => size_;

    /**
        The alignment of any given block.
    */
    final @property size_t alignment() => alignment_;

    /**
        Pointer to the start of the arena's memory.
    */
    final @property void* ptr() => start_;

    /**
        Constructs a new arena to store allocated data.

        Params:
            alignment =     The alignment of elements within the block,
                            will be rounded up to nearest pointer alignment.
            size =          The total size to allocate,
                            will be rounded up to nearest alignment, then page size.
    */
    this(size_t alignment, size_t size) {
        this.alignment_ = nu_alignup(alignment, (void*).sizeof);
        this.size_ = nu_alignup(nu_alignup(size, alignment_), PAGE_SIZE);
        this.usable_ = nu_aligndown(size, alignment_);
        this.blocks = nu_malloca!BlockInfo(usable_ / alignment_);
    }

    /**
        Gets whether the sub-arena has the given address.

        Params:
            address = The address to query.

        Returns:
            $(D true) if the given address is found in the arena,
            $(D false) otherwise.
    */
    bool has(void* address) {
        return address >= start_ && address < start_ + usable_;
    }

    /** 
        Allocates memory on the heap.
        
        Params:
            size = The amount of bytes to allocate from the heap.

        Returns: 
            A pointer to the memory allocated on the heap.
            $(D null) if operation failed.
    */
    override void* alloc(size_t size) {
        ptrdiff_t block = this.findFree(this.bytesToBlocks(size));
        if (block == -1)
            return null;

        this.claim(block, size);
        return this.blockToAddress(block);
    }

    /** 
        Attempts to reallocate an existing memory allocation on the heap.

        Params:
            address =   The original allocation
            size =      The new size of the allocation, in bytes.
        
        Returns:
            A pointer to the memory allocated on the heap.
            $(D null) if the operation failed. 
    */
    override void* realloc(void* address, size_t size) {
        if (!isInbounds(address))
            return null;

        if (address is null)
            return this.alloc(size);

        ptrdiff_t offset = this.find(address);
        if (offset >= 0) {
            size_t usedByBlock = this.totalBlockUsage(offset);

            // 1.   Downsize should just claim and re-claim the block,
            //      with the new desired size.
            if (size < usedByBlock) {
                this.unclaim(offset);
                this.claim(offset, size);
                return address;
            }

            // 2.   For upsizing, we should first try to do an in-place
            //      reallocation by claiming more blocks.
            ptrdiff_t scanOffsetStart = offset + this.bytesToBlocks(usedByBlock);
            if (this.canClaim(scanOffsetStart, this.bytesToBlocks(size))) {
                this.unclaim(offset);
                this.claim(offset, size);
                return address;
            }

            // 3.   At this point we'll need to find a range that can fit the given size.
            //      So we'll just free and allocate the memory anew, if possible.
            if (bytesFree - usedByBlock < usable_)
                return null;

            size_t newBlock = this.findFree(this.bytesToBlocks(size));
            nu_memcpy(this.blockToAddress(newBlock), this.blockToAddress(offset), usedByBlock);
            this.unclaim(offset);
            this.claim(newBlock, size);
            return this.blockToAddress(newBlock);
        }

        return null;
    }

    /** 
        Frees memory from the heap.
        Note: Only memory owned by the heap may be freed by it.

        Params:
            address = The allocation to free.
    */
    override void free(void* address) {
        if (!isInbounds(address))
            return;

        ptrdiff_t offset = this.find(address);
        assert(offset >= 0, "invalid address");
        assert(blocks[offset].flags & BLOCK_FLAG_USED, "double free");

        // Mark the memory as freed and available for reuse.
        this.unclaim(offset);
    }

    /**
        Gets the size of the given allocation.

        Params:
            address = The address of the allocation.

        Returns:
            The size of the allocation, or $(D 0).
    */
    size_t getAllocationSize(void* address) {
        if (!isInbounds(address))
            return 0;

        ptrdiff_t block = this.find(address);
        return block >= 0 ? this.totalBlockUsage(block) : 0;
    }

    /**
        Gets the base address of an allocation.

        Params:
            address = The address of the allocation.

        Returns:
            The base address of the allocation,
            or $(D null).
    */
    void* getAllocationBase(void* address) {
        if (!isInbounds(address))
            return null;

        ptrdiff_t block = this.find(address);
        return block >= 0 ? this.blockToAddress(block) : null;
    }
}

/// Indicates that the subblock is used.
enum BLOCK_FLAG_USED = 0x01;

/// Indicates that the subblock is a part of a larger
/// allocation.
enum BLOCK_FLAG_PARTIAL = 0x02;

// Allocation data
struct BlockInfo {

    /**
        Flags of the block
    */
    size_t flags;

    /**
        Length of the allocation within the block.
    */
    size_t length;
}
