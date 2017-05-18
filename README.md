# tomcat-dev
My personnal tools for development with Tomcat, particularly with a remote server like in a Docker container.
The main intent is to allow "resource hot-deployment" in a running webapp, which seems impossible in various IDE for a remote server.

**Status : unmaintained / deprecated**. I just share the code if you want to build a similar system.

## Fsobs
This system is built around **inotifywait** tool to observe filesystem events on a directory and process them with user scripts.
To start a monitoring loop :
```shell
./fsobs.sh config_file.conf
```
Logs events in the standard output. Kill it (SIGTERM) or interrupt it (Ctrl+C) to stop it.
The script requires a configuration file in argument, it must contain those parameters :
```shell
# Path to the directory to observe. It may not exist yet
base_path=/my/path
# List of events (see man inotifywait for the list), comma-separated, in lowercase
events=create,access,close_write
# An executable (path or command name) that will process each event
processor=/home/zboub/myscript.sh
```
The system allows the monitored directory to be nonexistent, in this case, it tries again shortly. Each try, the system rereads the configuration file, so that the base_path can change. This is designed so to avoid the user to stop and re-run the script after a change.
In case the monitored directory is removed in some way, the monitoring stops and the script re-tries to monitor it again like when the path is nonexistent.

The *processor* script accepts 4 arguments
1. path to the same configuration file used by fsobs
1. monitored directory path (actual base_path)
1. event (one of those allowed in the config file)
1. path related to the event (ex: path of the saved file)
The script can then extract other custom parameters from the config file

## Docker
The image is based on the official Tomcat image (atm, only 8-jre8-alpine) with the following changes :
* The entry point is /opt/bin/custom-catalina.sh which wraps catalina.sh and calls /opt/bin/custom-init.sh before everything
* tomcat-users.xml contains a single user "admin" (pwd: "admin")
* Manager's context.xml has its IP limitation removed

You should create a directory for any customimzation stuff and mount it in `$CUSTOM_STUFF_DIR` (/opt/custom).
The custom-init.sh script does the following at container startup :
* Overwrites tomcat files present in `$CUSTOM_STUFF_DIR/tomcat`, paths are relative to `$CATALINA_HOME` (/usr/local/tomcat)
* Executes any shell script (.sh) in `$CUSTOM_STUFF_DIR/init`
* For each "fsobs" config file ([name].conf) in `$CUSTOM_STUFF_DIR/fsobs`, runs the fsobs script in background and log output in /var/log/fsobs-[name].log.

### Resource hot-deployment
In a situation where you have locally the final exploded webapp (a directory that may constitute a WAR) and your IDE can copy resources (static assets, html, jsp..) in this directory on save (Netbeans can), you can use fsobs system with the fsobs-hotdeploy.sh processor script to synchronize this directory to the exploded running webapp in your container.

**Note : it's way simpler to mount your local webapp exploded dir to the target tomcat webapp exploded dir instead of using this system**, at the cost of not being able to make a clean build without restarting the container.

From the following setup :
* Your project is in /home/abc/myproject
* The build system makes everything in /home/abc/myproject/target
* The final exploded webapp is in /home/abc/myproject/target/myproject-1.0-SNAPSHOT (the WAR path is the same with .war)
* You have mounted /home/abc/custom as the custom directory for `$CUSTOM_STUFF_DIR`
* You choose to make your local project available in the container by mounting /home/abc/project to /hotdeploy/myproject

You can use fsobs with the fsobs-hotdeploy.sh processor by creating the following config file /home/abc/custom/fsobs/xxx.conf 
```shell
# Path to the directory to monitor. It may not exist or can be deleted
base_path=/hotdeploy/myproject/target
# The only event to monitor to make fsobs-hotdeploy work
events=close_write
# The processor command name or path
processor=fsobs-hotdeploy.sh
# The path of the exploded webapp dir, relative to base_path
input_path=myproject-1.0-SNAPSHOT
# Webapp context name. Defaults to the config file name without .conf
#context=xxx
# Absolute output webapp dir path in the running tomcat. Defaults to $CATALINA_HOME/webapps/<context>
#output_path=
# If input_war is provided, manages the war deployment when the war is changed, by copying it to $output_path.war
# input_war is the path to the war relative to base_path. If "1", takes $input_path to determine it.
#input_war=1
```

Notes: 
* You could observe /hotdeploy/myproject/target/myproject-1.0-SNAPSHOT directly if you don't need the war deploy feature, it's better to monitor a less deep directory. In that case input_path can be omitted
* fsobs-hotdeploy doesn't manage file deletions or moves, it's only to update existing resources or creating new ones
