class_name SaveLock extends RefCounted

## SaveLock
## Lets one run at a time write a save. A run that plays a save takes a lock file
## next to it, "<save>.lock", and gives it up when its window closes. The file
## holds two lines, the holder's process id and the time of its last heartbeat:
##
##     pid=<OS.get_process_id()>
##     time=<unix time>
##
## A lock is live when its process is alive and its time is within
## STALE_AFTER_SECONDS. A second run that finds a live lock plays the save in
## memory instead of overwriting the first run's progress. A lock that is not
## live (its run crashed or was killed, or hung) is stale, and the next run takes
## it over. A run that hung finds out at its next heartbeat, when refresh() says
## the lock is no longer its own. The lock is advisory: two runs that open one
## save within the same few milliseconds can both win it. Statics only. Every
## path comes from the caller, so a test can point it at a temp save.

#-----------------------------------------------------------------------------
# ENUMS AND CONSTANTS
#-----------------------------------------------------------------------------

## What a heartbeat (refresh()) finds.
enum Heartbeat {
	## The lock is this run's, and its time is now.
	HELD,
	## The lock is not this run's any more: another run's lock is there now (this
	## run hung past STALE_AFTER_SECONDS and was taken over), or the lock file is
	## gone (which may mean another run took the save over and then let go).
	LOST,
	## The lock file is there but cannot be read, as while another process (an
	## antivirus scan, say) holds it. Whose it is is not known: nothing is changed,
	## and the next heartbeat reads it again.
	UNREADABLE,
}

## How long a lock stays live without a heartbeat, in seconds. The SaveTimer's
## tick, every 5 seconds, is the heartbeat, so a run that is alive keeps its lock.
const STALE_AFTER_SECONDS: int = 60

#-----------------------------------------------------------------------------
# LOCKING
#-----------------------------------------------------------------------------

## The lock file of the save at `save_path`: "user://save.tres" gives
## "user://save.tres.lock".
static func lock_path_for(save_path: String) -> String:
	return save_path + ".lock"

## Takes the lock on the save at `save_path`: writes the lock file with this run's
## pid and the time now. Returns true when there was no lock, the lock was stale or
## it was already this run's. Returns false when another live run holds it, and
## leaves that run's lock as it was. It makes the save's folder first, which a
## --save file in a new folder does not have yet. A lock file that still cannot be
## written is logged, and the run goes on without a lock.
static func acquire(save_path: String) -> bool:
	var lock: Dictionary = _read_lock(save_path)
	if not lock.is_empty() and int(lock["pid"]) != OS.get_process_id() and _is_live(lock):
		return false
	# A folder that cannot be made shows up as the lock file that cannot be opened.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_path.get_base_dir()))
	_write_lock(save_path)
	return true

## The heartbeat: moves the time in the lock on the save at `save_path` to now while
## the lock is still this run's (HELD), and otherwise says what it found and leaves
## things as they are: LOST when another run's lock is there now, or the lock file is
## gone, and UNREADABLE when the lock file is there but cannot be read. A run that
## gets LOST must stop writing the save; one that gets UNREADABLE reads the lock
## again at its next heartbeat.
static func refresh(save_path: String) -> Heartbeat:
	var lock_path: String = lock_path_for(save_path)
	if not FileAccess.file_exists(lock_path):
		return Heartbeat.LOST
	var file: FileAccess = FileAccess.open(lock_path, FileAccess.READ)
	if file == null:
		return Heartbeat.UNREADABLE
	var lock: Dictionary = _parse_lock(file.get_as_text())
	file.close()
	if lock.is_empty() or int(lock["pid"]) != OS.get_process_id():
		return Heartbeat.LOST
	_write_lock(save_path)
	return Heartbeat.HELD

## Deletes the lock on the save at `save_path` when it is this run's. Another
## run's lock is never deleted.
static func release(save_path: String) -> void:
	if holder_pid(save_path) != OS.get_process_id():
		return
	var lock_path: String = lock_path_for(save_path)
	var error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(lock_path))
	if error != OK:
		Log.warn("SaveLock: Could not delete %s (error %d)" % [lock_path, error])

## The process id the lock on the save at `save_path` names, or 0 when there is no
## lock or it names no process. It does not say whether that run is still alive.
static func holder_pid(save_path: String) -> int:
	var lock: Dictionary = _read_lock(save_path)
	return 0 if lock.is_empty() else int(lock["pid"])

## True when the process with this pid is running. This run's own pid always is.
## OS.is_process_running() only knows the processes this one started, so the OS is
## asked: on Windows `tasklist` filtered to the pid, which prints the process's row
## with the pid in quotes when it runs (about 100 ms); elsewhere `kill -0`, which
## exits 0 when the process can be signalled. A check that cannot run counts the
## process as gone.
static func is_process_alive(pid: int) -> bool:
	# To kill -0, 0 is a process group and a negative pid is a group or every
	# process, so none of them names one process.
	if pid <= 0:
		return false
	if pid == OS.get_process_id():
		return true
	var output: Array = []
	if OS.get_name() == "Windows":
		OS.execute("tasklist", ["/FI", "PID eq %d" % pid, "/NH", "/FO", "CSV"], output)
		return not output.is_empty() and String(output[0]).contains("\"%d\"" % pid)
	# Its error text is read too, so a process that is gone prints nothing here.
	return OS.execute("kill", ["-0", str(pid)], output, true) == 0

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## The lock on the save at `save_path` as {"pid": int, "time": int}, or {} when
## there is no lock, it cannot be read, or it names no process (an empty or
## garbled file). A lock with no time reads as time 0, so it is stale.
static func _read_lock(save_path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(lock_path_for(save_path), FileAccess.READ)
	if file == null:
		return {}
	var lock: Dictionary = _parse_lock(file.get_as_text())
	file.close()
	return lock

## A lock file's text as {"pid": int, "time": int}, or {} when it names no process.
static func _parse_lock(text: String) -> Dictionary:
	var fields: Dictionary = {}
	for line: String in text.split("\n"):
		var parts: PackedStringArray = line.strip_edges().split("=", true, 1)
		if parts.size() == 2:
			fields[parts[0]] = parts[1].to_int()
	if int(fields.get("pid", 0)) <= 0:
		return {}
	return {"pid": int(fields["pid"]), "time": int(fields.get("time", 0))}

## Writes this run's pid and the time now to the lock file of the save at
## `save_path`, replacing what was there.
static func _write_lock(save_path: String) -> void:
	var lock_path: String = lock_path_for(save_path)
	var file: FileAccess = FileAccess.open(lock_path, FileAccess.WRITE)
	if file == null:
		Log.warn("SaveLock: Could not write %s (error %d), so this run holds no lock on its save" % [lock_path, FileAccess.get_open_error()])
		return
	file.store_string("pid=%d\ntime=%d\n" % [OS.get_process_id(), int(Time.get_unix_time_from_system())])
	file.close()

## True when the lock's time is within STALE_AFTER_SECONDS and its process is
## alive. The time is checked first, so the process check, the slow one, only runs
## for a recent lock.
static func _is_live(lock: Dictionary) -> bool:
	var age: float = Time.get_unix_time_from_system() - float(lock["time"])
	return age <= STALE_AFTER_SECONDS and is_process_alive(int(lock["pid"]))
