extends GutTest

## Unit tests for SaveLock: the lock file that lets one run at a time write a
## save. "Another run" is a real helper process (a ping on Windows, a sleep
## elsewhere), because a lock is live only while its process is alive and only
## the OS can say. So is a process that holds a lock file shut, as an antivirus
## scan can (PowerShell, on Windows only). A lock file that cannot be written is a
## folder in its place, under FOLDER. Every lock sits next to a temp save in
## user:// and is removed after each test, so the developer's real save and its
## lock are never read or written. The helper is killed after each test, pass or
## fail.

## What a temp save's name starts with: after_each() removes every file in
## user:// that starts with it.
const TMP_PREFIX: String = "__test_save_lock_"

## A folder that does not exist until a test makes it.
const FOLDER: String = "user://__test_save_lock_folder"

## A pid no process has: Windows hands out multiples of 4, and Linux numbers its
## processes up to 32768 unless pid_max is raised.
const DEAD_PID: int = 999999

## The pid of the helper process a test starts (another run, or a process that
## holds a lock file shut), or 0.
var _helper_pid: int = 0

func after_each() -> void:
	if _helper_pid > 0:
		OS.kill(_helper_pid)
		_helper_pid = 0
	for file_name: String in DirAccess.get_files_at("user://"):
		if file_name.begins_with(TMP_PREFIX):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + file_name))
	_remove_tree(FOLDER)

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _path(test_name: String) -> String:
	return "user://%s%s.tres" % [TMP_PREFIX, test_name]

func _now() -> int:
	return int(Time.get_unix_time_from_system())

func _global(path: String) -> String:
	return ProjectSettings.globalize_path(path)

func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)

## Deletes `dir_path` and everything under it.
func _remove_tree(dir_path: String) -> void:
	if not DirAccess.dir_exists_absolute(_global(dir_path)):
		return
	for file_name: String in DirAccess.get_files_at(dir_path):
		DirAccess.remove_absolute(_global(dir_path.path_join(file_name)))
	for folder_name: String in DirAccess.get_directories_at(dir_path):
		_remove_tree(dir_path.path_join(folder_name))
	DirAccess.remove_absolute(_global(dir_path))

## Starts a process that lives for about five seconds, as another run does, and
## returns its pid. after_each() kills it.
func _start_other_run() -> int:
	if OS.get_name() == "Windows":
		_helper_pid = OS.create_process("cmd", ["/c", "ping", "-n", "6", "127.0.0.1"])
	else:
		_helper_pid = OS.create_process("sleep", ["5"])
	assert_gt(_helper_pid, 0, "precondition: the helper process started")
	return _helper_pid

## Starts a process that opens the file at `path` with no sharing, as an antivirus
## scan can, so no other process can read it, and holds it for 30 s. after_each()
## kills it.
func _hold_shut(path: String) -> void:
	var command: String = "$f = [System.IO.File]::Open('%s', 'Open', 'ReadWrite', 'None'); Start-Sleep -Seconds 30; $f.Close()" % _global(path)
	_helper_pid = OS.create_process("powershell", ["-NoProfile", "-NonInteractive", "-Command", command])
	assert_gt(_helper_pid, 0, "precondition: the helper process started")

## Writes the lock on the save at `save_path` as a run with this pid and
## heartbeat time would have.
func _write_lock(save_path: String, pid: int, time: int) -> void:
	var file: FileAccess = FileAccess.open(SaveLock.lock_path_for(save_path), FileAccess.WRITE)
	file.store_string("pid=%d\ntime=%d\n" % [pid, time])
	file.close()

## The heartbeat time in the lock on the save at `save_path`, or -1 when there is
## no such line.
func _time_in_lock(save_path: String) -> int:
	for line: String in _read(SaveLock.lock_path_for(save_path)).split("\n"):
		if line.strip_edges().begins_with("time="):
			return line.strip_edges().trim_prefix("time=").to_int()
	return -1

#-----------------------------------------------------------------------------
# ACQUIRE
#-----------------------------------------------------------------------------

func test_the_lock_sits_next_to_the_save() -> void:
	assert_eq(SaveLock.lock_path_for("user://save.tres"), "user://save.tres.lock")

func test_a_free_save_is_acquired() -> void:
	var path := _path("free")
	assert_true(SaveLock.acquire(path), "nobody holds a save with no lock")
	assert_eq(SaveLock.holder_pid(path), OS.get_process_id(), "the lock holds our pid")

func test_the_lock_file_holds_the_pid_and_the_time() -> void:
	var path := _path("format")
	var before := _now()
	SaveLock.acquire(path)
	var lines: PackedStringArray = _read(SaveLock.lock_path_for(path)).strip_edges().split("\n")
	assert_eq(lines.size(), 2, "the lock file is two lines")
	if lines.size() == 2:
		assert_eq(lines[0], "pid=%d" % OS.get_process_id())
		assert_true(lines[1].begins_with("time="), "the second line is the time")
	assert_between(_time_in_lock(path), before, _now(), "the time is when the lock was taken")

func test_our_own_lock_is_acquired_again() -> void:
	var path := _path("own")
	assert_true(SaveLock.acquire(path))
	assert_true(SaveLock.acquire(path), "a run that holds the lock can take it again")
	assert_eq(SaveLock.holder_pid(path), OS.get_process_id())

func test_a_live_run_keeps_its_lock() -> void:
	var path := _path("live")
	var other_pid := _start_other_run()
	_write_lock(path, other_pid, _now())
	assert_false(SaveLock.acquire(path), "a run that is alive and recent holds the save")
	assert_eq(SaveLock.holder_pid(path), other_pid, "its lock is left as it was")

## The lock goes stale STALE_AFTER_SECONDS after its time, not before.
func test_a_heartbeat_inside_the_window_still_holds() -> void:
	var path := _path("recent")
	var other_pid := _start_other_run()
	_write_lock(path, other_pid, _now() - (SaveLock.STALE_AFTER_SECONDS - 10))
	assert_false(SaveLock.acquire(path), "a heartbeat 10 seconds short of stale is live")
	assert_eq(SaveLock.holder_pid(path), other_pid)

func test_a_dead_process_lock_is_taken_over() -> void:
	var path := _path("dead")
	_write_lock(path, DEAD_PID, _now())
	assert_true(SaveLock.acquire(path), "a lock whose process is gone is stale however recent")
	assert_eq(SaveLock.holder_pid(path), OS.get_process_id(), "the lock is ours now")

func test_an_old_heartbeat_is_taken_over() -> void:
	var path := _path("old")
	var other_pid := _start_other_run()
	_write_lock(path, other_pid, _now() - 120)
	assert_true(SaveLock.acquire(path), "a lock nobody refreshed for a while is stale even if its process is alive")
	assert_eq(SaveLock.holder_pid(path), OS.get_process_id(), "the lock is ours now")

## A garbled lock can be read, and names no run, so nobody holds the save.
func test_a_garbled_lock_is_taken_over() -> void:
	var path := _path("garbage")
	var file: FileAccess = FileAccess.open(SaveLock.lock_path_for(path), FileAccess.WRITE)
	file.store_string("this is not a lock")
	file.close()
	assert_eq(SaveLock.holder_pid(path), 0, "a lock with no pid has no holder")
	assert_true(SaveLock.acquire(path), "a lock that names no run cannot hold the save")
	assert_eq(SaveLock.holder_pid(path), OS.get_process_id())

## A lock file this run cannot read, as while an antivirus scan holds it, may be
## another run's: whose it is is not known, so acquire() does not take it, and
## leaves it as it was. The lock here names a run that is gone, which acquire()
## would take over if it could read it.
func test_a_lock_it_cannot_read_is_refused() -> void:
	if OS.get_name() != "Windows":
		pass_test("the helper that holds a file shut is PowerShell")
		return
	var path := _path("acquire_shut")
	_write_lock(path, DEAD_PID, _now())
	var lock_text := _read(SaveLock.lock_path_for(path))
	_hold_shut(SaveLock.lock_path_for(path))
	var shut: bool = await wait_until(func() -> bool: return FileAccess.open(SaveLock.lock_path_for(path), FileAccess.READ) == null, 10.0)
	assert_true(shut, "precondition: the lock file cannot be read")
	assert_false(SaveLock.acquire(path), "a lock whose holder is not known is not taken")
	OS.kill(_helper_pid)
	_helper_pid = 0
	var open_again: bool = await wait_until(func() -> bool: return FileAccess.open(SaveLock.lock_path_for(path), FileAccess.READ) != null, 10.0)
	assert_true(open_again, "precondition: the lock file can be read again")
	assert_eq(_read(SaveLock.lock_path_for(path)), lock_text, "the lock was left as it was")

## A lock acquire() cannot write does not name this run, so it is not taken either.
## A folder in the lock file's place makes one on every platform.
func test_a_lock_it_cannot_write_is_refused() -> void:
	# Under FOLDER, which after_each() removes with everything in it.
	var path := FOLDER.path_join("unwritable.tres")
	DirAccess.make_dir_recursive_absolute(_global(SaveLock.lock_path_for(path)))
	assert_false(SaveLock.acquire(path), "a lock this run could not write is not its own")
	assert_eq(SaveLock.holder_pid(path), 0, "and nothing names this run")

## A save given with --save may sit in a folder that does not exist yet.
func test_acquire_makes_the_folder_of_a_new_save() -> void:
	var path := FOLDER.path_join("runs/new.tres")
	assert_true(SaveLock.acquire(path))
	assert_eq(SaveLock.holder_pid(path), OS.get_process_id(), "the lock is written although its folder was new")

#-----------------------------------------------------------------------------
# HOLDER
#-----------------------------------------------------------------------------

func test_holder_pid_is_zero_without_a_lock() -> void:
	assert_eq(SaveLock.holder_pid(_path("none")), 0)

#-----------------------------------------------------------------------------
# REFUSAL REASON
#-----------------------------------------------------------------------------

func test_a_refusal_names_the_run_that_holds_the_lock() -> void:
	var path := _path("reason_live")
	var other_pid := _start_other_run()
	_write_lock(path, other_pid, _now())
	assert_false(SaveLock.acquire(path), "precondition: another live run holds the save")
	assert_eq(SaveLock.refusal_reason(path), "in use by another run (pid %d)" % other_pid)

## A lock that names no run has no pid to name, so the reason never says "pid 0".
func test_the_refusal_of_a_lock_that_names_no_run_names_no_pid() -> void:
	# Under FOLDER, which after_each() removes with everything in it.
	var path := FOLDER.path_join("reason_unwritable.tres")
	DirAccess.make_dir_recursive_absolute(_global(SaveLock.lock_path_for(path)))
	assert_false(SaveLock.acquire(path), "precondition: the lock cannot be written")
	assert_eq(SaveLock.refusal_reason(path), "possibly in use by another run (its lock file could not be read or written)")

#-----------------------------------------------------------------------------
# REFRESH
#-----------------------------------------------------------------------------

func test_refresh_rewrites_the_time_of_our_lock() -> void:
	var path := _path("refresh_own")
	_write_lock(path, OS.get_process_id(), _now() - 30)
	var before := _now()
	assert_eq(SaveLock.refresh(path), SaveLock.Heartbeat.HELD, "the lock is still ours")
	assert_gte(_time_in_lock(path), before, "the heartbeat moves the time to now")
	assert_eq(SaveLock.holder_pid(path), OS.get_process_id())

func test_refresh_leaves_another_runs_lock_alone() -> void:
	var path := _path("refresh_other")
	var other_pid := _start_other_run()
	var old_time := _now() - 30
	_write_lock(path, other_pid, old_time)
	assert_eq(SaveLock.refresh(path), SaveLock.Heartbeat.LOST, "it is not ours")
	assert_eq(SaveLock.holder_pid(path), other_pid)
	assert_eq(_time_in_lock(path), old_time, "another run's heartbeat is its own to keep")

## A run that hung past STALE_AFTER_SECONDS can have its lock taken over. Its
## next heartbeat is how it finds out.
func test_refresh_reports_a_lost_lock() -> void:
	var path := _path("refresh_lost")
	assert_true(SaveLock.acquire(path))
	assert_eq(SaveLock.refresh(path), SaveLock.Heartbeat.HELD, "precondition: the lock is ours until it is taken over")
	var other_pid := _start_other_run()
	var other_time := _now() - 5
	_write_lock(path, other_pid, other_time)
	assert_eq(SaveLock.refresh(path), SaveLock.Heartbeat.LOST, "a lock another run holds now is not ours any more")
	assert_eq(SaveLock.holder_pid(path), other_pid, "and it is left as it is")
	assert_eq(_time_in_lock(path), other_time, "its heartbeat is not touched")

## A lock file that is gone may mean another run took the save over and let go, so
## it is no more ours than a lock another run holds, and none is made in its place.
func test_refresh_reports_a_lock_that_is_gone() -> void:
	var path := _path("refresh_none")
	assert_eq(SaveLock.refresh(path), SaveLock.Heartbeat.LOST, "no lock is not ours")
	assert_false(FileAccess.file_exists(SaveLock.lock_path_for(path)), "only a lock that is ours is refreshed")

## A lock file that is there but cannot be read, as while an antivirus scan holds
## it, says nothing about whose it is. The heartbeat reports that and changes
## nothing, so the run can read it again at its next one.
func test_refresh_reports_a_lock_it_cannot_read() -> void:
	if OS.get_name() != "Windows":
		pass_test("the helper that holds a file shut is PowerShell")
		return
	var path := _path("refresh_shut")
	assert_true(SaveLock.acquire(path))
	var lock_text := _read(SaveLock.lock_path_for(path))
	_hold_shut(SaveLock.lock_path_for(path))
	var shut: bool = await wait_until(func() -> bool: return FileAccess.open(SaveLock.lock_path_for(path), FileAccess.READ) == null, 10.0)
	assert_true(shut, "precondition: the lock file cannot be read")
	assert_eq(SaveLock.refresh(path), SaveLock.Heartbeat.UNREADABLE, "the heartbeat cannot tell whose the lock is")
	OS.kill(_helper_pid)
	_helper_pid = 0
	var open_again: bool = await wait_until(func() -> bool: return FileAccess.open(SaveLock.lock_path_for(path), FileAccess.READ) != null, 10.0)
	assert_true(open_again, "precondition: the lock file can be read again")
	assert_eq(_read(SaveLock.lock_path_for(path)), lock_text, "the lock was left as it was")
	assert_eq(SaveLock.refresh(path), SaveLock.Heartbeat.HELD, "and the next heartbeat finds it ours")

#-----------------------------------------------------------------------------
# RELEASE
#-----------------------------------------------------------------------------

func test_release_deletes_our_lock() -> void:
	var path := _path("release_own")
	SaveLock.acquire(path)
	assert_eq(SaveLock.holder_pid(path), OS.get_process_id(), "precondition: the lock is ours")
	SaveLock.release(path)
	assert_false(FileAccess.file_exists(SaveLock.lock_path_for(path)), "the lock file is gone")
	assert_eq(SaveLock.holder_pid(path), 0)

func test_release_leaves_another_runs_lock() -> void:
	var path := _path("release_other")
	var other_pid := _start_other_run()
	_write_lock(path, other_pid, _now())
	SaveLock.release(path)
	assert_eq(SaveLock.holder_pid(path), other_pid, "a lock that is not ours is never deleted")

#-----------------------------------------------------------------------------
# PROCESSES
#-----------------------------------------------------------------------------

func test_is_process_alive() -> void:
	assert_true(SaveLock.is_process_alive(OS.get_process_id()), "this run is alive")
	assert_false(SaveLock.is_process_alive(DEAD_PID), "no process has this pid")

func test_no_pid_below_one_is_alive() -> void:
	assert_false(SaveLock.is_process_alive(0))
	assert_false(SaveLock.is_process_alive(-1), "-1 would mean every process to kill -0")
