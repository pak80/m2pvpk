#!/bin/bash
#-----------------------------------------------------------------------------

safex_cat() {
  XXFILE=$1
  if [ -f "${XXFILE}" ] ; then
    cat ${XXFILE} | sed "s/[[:cntrl:][:punct:]]//g"
  else
    echo $2
  fi
}

safex_treecat() {
  # arg 1 is file to look for
  # arg 2 is default value used when file is not found
  XXFILE=$1
  if [ ! -f "${XXFILE}" ] ; then 
    XXFILE=../${XXFILE}
  fi 
  if [ -f "${XXFILE}" ] ; then 
    cat ${XXFILE} | sed "s/[[:cntrl:][:punct:]]//g"
  else
    echo $2
  fi
}

safe_treecat() {
  # arg 1 is file to look for
  # arg 2 is default value used when file is not found
  XXFILE=$1
  if [ ! -f "${XXFILE}" ] ; then 
    XXFILE=../${XXFILE}
  fi 
  if [ -f "${XXFILE}" ] ; then 
    cat ${XXFILE} | sed "s/[[:cntrl:]]//g"
  else
    echo $2
  fi
}

safex_tree() {
  # arg 1 is file to look for
  # arg 2 is default filename used when file is not found
  XXFILE=$1
  if [ ! -f "${XXFILE}" ] ; then 
    XXFILE=../${XXFILE}
  fi 
  if [ -f "${XXFILE}" ] ; then 
    echo ${XXFILE}
  else
    echo $2 
  fi
}

#-----------------------------------------------------------------------------

locate_data() {
  QFILE=$1
  QNAME=$2
  QTIME=$3
  QTBAK=$4
  SFILE=${QFILE}-${QNAME}-${QTIME}.h5
  if [ -f "${SFILE}" ] ; then 
    # there is a time specific data set so all is ok
    DASET=${QNAME}
  else
    # there is NO time specific data set so look for a static one
    SFILE=${QFILE}-${QNAME}-${QTBAK}.h5
    if [ -f "${SFILE}" ] ; then 
      DASET=${QNAME}
    else
      # there is NO timed or static data set, so set zero
      SFILE=geom.h5
      DASET=zero
    fi
  fi
  echo $SFILE $DASET
}

locate_template() {
  QFILE=$1
  if [ -f "${QFILE}" ] ; then 
    echo $QFILE
  elif [ -f "../${QFILE}" ] ; then 
    echo ../$QFILE
  else
    # (even) if this isn't there, the error wll be caught later
    echo ${HOME}/lib/${QFILE}
  fi
}

    
#-----------------------------------------------------------------------------


CORENAME=m2pvpk

if [ "$1" = "help" ] ; then 
  echo "${CORENAME}_meep: help is not currently implemented to any great extent"
  echo 
  echo "This is a bash shell script which does a lot of unix stream editing"
  echo "to turn templates into a complete (or at least workable) xdmf file"
  echo "that ParaView can load and display. It currently expects individual files"
  echo "at each time point."

  echo 
  echo "Behaviour is controlled by special local files prefixed with P. If a local"
  echo "version is not present, it will look at the parent directories, or"
  echo "(try to) assume something sensible."
  echo "The files are:"
  echo "    P.name     - the simulation name as per the meep ctl file"
  echo "    P.xdmflist - the list of meep outputs to put into the xdmf file"
  echo "               - this is a space-separated list of colon-separated triples"
  echo "               - 1. vector|scalar"
  echo "               - 2. hdf5 element name"
  echo "               - 3. readable name"
  echo 
  echo "WARNING:"
  echo 
  echo "Be aware that Paraview reads arrays in a different order to meep so that"
  echo "meep axes of XYZ show up in ParaView in the order zyx (i.e. X and z are swapped)."
  exit
fi

echo

HFILE=$1
if [ -z "${HFILE}" ] ; then 
  CTLGUESS=$(ls *ctl | head -1)
  CTLGUESS=${CTLGUESS%.ctl}
  if [ -z "${CTLGUESS}" ] ; then 
    CTLGUESS=testwire
  fi
  HFILE=$(safex_cat P.name ${CTLGUESS})
  echo $0: name is $HFILE
fi
ELABEL="${CORENAME}_meep("${HFILE}")"

mkdir -p old
SEDFILE=${HFILE}.sed
echo > ${SEDFILE}
LOGFILE=${HFILE}.xdmf.log ; mv ${LOGFILE} old/${LOGFILE}

if [ -z "$2" ] ; then 
  MEGALIST=$(ls ${HFILE}-ex-*.h5 | grep -v eps | sed "s/${HFILE}-ex-//" | sed 's/.h5//' )
else
  MEGALIST=$(ls ${HFILE}-$2-*.h5 | grep -v eps | sed "s/${HFILE}-ex-//" | sed 's/.h5//' )
fi 
echo ${ELABEL}: $MEGALIST > ${LOGFILE}
echo ${ELABEL}: times/frames $(echo $MEGALIST | wc -w)

VARLIST=$(safe_treecat P.xdmflist "vector:e:Electric_field scalar:eps:Permittivity")
echo ${ELABEL}: varlist is $VARLIST
echo ${ELABEL}: nb: Paraview swaps axes XYZ to zyx

echo ${ELABEL}: WARNING NOTICE - template processing uses triple underscore to delineate substitutions


  #- - - - - - - - - - 

# pick the first (by sort) h5 file that is lying around and use it to extract/set-up the geometry
# use a sort so that we can be more sure WHICH file will be chosen, in case it matters
  HFILE_ANY=$(ls ${HFILE}*h5 | sort | head -1)
  HFILE_ANYINFO=$(h5ls ${HFILE_ANY} | head -1)
  HFILE_ANYDASET=$(echo ${HFILE_ANYINFO} | awk '{print$1}')
  echo ${ELABEL}: extracting geometry from $HFILE_ANY and use nominal dataset $HFILE_ANYDASET

  GRIDPOINTS=$(echo ${HFILE_ANYINFO} | awk -F\{ '{print$2}' | awk -F\} '{print$1}' | sed 's/,/ /g' | head -1)
  GRIDPVXX=$(echo ${GRIDPOINTS} | awk '{print$1}')
  GRIDPVYY=$(echo ${GRIDPOINTS} | awk '{print$2}')
  GRIDPVZZ=$(echo ${GRIDPOINTS} | awk '{print$3}') 

  GRIDOFFX=$(echo "-(${GRIDPVXX}-1)/2" | bc -l)
  GRIDOFFY=$(echo "-(${GRIDPVYY}-1)/2" | bc -l)
  GRIDOFFZ=$(echo "-(${GRIDPVZZ}-1)/2" | bc -l)

  XXXGRIDNAME=${HFILE}
  XXXGRIDXYZ=${GRIDPOINTS}
  XXXGRIDORIGIN=" ${GRIDOFFX} ${GRIDOFFY} ${GRIDOFFZ} "
  XXXGRIDSPACING="1.00 1.00 1.00"
  XXXGRIDFILE=${HFILE}

  echo "
s/___DFORMAT___/HDF/
s/___GRIDNAME___/${XXXGRIDNAME}/
s/___GRIDXYZ___/${XXXGRIDXYZ}/g
s/___GRIDORIGIN___/${XXXGRIDORIGIN}/
s/___GRIDSPACING___/${XXXGRIDSPACING}/
s/___GRIDFILE___/${XXXGRIDFILE}/g" >> ${SEDFILE}

#- - - - - - - - - - 
if [ ! -f geom.h5 ] ; then 
  # make some dummy data as a drop-in, in case of missing files later
  h5math -e "0.00*d1"      -d zero geom.h5 ${HFILE_ANY}:${HFILE_ANYDASET}
  h5math -e "0.00*d1+1" -a -d unit geom.h5 ${HFILE_ANY}:${HFILE_ANYDASET}
fi

TIMELISTRAW=$MEGALIST
TIMELIST=
for TT in $TIMELISTRAW
do
  # strip up to 7 leading zeros
  TX=${TT#0000}
  TY=${TX#00}
  TIMELIST=${TIMELIST}" "${TY#0}
done
TIMEDIM=$(echo $TIMELIST | wc -w)

# actually template uses uses HyperSlab not Timelist, 
# so should specify START, INCREMENT, NUMBER not $TIMELIST

  echo "
s/___TIMELIST___/${TIMELIST}/
s/___TIMEDIM___/${TIMEDIM}/g" >> ${SEDFILE}


FTEMPLATE=$(locate_template ${CORENAME}.head.template)
if [ ! -f "${FTEMPLATE}" ] ; then 
  echo ${ELABEL}:  no head template ${FTEMPLATE}
  exit
else
  sed -f ${SEDFILE} ${FTEMPLATE} > ${HFILE}.xdmf
fi

ITT=0
for TT in $TIMELISTRAW
do
  ITT=$(( ${ITT} + 1 ))
  /bin/echo -n .

  # set up the time label (this bit only needs TIMEINDEX)
  FTEMPLATE=$(locate_template ${CORENAME}.framehead.template)
  sed "s/___TIMEINDEX___/${ITT}/" ${FTEMPLATE} |  \
    sed "s/___TIMENAME___/${TT}/" >>  ${HFILE}.xdmf
  
  for VVV in $VARLIST
  do
     VTYPE=$( echo $VVV | awk -F: '{print$1}')
     VNAME=$( echo $VVV | awk -F: '{print$2}')
     VLABEL=$(echo $VVV | awk -F: '{print$3}')
     echo > ${SEDFILE}.t

     # currently this requires individual h5 files at each time point
     #  but in future (if) I can specify file:set[pos;strides] in the xdmf -
     #  as per h5ls/h5dump - then unitary multi-time files could be used.
 
     case $VTYPE in
       vector)
         INFO_X=$( locate_data ${HFILE} ${VNAME}x ${TT} DNX )
           HFILE_X=$(echo $INFO_X | awk '{print$1}')
           DASET_X=$(echo $INFO_X | awk '{print$2}')
         INFO_Y=$( locate_data ${HFILE} ${VNAME}y ${TT} DNX )
           HFILE_Y=$(echo $INFO_Y | awk '{print$1}')
           DASET_Y=$(echo $INFO_Y | awk '{print$2}')
         INFO_Z=$( locate_data ${HFILE} ${VNAME}z ${TT} DNX )
           HFILE_Z=$(echo $INFO_Z | awk '{print$1}')
           DASET_Z=$(echo $INFO_Z | awk '{print$2}')
   
         echo ${ELABEL}:  $VTYPE for ${TT} is ${HFILE_X}:${DASET_X} ${HFILE_Y}:${DASET_Y} ${HFILE_Z}:${DASET_Z} > $LOGFILE

         # needs some of the global info
         cp ${SEDFILE} ${SEDFILE}.t
         echo "
s/___VECTORNAME___/${VLABEL}/
s/___VECTORDATAX___/${HFILE_X}:${DASET_X}/
s/___VECTORDATAY___/${HFILE_Y}:${DASET_Y}/
s/___VECTORDATAZ___/${HFILE_Z}:${DASET_Z}/"  >> ${SEDFILE}.t

         FTEMPLATE=$(locate_template ${CORENAME}.vector.template)
         if [ ! -f "${FTEMPLATE}" ] ; then 
           echo ${ELABEL}:  no frame template $II $ITT
           exit
         else
           sed -f ${SEDFILE}.t ${FTEMPLATE} >> ${HFILE}.xdmf
         fi
       ;;
       scalar)
         INFO_S=$( locate_data ${HFILE} ${VNAME} ${TT} 000000.00 )
           HFILE_S=$(echo $INFO_S | awk '{print$1}')
           DASET_S=$(echo $INFO_S | awk '{print$2}')

         echo ${ELABEL}:  $VTYPE for ${TT} is ${HFILE_S}:${DASET_S} > $LOGFILE

         # needs some of the global info
         cp ${SEDFILE} ${SEDFILE}.t
         echo "
s/___SCALARNAME___/${VLABEL}/
s/___SCALARDATA___/${HFILE_S}:${DASET_S}/"  >> ${SEDFILE}.t

         FTEMPLATE=$(locate_template ${CORENAME}.scalar.template)
         if [ ! -f "${FTEMPLATE}" ] ; then 
           echo ${ELABEL}:  no frame template $II $ITT
           exit
         else
           sed -f ${SEDFILE}.t ${FTEMPLATE} >> ${HFILE}.xdmf
         fi
       ;;
       *)
         echo ${ELABEL}: no such variable type $VVV $II $ITT
       esac

  done

  FTEMPLATE=$(locate_template ${CORENAME}.frametail.template)
  cat $FTEMPLATE >> ${HFILE}.xdmf

done





  echo # no more progress dots needed

  FTEMPLATE=$(locate_template ${CORENAME}.tail.template)
  if [ ! -f "${FTEMPLATE}" ] ; then 
    echo ${ELABEL}:  no tail template ${FTEMPLATE}
    exit 
  else
    cat ${FTEMPLATE} >> ${HFILE}.xdmf
  fi

echo ${ELABEL}: 
echo
