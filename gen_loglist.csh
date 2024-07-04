#!/tool/pandora64/bin/tcsh

# Input(s):
#   $1 = csh file that sets up the environment for a tree
#   $2 = project variant to be boot
#   $3 = Directory path for the tree
# Usage : run_custom_regress_mc_cds.csh <env_file> <project_name> <directory_path>

set cron_time = `date`;

set script = `echo "$0" | sed 's/.*\/\([^\/]*\)$/\1/'`

if($# == 0 || $# == 1 || $# == 2) then
  echo "Usage: $0 <env_file> <project_name> <directory_path>"
  echo "e.g. $0 src/test/scripts/regress/profiles/nightly_mcip_ci_svdc.thebe.sj.env thebe /proj/r11xx_verif_scratch2/nightly_mcip_thebe"
  exit 1
endif

if(! -e $1) then
    echo "ERROR: ${script} requires a csh file that sets up the environment for a tree"
    exit 1
endif

set DJ_CONTEXT = $argv[2]
set STEM = $argv[3]
# go to the $STEM directory
cd $STEM
# Capture P4CLIENT and P4PORT from the P4CONFIG File
foreach line ("`cat P4CONFIG`")
  if ( `echo $line` !~ *"#"* ) then
    set $line
  endif
end
echo "P4PORT=$P4PORT"
echo "P4CLIENT=$P4CLIENT"

source /proj/verif_release_ro/cbwa_initscript/current/cbwa_init.csh
bootenv -v $DJ_CONTEXT
setenv PROJECT $DJ_CONTEXT

# XXX redundant if $1 sources project alias
echo "${script}: clearing environment"
#source /tools/hdk/bootstrap/infra/setup/csh/cshreset

echo "${script}: loading configuration from $1"
source $1

if($?change == 0) then
    echo "ERROR: ${script} requires $1 to set \$change"
    exit 1
endif

set cshrc_time = `date`;

# Timestamp
echo "${script}: generating log and database timestamps"
set timestamp = `date`;
set log_timestamp = `date -d "$timestamp" +"%Y%m%d_%H%M"`;
set db_timestamp = `date -d "$timestamp" +"%F %T"`
set logdir_base = "$STEM/logs_regress"
set logdir = "$logdir_base/$BUILD_VARIANT/logs"

if (! -d $logdir/$log_timestamp) then
    mkdir -p $logdir/$log_timestamp
endif

set loggzdir = "$logdir/$log_timestamp/loggzdir"
if (! -d $loggzdir) then
    mkdir -p $loggzdir
    cd $loggzdir
    find -name "mmhub_*.log.gz" | xargs -i cp {} $loggzdir
    cd $loggzdir
    gzip -d -r .
    touch ungzfilelist.txt
    find `pwd` -name "*.log" > ungzfilelist.txt
endif

setenv REGRESSLOG "$logdir/$log_timestamp/tree_regress.log"
if (! -e $REGRESSLOG) then
    echo "REGRESS_TIME $timestamp"  > $REGRESSLOG
    echo "SYNC_TIME $timestamp"    >> $REGRESSLOG
    echo "SYNC_CHANGE $change ."   >> $REGRESSLOG
endif

set profile_log = "$logdir/$log_timestamp/profile.log";
echo "cron_time  $cron_time"   > $profile_log
echo "cshrc_time $cshrc_time" >> $profile_log

set sync_log = "$logdir/$log_timestamp/p4_sync.log";
echo "cron_time  $cron_time"   > $sync_log

set CHANGE = "$change";
echo "current_change $change" >> $sync_log

set prevchange = `awk '{print $4}' $STEM/logs_regress/$BUILD_VARIANT/logs/current.vars | head -n 1`;

if($prevchange == $change) then
  echo "$DJ_CONTEXT $TREE Regression is running on the same CL $change. Is this intended? " | mailx -s "$TREE Regression running on the same CL at site $SITE" anita.jagdeo@amd.com alex.yang@amd.com lily.fu@amd.com
endif

## If regression is cover then set these environment variables
## Also create file cover_variables which will make things easier if the cover merge flow has to be run manually
if ( $TREE =~ *cover* ) then
    set cover_variables = "$logdir/$log_timestamp/cover_variables"
    echo "${script} : setting cover related variables"
    setenv LOG_TIMESTAMP "$log_timestamp"
    setenv STARTTIME "$db_timestamp"
    echo "setenv LOG_TIMESTAMP $LOG_TIMESTAMP" > $cover_variables
    echo setenv STARTTIME  \"$STARTTIME\" >> $cover_variables
    echo "setenv CHANGE $CHANGE" >> $cover_variables
    echo "setenv TREE $TREE" >> $cover_variables
    echo source \"$STEM/src/test/scripts/dvdb/postgresql.$SITE.env\" >> $cover_variables
endif

# kill any lingering jobs / wait a minute.
echo "${script}: killing jobs matching ${PROJECT}_${TREE}*"
lsf_bkill -J "${PROJECT}_${TREE}*"
set bkill_time = `date`;
echo "bkill_time $bkill_time" >> $profile_log
#sleep 60  # XXX is this enough?  This doesn't seem safe.

# Be absolutely certain we clean everything.
cd $STEM && rm -rf $OUT_HOME 
set clobber_time = `date`;
echo "clobber_time  $clobber_time"  >> $profile_log
cd $STEM && \rm -rf .jobscripts

echo "${script}: Performing p4w sync_all"
p4w sync_all @$CHANGE >> $sync_log
set sync_time = `date`;
echo "sync_time  $sync_time"  >> $profile_log

# Re-alias project in case setup files in tree were updated.
# XXX redundant if $1 sources project alias
echo "${script}: clearing environment"
#source /tools/hdk/bootstrap/infra/setup/csh/cshreset

echo "${script}: loading configuration from $1"
source $1

echo "Printing ENV after re running the alias"
env
module list
echo "DJ:"
which dj
setenv OUT_DESIGN_bin  ${OUT_HOME}/${DJ_CONTEXT}/common/pub/bin
setenv LD_LIBRARY_PATH ${LD_LIBRARY_PATH}:${OUT_DESIGN_bin}:${OUT_DESIGN_bin}/sim/${DV_SIM_NAME}

unsetenv DJ_ABORT_ON_ERROR
#Set LSF variables
if ( $SITE =~ "MKDC" ) then 
  setenv DJ_GCF_OPTS "queue:'regr_high', name:'dj', mem:3000, cores:2, select:'type==RHEL5_64', lsf_native:'-P mcip-ver -G mcip-ver'"
else if ( $SITE =~ "ATL") then
  setenv DJ_GCF_OPTS "queue:'regr_high', name:'dj', mem:3000, cores:2, select:'type==RHEL5_64', lsf_native:'-P mcip-ver -G mcip-ver'"
else if ( $SITE =~ "CYB") then
  setenv DJ_GCF_OPTS "queue:'regr_normal', name:'dj', mem:3000, select:'type==RHEL5_64', lsf_native:'-P mcip-ver'"
else if ( $SITE =~ "SVDC" )  then
  setenv DJ_GCF_OPTS "queue:'bulk', name:'dj', mem:3000, select:'type==RHEL5_64', lsf_native:'-P mcip-ver -G mcip-ver.priority'"
else 
  setenv DJ_GCF_OPTS "queue:'bulk', name:'dj', mem:3000, select:'type==RHEL5_64', lsf_native:'-P $env(PROJECT)-ver'"
endif

echo "LSF_PROJECT IS $LSF_PROJECT"
echo "LSF_GROUP IS $LSF_GROUP"
echo "LSF_QUEUE IS $LSF_QUEUE"
echo "LSF_JOBGROUP IS $LSF_JOBGROUP"

# Set coverage hierarchical file path
#set cm_hier_path = "$STEM/src/test/suites/mc/coverage/variant/${PROJECT}"

if ( $TREE =~ *cover* ) then
    alias DJCMD dj -c -v -e \'run_test \"$BLOCK -w $WHEN \"\' -DRUN_DV=OFF ${DJ_RUN_OPTIONS} -J lsf -m 1 -l dj.log -D CM -D CMOPT=line+fsm+tgl+cond+assert -D CM_HIER=$cm_hier_path/cm_hier.txt #|| exit
    DJCMD
else
    alias DJCMD dj -c -v -e \'run_test \"$BLOCK -w $WHEN \"\' -DRUN_DV=OFF ${DJ_RUN_OPTIONS} -J lsf -m 16 -l dj.log #|| exit
    DJCMD
endif

# save information that points to where the log files for the current run are
set currentvars = "$logdir/current.vars"
rm -f $currentvars
#source $1
echo "set change = $CHANGE" > $currentvars
echo "set logdir = $logdir/$log_timestamp" >> $currentvars

# dump information needed by dvdb and launch processes
echo "${script}: setting dvdb variables"
source "$STEM/src/test/scripts/dvdb/import/set_current_run_vars.csh"

echo "${script}: dumping dvdb variables to file"
source "$STEM/src/test/scripts/dvdb/import/dump_current_run_vars.csh"

echo "${script}: loading PostgreSQL environment variables"
source "$STEM/src/test/scripts/dvdb/postgresql.$SITE.env"

echo "${script}: starting dvdb import"
source "$STEM/src/test/scripts/dvdb/import/import_current_run.csh" killlast
set db_time = `date`;
echo "db_time    $db_time"    >> $profile_log
if($status != 0) exit 1

limit coredumpsize 0
setenv DESIGN_NAME $DJ_CONTEXT
setenv NO_LOCAL_HOST_TYPE_CHECK 1

echo "${script}: ${logdir}"
mkdir -p $logdir

if ( $TREE =~ *cover* ) then

      echo   "cd $logdir && dv ${GFXBLOCK} -nosc -cds  -where ${WHERE} && status!~listed && when!~never -job id=${PROJECT}_${TREE}${HOST} group=${LSF_GROUP} ${DV_JOBTYPE} queue=${LSF_QUEUE} jobs=${LSF_JOBS} select=(type==RHEL5_64)&&(mem21000)&&(swp>5000)&&(tmp>10000) project=${LSF_PROJECT} -verbose -quiet -tidy -D CHANGE=${CHANGE} -D NO_DEBUG_SYMBOLS -D USE_RGB -D TIDY REGRESS ${DVOPTIONS} -log ${TREE}%.log -logunique -regress ${TREE} -D CM -D CMOPT=line+fsm+tgl+cond+assert -D CM_HIER=$cm_hier_path/cm_hier.txt"

      echo "Start dv job..."

      cd $logdir && dv "${GFXBLOCK}" -nosc -cds  -where "${WHERE} && status!~listed && when!~never" -job "id=${PROJECT}_${TREE}${HOST} group=${LSF_GROUP} ${DV_JOBTYPE} queue=${LSF_QUEUE} jobs=${LSF_JOBS} select=(type==RHEL5_64)&&(mem>2000)&&(swp>5000)&&(tmp>10000) project=${LSF_PROJECT}" -verbose -quiet -tidy -D CHANGE=${CHANGE} -D NO_DEBUG_SYMBOLS -D USE_RGB -D "TIDY REGRESS"${DVOPTIONS} -log ${TREE}%.log -logunique -regress ${TREE} -D CM -D CMOPT=line+fsm+tgl+cond+assert -D CM_HIER=$cm_hier_path/cm_hier.txt

else

     echo "cd $logdir && dv ${GFXBLOCK} -nosc -cds  -where ${WHERE} -job id=${PROJECT}_${TREE}${HOST} group=${LSF_GROUP} ${DV_JOBTYPE} queue=${LSF_QUEUE} jobs=${LSF_JOBS} select=(type==RHEL5_64)&&(mem>=2000)&&(swp>5000)&&(tmp>10000) project=${LSF_PROJECT} -verbose -quiet -tidy -D CHANGE=${CHANGE} -D NO_DEBUG_SYMBOLS -D USE_RGB -D TIDY REGRESS ${DVOPTIONS} -log ${TREE}%.log -logunique -regress ${TREE}"
#     echo "cd $logdir && dv ${GFXBLOCK} -nosc -cds  -where ${WHERE} && status!~listed && when!~never -job id=${PROJECT}_${TREE}${HOST} group=${LSF_GROUP} ${DV_JOBTYPE} queue=${LSF_QUEUE} jobs=${LSF_JOBS} select=(type==RHEL5_64)&&(mem>=2000)&&(swp>5000)&&(tmp>10000) project=${LSF_PROJECT} -verbose -quiet -tidy -D CHANGE=${CHANGE} -D NO_DEBUG_SYMBOLS -D USE_RGB -D TIDY REGRESS ${DVOPTIONS} -log ${TREE}%.log -logunique -regress ${TREE}"

     echo "Start dv job..."

     cd $logdir && dv "${GFXBLOCK}" -nosc -cds  -where "${WHERE}" -job "id=${PROJECT}_${TREE}${HOST} group=${LSF_GROUP} ${DV_JOBTYPE} queue=${LSF_QUEUE} jobs=${LSF_JOBS} select=(type==RHEL5_64)&&(mem>=2000)&&(swp>5000)&&(tmp>10000) project=${LSF_PROJECT}" -verbose -quiet -tidy -D CHANGE=${CHANGE} -D NO_DEBUG_SYMBOLS -D USE_RGB -D "TIDY REGRESS" ${DVOPTIONS} -log ${TREE}%.log -logunique -regress ${TREE}
#     cd $logdir && dv "${GFXBLOCK}" -nosc -cds  -where "${WHERE} && status!~listed && when!~never" -job "id=${PROJECT}_${TREE}${HOST} group=${LSF_GROUP} ${DV_JOBTYPE} queue=${LSF_QUEUE} jobs=${LSF_JOBS} select=(type==RHEL5_64)&&(mem>=2000)&&(swp>5000)&&(tmp>10000) project=${LSF_PROJECT}" -verbose -quiet -tidy -D CHANGE=${CHANGE} -D NO_DEBUG_SYMBOLS -D USE_RGB -D "TIDY REGRESS" ${DVOPTIONS} -log ${TREE}%.log -logunique -regress ${TREE}

endif

cp -f $STEM/dj.log $logdir/dj.log

set dv_time = `date`;
echo "dv_time    $dv_time"    >> $profile_log
