#!/bin/bash
set -x
OSNAME=$(uname -s)
if [[ $OSNAME == "Linux" ]]
then
	ORACLE_SID=rssnew;export ORACLE_SID
	ORACLE_HOME=/u01/app/oracle/product/12.1.0/dbhome_1;export ORACLE_HOME;
	NLS_LANG=English_America.AL32UTF8;export NLS_LANG; 
	LANG=en_US.UTF-8;export LANG;
	ORACLE_BIN=$ORACLE_HOME/bin
	SQLPLUS=$ORACLE_BIN/sqlplus
	HOME_DIR=/home/rsssale
	LOG=$HOME_DIR/rsssale.log
	LOG_FTP=$HOME_DIR/rsssale_ftp.log
	TRANSFERCOMPLETE="226 Successfully transferred"
else
	if [[ $OSNAME == "Darwin" ]]
	then
		ORACLE_SID=rssnew;export ORACLE_SID
		ORACLE_HOME=/usr/local/oracle/oraclient;export ORACLE_HOME;
		DYLD_LIBRARY_PATH=/usr/local/oracle/oraclient;export DYLD_LIBRARY_PATH
		ORACLE_BIN=/usr/local/oracle/oraclient
		SQLPLUS=$ORACLE_BIN/sqlplus
		HOME_DIR=/Users/ilya/rss/rsssale
		LOG=$HOME_DIR/rsssale.log
		LOG_FTP=$HOME_DIR/rsssale_ftp.log
		TRANSFERCOMPLETE="226 Successfully transferred"
	else
		echo ${A-`date "+%Y-%m-%d %H:%M:%S"`}" OS $OSNAME undef."  | tee -a $LOG
		exit 1;
	fi
fi

FILE_STATUS_READY=4
FILE_STATUS_UNLOAD=5
FILE_UNLOAD_NAME=unload.sql
FILE_UNLOAD_SCRIPT=$HOME_DIR/$FILE_UNLOAD_NAME

SPOOL_DIR=$HOME_DIR/trans
SENDED_DIR=$HOME_DIR/sended
#
USERID=rssman/xdr5tgb@${ORACLE_SID}
SQLPLUS_KEY=-silent

echo ${A-`date "+%Y-%m-%d %H:%M:%S"`}" **** \"$0\" on  \"$OSNAME\" started"  | tee -a $LOG
case "$1" in
  rostokino)
	HOST=imf.sales-flow.ru
	PORT=3021
	LOGIN=Opticcity 
	PASSWORD=Cn52gXbs
	;;
  otradnoe)
	HOST=imf.sales-flow.ru
	PORT=3021
	LOGIN=opticcity_zvo
	PASSWORD=gMwSeb2W
	;;
  
  *)
	echo $"Usage: $PROG {rostokino|otradnoe}"
	exit 1
esac
NODE=$1
echo ${A-`date "+%Y-%m-%d %H:%M:%S"`}" **** \"$0\" on  \"$OSNAME\" started"  | tee -a $LOG
echo ${A-`date "+%Y-%m-%d %H:%M:%S"`}" Create unload scrip  started."  | tee -a $LOG
rm -f $FILE_UNLOAD_SCRIPT 
$SQLPLUS  $SQLPLUS_KEY $USERID <<EOF
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF TERMOUT OFF TRIMSPOOL ON LINESIZE 1000
spool $FILE_UNLOAD_SCRIPT
select * from (
select xsm.file_unload_script from wrh_xml_sale_files xsm
where xsm.status = $FILE_STATUS_READY
order by id
) where rownum = 1
;
spool off;
exit;
EOF

FILE_NAME=`grep "SPOOL" ${FILE_UNLOAD_SCRIPT} | awk '{print $2;}'`
FILE_ID=`grep "where" ${FILE_UNLOAD_SCRIPT} | awk '{print $4;}'`
cd $SPOOL_DIR
$SQLPLUS $SQLPLUS_KEY $USERID @${FILE_UNLOAD_SCRIPT}
echo ${A-`date "+%Y-%m-%d %H:%M:%S"`}" File with id=$FILE_ID and name $FILE_NAME unloaded."  | tee -a $LOG
#  convert cp1251 into utf8
#mv $FILE_NAME{,.orig} && iconv -f CP1251 -t UTF-8 ${FILE_NAME}.orig -o $FILE_NAME
$SQLPLUS  $SQLPLUS_KEY  $USERID <<EOF
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF TERMOUT OFF TRIMSPOOL ON LINESIZE 1000
update wrh_xml_sale_files xsm
set xsm.status=$FILE_STATUS_UNLOAD
where xsm.status = $FILE_STATUS_READY and xsm.id=$FILE_ID;
/
commit;
/
exit;
EOF
echo ${A-`date "+%Y-%m-%d %H:%M:%S"`}" File whith id=$FILE_ID and name $FILE_NAME processed successfuly."  | tee -a $LOG
