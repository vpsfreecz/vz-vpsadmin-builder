#! @shell@
#
# core-node Startup script for vpsAdmin core node
#
# chkconfig: - 70 15
# description: Integrates the node in vpsAdmin cluster
#
### BEGIN INIT INFO
# Provides: core-node
# Required-Start: $local_fs $remote_fs $network $named
# Required-Stop: $local_fs $remote_fs $network
# Should-Start:
# Short-Description: start and stop vpsAdmin core node
# Description: Integrades the node in vpsAdmin cluster
### END INIT INFO

# Source function library.
. /etc/rc.d/init.d/functions

shell=@shell@
user=node
node=@node@
dataDir=/var/vpsadmin/core-node
release=$dataDir
cmd="$release/bin/node"

start() {
	mkdir -p $release/var
	@rsync@/bin/rsync -a --delete --exclude var/ $node/ $release/
	chown $user $release/var

	sudo -u $user $shell <<EOF
cd $release
$cmd start
EOF
}

stop() {
	sudo -u $user $shell <<EOF
cd $release
$cmd stop
EOF
	# TODO: kill epmd
}

status() {
	export RELEASE_READ_ONLY=1

	if [ -d "$release" ] ; then
		sudo -u $user $shell <<EOF
cd $release
$cmd pid
EOF
		if [ $? == 0 ] ; then
			echo "core-node is running"
		else
			echo "core-node is not running"
		fi
	else
		echo "core-node is not running"
	fi
}

case $1 in
	start)
		start
		;;
	stop)
		stop
		;;
	restart)
		stop

		if [ "$?" == "0" ] ; then
		    start
		fi
		;;
	status)
		status
		;;
	*)
		echo "Usage: $0 {start|stop|restart|status}"
		;;
esac
