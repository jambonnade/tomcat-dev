#!/bin/sh

if [ -z "$CATALINA_HOME" -o ! -d "$CATALINA_HOME" ]
then
	echo "Invalid CATALINA_HOME"
	exit 1
fi

# Overwrite tomcat files with custom files
customtomcat_dir="$CUSTOM_STUFF_DIR/tomcat"
if [ -d "$customfiles_dir" ]
then
	echo "Overwriting tomcat files..."
	cp -av "$customfiles_dir/"* "$CATALINA_HOME/"
fi

# Run user scripts
scripts_dir="$CUSTOM_STUFF_DIR/init"
if [ -d "$scripts_dir" ]
then
	echo "Executing user scripts..."
	for f in $(find "$scripts_dir" -type f -name '*.sh')
	do
		echo "$f..."
		$f
	done
fi

# Run automatic file observers
fsobs_conf_dir="$CUSTOM_STUFF_DIR/fsobs"
if [ -d "$fsobs_conf_dir" ]
then
	for f in "$fsobs_conf_dir"/*.conf
	do
		name="${f##*/}"
		name="${name%.conf}"
		log="/var/log/fsobs-$name.log"
		fsobs.sh "$f" > "$log" &
	done
fi

