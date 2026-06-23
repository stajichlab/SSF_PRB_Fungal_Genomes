#!/usr/bin/bash -l
#SBATCH -p short -c  2 --mem 2gb -N 1 -n 1

module load ncbi-table2asn
module load ncbi-asn_tools
BASE=Exophiala_mansonii_UM1755
SBT=../../lib/sbt/UM1755.sbt
table2asn -l paired-ends -V v -M n -c ef -i $BASE.fsa -o $BASE.sqn -Z \
	-t $SBT -euk -j "[organism=Exophiala mansonii] [strain=UM1755] [gcode=1]"

asn2all -i $BASE.sqn -f d -v $BASE.aa -o $BASE.cds
