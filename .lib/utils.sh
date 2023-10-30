# shellcheck shell=bash

error() # message status
{
	local message="$1"
	local status="${2:-1}"

	echo "$message" >&2

	return "$status"
}

parse_duration() # duration
{
	local duration="${1:-0s}"

	local suffix="${1: -1}"
	local value="${1:0:-1}"

	local factor

	case "$suffix"
	in
		s)	factor=1;;
		m)	factor=60;;
		h)	factor=3600;;
		*)	error "Invalid duration: '$duration'!"; return;;
	esac

	if [[ "$value" =~ [[:digit:]]+ ]]
	then
		echo "$((value * factor))"
	else
		error "Invalid duration: '$duration'!"; return
	fi
}
