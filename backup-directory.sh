#!/bin/bash
#
# $Id$
#
# Backup a directory and backup it on a remote host.
#

appname=`basename $0`

#
# Set some defaults
#
targetfilepath="."
targetfilename="backup"
verbose=false
sshopts=""
identity=""
compress_app="/bin/tar cvfz"
compress_ext="tar.gz"

#
# Function to explain how to use the program
#
function usage () {
	echo
	echo "$appname [-h]"
	echo "$appname [-v] [--scp remote] [--identity ssh-key] [--ssh-opts ssh options] [--out-dir directory name] [--file-name targetfile-base-name] directory_pathname"
	cat - <<EOF

This script backups a directory to a compressed file (.tar.gz).

Using the --scp option, the backup file can be generated on one
machine and copied to a backup server once dumped.

  -v             -- Verbose mode
  --file-name base -- Base name for backup file, defaults to "backup".
  --scp remote   -- Location for remote backups.  Files are transfered via scp,
                    then removed from the local directory.
  --identity     -- Identity file for scp transfer
  --ssh-opts      -- options to use for scp
  --out-dir      -- path where backup file should be written, defaults to "."
EOF
	echo
	echo "Example:"
	echo "  $appname -v --scp user@backupserver:/backups mydirectory"
	echo
	exit $1
}


#
# Process arguments
#
while [ $# -gt 0 ]
do
    opt="$1"
	case "$opt" in
		-h) usage 0;;
		--scp) dest="$2"; 
			shift;;
		--identity) identity="$2";
			shift;;
		--ssh-opts)  sshopts="$2";
			shift;;
		--out-dir) targetfilepath="$2";
			shift;;
		--file-name) targetfilename="$2";
			shift;;
		-v) verbose=true;;
		*) break;;
	esac
	shift
done

directory_pathname="$1"
if [ -z "$directory_pathname" ]
then
	echo "Failed: Directory's pathname argument required"
	usage 1
fi

$verbose && echo "Backing up: $directory_pathname"
if [ "$dest" != "" ]
then
	$verbose && echo "      Dest: $dest"
fi
if [ "$identity" != "" ] ; then
	$verbose && echo "  Identity: $identity"
fi
if [ "$sshopts" != "" ] ; then
	$verbose && echo "  ssh opts: $sshopts"
fi

#
# Function to do the backup for a directory
#
function backup_directory () {
	typeset src_name=$1
	timeslot=`date +%y%m%d-%H%M`
	timeinfo=`date '+%T %x'`

	short_name=`basename "$src_name"`

	$verbose && echo "Backup at $timeinfo for time slot $timeslot on directory: $src_name"
	dumpfile="$targetfilepath/${targetfilename}-${short_name}-$timeslot.${compress_ext}"

	$verbose && echo -n "Backup ..."
	touch ${dumpfile}
	${compress_app} ${dumpfile} ${src_name}


	RC=$?

	$verbose && echo

	if [ $RC -ne 0 ]
	then
		rm -f "$dumpfile"
		return $RC
	fi
	
	$verbose && echo "Created $dumpfile"

	if [ "$dest" != "" ]
	then
		if [ -z "$identity" ] ; then
			scp $sshopts "$dumpfile" "$dest"
		else
			scp $sshopts -i $identity "$dumpfile" "$dest"
		fi
		RC=$?
		rm -f "$dumpfile"
	fi

	return $RC
}

#
# Do the backup
#
echo "started"
backup_directory $directory_pathname || exit 1

exit 0
