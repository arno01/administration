#! /bin/sh
#
# see http://openbuildservice.org/help/manuals/obs-best-practices/cha.obs.best-practices.bootstrapping.html
#
# We only copy when md5sum changes!
# No use of md5sum. They are unreliable. Better compare timestamps in the log.
#
# FIXME: the timestamp comparison is easily fooled by interrupted transfers.
#        can we retrieve the list of files with their individual md5sums easily? Maybe they can match?

test -z "$OBS_API_DST"  && OBS_API_DST=obs-new
test -z "$OBS_API_SRC"  && OBS_API_SRC=obs-old
test -z "$OBS_USER_DST" && OBS_USER_DST=$(osc -A$OBS_API_DST whois | awk -F: '{ print $1 }')

echo "Using: env OBS_API_SRC=$OBS_API_SRC OBS_API_DST=$OBS_API_DST OBS_USER_DST=$OBS_USER_DST"

if [ -z "$1" ]; then
  echo "Projects on $OBS_API_SRC:"
  echo "-------------------------"
  osc -A$OBS_API_SRC ls
  echo ""
  echo "To copy a project from $OBS_API_SRC to OBS_API_DST try "
  echo "\t $0 PROJECT_NAME ..."
  exit 0
fi

echo "press ENTER to continue"
read a

for prj in "$@"; do
  echo "copying project $prj ..."
  if [ -z "$(osc -A$OBS_API_DST meta prj $prj)" ]; then
    echo "creating $prj at $OBS_API_DST ..."
    # remove all users, add myself as maintainer
    osc -A$OBS_API_SRC meta prj $prj | grep -v userid= | sed -e 's@</project>@<person userid="'$OBS_USER_DST'" role="maintainer"/></project>@' | osc -A$OBS_API_DST meta prj $prj -F - --force || exit 1
    # also copy prjconf
    osc -A$OBS_API_SRC meta prjconf $prj | osc -A$OBS_API_DST meta prjconf $prj -F - --force || exit 1
  fi
  pkgs=$(osc -A$OBS_API_SRC ls $prj)
  npkgs=$(echo $pkgs | wc -w)
  counter=0
  echo "Packages in $prj: $(echo $pkgs)"
  for pkg in $pkgs; do
    counter=$(expr $counter + 1)
    # md5_old=$(osc -A$OBS_API_SRC log $prj $pkg 2>&1 | head -n2 | awk -F\| '{ print $4 }')
    # md5_new=$(osc -A$OBS_API_DST log $prj $pkg 2>&1 | head -n2 | awk -F\| '{ print $4 }')
    tstamp_old=$(osc -A$OBS_API_SRC log $prj $pkg 2>&1 | head -n2 | awk -F\| '{ print $3 }' | tr -d ' ')
    tstamp_new=$(osc -A$OBS_API_DST log $prj $pkg 2>&1 | head -n2 | awk -F\| '{ print $3 }' | tr -d ' ')
    tstamp_late=$((echo "$tstamp_old"; echo "$tstamp_new")  | sort -r | head -n 1)
    # md5sums are unreliable. sometimes they match, sometimes they dont.
    # if [ "$md5_old" = "$md5_new" ]; then
    #   echo "$prj: $counter/$npkgs md5sum $(echo $md5_new) match $pkg - skipping ..."
    #####
    # extra echo to strip newlines and stuff.
    if [ "$(echo $tstamp_new)" = "$(echo $tstamp_late)" ]; then
      echo "$prj: $counter/$npkgs unchanged $pkg - skipping ..."
    else
      echo "$prj: $counter/$npkgs ..."
      echo "+ osc -A$OBS_API_SRC copypac -t $OBS_API_DST $prj $pkg $prj"
      osc -A$OBS_API_SRC copypac -t $OBS_API_DST $prj $pkg $prj || exit 1
    fi
  done
done

