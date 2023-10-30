# shellcheck shell=bash

task.has_var() # [name]...
{
	until [ $# -eq 0 ]
	do
		local name="$1"; shift

		[ -n "${!name-}" ] || return 1
	done
}

task.has_fun() # [name]...
{
	while [ $# -gt 0 ]
	do
		local name="$1"; shift

		declare -f -F "$name" >/dev/null || return 1
	done
}

task.assert_var() # task_file [name]...
{
	local task_file="$1"; shift

	while [ $# -gt 0 ]
	do
		local name="$1"; shift

		if ! task.has_var "$name"
		then
			echo "$task_file: Task needs a '$name' variable!" >&2
			return 1
		fi
	done
}

task.assert_fun() # task_file [name]...
{
	local task_file="$1"; shift

	while [ $# -gt 0 ]
	do
		local name="$1"; shift

		if ! task.has_fun "$name"
		then
			error "$task_file: Task needs a '$name' function!"; return
		fi
	done
}

task.pids() # name dest_var
{
	local name="$1"
	local dest_var="$2"

	local runfile="$TASKMASTER_HOME/$RUNNING_DIR/$name$RUN_SUFFIX"

	if ! [ -f "$runfile" ]
	then
		error "Task '$name' is not running!"; return
	fi

	mapfile -t "$dest_var" < "$runfile"
}

task.is_available() # name
{
	local name="$1"
	local filename="$name$TASK_SUFFIX"

	[ -f "$TASKMASTER_HOME/$AVAILABLE_DIR/$filename" ]
}

task.is_enabled() # name
{
	local name="$1"
	local filename="$name$TASK_SUFFIX"

	[ -f "$TASKMASTER_HOME/$ENABLED_DIR/$filename" ]
}

task.is_started() # name
{
	local name="$1"
	local runfile="$TASKMASTER_HOME/$RUNNING_DIR/$name$RUN_SUFFIX"

	[ -f "$runfile" ]
}

task.time_started() # name
{
	stat -c %Y "$TASKMASTER_HOME/$RUNNING_DIR/$name$RUN_SUFFIX"
}

# shellcheck disable=SC2034
task.load() # name
{
	local name="$1"
	local filename="$name$TASK_SUFFIX"

	if task.is_available "$name"
	then
		# shellcheck source=/dev/null
		source "$TASKMASTER_HOME/$AVAILABLE_DIR/$filename"

		# TODO: Set all values or default values
		task.assert_fun "$name" start

		process_count="${process_count:-$DEFAULT_PROCESS_COUNT}"
		restart="${restart:-$DEFAULT_RESTART}"
		success_status="${success_status:-$DEFAULT_SUCCESS_STATUS}"
		retry="${retry:-$DEFAULT_RETRY}"

		min_runtime_s=$(parse_duration "${min_runtime:-$DEFAULT_MIN_RUNTIME}")
		stop_timeout_s=$(parse_duration "${stop_timeout:-$DEFAULT_STOP_TIMEOUT}")

		stop_signal="${stop_signal:-$DEFAULT_STOP_SIGNAL}"
		stdout="${stdout:-$DEFAULT_STDOUT}"
		stderr="${stderr:-$DEFAULT_STDERR}"
		umask="${umask:-$DEFAULT_UMASK}"
		uid="${uid:-$DEFAULT_UID}"
		gid="${gid:-$DEFAULT_GID}"
	else
		error "No task named '$name' is available!"; return
	fi
}

task.is_running() # name
{
	local name="$1"

	task.is_started "$name"

	local pids

	local runtime min_runtime_s

	task.pids "$name" pids 2>/dev/null || return

	for pid in "${pids[@]}"
	do
		kill -0 "$pid" 2>/dev/null
	done

	runtime=$(($(date +%s) - $(task.time_started "$name")))

	min_runtime_s=$(
		task.load "$name"

		echo "$min_runtime_s"
	) || return 2

	[ "$runtime" -ge "$min_runtime_s" ]
}

task.is_stopping() # name
{
	local name="$1"

	[ -f "$TASKMASTER_HOME/$STOPPING_DIR/$name$RUN_SUFFIX" ]
}
