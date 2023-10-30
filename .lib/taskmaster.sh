# shellcheck shell=bash

TASKMASTER_HOME="${TASKMASTER_HOME:-.}"
TASKMASTER_LIB="${TASKMASTER_LIB:-$TASKMASTER_HOME/.lib}"

# shellcheck source="task.sh"
source "$TASKMASTER_LIB/task.sh"

# shellcheck source="utils.sh"
source "$TASKMASTER_LIB/utils.sh"

watchdog() # name duration_s [pids]...
{
	local name="$1"; shift
	local duration_s="$1"; shift

	sleep "$duration_s"

	for pid in "$@"
	do
		if [ -d "/proc/$pid" ]
		then
			kill -KILL "$pid"
		fi
	done

	rm -f "$TASKMASTER_HOME/stopping/$name$RUN_SUFFIX"
}

taskmaster.init() # name
{
	pushd "$TASKMASTER_HOME" >/dev/null
		mkdir -p -- \
			{"$AVAILABLE_DIR","$ENABLED_DIR","$RUNNING_DIR","$STOPPING_DIR"}
	popd >/dev/null
}

taskmaster.enable() # name
{
	if ! [ $# -ge 1 ]
	then
		error 'enable: Missing task name'; return
	fi

	local name="$1"
	local filename="$name$TASK_SUFFIX"

	pushd "$TASKMASTER_HOME" >/dev/null
		if task.is_available "$name"
		then
			ln -vsf "../$AVAILABLE_DIR/$filename" "enabled/$filename"
		else
			error "No task named '$name' is available!"
		fi
	popd >/dev/null
}

taskmaster.disable()
{
	if ! [ $# -ge 1 ]
	then
		error 'disable: Missing task name'; return
	fi

	local name="$1"
	local filename="$name$TASK_SUFFIX"

	pushd "$TASKMASTER_HOME" >/dev/null
		if task.is_enabled "$name"
		then
			rm -v "enabled/$filename"
		else
			error "No task named '$name' is enabled!"
		fi
	popd >/dev/null
}

taskmaster.start()
{
	if ! [ $# -ge 1 ]
	then
		error 'start: Missing task name'; return
	fi

	local name="$1"
	local filename="$name$TASK_SUFFIX"

	pushd "$TASKMASTER_HOME" >/dev/null
	(
		set -euo pipefail

		task.load "$name"

		start &

		echo "$!" > "$TASKMASTER_HOME/$RUNNING_DIR/$name$RUN_SUFFIX"
	)

	echo "Started '$name'!"

	popd >/dev/null
}

taskmaster.stop() # name
{
	if ! [ $# -ge 1 ]
	then
		error 'stop: Missing task name'; return
	fi

	local name="$1"

	if ! task.is_running "$name"
	then
		return 0
	fi

	local filename="$name$RUN_SUFFIX"

	local stop_signal stop_timeout_s

	local pids

	# shellcheck source=/dev/null
	. <(
		task.load "$name"

		echo "stop_signal=$stop_signal" "stop_timeout_s=$stop_timeout_s"
	)

	task.pids "$name" pids || return

	pushd "$TASKMASTER_HOME" >/dev/null
		mv "$RUNNING_DIR/$filename" "$STOPPING_DIR/$filename"

		for pid in "${pids[@]}"
		do
			kill "-$stop_signal"  "$pid" || :
		done

		watchdog "$name" "$stop_timeout_s" "${pids[@]}" &
	popd >/dev/null
}

taskmaster.restart()
{
	taskmaster.stop "$@"
	taskmaster.start "$@"
}

taskmaster.reload()
{
	true
}

taskmaster.status() # name
{
	if ! [ $# -ge 1 ]
	then
		error 'status: Missing task name'; return
	fi

	local name="$1"

	task.is_enabled "$@" && echo "Enabled" || echo "Disabled"
	task.is_started "$@" && echo "Started" || echo "Stopped"
	task.is_running "$@" && echo "Running" || echo "Not running"
}
