#!/bin/sh

LANG=C
PATH=/bin:/sbin:/usr/sbin:/usr/bin
DATE=`date +%Y%m%d-%H%M`
TARGET_DIR=`uname -n`_${DATE}
CP_LIST=collect_cp.lst
LS_LIST=collect_lsR.lst
PERM_LIST=collect_permission.lst

BG=""
MKDIR="/bin/mkdir"
CAT="/bin/cat"
CP="/bin/cp"
LS="/bin/ls"
WC="/usr/bin/wc -l"
EXPR="/usr/bin/expr"
ETHTOOL="/sbin/ethtool"
TAR="/bin/tar"
GREP="/bin/grep"
MV="/bin/mv"
SED="/bin/sed"
TR="/usr/bin/tr"
CUT="/bin/cut"
SORT="/bin/sort"
RM="/bin/rm"
CLEAR="/usr/bin/clear"
TEE="/usr/bin/tee"
EGREP="/bin/egrep"
BLKID="/sbin/blkid"
UDEVADM="/sbin/udevadm"

if [ -d "${TARGET_DIR}" ]
then
	echo "${TARGET_DIR} is already exists. wait one minutes."
	exit 1
fi

[ x${USER} = x"root" ] || { echo "user is not superuser." ; exit 1; }



help_option() {
   ${CAT} << EOF
   $(basename ${0}) is a tool for information collection.
   
   Usage:
      $(basename ${0}) [OPTIONS]
      $(basename ${0}) [OPTIONS]... -b DIRECTORY
      $(basename ${0}) [OPTIONS]... -b DIRECTORY --exclude EXCLUDE DIRECTORY
    
   Options:
      --help, -h		print this
      --debug, -d		exec debugmode
      --backup,-b directory		copy to compress the directory.(tar.gz)
      -b --exclude directory	exclude and copy to compress the directory.(tar.gz)

EOF
}

usage() {
   ${CAT} << EOF
   Try $(basename ${0}) '--help' for more information.
EOF
   exit 1  
}


check_command_result() {
	if [ $? -eq 0 ]
	then
		echo -e "[  OK  ]\t\t\t${1}" >>${TARGET_DIR}/result_${2}.log
	else
		echo -e "[  \e[31;1mFAILED\e[m  ]\t\t${1}"
		echo -e "[  FAILED  ]\t\t\t${1}" >> ${TARGET_DIR}/result_${2}.log
	fi
	
}

exec_collect_info() {
	${MKDIR} ${TARGET_DIR}
	${MKDIR} ${TARGET_DIR}/cp
	${MKDIR} ${TARGET_DIR}/ls
	${MKDIR} ${TARGET_DIR}/cmd
	${MKDIR} ${TARGET_DIR}/permission
	${MKDIR} ${TARGET_DIR}/backup_file
	CP_DIR=${TARGET_DIR}/cp
	LS_DIR=${TARGET_DIR}/ls
	CMD_DIR=${TARGET_DIR}/cmd
	BACKUP_DIR=${TARGET_DIR}/backup_file

	##################
	# ${CP} files
	##################
	#${MKDIR} ${CP_DIR}/logrotate.d
	#${MKDIR} ${CP_DIR}/ifcfg
	#${MKDIR} ${CP_DIR}/messages
	#${MKDIR} ${CP_DIR}/adm_messages
	#${MKDIR} ${CP_DIR}/route
	#${MKDIR} ${CP_DIR}/maillog
	#${MKDIR} ${CP_DIR}/lifekeeper_log
	#${MKDIR} ${CP_DIR}/tomcat8_log
	#${MKDIR} ${CP_DIR}/sysctl.d
	[ -f /var/log/ha-log ] && ${MKDIR} ${CP_DIR}/ha-log
	if [ -f "${CP_LIST}" ] ; then
		echo -e "\n##### cp files #####">>${TARGET_DIR}/result_cp.log
		${CAT} ${CP_LIST} | while read line
		do
      [ x"${line}" = x ] && continue
      OLDIFS=${IFS}
			IFS=","
			set  -- ${line}
      IFS=${OLDIFS}

      if [ x = x"${2##*/}" ] ; then
        ${MKDIR} -p ${CP_DIR}/${2%/*}
      fi
      
			if [ ${#} -le 2 ]; then
        if [ x = x"${2##*/}" ] ; then
            [ ! -d ${CP_DIR}/${2%/*} ] && ${MKDIR} -p ${CP_DIR}/${2%/*}
        fi
				[ -f ${1} ] && ${LS} ${1} > /dev/null 2>&1 && { ${CP} -p ${1} ${CP_DIR}/${2}; check_command_result "${CP} -p ${1} ${CP_DIR}/${2}" "cp"; }
				[ -f ${1} ] && ${LS} ${1} > /dev/null 2>&1 && { ${LS} -l ${1} |${TR} -s ' '  | ${CUT} -d ' ' -f 1,3-4,9 | ${SED} -e "s/ /\t/g">> ${TARGET_DIR}/permission/file_permission.tmp; } 
				#check_command_result "permission check  ${1}"
			else
        CP_SUBDIR=`echo ${@:$#}`
        CP_SUBDIR=${CP_SUBDIR%/*}
        [ ! -d ${CP_DIR}/${CP_SUBDIR} ] && ${MKDIR} -p ${CP_DIR}/${CP_SUBDIR}
				while :
				do
           OUT_FILE=`echo ${1} |${SED} -e "s/:/_/"`
				   { ${CP} -p ${1} ${CP_DIR}/${@:$#}/${OUT_FILE##*/}; check_command_result "${CP} -p ${1} ${CP_DIR}/${@:$#}/${OUT_FILE##*/}" "cp"; }
					 { ${LS} -l ${1} |${TR} -s ' '  | ${CUT} -d ' ' -f 1,3-4,9 | ${SED} -e "s/ /\t/g">> ${TARGET_DIR}/permission/file_permission.tmp; }
					shift
					[ ${#} -lt 2 ] && break
				done
			fi
		done
		${CAT} ${TARGET_DIR}/permission/file_permission.tmp | ${SORT} -k 4,4 >${TARGET_DIR}/permission/file_permission.log
	fi
	
	${LS} /etc/sysconfig/network-scripts/ | ${GREP} -q ifcfg-bond
	rc=$?
	if [ $rc -eq 0 ]
	then
		for i in `${LS} ${CP_DIR}/ifcfg/ifcfg-bond* |${GREP} ":"`
		do
		${MV} $i `echo $i |${SED} -e "s/:/_/"`
		done
	fi
	
	
	ETH_COUNT=`ls /sys/class/net/ | ${GREP} eth | ${WC}`
	i=0
	while [ "${i}" -lt "${ETH_COUNT}" ]
	do
		{ ${CP} -p /sys/class/net/eth${i}/operstate ${CP_DIR}/eth${i}_operstatea; check_command_result "${CP} -p /sys/class/net/eth${i}/operstate ${CP_DIR}/eth${i}_operstate" "cp"; } &
		i=`${EXPR} ${i} + 1`
	done
	
	i=0
	while [ "${i}" -lt "${ETH_COUNT}" ]
	do
		{ echo "eth ${i} `${LS} -l /sys/class/net/eth${i} | ${GREP} device`" >> ${CP_DIR}/pass_address.txt 2>&1; check_command_result "${LS} -l /sys/class/net/eth${i} | ${GREP} device" "cp"; } &
		i=`${EXPR} ${i} + 1`
	done
	
	##################
	# cp backup file
	##################
	if [ "${BKUP_FLG:-0}" -eq 1 ] ; then
		CURRENT_DIR=`pwd`
		
			
			if [[ -d ${BKUPDIR} ]]
			then
   				echo -e "\n#### backup ${BKUPDIR} ####"  >>${TARGET_DIR}/result_${BKUPDIR//\//_}.log
   				{ /bin/sh -c "cd ${BKUPDIR} && ${TAR} cvzf ${CURRENT_DIR}/${BACKUP_DIR}/${BKUPDIR//\//_}.tar.gz *">> ${CURRENT_DIR}/${TARGET_DIR}/result_${BKUPDIR//\//_}.log 2>&1; \
   				check_command_result "cd ${BKUPDIR} && ${TAR} cvzf ${CURRENT_DIR}/${BACKUP_DIR}/${BKUPDIR//\//_}.tar.gz *" "${BKUPDIR//\//_}"; } &
			fi
	fi	

	##################
	# ${LS} directory
	##################
	if [ -f "${LS_LIST}" ] ; then
		echo -e "\n##### ${LS} directory #####">>${TARGET_DIR}/result_ls.log
		${CAT} ${LS_LIST} | while read line 
			do
      OLDIFS=${IFS}
			IFS=","
			set  -- ${line}
      IFS=${OLDIFS}
			[ -d ${1} ] && { ${LS} -lRa ${1} > ${LS_DIR}/${2}.txt; check_command_result "${LS} -lRa ${1}" "ls"; }
		done &
	fi
	{ ${LS} -la / > ${LS_DIR}/ls-topdir.txt; check_command_result "${LS} -la /" "ls"; } &
	
	##################
	# command
	##################
	echo -e "\n##### command #####">>${TARGET_DIR}/result_cmd.log
	${EGREP} -v "^#|^$" collect_cmd.lst | \
	while read line
	do
		OLDIFS=${IFS}	
		IFS=","
		set -- ${line}
		IFS=${OLD_IFS}

    if `echo ${2} | ${GREP} -q '/'` ; then
      ${MKDIR} -p ${CMD_DIR}/${2%/*}
    fi
      
		COMMAND=`echo ${1} | /bin/awk '{print $1}'`
		if [ ! -f "${COMMAND}" ] ; then
			if ! `type -a ${COMMAND} 2> /dev/null | ${GREP} -q builtin` ; then
				continue
			fi
		fi
		( eval ${1} > ${CMD_DIR}/${2} 2>&1 ; check_command_result "${1}" "cmd" )
    done

	##################
	# For AWS
	##################
  type -a aws > /dev/null 2>&1
  if [ ${?} -eq 0 ] ; then
      ${MKDIR} ${TARGET_DIR}/AWS
      ${EGREP} -v "^#|^$" cmd_AWS.lst | \
      while read line
      do
          OLDIFS=${IFS}	
          IFS=","
          set -- ${line}
          IFS=${OLD_IFS}
          COMMAND=`echo ${1} | /bin/awk '{print $1}'`
          ( eval ${1} > ${TARGET_DIR}/AWS/${2} 2>&1 ; check_command_result "${1}" "cmd" )
      done
  fi

	##################
	# For KVM
	##################
    virsh list --name  | grep -v ^$ | \
    while read line
    do
        ( virsh domblklist ${line} >${CMD_DIR}/virsh_domblklist_${line} 2>&1 ; check_command_result "virsh domblklist ${line}" "cmd" )
        ( virsh domblklist ${line} >${CMD_DIR}/virsh_domiflist_${line} 2>&1 ; check_command_result "virsh domiflist ${line}" "cmd" )
        ( virsh dommemstat ${line} >${CMD_DIR}/virsh_dommemstat_${line} 2>&1 ; check_command_result "virsh dommemstat ${line}" "cmd" )
        ( virsh vcpucount ${line} >${CMD_DIR}/virsh_vcpucount_${line} 2>&1 ; check_command_result "virsh vcpucount ${line}" "cmd" )
        ( virsh domdisplay ${line} >${CMD_DIR}/virsh_domdisplay_${line} 2>&1 ; check_command_result "virsh domdisplay ${line}" "cmd" )
    done



	[ -f /usr/local/dhcpd/shell/d6active.sh ]  && ( /usr/local/dhcpd/shell/d6active.sh -p > ${CMD_DIR}/d6active.sh-p.txt 2>&1        ; check_command_result "/usr/local/dhcpd/shell/d6active.sh -p" "cmd" ) 
	
	for i in `${BLKID} | /bin/awk '{print $1}'`
	do
    BLK_DEVICE=${i%:}
		if [ -b ${BLK_DEVICE} ] ; then
			( /sbin/parted -s ${BLK_DEVICE} unit s print > ${CMD_DIR}/parted/parted`echo ${BLK_DEVICE//\//_} | sed -e "s/:/_/"`_unit-s_print.txt 2>&1; check_command_result "/sbin/parted -s ${BLK_DEVICE} unit s print" "cmd" )
			( /sbin/parted -s ${BLK_DEVICE} unit b print > ${CMD_DIR}/parted/parted`echo ${BLK_DEVICE//\//_} | sed -e "s/:/_/"`_unit-b_print.txt 2>&1; check_command_result "/sbin/parted -s ${BLK_DEVICE} unit b print" "cmd" )
		else
			break
		fi
	done		
	

    ls -1 /dev/sd* | while read line; do echo ${line%%[0-9]*}; done | sort | uniq | \
    while read line2
    do
        ( /sbin/parted -s ${line2} unit mib p > ${CMD_DIR}/parted/parted`echo ${line2//\//_}`_unit-mib_print.txt 2>&1 ;check_command_result "/sbin/parted -s ${line2} unit mib p" "cmd" )
        ( /sbin/parted -s ${line2} unit s   p > ${CMD_DIR}/parted/parted`echo ${line2//\//_}`_unit-s_print.txt 2>&1   ;check_command_result "/sbin/parted -s ${line2} unit s   p" "cmd" )
    done


	PARTN=`/bin/mount |/bin/grep -w "ext[3-4]" |/bin/awk '{print $1}'`
	
	for i in ${PARTN}
	do
		{ /sbin/tune2fs -l $i > ${CMD_DIR}/tune2fs-l_${i##*/}.txt 2>&1; check_command_result "/sbin/tune2fs -l $i" "cmd"; } &
		shift
	done

	PARTN_XFS=`/bin/mount |/bin/grep -w "xfs" |/bin/awk '{print $1}'`
	
	for i in ${PARTN_XFS}
	do
		{ /sbin/xfs_info $i     > ${CMD_DIR}/xfs_info_${i##*/}.txt    2>&1; check_command_result "/sbin/xfs_info $i" "cmd";     } &
		{ /sbin/xfs_admin -l $i > ${CMD_DIR}/xfs_admin-l_${i##*/}.txt 2>&1; check_command_result "/sbin/xfs_admin -l $i" "cmd"; } &
		shift
	done
	
	
	i=0
	while [ "${i}" -lt "${ETH_COUNT}" ]
	do
        	${ETHTOOL} eth${i} > ${CMD_DIR}/ethtool_eth${i}.txt 2>&1
        	check_command_result "${ETHTOOL} eth${i}" "cmd"
        	${ETHTOOL} -i eth${i} > ${CMD_DIR}/ethtool-i_eth${i}.txt 2>&1
        	check_command_result "${ETHTOOL} -i eth${i}" "cmd"
          ${UDEVADM} info -a -p /sys/class/net/${i} > ${CMD_DIR}/udevadm_info-a-p_eth${i}.txt 2>&1
        	i=`${EXPR} ${i} + 1`
	done &
	
	#######################
	# directory permission
	#######################
	if [ -f ${PERM_LIST} ] ; then
		echo -e "\n##### directory permission #####">>${TARGET_DIR}/result_perm.log
		
		for i in `${GREP} -v "^#" ${PERM_LIST}`
		do
			[ -d ${i} -o -f ${i} ] && { ${LS} -ld $i |${TR} -s ' '  | ${CUT} -d ' ' -f 1,3-4,9 | ${SED} -e "s/ /\t/g">> ${TARGET_DIR}/permission/dir_permission.tmp; check_command_result "${LS} -ld ${i}" "perm"; }
		done &
		#echo "">>${TARGET_DIR}/result.log
		
		wait
		
		echo -e "\n# compress ${CP_DIR}/messages" >> ${TARGET_DIR}/result_cp.log
    ( cd ${CP_DIR} ; ${TAR} cvzf messages.tar.gz messages ) >> ${TARGET_DIR}/result_cp.log 2>&1 ; check_command_result "${TAR} cvzf ${CP_DIR}/messages.tar.gz ${CP_DIR}/messages" "cp"
		${RM} -rf ${CP_DIR}/messages
		
		${CAT} ${TARGET_DIR}/permission/dir_permission.tmp | ${SORT} -k 4,4 > ${TARGET_DIR}/permission/dir_permission.log
		${RM} -f ${TARGET_DIR}/permission/file_permission.tmp
		${RM} -f ${TARGET_DIR}/permission/dir_permission.tmp
	else
		wait
	fi	



  
	
	##################
	# log join
	##################
	for i in result_cp.log result_cmd.log result_ls.log result_perm.log
	do
   	if [[ -f ${TARGET_DIR}/${i} ]]
   		then
   	   	${CAT} ${TARGET_DIR}/${i} >>${TARGET_DIR}/result_all.log && \
	      	${RM} -f ${TARGET_DIR}/${i}
   	fi
	done
	
	##################
	# compression
	##################
	
	echo ""                     | ${TEE} -a ${TARGET_DIR}/result_all.log
	echo "####################" | ${TEE} -a ${TARGET_DIR}/result_all.log
	echo "#compression..."      | ${TEE} -a ${TARGET_DIR}/result_all.log
	echo "####################" | ${TEE} -a ${TARGET_DIR}/result_all.log
	sleep 3
	${TAR} cvzf ${TARGET_DIR}.tar.gz ${TARGET_DIR}/* > /dev/null 2>&1
	
	check_command_result "compression ${TARGET_DIR}.tar.gz" "all"
	
	chmod 777 ${TARGET_DIR}.tar.gz
	chmod 777 ../collect_info
	${LS} -l ${TARGET_DIR}.tar.gz | ${TEE} -a ${TARGET_DIR}/result_all.log
	echo ""                       | ${TEE} -a ${TARGET_DIR}/result_all.log

}





while [ ${#} -gt "0" ]
do
   case ${1} in
   -h|--help)
            help_option
            exit 0
         ;;

   -d|--debug)
         set -x
         ;;

   -b|--backup)
        if [[ "${2}"  =~ -.*  || x"${2}" = x ]] ;then
            echo "$@ Invalid argments."
            help_option
            exit 1
        fi

         BKUP_FLG=1
         BKUPDIR="$2"
         shift
        ;;

   *)
         echo "[ERROR] Invalid option '${1}'"
         usage
         exit 1
         ;;
   esac
   shift
done
exec_collect_info

exit 0

