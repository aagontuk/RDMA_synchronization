### Pessimistic ###

Read Path: FAA() -> READ() -> Poll() -> FAA()

Write Path: CAS() -> READ() -> Poll() -> Local Update -> WRITE() -> FAA()

### Broken ###

Read Path: READ() -> Poll() -> READ() -> Poll()

Write Path: CAS() -> READ() -> Poll() -> Increment version -> Write() write verison -> FAA() unlock lock bit

### Broken Fixed ###

Read Path: READ_FENCED() -> Poll() -> READ() -> Poll() -> READ() -> Poll()

Write Path: CAS() -> READ() -> Poll() -> Increment version -> Write() write verison -> FAA() unlock lock bit

### RC ###

Read Path: READ() -> READ() -> Poll(2)

Write Path: CAS() -> READ() -> Poll() -> Increment version -> Write() write verison -> FAA() unlock lock bit

### RC Optimized ###

Read Path: READ() -> READ()

Write Path: CAS() -> READ() -> Poll() -> Increment version -> Write() write verison -> FAA() unlock lock bit
