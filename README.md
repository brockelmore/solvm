# solvm: The EVM inside the EVM

## WTF?
A (slightly) stripped down version of the EVM implemented on top of the EVM using yul and solidity.

## Why?
idk, for fun. Its a fun memory-management challenge. Also I've always wanted scripting in solidity and this is a step in that direction.

## How?
A dynamic in-memory array is used as a jump table for ops. A dynamic in-memory array is used for the simulated EVM's stack variables. The simulated EVM's memory is held at a moveable offset and can move if needed (unlikely unless stack is forced to move).

## Limits
Currently no EVM context or state opcodes (`address`, `balance`, `caller`, `origin`, `callvalue`, `calldataload`, etc.). We can simulate a lot of these in memory if want though, just haven't gotten around to it.

A bunch of opcodes haven't been implemented.

Also bugs. Probably many bugs.

And gas. There are large one-time gas costs, that get amortized with more ops (but not a ton).