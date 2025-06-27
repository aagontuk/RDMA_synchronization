### Pessimistic ###

Read Path: FAA(unsignaled) [inc reader] -> READ() -> Poll() -> check if writer locked -> FAA(unsignaled) [dec reader]

Write Path: CAS() -> READ() -> Poll() -> Local Update -> WRITE() -> FAA()

### Broken ###

Read Path: READ() -> Poll() -> READ() -> Poll()

Write Path: CAS() -> READ() -> Poll() -> Increment version -> Write() write verison -> FAA() unlock lock bit

### Broken Fixed ###

Read Path: READ_FENCED() -> Poll() -> READ() -> Poll() -> READ() -> Poll()

Write Path: CAS() -> READ() -> Poll() -> Increment version -> Write() write verison -> FAA() unlock lock bit

**The fence means that the processing of this WR will be blocked until all prior posted RDMA Read and Atomic WRs will be completed**

### Broken Fixed Optimized ###

Read Path: READ_FENCED() -> READ_FENCED() -> READ() -> Poll()

### RC ###

Read Path: READ(unsignaled) -> READ() -> Poll(1)

Write Path: CAS() -> READ() -> Poll() -> Increment version -> Write() write verison -> FAA() unlock lock bit

### RC Optimized ###

Read Path: READ() -> READ()

Write Path: CAS() -> READ() -> Poll() -> Increment version -> Write() write verison -> FAA() unlock lock bit
