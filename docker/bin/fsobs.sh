#!/bin/sh

#set -x

conf_path="$1"

if [ -z "$conf_path" ]
then
	echo "Provide a configuration file path"
	exit 1
fi


OLDIFS="$IFS"

fifo_path=$(mktemp -u)
inotify_pid=

kill_inotify() {
	if [ -n "$inotify_pid" ]
	then
		kill $inotify_pid
		inotify_pid=
	fi
}

on_exit() {
	kill_inotify
	rm -f $fifo_path
	exit
}

trap "on_exit" 2 3 15

mkfifo $fifo_path


while true
do
	base_path=
	events=
	processor=
	retry_delay=1
	
	if [ -f "$conf_path" ]
	then
		# Note : "source" not available everywhere with /bin/sh ; Manual parsing
		base_path=$(awk -F '=' '/^base_path=/{print $2}' "$conf_path")
		events=$(awk -F '=' '/^events=/{print $2}' "$conf_path")
		processor=$(awk -F '=' '/^processor=/{print $2}' "$conf_path")
	fi

	if which "$processor" > /dev/null 2>&1
	then
		processor=$(which "$processor")
	fi

	if [ -n "$base_path" -a -d "$base_path" -a -x "$processor" -a -n "$events" ]
	then
		base_path="${base_path%/}"

		# Add terminating events to the watched events 
		# (despite what manual says, they are not triggered if not given)
		event_list=delete_self,move_self,unmount,$events

		echo "Starting observing $base_path..."
		inotifywait -m -r -e $event_list --timefmt '%Y-%m-%d %H:%M:%S' --format '%T %e %w %f' "$base_path" > $fifo_path &
		inotify_pid=$!

		while read evt_date evt_time evt_events evt_dir evt_file
		do
			# Final path seems to be always the concatenation of the two
			evt_path="$evt_dir$evt_file"
			
			# Input event list in lowercase, output events in uppercase
			evt_events=$(echo $evt_events | tr '[:upper:]' '[:lower:]')

			echo "[$evt_date $evt_time] $evt_events $evt_path"

			IFS=,
			for evt_type in $evt_events
			do
				# Check if terminating event
				quit=
				case "$evt_type" in
					unmount)
						echo "$base_path unmounted, stop observing"
						quit=1
						;;
					delete_self | move_self)
						# Note : directory events end with /
						if [ "$evt_path" = "$base_path/" ]
						then
							echo "$base_path deleted, stop observing"
							quit=1
						fi
						;;
				esac

				if [ -n "$quit" ]
				then
					kill_inotify
				else
					# Filter events that were merged with a desired one
					if echo "$events" | grep -w "$evt_type" > /dev/null
					then
						# Call the processor
						$processor "$conf_path" "$base_path" "$evt_type" "$evt_path"
					fi
				fi
			done
			IFS="$OLDIFS"
		done < $fifo_path
	fi
	sleep $retry_delay
done

on_exit

