import redis, unittest, asyncdispatch, os, strutils

type
  RedisServerVersion* = tuple[major, minor, patch: int]

proc parseRedisVersion*(infoStr: string): RedisServerVersion =
  for line in infoStr.splitLines():
    let stripped = line.strip()
    if stripped.startsWith("redis_version:"):
      let verStr = stripped.split(':')[1].strip()
      let parts = verStr.split('.')
      let maj = if parts.len > 0: parseInt(parts[0]) else: 0
      let min = if parts.len > 1: parseInt(parts[1]) else: 0
      var patchStr = if parts.len > 2: parts[2] else: "0"
      if '-' in patchStr:
        patchStr = patchStr.split('-')[0]
      let patch = try: parseInt(patchStr) except ValueError: 0
      return (maj, min, patch)
  return (0, 0, 0)

proc getTestHost*(): string =
  let envHost = getEnv("REDIS_HOST", "")
  if envHost.len > 0:
    return envHost
  return "localhost"

proc getTestPort*(): Port =
  let envPort = getEnv("REDIS_PORT", "")
  if envPort.len > 0:
    return Port(parseInt(envPort))
  return 6379.Port

proc getTestDb*(): int =
  let envDb = getEnv("REDIS_TEST_DB", "")
  if envDb.len > 0:
    return parseInt(envDb)
  return 15

proc openTestClient*(): Redis =
  result = redis.open(getTestHost(), getTestPort())
  let db = getTestDb()
  if db != 0:
    discard result.select(db)
  discard result.flushdb()

proc openAsyncTestClient*(): Future[AsyncRedis] {.async.} =
  result = await redis.openAsync(getTestHost(), getTestPort())
  let db = getTestDb()
  if db != 0:
    discard await result.select(db)

proc getServerVersion*(r: Redis): RedisServerVersion =
  let info = r.info()
  return parseRedisVersion(info)

proc getServerVersion*(r: AsyncRedis): Future[RedisServerVersion] {.async.} =
  let info = await r.info()
  return parseRedisVersion(info)

proc isAtLeastVersion*(r: Redis, major: int, minor: int = 0): bool =
  let v = r.getServerVersion()
  if v.major != major:
    return v.major > major
  return v.minor >= minor

proc isAtLeastVersion*(r: AsyncRedis, major: int, minor: int = 0): Future[bool] {.async.} =
  let v = await r.getServerVersion()
  if v.major != major:
    return v.major > major
  return v.minor >= minor

template xfailBefore*(r: Redis, minMajor: int, minMinor: int, body: untyped) =
  if r.isAtLeastVersion(minMajor, minMinor):
    body
  else:
    expect RedisError:
      body
