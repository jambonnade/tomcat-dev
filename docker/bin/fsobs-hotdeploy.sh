#!/bin/sh

#set -x

conf_path="$1"
base_path="${2%/}"
e="$3"
path="$4"


name="${conf_path##*/}"
name="${name%.conf}"

if [ -f "$conf_path" ]
then
	# Note : "source" not available everywhere with /bin/sh ; Manual parsing
	context=$(awk -F '=' '/^context=/{print $2}' "$conf_path")
	output_path=$(awk -F '=' '/^output_path=/{print $2}' "$conf_path")
	input_path=$(awk -F '=' '/^input_path=/{print $2}' "$conf_path")
	input_war=$(awk -F '=' '/^input_war=/{print $2}' "$conf_path")
fi

if [ -z "$context" ]
then
	context="$name"
fi

if [ -n "$output_path" ]
then
	output_path="${output_path%/}"
else
	output_path="$CATALINA_HOME/webapps/$context"
fi


if [ -n "$input_path" ] 
then
	# Input path is relative in configuration
	input_path="$base_path/${input_path%/}"
else
	# Assumes base_path is webapp input path
	input_path="$base_path"
fi


# Optional war deployment if asked ; shortcuts the rest
if [ -n "$input_war" ]
then
	if [ "$input_war" = 1 ]
	then
		# Automatic war path from webapp input path
		input_war="$input_path.war"
	else
		# Path is relative to base path
		input_war="$base_path/$input_war"
	fi

	if [ "$input_war" = "$path" ]
	then
		# Automatic output war path from output webapp path
		cp -v "$input_war" "$output_path.war"
		exit
	fi
fi


if [ ! -d "$output_path" ]
then
	echo "Invalid output webapp dir $output_path or not yet ready"
	exit
fi

# Identifies the path relative to the webapp root
rel_path="${path##$input_path/}"


# Filter events not inside the input webapp root
if [ "$rel_path" = "$path" ]
then
	echo "Not in input webapp root"
	exit
fi

# Filter elements that may cause a re-deploy and folders
case "$rel_path" in
	WEB-INF/* | META-INF/* | */)
		echo "Filtered file"
		exit
		;;
esac

# Copy the resource with necessary missing folders
cd "$input_path"
cp -v --parents "$rel_path" "$output_path/"

