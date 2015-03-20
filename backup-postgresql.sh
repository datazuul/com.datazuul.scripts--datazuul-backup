#!/bin/bash
#
# $Id$
#
# Dump a PostgreSQL database and backup it on a remote host.
#

appname=`basename $0`
export PGUSER=postgres

#
# Set some defaults
#
dumpfilepath="."
dumpfilename="postgresql-dump"
verbose=false
sshopts=""
identity=""

#
# Function to explain how to use the program
#
function usage () {
	echo
	echo "$appname [-h]"
	echo "$appname [-v] [--scp remote] [--identity ssh-key] [--ssh-opts ssh options] [--out-dir directory name] [--compress (gzip|bzip2)] [--file-name dumpfile-base-name] database_name"
	cat - <<EOF

This script dumps a PostgreSQL database to a compressed file.

Using the --scp option, the backup file can be generated on one
machine and copied to a backup server once dumped.

  -v             -- Verbose mode
  --file-name base -- Base name for dump file, defaults to "postgresql-dump".
  --scp remote   -- Location for remote backups.  Files are transfered via scp,
                    then removed from the local directory.
  --identity     -- Identity file for scp transfer
  --ssh-opts      -- options to use for scp
  --out-dir      -- path where dump file should be written, defaults to "."
  --compress     -- compression method (gzip or bzip2, defaults to bzip2)
EOF
	echo
	echo "Example:"
	echo "  $appname -v --scp user@backupserver:/backups/postgresql mydatabase"
	echo
	exit $1
}

compress_app="bzip2"
compress_ext="bz2"

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
		--out-dir) dumpfilepath="$2";
			shift;;
		--file-name) dumpfilename="$2";
			shift;;
		-v) verbose=true;;
		--compress)
			case "$2" in
				bzip2|bz|bzip)
					compress_app="bzip2";
					compress_ext="bz2";;
				gzip|gz)
					compress_app="gzip";
					compress_ext="gz";;
			esac;
			shift;;
		*) break;;
	esac
	shift
done

database_name="$1"
if [ -z "$database_name" ]
then
	echo "Failed: Database name argument required"
	usage 1
fi

$verbose && echo "Backing up: $database_name"
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
# Function to do the backup for one database
#
function backup_db () {
	typeset db_name=$1
	timeslot=`date +%y%m%d-%H%M`
	timeinfo=`date '+%T %x'`

	$verbose && echo "Backup and Vacuum at $timeinfo for time slot $timeslot on database: $db_name "
	dumpfile="$dumpfilepath/${dumpfilename}-${db_name}-$timeslot.${compress_ext}"

	$verbose && echo -n "Dumping ..."
	/usr/bin/vacuumdb -z -h localhost -U postgres $db_name >/dev/null 2>&1
	/usr/bin/pg_dump $db_name -h 127.0.0.1 | "$compress_app" > "$dumpfile"


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

backup_db $database_name || exit 1

exit 0
