//
//  KCMemoryAccessTests.m
//  MemoryAccessTests
//
//  Created by Kevin Conner on 12/2/12.
//  Copyright (c) 2012 Kevin Conner. All rights reserved.
//

#import "KCMemoryAccessTests.h"

// Begin by updating these definitions to match your use case.
// To test a 128x128x128 cube of bytes, you could try setting BASE to 8 since 8^7 = 128^3, and setting Item to int8_t.

// Use an integer type of the size you're accessing.
typedef int8_t Item;

// How many items are in your array? The test buffer will have BASE^7 items,
// so try a value near the seventh root of your item count.
#define BASE 8

// Run the test how many times for each case?
// If you use a small base and the process completes immediately, you can counterbalance by running more tests.
static int const kTestsPerCase = 10;



typedef enum {
    ItemOperationRead,
    ItemOperationWrite,
    ItemOperationReadWrite,
} ItemOperation;

#define B0 1
#define B1 BASE
#define B2 (B1 * BASE) // base^2
#define B3 (B2 * BASE) // base^3
#define B4 (B3 * BASE)
#define B5 (B4 * BASE)
#define B6 (B5 * BASE)
#define B7 (B6 * BASE)

static int const kItemCount = B7;
static Item buffer[kItemCount];



// We will test reading, writing, and read-modify-write.
// You can also add a case for doing work similar to your own inner loop.
static inline Item touchItem(Item *item, ItemOperation operation) {
    switch (operation) {
        case ItemOperationRead: {
            // The return values in this file exist only to get this statement not to be optimized out.
            return *item + 1; 
        }
        case ItemOperationWrite:
            *item = (Item) 1;
            return 1;
        case ItemOperationReadWrite:
            *item = 1 - *item;
            return 2;
    }
    return 0;
}

// Write to each item in the buffer once, treating it as a 1D, 2D, 3D or 4D array with specified dimensions.
// Memory access is done in column order. If we did this in row order then it would be purely sequential anyway.
// The idea is to see which sizes of inner loops make a difference.
// Run this with the profiler, and then view the line-by-line view of +runTests to see which access patterns are cheap or expensive.
static Item testMemoryAccessPattern(int dim1, int dim2, int dim3, int dim4, ItemOperation op)
{
    Item lastItem = 0;
    
    assert(dim4 * dim3 * dim2 * dim1 == kItemCount);
    for (int r = 0; r < kTestsPerCase; r++) {
        
        if (dim2 == 1 && dim3 == 1 && dim4 == 1) {
            Item *item1 = &buffer[0];
            for (int i1 = 0; i1 < dim1; i1++, item1++) {
                lastItem = touchItem(item1, op); // buffer[i1]
            }
        }
        else if (dim3 == 1 && dim4 == 1) {
            Item *item2 = &buffer[0];
            for (int i2 = 0; i2 < dim2; i2++, item2++) {
                Item *item1 = item2;
                for (int i1 = 0; i1 < dim1; i1++, item1 += dim2) {
                    lastItem = touchItem(item1, op); // buffer[i1 * dim2 + i2], that is, buffer[i1][i2]
                }
            }
        }
        else if (dim4 == 1) {
            const int dim2dim3 = dim2 * dim3;
            
            Item *item3 = &buffer[0];
            for (int i3 = 0; i3 < dim3; i3++, item3++) {
                Item *item2 = item3;
                for (int i2 = 0; i2 < dim2; i2++, item2 += dim3) {
                    Item *item1 = item2;
                    for (int i1 = 0; i1 < dim1; i1++, item1 += dim2dim3) {
                        lastItem = touchItem(item1, op); // buffer[(i1 * dim2 + i2) * dim3 + i3], that is, buffer[i1][i2][i3]
                    }
                }
            }
        }
        else {
            const int dim3dim4 = dim3 * dim4;
            const int dim2dim3dim4 = dim2 * dim3dim4;
            
            Item *item4 = &buffer[0];
            for (int i4 = 0; i4 < dim4; i4++, item4++) {
                Item *item3 = item4;
                for (int i3 = 0; i3 < dim3; i3++, item3 += dim4) {
                    Item *item2 = item3;
                    for (int i2 = 0; i2 < dim2; i2++, item2 += dim3dim4) {
                        Item *item1 = item2;
                        for (int i1 = 0; i1 < dim1; i1++, item1 += dim2dim3dim4) {
                            lastItem = touchItem(item1, op); // buffer[((i1 * dim2 + i2) * dim3 + i3) * dim4 + i4], that is, buffer[i1][i2][i3][i4]
                        }
                    }
                }
            }
        }
        
    }
    
    return lastItem; // The only reason we return this is to make the compiler not optimize out the read operation.
}

@implementation KCMemoryAccessTests

+ (int)runTests
{
    // First, touch every part of the buffer just to prepare.
    for (int i = 0; i < kItemCount; i++) {
        touchItem(&buffer[i], ItemOperationWrite);
    }
    
    // The following three blocks are identical except for op.
    // I've unrolled this loop so we can compare times for different operations.
    {
        ItemOperation op = ItemOperationRead;
        
        // One run of all B7 items - I expect this to be fastest.
        testMemoryAccessPattern(B7, B0, B0, B0, op);
        
        // 2D column-ordered
        testMemoryAccessPattern(B6, B1, B0, B0, op); // B1 runs of B6 items
        testMemoryAccessPattern(B5, B2, B0, B0, op); // B2 runs of B5 items
        testMemoryAccessPattern(B4, B3, B0, B0, op); // B3 runs of B4 items
        testMemoryAccessPattern(B3, B4, B0, B0, op); // B4 runs of B3 items
        testMemoryAccessPattern(B2, B5, B0, B0, op); // B5 runs of B2 items
        testMemoryAccessPattern(B1, B6, B0, B0, op); // B6 runs of B1 items
        
        // 3D column-ordered
        testMemoryAccessPattern(B5, B1, B1, B0, op); // B1 runs of B2 sub-runs of B5 items
        testMemoryAccessPattern(B4, B2, B1, B0, op); // B1 runs of B2 sub-runs of B4 items
        testMemoryAccessPattern(B3, B3, B1, B0, op); // etc
        testMemoryAccessPattern(B2, B4, B1, B0, op);
        testMemoryAccessPattern(B1, B5, B1, B0, op);
        testMemoryAccessPattern(B4, B1, B2, B0, op);
        testMemoryAccessPattern(B3, B2, B2, B0, op);
        testMemoryAccessPattern(B2, B3, B2, B0, op);
        testMemoryAccessPattern(B1, B4, B2, B0, op);
        testMemoryAccessPattern(B3, B1, B3, B0, op);
        testMemoryAccessPattern(B2, B2, B3, B0, op);
        testMemoryAccessPattern(B1, B3, B3, B0, op);
        testMemoryAccessPattern(B2, B1, B4, B0, op);
        testMemoryAccessPattern(B1, B2, B4, B0, op);
        testMemoryAccessPattern(B1, B1, B5, B0, op);
        
        // 4D column-ordered
        testMemoryAccessPattern(B4, B1, B1, B1, op); // B1 runs of B1 sub-runs of B1 sub-sub-runs of B4 items
        testMemoryAccessPattern(B3, B2, B1, B1, op); // etc
        testMemoryAccessPattern(B2, B3, B1, B1, op);
        testMemoryAccessPattern(B1, B4, B1, B1, op);
        testMemoryAccessPattern(B3, B1, B2, B1, op);
        testMemoryAccessPattern(B2, B2, B2, B1, op);
        testMemoryAccessPattern(B1, B3, B2, B1, op);
        testMemoryAccessPattern(B2, B1, B3, B1, op);
        testMemoryAccessPattern(B1, B2, B3, B1, op);
        testMemoryAccessPattern(B1, B1, B4, B1, op);
        testMemoryAccessPattern(B3, B1, B1, B2, op);
        testMemoryAccessPattern(B2, B2, B1, B2, op);
        testMemoryAccessPattern(B1, B3, B1, B2, op);
        testMemoryAccessPattern(B2, B1, B2, B2, op);
        testMemoryAccessPattern(B1, B2, B2, B2, op);
        testMemoryAccessPattern(B1, B1, B3, B2, op);
        testMemoryAccessPattern(B2, B1, B1, B3, op);
        testMemoryAccessPattern(B1, B2, B1, B3, op);
        testMemoryAccessPattern(B1, B1, B2, B3, op);
        testMemoryAccessPattern(B1, B1, B1, B4, op); // Worst case?
    }
    
    {
        ItemOperation op = ItemOperationWrite;
        
        // One run of all B7 items - I expect this to be fastest.
        testMemoryAccessPattern(B7, B0, B0, B0, op);
        
        // 2D column-ordered
        testMemoryAccessPattern(B6, B1, B0, B0, op); // B1 runs of B6 items
        testMemoryAccessPattern(B5, B2, B0, B0, op); // B2 runs of B5 items
        testMemoryAccessPattern(B4, B3, B0, B0, op); // B3 runs of B4 items
        testMemoryAccessPattern(B3, B4, B0, B0, op); // B4 runs of B3 items
        testMemoryAccessPattern(B2, B5, B0, B0, op); // B5 runs of B2 items
        testMemoryAccessPattern(B1, B6, B0, B0, op); // B6 runs of B1 items
        
        // 3D column-ordered
        testMemoryAccessPattern(B5, B1, B1, B0, op); // B1 runs of B2 sub-runs of B5 items
        testMemoryAccessPattern(B4, B2, B1, B0, op); // B1 runs of B2 sub-runs of B4 items
        testMemoryAccessPattern(B3, B3, B1, B0, op); // etc
        testMemoryAccessPattern(B2, B4, B1, B0, op);
        testMemoryAccessPattern(B1, B5, B1, B0, op);
        testMemoryAccessPattern(B4, B1, B2, B0, op);
        testMemoryAccessPattern(B3, B2, B2, B0, op);
        testMemoryAccessPattern(B2, B3, B2, B0, op);
        testMemoryAccessPattern(B1, B4, B2, B0, op);
        testMemoryAccessPattern(B3, B1, B3, B0, op);
        testMemoryAccessPattern(B2, B2, B3, B0, op);
        testMemoryAccessPattern(B1, B3, B3, B0, op);
        testMemoryAccessPattern(B2, B1, B4, B0, op);
        testMemoryAccessPattern(B1, B2, B4, B0, op);
        testMemoryAccessPattern(B1, B1, B5, B0, op);
        
        // 4D column-ordered
        testMemoryAccessPattern(B4, B1, B1, B1, op); // B1 runs of B1 sub-runs of B1 sub-sub-runs of B4 items
        testMemoryAccessPattern(B3, B2, B1, B1, op); // etc
        testMemoryAccessPattern(B2, B3, B1, B1, op);
        testMemoryAccessPattern(B1, B4, B1, B1, op);
        testMemoryAccessPattern(B3, B1, B2, B1, op);
        testMemoryAccessPattern(B2, B2, B2, B1, op);
        testMemoryAccessPattern(B1, B3, B2, B1, op);
        testMemoryAccessPattern(B2, B1, B3, B1, op);
        testMemoryAccessPattern(B1, B2, B3, B1, op);
        testMemoryAccessPattern(B1, B1, B4, B1, op);
        testMemoryAccessPattern(B3, B1, B1, B2, op);
        testMemoryAccessPattern(B2, B2, B1, B2, op);
        testMemoryAccessPattern(B1, B3, B1, B2, op);
        testMemoryAccessPattern(B2, B1, B2, B2, op);
        testMemoryAccessPattern(B1, B2, B2, B2, op);
        testMemoryAccessPattern(B1, B1, B3, B2, op);
        testMemoryAccessPattern(B2, B1, B1, B3, op);
        testMemoryAccessPattern(B1, B2, B1, B3, op);
        testMemoryAccessPattern(B1, B1, B2, B3, op);
        testMemoryAccessPattern(B1, B1, B1, B4, op); // Worst case?
    }
    
    {
        ItemOperation op = ItemOperationReadWrite;
        
        // One run of all B7 items - I expect this to be fastest.
        testMemoryAccessPattern(B7, B0, B0, B0, op);
        
        // 2D column-ordered
        testMemoryAccessPattern(B6, B1, B0, B0, op); // B1 runs of B6 items
        testMemoryAccessPattern(B5, B2, B0, B0, op); // B2 runs of B5 items
        testMemoryAccessPattern(B4, B3, B0, B0, op); // B3 runs of B4 items
        testMemoryAccessPattern(B3, B4, B0, B0, op); // B4 runs of B3 items
        testMemoryAccessPattern(B2, B5, B0, B0, op); // B5 runs of B2 items
        testMemoryAccessPattern(B1, B6, B0, B0, op); // B6 runs of B1 items
        
        // 3D column-ordered
        testMemoryAccessPattern(B5, B1, B1, B0, op); // B1 runs of B2 sub-runs of B5 items
        testMemoryAccessPattern(B4, B2, B1, B0, op); // B1 runs of B2 sub-runs of B4 items
        testMemoryAccessPattern(B3, B3, B1, B0, op); // etc
        testMemoryAccessPattern(B2, B4, B1, B0, op);
        testMemoryAccessPattern(B1, B5, B1, B0, op);
        testMemoryAccessPattern(B4, B1, B2, B0, op);
        testMemoryAccessPattern(B3, B2, B2, B0, op);
        testMemoryAccessPattern(B2, B3, B2, B0, op);
        testMemoryAccessPattern(B1, B4, B2, B0, op);
        testMemoryAccessPattern(B3, B1, B3, B0, op);
        testMemoryAccessPattern(B2, B2, B3, B0, op);
        testMemoryAccessPattern(B1, B3, B3, B0, op);
        testMemoryAccessPattern(B2, B1, B4, B0, op);
        testMemoryAccessPattern(B1, B2, B4, B0, op);
        testMemoryAccessPattern(B1, B1, B5, B0, op);
        
        // 4D column-ordered
        testMemoryAccessPattern(B4, B1, B1, B1, op); // B1 runs of B1 sub-runs of B1 sub-sub-runs of B4 items
        testMemoryAccessPattern(B3, B2, B1, B1, op); // etc
        testMemoryAccessPattern(B2, B3, B1, B1, op);
        testMemoryAccessPattern(B1, B4, B1, B1, op);
        testMemoryAccessPattern(B3, B1, B2, B1, op);
        testMemoryAccessPattern(B2, B2, B2, B1, op);
        testMemoryAccessPattern(B1, B3, B2, B1, op);
        testMemoryAccessPattern(B2, B1, B3, B1, op);
        testMemoryAccessPattern(B1, B2, B3, B1, op);
        testMemoryAccessPattern(B1, B1, B4, B1, op);
        testMemoryAccessPattern(B3, B1, B1, B2, op);
        testMemoryAccessPattern(B2, B2, B1, B2, op);
        testMemoryAccessPattern(B1, B3, B1, B2, op);
        testMemoryAccessPattern(B2, B1, B2, B2, op);
        testMemoryAccessPattern(B1, B2, B2, B2, op);
        testMemoryAccessPattern(B1, B1, B3, B2, op);
        testMemoryAccessPattern(B2, B1, B1, B3, op);
        testMemoryAccessPattern(B1, B2, B1, B3, op);
        testMemoryAccessPattern(B1, B1, B2, B3, op);
        testMemoryAccessPattern(B1, B1, B1, B4, op); // Worst case?
    }
    
    // Actually using the Read result by returning it outside the compilation unit
    // forces the compiler not to optimize away the Read operation.
    return (int) testMemoryAccessPattern(B7, B0, B0, B0, ItemOperationRead);
}

@end
