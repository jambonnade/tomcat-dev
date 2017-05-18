# tomcat-dev
My personnal tools for development with Tomcat, particularly with a remote server like in a Docker container.
The main intent is to allow "resource hot-deployment" in a running webapp, which seems impossible in various IDE for a remote server. More info in the [Docker page](https://hub.docker.com/r/jambonnade/tomcat-dev/).

**Status : unmaintained / deprecated**. I just share the code if you want to build a similar system.

## Fsobs
This system is built around **inotifywait** tool to observe filesystem events on a directory and process them with user scripts.
To start a monitoring loop :
```shell
./fsobs.sh config_file.conf
```
You typically run the command as a background task (add "&") and take the output as a log (use redirections). Kill it (SIGTERM) or interrupt it (Ctrl+C) to stop it.
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
