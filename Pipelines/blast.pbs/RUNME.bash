#!/bin/bash

##################### VARIABLES
# Find the directory of the pipeline
if [[ "$PDIR" == "" ]] ; then PDIR=$(dirname $(readlink -f $0)); fi ;
CWD=$(pwd)

# Load config
if [[ "$PROJ" == "" ]] ; then PROJ="$1" ; fi
if [[ "$TASK" == "" ]] ; then TASK="$2" ; fi
if [[ "$TASK" == "" ]] ; then TASK="check" ; fi
NAMES=$(ls $PDIR/CONFIG.*.bash | sed -e 's/.*CONFIG\./    o /' | sed -e 's/\.bash//');
if [[ "$PROJ" == "" ]] ; then
   if [[ "$HELP" == "" ]] ; then
      echo "
Usage:
   $0 name task
   
   name	The name of the run.  CONFIG.name.bash must exist.
   task	The action to perform.  One of:
	o run: Executes the BLAST.
	o check: Indicates the progress of the task (default).
	o pause: Cancels running jobs (resume using run).

   See $PDIR/README.md for more information.
   
   Available names are:
$NAMES
" >&2
   else
      echo "$HELP   
   Available names are:
$NAMES
" >&2
   fi
   exit 1
fi
if [[ ! -e "$PDIR/CONFIG.$PROJ.bash" ]] ; then
   echo "$0: Error: Impossible to find $PDIR/CONFIG.$PROJ.bash, available names are:
$NAMES" >&2
   exit 1
fi
source "$PDIR/CONFIG.$PROJ.bash"
MINVARS="PDIR=$PDIR,SCRATCH=$SCRATCH,PROJ=$PROJ"
case $QUEUE in
bioforce-6)
   MAX_H=120 ;;
iw-shared-6)
   MAX_H=12 ;;
biocluster-6 | biohimem-6 | microcluster)
   MAX_H=240 ;;
*)
   echo "Unrecognized queue: $QUEUE." >&2 ;
   exit 1 ;;
esac ;

##################### FUNCTIONS
function REGISTER_JOB {
   STEP=$1
   SUBSTEP=$2
   MESSAGE=$3
   JOBID=$4

   if [[ "$JOBID" != "" ]] ; then
      MESSAGE="$MESSAGE [$JOBID]" ;
      echo "$STEP: $SUBSTEP: $(date)" > "$SCRATCH/log/active/$JOBID" ;
      #GUARDIAN_JOB=$(msub -l "depend=afternotok=$JOBID" -v "$MINVARS,STEP=$STEP,JOBID=$JOBID" "$PDIR/recover.pbs.bash") ;
   fi
   echo "$MESSAGE." >> "$SCRATCH/log/status/$STEP" ;
}

function LAUNCH_JOB {
   STEP=$1
   SUBSTEP=$2
   MESSAGE=$3
   BASHFILE=$4
   
   cd "$SCRATCH/log/eo" ;
   JOBID=$(bash "$BASHFILE" | tr -d '\n' || exit 1) ;
   cd $CWD ;
   REGISTER_JOB "$STEP" "$SUBSTEP" "$MESSAGE" "$JOBID" ;
   echo $JOBID ;
}

function JOB_DONE {
   STEP=$1

   echo "Done." >> "$SCRATCH/log/status/$STEP" ;
}

##################### RUN
# Create the scratch directory
if [[ ! -d $SCRATCH ]] ; then mkdir -p $SCRATCH ; fi;
# Execute task
if [[ ! -e "$PDIR/TASK.$TASK.bash" ]] ; then
   echo "Unrecognized task: $TASK." >&2 ;
   exit 1 ;
else
   source "$PDIR/TASK.$TASK.bash"
fi

